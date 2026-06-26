"use strict";

const crypto = require("node:crypto");

const ERROR_CODES = Object.freeze({
  unauthenticated: "unauthenticated",
  invalidArgument: "invalid_argument",
  calleeNotFound: "callee_not_found",
  userBusy: "user_busy",
  idempotencyConflict: "idempotency_conflict",
  callIdConflict: "call_id_conflict",
  lockRecoveryRequired: "lock_recovery_required",
  transactionFailed: "transaction_failed",
  callNotFound: "call_not_found",
  forbidden: "forbidden",
  invalidState: "invalid_state",
});

const ACTION_START_CALL = "startCall";
const ACTION_ACCEPT_CALL = "acceptCall";
const ACTION_DECLINE_CALL = "declineCall";
const ACTION_CANCEL_CALL = "cancelCall";
const ACTION_END_CALL = "endCall";
const ACTION_REPORT_PARTICIPANT_MEDIA = "reportParticipantMedia";
const ACTION_PROCESS_CALL_TIMEOUT = "processCallTimeout";
const ACTION_RENEW_ACTIVE_CALL_LEASE = "renewActiveCallLease";
const ACTION_PROCESS_ACTIVE_LEASE_TIMEOUT = "processActiveLeaseTimeout";
const CALL_SCHEMA_VERSION = 2;
const RINGING_DURATION_MS = 45 * 1000;
const ACCEPTED_JOIN_DURATION_MS = 30 * 1000;
const RECONNECT_GRACE_DURATION_MS = 25 * 1000;
const ACTIVE_LEASE_DURATION_MS = 60 * 1000;
const LOCK_EXPIRY_SAFETY_BUFFER_MS = 5 * 1000;
const COMMAND_TTL_MS = 7 * 24 * 60 * 60 * 1000;
const OPS_RETENTION_MS = 30 * 24 * 60 * 60 * 1000;
const PUBLIC_HISTORY_RETENTION_MS = 90 * 24 * 60 * 60 * 1000;
const TASK_OUTBOX_SCHEMA_VERSION = 1;
const TASK_OUTBOX_RETENTION_MS = 30 * 24 * 60 * 60 * 1000;
const TASK_DISPATCH_CLAIM_DURATION_MS = 2 * 60 * 1000;
const TASK_DISPATCH_MAX_ATTEMPTS = 20;
const TASK_DISPATCH_ERROR_CODE_MAX_LENGTH = 120;
const MAX_IDEMPOTENCY_KEY_LENGTH = 160;
const MAX_UID_LENGTH = 160;
const SUPPORTED_MEDIA_STATES = Object.freeze([
  "not_joined",
  "preparing",
  "joining",
  "joined",
  "reconnecting",
  "disconnected",
  "left",
  "media_failed",
]);
const MEDIA_TRANSITIONS = Object.freeze({
  not_joined: Object.freeze(["preparing", "joining", "joined", "media_failed"]),
  preparing: Object.freeze(["joining", "joined", "media_failed", "left"]),
  joining: Object.freeze(["joined", "disconnected", "media_failed", "left"]),
  joined: Object.freeze(["reconnecting", "disconnected", "media_failed", "left"]),
  reconnecting: Object.freeze(["joined", "disconnected", "media_failed", "left"]),
  disconnected: Object.freeze(["reconnecting", "joined", "media_failed", "left"]),
  media_failed: Object.freeze(["preparing", "left"]),
  left: Object.freeze([]),
});
const TIMEOUT_KINDS = Object.freeze([
  "ringing",
  "accepted_join",
  "reconnect",
]);
const TASK_KINDS = Object.freeze({
  ringingTimeout: "ringing_timeout",
  acceptedJoinTimeout: "accepted_join_timeout",
  reconnectTimeout: "reconnect_timeout",
  activeLeaseTimeout: "active_lease_timeout",
});
const TASK_TIMEOUT_KIND_BY_TASK_KIND = Object.freeze({
  ringing_timeout: "ringing",
  accepted_join_timeout: "accepted_join",
  reconnect_timeout: "reconnect",
});
const TASK_OUTBOX_STATUSES = Object.freeze([
  "pending",
  "dispatching",
  "dispatched",
  "dead_letter",
]);
const TASK_PUBLISHER_OUTCOMES = Object.freeze([
  "created",
  "already_exists",
]);
const TASK_EXECUTION_ACK_OUTCOMES = Object.freeze([
  "terminalized",
  "stale",
  "already_terminal",
  "missing",
]);
const TIMEOUT_CONFIG = Object.freeze({
  ringing: Object.freeze({
    lifecycleState: "ringing",
    deadlineField: "ringingDeadlineAt",
    terminalState: "missed",
    endReason: "ringing_timeout",
    failureCode: null,
  }),
  accepted_join: Object.freeze({
    lifecycleState: "accepted",
    deadlineField: "acceptedJoinDeadlineAt",
    terminalState: "failed",
    endReason: "accepted_join_timeout",
    failureCode: "accepted_join_timeout",
  }),
  reconnect: Object.freeze({
    lifecycleState: "active",
    deadlineField: "reconnectDeadlineAt",
    terminalState: "failed",
    endReason: "reconnect_timeout",
    failureCode: "reconnect_timeout",
  }),
});

class CallV2Error extends Error {
  constructor(code, message, details = undefined) {
    super(message);
    this.name = "CallV2Error";
    this.code = code;
    if (details !== undefined) {
      this.details = details;
    }
  }
}

class TaskPublisherError extends Error {
  constructor({ code, retryable }) {
    if (!isControlledDispatchErrorCode(code)) {
      throw new CallV2Error(
        ERROR_CODES.invalidArgument,
        "A controlled publisher error code is required.",
      );
    }
    if (typeof retryable !== "boolean") {
      throw new CallV2Error(
        ERROR_CODES.invalidArgument,
        "A publisher retryable flag is required.",
      );
    }
    super(code);
    this.name = "TaskPublisherError";
    this.code = code;
    this.retryable = retryable;
  }
}

function startCallV2({
  db,
  authUid,
  request,
  now,
  generateCallId,
}) {
  if (!db || typeof db.runTransaction !== "function") {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A Firestore database dependency is required.",
    );
  }

  const validatedRequest = validateStartCallInput(authUid, request);
  const nowDate = resolveNow(now);
  const callId = validateGeneratedId(generateCallId, "callId");
  const requestHash = sha256Hex(
    canonicalJson({
      calleeUid: validatedRequest.calleeUid,
      isVideo: validatedRequest.isVideo,
    }),
  );
  const idempotencyLookupId = sha256Hex(
    [
      validatedRequest.callerUid,
      ACTION_START_CALL,
      validatedRequest.idempotencyKey,
    ].join("\u0000"),
  );
  const commandId = `start_${sha256Hex(
    [
      validatedRequest.callerUid,
      ACTION_START_CALL,
      validatedRequest.idempotencyKey,
      requestHash,
      callId,
    ].join("\u0000"),
  ).slice(0, 48)}`;

  const ringingDeadlineAt = addMilliseconds(nowDate, RINGING_DURATION_MS);
  const lockExpiresAt = addMilliseconds(
    ringingDeadlineAt,
    LOCK_EXPIRY_SAFETY_BUFFER_MS,
  );
  const commandTtlAt = addMilliseconds(nowDate, COMMAND_TTL_MS);
  const opsRetentionExpiresAt = addMilliseconds(nowDate, OPS_RETENTION_MS);
  const callerRtcUid = deriveRtcUid(
    callId,
    validatedRequest.callerUid,
    "caller",
  );
  const calleeRtcUid = deriveDistinctRtcUid(
    callId,
    validatedRequest.calleeUid,
    "callee",
    callerRtcUid,
  );
  const agoraChannel = deriveAgoraChannel(callId);

  const response = Object.freeze({
    callId,
    lifecycleState: "ringing",
    version: 1,
    ringingDeadlineAt,
    callerRtcUid,
    calleeRtcUid,
    idempotentReplay: false,
  });

  const refs = buildRefs(db, {
    callerUid: validatedRequest.callerUid,
    calleeUid: validatedRequest.calleeUid,
    callId,
    idempotencyLookupId,
    commandId,
  });

  return db
    .runTransaction(async (transaction) => {
      const idempotencySnapshot = await transaction.get(refs.idempotencyRef);
      if (idempotencySnapshot.exists) {
        return handleExistingIdempotencyRecord(
          idempotencySnapshot.data(),
          {
            actorUid: validatedRequest.callerUid,
            action: ACTION_START_CALL,
          },
          requestHash,
        );
      }

      const sortedLockEntries = sortByDocumentId([
        { uid: validatedRequest.callerUid, ref: refs.callerLockRef },
        { uid: validatedRequest.calleeUid, ref: refs.calleeLockRef },
      ]);
      const lockSnapshots = [];
      for (const entry of sortedLockEntries) {
        lockSnapshots.push({
          ...entry,
          snapshot: await transaction.get(entry.ref),
        });
      }

      const referencedCallRefs = expiredLockCallRefs(db, lockSnapshots, nowDate);
      const referencedCallSnapshots = new Map();
      for (const callRef of referencedCallRefs) {
        referencedCallSnapshots.set(callRef.id, await transaction.get(callRef));
      }

      verifyLocksCanBeAcquired(
        lockSnapshots,
        referencedCallSnapshots,
        nowDate,
      );

      const collisionSnapshots = await readGeneratedIdCollisionTargets(
        transaction,
        refs,
      );
      verifyGeneratedIdIsUnused(collisionSnapshots);

      const calleeSnapshot = await transaction.get(refs.calleeUserRef);
      if (!calleeSnapshot.exists) {
        throw new CallV2Error(
          ERROR_CODES.calleeNotFound,
          "The requested callee does not exist.",
        );
      }

      const callerFencingToken = nextFencingToken(
        lockSnapshots,
        validatedRequest.callerUid,
      );
      const calleeFencingToken = nextFencingToken(
        lockSnapshots,
        validatedRequest.calleeUid,
      );

      const callerLock = buildLockDocument({
        uid: validatedRequest.callerUid,
        peerUid: validatedRequest.calleeUid,
        callId,
        nowDate,
        lockExpiresAt,
        commandId,
        fencingToken: callerFencingToken,
      });
      const calleeLock = buildLockDocument({
        uid: validatedRequest.calleeUid,
        peerUid: validatedRequest.callerUid,
        callId,
        nowDate,
        lockExpiresAt,
        commandId,
        fencingToken: calleeFencingToken,
      });

      transaction.create(refs.callRef, {
        schemaVersion: CALL_SCHEMA_VERSION,
        callSystem: "v2",
        lifecycleState: "ringing",
        terminal: false,
        version: 1,
        callerUid: validatedRequest.callerUid,
        calleeUid: validatedRequest.calleeUid,
        participantUids: [
          validatedRequest.callerUid,
          validatedRequest.calleeUid,
        ],
        mediaProvider: "agora",
        agoraChannel,
        isVideo: validatedRequest.isVideo,
        createdAt: nowDate,
        updatedAt: nowDate,
        ringingDeadlineAt,
        acceptedAt: null,
        // Server-owned audit field for the participant who accepts the call.
        acceptedByUid: null,
        acceptedJoinDeadlineAt: null,
        activeAt: null,
        reconnectDeadlineAt: null,
        endedAt: null,
        endedByUid: null,
        endReason: null,
        failureCode: null,
        historyVisible: true,
        historyExpiresAt: null,
        lastPublicEventAt: nowDate,
      });

      transaction.create(
        refs.callerParticipantRef,
        buildParticipantDocument({
          uid: validatedRequest.callerUid,
          role: "caller",
          rtcUid: callerRtcUid,
        }),
      );
      transaction.create(
        refs.calleeParticipantRef,
        buildParticipantDocument({
          uid: validatedRequest.calleeUid,
          role: "callee",
          rtcUid: calleeRtcUid,
        }),
      );

      transaction.set(refs.callerLockRef, callerLock);
      transaction.set(refs.calleeLockRef, calleeLock);

      transaction.create(refs.callOpsRef, {
        callId,
        createdAt: nowDate,
        terminalAt: null,
        latestOpsVersion: 1,
        opsRetentionExpiresAt,
        lockClaims: {
          caller: {
            uid: validatedRequest.callerUid,
            fencingToken: callerFencingToken,
          },
          callee: {
            uid: validatedRequest.calleeUid,
            fencingToken: calleeFencingToken,
          },
        },
      });

      transaction.create(refs.commandRef, {
        commandId,
        actorUid: validatedRequest.callerUid,
        action: ACTION_START_CALL,
        requestHash,
        idempotencyLookupId,
        callId,
        status: "completed",
        createdAt: nowDate,
        completedAt: nowDate,
        ttlAt: commandTtlAt,
      });

      transaction.create(refs.idempotencyRef, {
        actorUid: validatedRequest.callerUid,
        action: ACTION_START_CALL,
        requestHash,
        callId,
        result: response,
        createdAt: nowDate,
        completedAt: nowDate,
        ttlAt: commandTtlAt,
      });
      createTaskOutboxDocument(
        transaction,
        refs.callOpsRef,
        buildCallTimeoutTaskIntent({
          callId,
          taskKind: TASK_KINDS.ringingTimeout,
          expectedCallVersion: 1,
          expectedDeadlineAt: ringingDeadlineAt,
          createdAt: nowDate,
        }),
      );

      return response;
    })
    .catch((error) => {
      return recoverIdempotencyCreateConflictOrThrow({
        error,
        idempotencyRef: refs.idempotencyRef,
        expected: {
          actorUid: validatedRequest.callerUid,
          action: ACTION_START_CALL,
        },
        requestHash,
        fallbackMessage: "The start-call transaction failed.",
      });
    });
}

function acceptCallV2({ db, authUid, request, now }) {
  assertDbDependency(db);
  const validatedRequest = validateLifecycleCommandInput(authUid, request);
  const nowDate = resolveNow(now);
  const acceptedAt = nowDate;
  const acceptedJoinDeadlineAt = addMilliseconds(
    acceptedAt,
    ACCEPTED_JOIN_DURATION_MS,
  );
  const command = buildLifecycleCommandContext({
    actorUid: authUid,
    action: ACTION_ACCEPT_CALL,
    callId: validatedRequest.callId,
    idempotencyKey: validatedRequest.idempotencyKey,
    controlledPayload: {},
  });
  const refs = buildLifecycleRefs(db, {
    callId: validatedRequest.callId,
    actorUid: authUid,
    idempotencyLookupId: command.idempotencyLookupId,
    commandId: command.commandId,
  });

  return db
    .runTransaction(async (transaction) => {
      const idempotencySnapshot = await transaction.get(refs.idempotencyRef);
      if (idempotencySnapshot.exists) {
        return handleExistingIdempotencyRecord(
          idempotencySnapshot.data(),
          { actorUid: authUid, action: ACTION_ACCEPT_CALL },
          command.requestHash,
        );
      }

      const callSnapshot = await transaction.get(refs.callRef);
      const call = requireMutableV2Call(callSnapshot, validatedRequest.callId);
      const callOpsSnapshot = await transaction.get(refs.callOpsRef);
      const callOps = requireCallOps(callOpsSnapshot, validatedRequest.callId);
      const actorParticipantSnapshot = await transaction.get(
        refs.actorParticipantRef,
      );
      const lockSnapshots = await readParticipantLockSnapshots(
        transaction,
        db,
        call,
      );

      requireParticipantAuthorization(actorParticipantSnapshot, call, authUid);
      if (authUid !== call.calleeUid) {
        throw new CallV2Error(
          ERROR_CODES.forbidden,
          "Only the callee may accept this call.",
        );
      }
      if (call.terminal || call.lifecycleState !== "ringing") {
        throw new CallV2Error(
          ERROR_CODES.invalidState,
          "Only a ringing call can be accepted.",
        );
      }
      requireOpenRingingWindow(call, nowDate);

      const claims = requireLockClaims(callOps, call);
      requireMatchingLocksForAccept(
        lockSnapshots.byRole,
        claims,
        call.id,
        nowDate,
      );

      const nextCallVersion = nextMonotonicVersion(call.version);
      const nextOpsVersion = nextMonotonicVersion(callOps.latestOpsVersion);
      const lockExpiresAt = addMilliseconds(
        acceptedJoinDeadlineAt,
        LOCK_EXPIRY_SAFETY_BUFFER_MS,
      );
      const result = Object.freeze({
        callId: call.id,
        lifecycleState: "accepted",
        version: nextCallVersion,
        acceptedAt,
        acceptedJoinDeadlineAt,
        idempotentReplay: false,
      });

      transaction.update(refs.callRef, {
        lifecycleState: "accepted",
        version: nextCallVersion,
        acceptedAt,
        acceptedByUid: authUid,
        acceptedJoinDeadlineAt,
        updatedAt: nowDate,
        lastPublicEventAt: nowDate,
      });
      transaction.update(refs.actorParticipantRef, {
        acceptedAt,
      });
      updateAcceptedLock(transaction, lockSnapshots.byRole.caller.ref, {
        nowDate,
        lockExpiresAt,
      });
      updateAcceptedLock(transaction, lockSnapshots.byRole.callee.ref, {
        nowDate,
        lockExpiresAt,
      });
      transaction.update(refs.callOpsRef, {
        latestOpsVersion: nextOpsVersion,
        opsRetentionExpiresAt: addMilliseconds(nowDate, OPS_RETENTION_MS),
      });
      createCommandRecords(transaction, refs, {
        command,
        actorUid: authUid,
        action: ACTION_ACCEPT_CALL,
        callId: call.id,
        nowDate,
        result,
      });
      createTaskOutboxDocument(
        transaction,
        refs.callOpsRef,
        buildCallTimeoutTaskIntent({
          callId: call.id,
          taskKind: TASK_KINDS.acceptedJoinTimeout,
          expectedCallVersion: nextCallVersion,
          expectedDeadlineAt: acceptedJoinDeadlineAt,
          createdAt: nowDate,
        }),
      );

      return result;
    })
    .catch((error) =>
      recoverIdempotencyCreateConflictOrThrow({
        error,
        idempotencyRef: refs.idempotencyRef,
        expected: { actorUid: authUid, action: ACTION_ACCEPT_CALL },
        requestHash: command.requestHash,
        fallbackMessage: "The call command transaction failed.",
      }),
    );
}

function declineCallV2({ db, authUid, request, now }) {
  return runTerminalLifecycleCommand({
    db,
    authUid,
    request,
    now,
    action: ACTION_DECLINE_CALL,
    targetLifecycleState: "declined",
    endReason: "declined",
    allowedRoles: ["callee"],
    allowedLifecycleStates: ["ringing"],
  });
}

function cancelCallV2({ db, authUid, request, now }) {
  return runTerminalLifecycleCommand({
    db,
    authUid,
    request,
    now,
    action: ACTION_CANCEL_CALL,
    targetLifecycleState: "cancelled",
    endReason: "cancelled",
    allowedRoles: ["caller"],
    allowedLifecycleStates: ["ringing"],
  });
}

function endCallV2({ db, authUid, request, now }) {
  return runTerminalLifecycleCommand({
    db,
    authUid,
    request,
    now,
    action: ACTION_END_CALL,
    targetLifecycleState: "completed",
    endReason: "ended_by_participant",
    allowedRoles: ["caller", "callee"],
    allowedLifecycleStates: ["accepted", "active"],
  });
}

function reportParticipantMediaV2({ db, authUid, request, now }) {
  assertDbDependency(db);
  const validatedRequest = validateMediaReportInput(authUid, request);
  const nowDate = resolveNow(now);
  const command = buildLifecycleCommandContext({
    actorUid: authUid,
    action: ACTION_REPORT_PARTICIPANT_MEDIA,
    callId: validatedRequest.callId,
    idempotencyKey: validatedRequest.idempotencyKey,
    controlledPayload: {
      mediaState: validatedRequest.mediaState,
    },
  });
  const refs = buildLifecycleRefs(db, {
    callId: validatedRequest.callId,
    actorUid: authUid,
    idempotencyLookupId: command.idempotencyLookupId,
    commandId: command.commandId,
  });

  return db
    .runTransaction(async (transaction) => {
      const idempotencySnapshot = await transaction.get(refs.idempotencyRef);
      if (idempotencySnapshot.exists) {
        return handleExistingIdempotencyRecord(
          idempotencySnapshot.data(),
          {
            actorUid: authUid,
            action: ACTION_REPORT_PARTICIPANT_MEDIA,
          },
          command.requestHash,
        );
      }

      const callSnapshot = await transaction.get(refs.callRef);
      const call = requireMutableV2Call(callSnapshot, validatedRequest.callId);
      const callOpsSnapshot = await transaction.get(refs.callOpsRef);
      const callOps = requireCallOps(callOpsSnapshot, validatedRequest.callId);
      const participantSnapshots = await readCallParticipantSnapshots(
        transaction,
        refs.callRef,
        call,
      );
      const lockSnapshots = await readParticipantLockSnapshots(
        transaction,
        db,
        call,
      );

      const actorRole = roleForParticipant(call, authUid);
      if (!actorRole) {
        throw new CallV2Error(
          ERROR_CODES.forbidden,
          "The actor is not a participant in this call.",
        );
      }
      const participants = validateMediaParticipantSnapshots(
        participantSnapshots.byRole,
        call,
      );
      if (call.terminal) {
        throw new CallV2Error(
          ERROR_CODES.invalidState,
          "Terminal calls cannot accept new media reports.",
        );
      }

      validateMediaLifecycleAllowsReport({
        call,
        nowDate,
        participantMediaStates: {
          caller: participants.byRole.caller.data.mediaState,
          callee: participants.byRole.callee.data.mediaState,
        },
        currentMediaState: participants.byRole[actorRole].data.mediaState,
        requestedMediaState: validatedRequest.mediaState,
      });
      const claims = requireLockClaims(callOps, call);
      requireReportingParticipantLock({
        lockEntry: lockSnapshots.byRole[actorRole],
        claim: claims[actorRole],
        call,
        role: actorRole,
        nowDate,
      });

      const currentParticipant = participants.byRole[actorRole].data;
      const mediaChanged =
        currentParticipant.mediaState !== validatedRequest.mediaState;
      if (
        mediaChanged &&
        !isIncrementableMediaVersion(currentParticipant.mediaVersion)
      ) {
        throw new CallV2Error(
          ERROR_CODES.transactionFailed,
          "The participant media version cannot be safely incremented.",
        );
      }

      const resultingMediaStates = {
        caller: participants.byRole.caller.data.mediaState,
        callee: participants.byRole.callee.data.mediaState,
      };
      resultingMediaStates[actorRole] = validatedRequest.mediaState;

      const callUpdate = computeMediaCallUpdate({
        call,
        callOps,
        claims,
        lockSnapshots: lockSnapshots.byRole,
        resultingMediaStates,
        previousMediaState: currentParticipant.mediaState,
        nextMediaState: validatedRequest.mediaState,
        mediaChanged,
        nowDate,
      });
      const taskIntents = buildMediaTaskOutboxIntents({
        call,
        callUpdate,
        participants,
        claims,
        lockSnapshots: lockSnapshots.byRole,
        nowDate,
      });

      const nextOpsVersion = nextMonotonicVersion(callOps.latestOpsVersion);
      const nextMediaVersion = mediaChanged
        ? currentParticipant.mediaVersion + 1
        : currentParticipant.mediaVersion;
      const result = Object.freeze({
        callId: call.id,
        participantUid: authUid,
        mediaState: validatedRequest.mediaState,
        mediaVersion: nextMediaVersion,
        mediaChanged,
        lifecycleState: callUpdate.lifecycleState,
        callVersion: callUpdate.callVersion,
        promotedToActive: callUpdate.promotedToActive,
        activeAt: callUpdate.activeAt,
        reconnectDeadlineAt: callUpdate.reconnectDeadlineAt,
        idempotentReplay: false,
      });

      if (mediaChanged) {
        transaction.update(
          participants.byRole[actorRole].ref,
          buildMediaParticipantUpdate({
            participant: currentParticipant,
            nextMediaState: validatedRequest.mediaState,
            nextMediaVersion,
            nowDate,
          }),
        );
      }
      if (callUpdate.callFields) {
        transaction.update(refs.callRef, callUpdate.callFields);
      }
      for (const lockUpdate of callUpdate.lockUpdates) {
        transaction.update(lockUpdate.ref, lockUpdate.fields);
      }
      transaction.update(refs.callOpsRef, {
        latestOpsVersion: nextOpsVersion,
        opsRetentionExpiresAt: addMilliseconds(nowDate, OPS_RETENTION_MS),
      });
      createCommandRecords(transaction, refs, {
        command,
        actorUid: authUid,
        action: ACTION_REPORT_PARTICIPANT_MEDIA,
        callId: call.id,
        nowDate,
        result,
      });
      for (const intent of taskIntents) {
        createTaskOutboxDocument(transaction, refs.callOpsRef, intent);
      }

      return result;
    })
    .catch((error) =>
      recoverIdempotencyCreateConflictOrThrow({
        error,
        idempotencyRef: refs.idempotencyRef,
        expected: {
          actorUid: authUid,
          action: ACTION_REPORT_PARTICIPANT_MEDIA,
        },
        requestHash: command.requestHash,
        fallbackMessage: "The media report transaction failed.",
      }),
    );
}

function processCallTimeoutV2({ db, request, now }) {
  assertDbDependency(db);
  const nowDate = resolveNow(now);
  const validatedRequest = validateTimeoutRequestInput(request);
  const config = TIMEOUT_CONFIG[validatedRequest.timeoutKind];
  const command = buildTimeoutCommandContext(validatedRequest);
  const refs = buildTimeoutRefs(db, {
    callId: validatedRequest.callId,
    commandId: command.commandId,
  });

  return db
    .runTransaction(async (transaction) => {
      const commandSnapshot = await transaction.get(refs.commandRef);
      if (commandSnapshot.exists) {
        return handleExistingTimeoutCommandRecord(
          commandSnapshot.data(),
          {
            callId: validatedRequest.callId,
            timeoutKind: validatedRequest.timeoutKind,
            requestHash: command.requestHash,
          },
        );
      }

      const callSnapshot = await transaction.get(refs.callRef);
      if (!callSnapshot.exists) {
        return buildTimeoutNoopResult({
          callId: validatedRequest.callId,
          timeoutKind: validatedRequest.timeoutKind,
          status: "missing",
        });
      }

      const call = requireExistingV2CallForTimeout(
        callSnapshot,
        validatedRequest.callId,
      );
      if (call.terminal) {
        return buildTimeoutNoopResult({
          callId: call.id,
          timeoutKind: validatedRequest.timeoutKind,
          status: "already_terminal",
          call,
        });
      }
      if (
        call.lifecycleState !== config.lifecycleState ||
        call.version !== validatedRequest.expectedCallVersion
      ) {
        return buildTimeoutNoopResult({
          callId: call.id,
          timeoutKind: validatedRequest.timeoutKind,
          status: "stale",
          call,
        });
      }

      const authoritativeDeadline = requireTimeoutDeadline(
        call,
        validatedRequest.timeoutKind,
        config,
      );
      if (authoritativeDeadline.millis !== validatedRequest.expectedDeadlineMs) {
        return buildTimeoutNoopResult({
          callId: call.id,
          timeoutKind: validatedRequest.timeoutKind,
          status: "stale",
          call,
        });
      }
      validateTimeoutTemporalFields(call, validatedRequest.timeoutKind);
      if (nowDate.getTime() < authoritativeDeadline.millis) {
        return buildTimeoutNoopResult({
          callId: call.id,
          timeoutKind: validatedRequest.timeoutKind,
          status: "not_due",
          call,
        });
      }

      let participants = null;
      if (validatedRequest.timeoutKind === "reconnect") {
        const participantSnapshots = await readCallParticipantSnapshots(
          transaction,
          refs.callRef,
          call,
        );
        participants = validateMediaParticipantSnapshots(
          participantSnapshots.byRole,
          call,
        );
        if (
          participants.byRole.caller.data.mediaState === "joined" &&
          participants.byRole.callee.data.mediaState === "joined"
        ) {
          throw new CallV2Error(
            ERROR_CODES.transactionFailed,
            "The reconnect timeout state is inconsistent.",
          );
        }
      }

      const callOpsSnapshot = await transaction.get(refs.callOpsRef);
      const callOps = requireCallOps(callOpsSnapshot, call.id);
      const lockSnapshots = await readParticipantLockSnapshots(
        transaction,
        db,
        call,
      );
      const nextCallVersion = nextMonotonicVersion(call.version);
      const nextOpsVersion = nextMonotonicVersion(callOps.latestOpsVersion);
      const lockReleaseResults = releaseScopedLocks(
        transaction,
        lockSnapshots.byRole,
        callOps,
        call,
      );
      const historyExpiresAt = addMilliseconds(
        nowDate,
        PUBLIC_HISTORY_RETENTION_MS,
      );
      const result = Object.freeze({
        callId: call.id,
        timeoutKind: validatedRequest.timeoutKind,
        status: "terminalized",
        lifecycleState: config.terminalState,
        terminal: true,
        version: nextCallVersion,
        endedAt: nowDate,
        endReason: config.endReason,
        failureCode: config.failureCode,
        lockReleaseResults,
        idempotentReplay: false,
      });

      transaction.update(refs.callRef, {
        lifecycleState: config.terminalState,
        terminal: true,
        version: nextCallVersion,
        updatedAt: nowDate,
        lastPublicEventAt: nowDate,
        endedAt: nowDate,
        endedByUid: null,
        endReason: config.endReason,
        failureCode: config.failureCode,
        historyVisible: true,
        historyExpiresAt,
      });
      transaction.update(refs.callOpsRef, {
        latestOpsVersion: nextOpsVersion,
        terminalAt: nowDate,
        terminalState: config.terminalState,
        terminalReason: config.endReason,
        failureCode: config.failureCode,
        timeoutKind: validatedRequest.timeoutKind,
        timeoutDeadlineAt: authoritativeDeadline.value,
        timeoutProcessedAt: nowDate,
        lockReleaseResults,
        opsRetentionExpiresAt: addMilliseconds(nowDate, OPS_RETENTION_MS),
      });
      createTimeoutCommandRecord(transaction, refs.commandRef, {
        command,
        timeoutKind: validatedRequest.timeoutKind,
        expectedCallVersion: validatedRequest.expectedCallVersion,
        timeoutDeadlineAt: authoritativeDeadline.value,
        callId: call.id,
        nowDate,
        result,
      });

      return result;
    })
    .catch((error) =>
      recoverTimeoutCommandCreateConflictOrThrow({
        error,
        commandRef: refs.commandRef,
        expected: {
          callId: validatedRequest.callId,
          timeoutKind: validatedRequest.timeoutKind,
          requestHash: command.requestHash,
        },
        fallbackMessage: "The timeout transaction failed.",
      }),
    );
}

function renewActiveCallLeaseV2({ db, authUid, request, now }) {
  assertDbDependency(db);
  const validatedRequest = validateActiveLeaseRenewalInput(authUid, request);
  const nowDate = resolveNow(now);
  const leaseExpiresAt = addMilliseconds(nowDate, ACTIVE_LEASE_DURATION_MS);
  const command = buildLifecycleCommandContext({
    actorUid: authUid,
    action: ACTION_RENEW_ACTIVE_CALL_LEASE,
    callId: validatedRequest.callId,
    idempotencyKey: validatedRequest.idempotencyKey,
    controlledPayload: {
      heartbeatVersion: validatedRequest.heartbeatVersion,
    },
  });
  const refs = buildLifecycleRefs(db, {
    callId: validatedRequest.callId,
    actorUid: authUid,
    idempotencyLookupId: command.idempotencyLookupId,
    commandId: command.commandId,
  });

  return db
    .runTransaction(async (transaction) => {
      const idempotencySnapshot = await transaction.get(refs.idempotencyRef);
      if (idempotencySnapshot.exists) {
        return handleExistingIdempotencyRecord(
          idempotencySnapshot.data(),
          {
            actorUid: authUid,
            action: ACTION_RENEW_ACTIVE_CALL_LEASE,
          },
          command.requestHash,
        );
      }

      const callSnapshot = await transaction.get(refs.callRef);
      const call = requireMutableV2Call(callSnapshot, validatedRequest.callId);
      if (call.terminal || call.lifecycleState !== "active") {
        throw new CallV2Error(
          ERROR_CODES.invalidState,
          "Only an active call can renew its active lease.",
        );
      }
      const actorRole = roleForParticipant(call, authUid);
      if (!actorRole) {
        throw new CallV2Error(
          ERROR_CODES.forbidden,
          "The actor is not a participant in this call.",
        );
      }
      requireActiveTemporalFields(call);
      requireOpenReconnectWindowIfPresent(call, nowDate);

      const callOpsSnapshot = await transaction.get(refs.callOpsRef);
      const callOps = requireCallOps(callOpsSnapshot, validatedRequest.callId);
      const participantSnapshots = await readCallParticipantSnapshots(
        transaction,
        refs.callRef,
        call,
      );
      const participants = validateMediaParticipantSnapshots(
        participantSnapshots.byRole,
        call,
      );
      const lockSnapshots = await readParticipantLockSnapshots(
        transaction,
        db,
        call,
      );
      const claims = requireLockClaims(callOps, call);
      const participant = participants.byRole[actorRole].data;

      if (!["joined", "reconnecting"].includes(participant.mediaState)) {
        throw new CallV2Error(
          ERROR_CODES.invalidState,
          "The participant media state cannot renew an active lease.",
        );
      }
      if (!isIncrementableHeartbeatVersion(participant.heartbeatVersion)) {
        throw new CallV2Error(
          ERROR_CODES.transactionFailed,
          "The participant heartbeat version cannot be safely incremented.",
        );
      }
      if (
        validatedRequest.heartbeatVersion !==
        participant.heartbeatVersion + 1
      ) {
        throw new CallV2Error(
          ERROR_CODES.invalidState,
          "The heartbeat version is not the next expected version.",
        );
      }

      requireReportingActiveLeaseLock({
        lockEntry: lockSnapshots.byRole[actorRole],
        claim: claims[actorRole],
        call,
        role: actorRole,
        nowDate,
      });

      const nextOpsVersion = nextMonotonicVersion(callOps.latestOpsVersion);
      const taskIntents = call.reconnectDeadlineAt === null
        ? [
            buildActiveLeaseTimeoutTaskIntent({
              callId: call.id,
              participantUid: authUid,
              expectedCallVersion: call.version,
              expectedHeartbeatVersion: validatedRequest.heartbeatVersion,
              expectedFencingToken: claims[actorRole].fencingToken,
              expectedLeaseExpiresAt: leaseExpiresAt,
              createdAt: nowDate,
            }),
          ]
        : [];
      const result = Object.freeze({
        callId: call.id,
        participantUid: authUid,
        heartbeatVersion: validatedRequest.heartbeatVersion,
        lastHeartbeatAt: nowDate,
        leaseExpiresAt,
        lifecycleState: call.lifecycleState,
        callVersion: call.version,
        idempotentReplay: false,
      });

      transaction.update(participants.byRole[actorRole].ref, {
        heartbeatVersion: validatedRequest.heartbeatVersion,
        lastHeartbeatAt: nowDate,
      });
      transaction.update(lockSnapshots.byRole[actorRole].ref, {
        updatedAt: nowDate,
        expiresAt: leaseExpiresAt,
      });
      transaction.update(refs.callOpsRef, {
        latestOpsVersion: nextOpsVersion,
        opsRetentionExpiresAt: addMilliseconds(nowDate, OPS_RETENTION_MS),
      });
      createCommandRecords(transaction, refs, {
        command,
        actorUid: authUid,
        action: ACTION_RENEW_ACTIVE_CALL_LEASE,
        callId: call.id,
        nowDate,
        result,
      });
      for (const intent of taskIntents) {
        createTaskOutboxDocument(transaction, refs.callOpsRef, intent);
      }

      return result;
    })
    .catch((error) =>
      recoverIdempotencyCreateConflictOrThrow({
        error,
        idempotencyRef: refs.idempotencyRef,
        expected: {
          actorUid: authUid,
          action: ACTION_RENEW_ACTIVE_CALL_LEASE,
        },
        requestHash: command.requestHash,
        fallbackMessage: "The active lease renewal transaction failed.",
      }),
    );
}

function processActiveLeaseTimeoutV2({ db, request, now }) {
  assertDbDependency(db);
  const nowDate = resolveNow(now);
  const validatedRequest = validateActiveLeaseTimeoutRequestInput(request);
  const command = buildActiveLeaseTimeoutCommandContext(validatedRequest);
  const refs = buildTimeoutRefs(db, {
    callId: validatedRequest.callId,
    commandId: command.commandId,
  });

  return db
    .runTransaction(async (transaction) => {
      const commandSnapshot = await transaction.get(refs.commandRef);
      if (commandSnapshot.exists) {
        return handleExistingActiveLeaseTimeoutCommandRecord(
          commandSnapshot.data(),
          {
            callId: validatedRequest.callId,
            participantUid: validatedRequest.participantUid,
            requestHash: command.requestHash,
          },
        );
      }

      const callSnapshot = await transaction.get(refs.callRef);
      if (!callSnapshot.exists) {
        return buildActiveLeaseTimeoutNoopResult({
          callId: validatedRequest.callId,
          participantUid: validatedRequest.participantUid,
          status: "missing",
        });
      }

      const call = requireExistingV2CallForTimeout(
        callSnapshot,
        validatedRequest.callId,
      );
      if (call.terminal) {
        return buildActiveLeaseTimeoutNoopResult({
          callId: call.id,
          participantUid: validatedRequest.participantUid,
          status: "already_terminal",
          call,
        });
      }
      if (
        call.lifecycleState !== "active" ||
        call.version !== validatedRequest.expectedCallVersion
      ) {
        return buildActiveLeaseTimeoutNoopResult({
          callId: call.id,
          participantUid: validatedRequest.participantUid,
          status: "stale",
          call,
        });
      }
      requireActiveTemporalFields(call);
      if (call.reconnectDeadlineAt !== null) {
        return buildActiveLeaseTimeoutNoopResult({
          callId: call.id,
          participantUid: validatedRequest.participantUid,
          status: "stale",
          call,
        });
      }

      const targetRole = roleForParticipant(
        call,
        validatedRequest.participantUid,
      );
      if (!targetRole) {
        throw new CallV2Error(
          ERROR_CODES.transactionFailed,
          "The timeout participant is not part of the call.",
        );
      }

      const participantSnapshots = await readCallParticipantSnapshots(
        transaction,
        refs.callRef,
        call,
      );
      const participants = validateMediaParticipantSnapshots(
        participantSnapshots.byRole,
        call,
      );
      if (
        participants.byRole.caller.data.mediaState !== "joined" ||
        participants.byRole.callee.data.mediaState !== "joined"
      ) {
        throw new CallV2Error(
          ERROR_CODES.transactionFailed,
          "The active lease timeout state is inconsistent.",
        );
      }

      const targetParticipant = participants.byRole[targetRole].data;
      if (
        targetParticipant.heartbeatVersion !==
        validatedRequest.expectedHeartbeatVersion
      ) {
        return buildActiveLeaseTimeoutNoopResult({
          callId: call.id,
          participantUid: validatedRequest.participantUid,
          status: "stale",
          call,
        });
      }
      if (
        targetParticipant.heartbeatVersion > 0 &&
        !isValidTimestampValue(targetParticipant.lastHeartbeatAt)
      ) {
        throw new CallV2Error(
          ERROR_CODES.transactionFailed,
          "The participant heartbeat timestamp is malformed.",
        );
      }

      const callOpsSnapshot = await transaction.get(refs.callOpsRef);
      const callOps = requireCallOps(callOpsSnapshot, call.id);
      const lockSnapshots = await readParticipantLockSnapshots(
        transaction,
        db,
        call,
      );
      const targetClaim = lockClaimForRole(
        callOps,
        targetRole,
        validatedRequest.participantUid,
      );
      const targetLock = requireTargetActiveLeaseLock({
        lockEntry: lockSnapshots.byRole[targetRole],
        claim: targetClaim,
        call,
        role: targetRole,
      });
      if (targetLock.fencingToken !== validatedRequest.expectedFencingToken) {
        return buildActiveLeaseTimeoutNoopResult({
          callId: call.id,
          participantUid: validatedRequest.participantUid,
          status: "stale",
          call,
        });
      }

      const currentLeaseExpiresMs = strictTimestampMillis(targetLock.expiresAt);
      if (currentLeaseExpiresMs !== validatedRequest.expectedLeaseExpiresMs) {
        return buildActiveLeaseTimeoutNoopResult({
          callId: call.id,
          participantUid: validatedRequest.participantUid,
          status: "stale",
          call,
        });
      }
      if (nowDate.getTime() < currentLeaseExpiresMs) {
        return buildActiveLeaseTimeoutNoopResult({
          callId: call.id,
          participantUid: validatedRequest.participantUid,
          status: "not_due",
          call,
        });
      }

      const nextCallVersion = nextMonotonicVersion(call.version);
      const nextOpsVersion = nextMonotonicVersion(callOps.latestOpsVersion);
      const lockReleaseResults = releaseScopedLocks(
        transaction,
        lockSnapshots.byRole,
        callOps,
        call,
      );
      const historyExpiresAt = addMilliseconds(
        nowDate,
        PUBLIC_HISTORY_RETENTION_MS,
      );
      const result = Object.freeze({
        callId: call.id,
        participantUid: validatedRequest.participantUid,
        timeoutKind: "active_lease",
        status: "terminalized",
        lifecycleState: "failed",
        terminal: true,
        version: nextCallVersion,
        endedAt: nowDate,
        endReason: "active_lease_timeout",
        failureCode: "active_lease_timeout",
        lockReleaseResults,
        idempotentReplay: false,
      });

      transaction.update(refs.callRef, {
        lifecycleState: "failed",
        terminal: true,
        version: nextCallVersion,
        updatedAt: nowDate,
        lastPublicEventAt: nowDate,
        endedAt: nowDate,
        endedByUid: null,
        endReason: "active_lease_timeout",
        failureCode: "active_lease_timeout",
        historyVisible: true,
        historyExpiresAt,
      });
      transaction.update(refs.callOpsRef, {
        latestOpsVersion: nextOpsVersion,
        terminalAt: nowDate,
        terminalState: "failed",
        terminalReason: "active_lease_timeout",
        failureCode: "active_lease_timeout",
        timeoutKind: "active_lease",
        timeoutParticipantUid: validatedRequest.participantUid,
        timeoutDeadlineAt: targetLock.expiresAt,
        timeoutProcessedAt: nowDate,
        lockReleaseResults,
        opsRetentionExpiresAt: addMilliseconds(nowDate, OPS_RETENTION_MS),
      });
      createActiveLeaseTimeoutCommandRecord(transaction, refs.commandRef, {
        command,
        callId: call.id,
        participantUid: validatedRequest.participantUid,
        expectedCallVersion: validatedRequest.expectedCallVersion,
        expectedHeartbeatVersion: validatedRequest.expectedHeartbeatVersion,
        expectedFencingToken: validatedRequest.expectedFencingToken,
        timeoutDeadlineAt: targetLock.expiresAt,
        nowDate,
        result,
      });

      return result;
    })
    .catch((error) =>
      recoverActiveLeaseTimeoutCommandCreateConflictOrThrow({
        error,
        commandRef: refs.commandRef,
        expected: {
          callId: validatedRequest.callId,
          participantUid: validatedRequest.participantUid,
          requestHash: command.requestHash,
        },
        fallbackMessage: "The active lease timeout transaction failed.",
      }),
    );
}

function runTerminalLifecycleCommand({
  db,
  authUid,
  request,
  now,
  action,
  targetLifecycleState,
  endReason,
  allowedRoles,
  allowedLifecycleStates,
}) {
  assertDbDependency(db);
  const validatedRequest = validateLifecycleCommandInput(authUid, request);
  const nowDate = resolveNow(now);
  const command = buildLifecycleCommandContext({
    actorUid: authUid,
    action,
    callId: validatedRequest.callId,
    idempotencyKey: validatedRequest.idempotencyKey,
    controlledPayload: {
      lifecycleState: targetLifecycleState,
      endReason,
    },
  });
  const refs = buildLifecycleRefs(db, {
    callId: validatedRequest.callId,
    actorUid: authUid,
    idempotencyLookupId: command.idempotencyLookupId,
    commandId: command.commandId,
  });

  return db
    .runTransaction(async (transaction) => {
      const idempotencySnapshot = await transaction.get(refs.idempotencyRef);
      if (idempotencySnapshot.exists) {
        return handleExistingIdempotencyRecord(
          idempotencySnapshot.data(),
          { actorUid: authUid, action },
          command.requestHash,
        );
      }

      const callSnapshot = await transaction.get(refs.callRef);
      const call = requireMutableV2Call(callSnapshot, validatedRequest.callId);
      const callOpsSnapshot = await transaction.get(refs.callOpsRef);
      const callOps = requireCallOps(callOpsSnapshot, validatedRequest.callId);
      const actorParticipantSnapshot = await transaction.get(
        refs.actorParticipantRef,
      );
      const lockSnapshots = await readParticipantLockSnapshots(
        transaction,
        db,
        call,
      );

      const actorRole = requireParticipantAuthorization(
        actorParticipantSnapshot,
        call,
        authUid,
      );
      if (!allowedRoles.includes(actorRole)) {
        throw new CallV2Error(
          ERROR_CODES.forbidden,
          "The actor is not allowed to perform this call command.",
        );
      }
      if (
        call.terminal ||
        !allowedLifecycleStates.includes(call.lifecycleState)
      ) {
        throw new CallV2Error(
          ERROR_CODES.invalidState,
          "The call is not in a valid state for this command.",
        );
      }
      if (call.lifecycleState === "ringing") {
        requireOpenRingingWindow(call, nowDate);
      }

      const nextCallVersion = nextMonotonicVersion(call.version);
      const nextOpsVersion = nextMonotonicVersion(callOps.latestOpsVersion);
      const lockReleaseResults = releaseScopedLocks(
        transaction,
        lockSnapshots.byRole,
        callOps,
        call,
      );
      const historyExpiresAt = addMilliseconds(
        nowDate,
        PUBLIC_HISTORY_RETENTION_MS,
      );
      const result = Object.freeze({
        callId: call.id,
        lifecycleState: targetLifecycleState,
        terminal: true,
        version: nextCallVersion,
        endedAt: nowDate,
        endReason,
        lockReleaseResults,
        idempotentReplay: false,
      });

      transaction.update(refs.callRef, {
        lifecycleState: targetLifecycleState,
        terminal: true,
        version: nextCallVersion,
        updatedAt: nowDate,
        lastPublicEventAt: nowDate,
        endedAt: nowDate,
        endedByUid: authUid,
        endReason,
        historyExpiresAt,
      });
      transaction.update(refs.callOpsRef, {
        latestOpsVersion: nextOpsVersion,
        terminalAt: nowDate,
        terminalState: targetLifecycleState,
        terminalReason: endReason,
        opsRetentionExpiresAt: addMilliseconds(nowDate, OPS_RETENTION_MS),
        lockReleaseResults,
      });
      createCommandRecords(transaction, refs, {
        command,
        actorUid: authUid,
        action,
        callId: call.id,
        nowDate,
        result,
      });

      return result;
    })
    .catch((error) =>
      recoverIdempotencyCreateConflictOrThrow({
        error,
        idempotencyRef: refs.idempotencyRef,
        expected: { actorUid: authUid, action },
        requestHash: command.requestHash,
        fallbackMessage: "The call command transaction failed.",
      }),
    );
}

function assertDbDependency(db) {
  if (!db || typeof db.runTransaction !== "function") {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A Firestore database dependency is required.",
    );
  }
}

function validateLifecycleCommandInput(authUid, request) {
  if (!isValidIdentifier(authUid, MAX_UID_LENGTH)) {
    throw new CallV2Error(
      ERROR_CODES.unauthenticated,
      "An authenticated actor is required.",
    );
  }
  if (!request || typeof request !== "object" || Array.isArray(request)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A lifecycle command request object is required.",
    );
  }

  const allowedKeys = new Set(["callId", "idempotencyKey"]);
  for (const key of Object.keys(request)) {
    if (!allowedKeys.has(key)) {
      throw new CallV2Error(
        ERROR_CODES.invalidArgument,
        `Unsupported lifecycle command field: ${key}.`,
      );
    }
  }
  if (!isValidIdentifier(request.callId, 160)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A valid callId is required.",
    );
  }
  if (!isValidIdentifier(request.idempotencyKey, MAX_IDEMPOTENCY_KEY_LENGTH)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A valid idempotencyKey is required.",
    );
  }

  return {
    callId: request.callId,
    idempotencyKey: request.idempotencyKey,
  };
}

function validateMediaReportInput(authUid, request) {
  if (!isValidIdentifier(authUid, MAX_UID_LENGTH)) {
    throw new CallV2Error(
      ERROR_CODES.unauthenticated,
      "An authenticated actor is required.",
    );
  }
  if (!request || typeof request !== "object" || Array.isArray(request)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A media report request object is required.",
    );
  }

  const allowedKeys = new Set(["callId", "mediaState", "idempotencyKey"]);
  for (const key of Object.keys(request)) {
    if (!allowedKeys.has(key)) {
      throw new CallV2Error(
        ERROR_CODES.invalidArgument,
        `Unsupported media report field: ${key}.`,
      );
    }
  }
  if (!isValidIdentifier(request.callId, 160)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A valid callId is required.",
    );
  }
  if (!isSupportedMediaState(request.mediaState)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A supported mediaState is required.",
    );
  }
  if (!isValidIdentifier(request.idempotencyKey, MAX_IDEMPOTENCY_KEY_LENGTH)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A valid idempotencyKey is required.",
    );
  }

  return {
    callId: request.callId,
    mediaState: request.mediaState,
    idempotencyKey: request.idempotencyKey,
  };
}

function validateTimeoutRequestInput(request) {
  if (!request || typeof request !== "object" || Array.isArray(request)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A timeout request object is required.",
    );
  }

  const allowedKeys = new Set([
    "callId",
    "timeoutKind",
    "expectedCallVersion",
    "expectedDeadlineAt",
  ]);
  for (const key of Object.keys(request)) {
    if (!allowedKeys.has(key)) {
      throw new CallV2Error(
        ERROR_CODES.invalidArgument,
        `Unsupported timeout field: ${key}.`,
      );
    }
  }
  if (!isValidIdentifier(request.callId, 160)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A valid callId is required.",
    );
  }
  if (!TIMEOUT_KINDS.includes(request.timeoutKind)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A supported timeoutKind is required.",
    );
  }
  if (!Number.isSafeInteger(request.expectedCallVersion) ||
    request.expectedCallVersion <= 0
  ) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A positive safe expectedCallVersion is required.",
    );
  }
  const expectedDeadlineMs = strictTimestampMillis(request.expectedDeadlineAt);
  if (expectedDeadlineMs === null) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A strict expectedDeadlineAt timestamp is required.",
    );
  }

  return {
    callId: request.callId,
    timeoutKind: request.timeoutKind,
    expectedCallVersion: request.expectedCallVersion,
    expectedDeadlineAt: request.expectedDeadlineAt,
    expectedDeadlineMs,
  };
}

function validateActiveLeaseRenewalInput(authUid, request) {
  if (!isValidIdentifier(authUid, MAX_UID_LENGTH)) {
    throw new CallV2Error(
      ERROR_CODES.unauthenticated,
      "An authenticated actor is required.",
    );
  }
  if (!request || typeof request !== "object" || Array.isArray(request)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "An active lease renewal request object is required.",
    );
  }

  const allowedKeys = new Set([
    "callId",
    "heartbeatVersion",
    "idempotencyKey",
  ]);
  for (const key of Object.keys(request)) {
    if (!allowedKeys.has(key)) {
      throw new CallV2Error(
        ERROR_CODES.invalidArgument,
        `Unsupported active lease renewal field: ${key}.`,
      );
    }
  }
  if (!isValidIdentifier(request.callId, 160)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A valid callId is required.",
    );
  }
  if (
    !Number.isSafeInteger(request.heartbeatVersion) ||
    request.heartbeatVersion <= 0
  ) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A positive safe heartbeatVersion is required.",
    );
  }
  if (!isValidIdentifier(request.idempotencyKey, MAX_IDEMPOTENCY_KEY_LENGTH)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A valid idempotencyKey is required.",
    );
  }

  return {
    callId: request.callId,
    heartbeatVersion: request.heartbeatVersion,
    idempotencyKey: request.idempotencyKey,
  };
}

function validateActiveLeaseTimeoutRequestInput(request) {
  if (!request || typeof request !== "object" || Array.isArray(request)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "An active lease timeout request object is required.",
    );
  }

  const allowedKeys = new Set([
    "callId",
    "participantUid",
    "expectedCallVersion",
    "expectedHeartbeatVersion",
    "expectedFencingToken",
    "expectedLeaseExpiresAt",
  ]);
  for (const key of Object.keys(request)) {
    if (!allowedKeys.has(key)) {
      throw new CallV2Error(
        ERROR_CODES.invalidArgument,
        `Unsupported active lease timeout field: ${key}.`,
      );
    }
  }
  if (!isValidIdentifier(request.callId, 160)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A valid callId is required.",
    );
  }
  if (!isValidIdentifier(request.participantUid, MAX_UID_LENGTH)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A valid participantUid is required.",
    );
  }
  if (
    !Number.isSafeInteger(request.expectedCallVersion) ||
    request.expectedCallVersion <= 0
  ) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A positive safe expectedCallVersion is required.",
    );
  }
  if (!isValidHeartbeatVersion(request.expectedHeartbeatVersion)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A non-negative safe expectedHeartbeatVersion is required.",
    );
  }
  if (!isValidFencingToken(request.expectedFencingToken)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A valid expectedFencingToken is required.",
    );
  }
  const expectedLeaseExpiresMs = strictTimestampMillis(
    request.expectedLeaseExpiresAt,
  );
  if (expectedLeaseExpiresMs === null) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A strict expectedLeaseExpiresAt timestamp is required.",
    );
  }

  return {
    callId: request.callId,
    participantUid: request.participantUid,
    expectedCallVersion: request.expectedCallVersion,
    expectedHeartbeatVersion: request.expectedHeartbeatVersion,
    expectedFencingToken: request.expectedFencingToken,
    expectedLeaseExpiresAt: request.expectedLeaseExpiresAt,
    expectedLeaseExpiresMs,
  };
}

function buildLifecycleCommandContext({
  actorUid,
  action,
  callId,
  idempotencyKey,
  controlledPayload,
}) {
  const requestHash = sha256Hex(
    canonicalJson({
      action,
      callId,
      ...controlledPayload,
    }),
  );
  const idempotencyLookupId = sha256Hex(
    [actorUid, action, idempotencyKey].join("\u0000"),
  );
  const commandId = `${commandIdPrefix(action)}_${sha256Hex(
    [actorUid, action, idempotencyKey, requestHash, callId].join("\u0000"),
  ).slice(0, 48)}`;

  return {
    commandId,
    idempotencyLookupId,
    requestHash,
  };
}

function buildTimeoutCommandContext({
  callId,
  timeoutKind,
  expectedCallVersion,
  expectedDeadlineMs,
}) {
  const requestHash = sha256Hex(
    canonicalJson({
      action: ACTION_PROCESS_CALL_TIMEOUT,
      callId,
      timeoutKind,
      expectedCallVersion,
      expectedDeadlineMs,
    }),
  );
  const commandId = `timeout_${sha256Hex(
    [
      callId,
      timeoutKind,
      String(expectedCallVersion),
      String(expectedDeadlineMs),
    ].join("\u0000"),
  ).slice(0, 48)}`;

  return {
    commandId,
    requestHash,
  };
}

function buildActiveLeaseTimeoutCommandContext({
  callId,
  participantUid,
  expectedCallVersion,
  expectedHeartbeatVersion,
  expectedFencingToken,
  expectedLeaseExpiresMs,
}) {
  const requestHash = sha256Hex(
    canonicalJson({
      action: ACTION_PROCESS_ACTIVE_LEASE_TIMEOUT,
      callId,
      participantUid,
      expectedCallVersion,
      expectedHeartbeatVersion,
      expectedFencingToken,
      expectedLeaseExpiresMs,
    }),
  );
  const commandId = `active_lease_timeout_${sha256Hex(
    [
      callId,
      participantUid,
      String(expectedCallVersion),
      String(expectedHeartbeatVersion),
      String(expectedFencingToken),
      String(expectedLeaseExpiresMs),
    ].join("\u0000"),
  ).slice(0, 48)}`;

  return {
    commandId,
    requestHash,
  };
}

function buildCallTimeoutTaskIntent({
  callId,
  taskKind,
  expectedCallVersion,
  expectedDeadlineAt,
  createdAt,
}) {
  const timeoutKind = TASK_TIMEOUT_KIND_BY_TASK_KIND[taskKind];
  if (!timeoutKind) {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The call timeout task kind is unsupported.",
    );
  }
  const deadlineMs = strictTimestampMillis(expectedDeadlineAt);
  if (deadlineMs === null) {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The call timeout task deadline is malformed.",
    );
  }
  if (!Number.isSafeInteger(expectedCallVersion) || expectedCallVersion <= 0) {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The call timeout task version is malformed.",
    );
  }

  const identity = {
    taskKind,
    callId,
    expectedCallVersion,
    deadlineMs,
  };
  const taskId = `${taskKind}_${sha256Hex(canonicalJson(identity)).slice(0, 48)}`;
  return Object.freeze({
    taskId,
    callId,
    taskKind,
    dueAt: expectedDeadlineAt,
    payload: Object.freeze({
      callId,
      timeoutKind,
      expectedCallVersion,
      expectedDeadlineAt,
    }),
    createdAt,
    updatedAt: createdAt,
    ttlAt: addMilliseconds(toDate(expectedDeadlineAt), TASK_OUTBOX_RETENTION_MS),
  });
}

function buildActiveLeaseTimeoutTaskIntent({
  callId,
  participantUid,
  expectedCallVersion,
  expectedHeartbeatVersion,
  expectedFencingToken,
  expectedLeaseExpiresAt,
  createdAt,
}) {
  const leaseExpiresMs = strictTimestampMillis(expectedLeaseExpiresAt);
  if (leaseExpiresMs === null) {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The active lease timeout task deadline is malformed.",
    );
  }
  if (!Number.isSafeInteger(expectedCallVersion) || expectedCallVersion <= 0) {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The active lease timeout task call version is malformed.",
    );
  }
  if (!isValidHeartbeatVersion(expectedHeartbeatVersion)) {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The active lease timeout task heartbeat version is malformed.",
    );
  }
  if (!isValidFencingToken(expectedFencingToken)) {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The active lease timeout task fencing token is malformed.",
    );
  }

  const taskKind = TASK_KINDS.activeLeaseTimeout;
  const identity = {
    taskKind,
    callId,
    participantUid,
    expectedCallVersion,
    expectedHeartbeatVersion,
    expectedFencingToken,
    leaseExpiresMs,
  };
  const taskId = `${taskKind}_${sha256Hex(canonicalJson(identity)).slice(0, 48)}`;
  return Object.freeze({
    taskId,
    callId,
    taskKind,
    dueAt: expectedLeaseExpiresAt,
    payload: Object.freeze({
      callId,
      participantUid,
      expectedCallVersion,
      expectedHeartbeatVersion,
      expectedFencingToken,
      expectedLeaseExpiresAt,
    }),
    createdAt,
    updatedAt: createdAt,
    ttlAt: addMilliseconds(
      toDate(expectedLeaseExpiresAt),
      TASK_OUTBOX_RETENTION_MS,
    ),
  });
}

function commandIdPrefix(action) {
  return action.replace(/[^A-Za-z0-9]/g, "_").toLowerCase();
}

function buildLifecycleRefs(
  db,
  { callId, actorUid, idempotencyLookupId, commandId },
) {
  const callRef = db.collection("calls").doc(callId);
  return {
    callRef,
    actorParticipantRef: callRef.collection("participants").doc(actorUid),
    callOpsRef: db.collection("callOps").doc(callId),
    commandRef: db
      .collection("callOps")
      .doc(callId)
      .collection("commands")
      .doc(commandId),
    idempotencyRef: db.collection("callCommandKeys").doc(idempotencyLookupId),
  };
}

function buildTimeoutRefs(db, { callId, commandId }) {
  const callRef = db.collection("calls").doc(callId);
  return {
    callRef,
    callOpsRef: db.collection("callOps").doc(callId),
    commandRef: db
      .collection("callOps")
      .doc(callId)
      .collection("commands")
      .doc(commandId),
  };
}

function taskOutboxRef(callOpsRef, taskId) {
  return callOpsRef.collection("taskOutbox").doc(taskId);
}

function claimTaskOutboxDispatchV2({
  db,
  request,
  now,
  generateClaimToken,
}) {
  assertDbDependency(db);
  const validatedRequest = validateTaskOutboxRequest(request);
  const nowDate = resolveNow(now);
  if (typeof generateClaimToken !== "function") {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A claim token generator is required.",
    );
  }

  const ref = db
    .collection("callOps")
    .doc(validatedRequest.callId)
    .collection("taskOutbox")
    .doc(validatedRequest.taskId);

  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const task = requireValidTaskOutboxDocument(snapshot, validatedRequest);

    if (task.status === "dispatched") {
      return Object.freeze({
        callId: task.callId,
        taskId: task.taskId,
        status: "already_dispatched",
      });
    }

    if (task.status === "dead_letter") {
      return Object.freeze({
        callId: task.callId,
        taskId: task.taskId,
        status: "dead_letter",
      });
    }

    if (nowDate.getTime() >= task.ttlMs) {
      transaction.update(ref, {
        status: "dead_letter",
        claimToken: null,
        claimExpiresAt: null,
        updatedAt: nowDate,
        lastDispatchError: null,
        lastDispatchErrorCode: "outbox_ttl_expired",
      });
      return Object.freeze({
        callId: task.callId,
        taskId: task.taskId,
        status: "dead_letter",
      });
    }

    if (
      task.status === "dispatching" &&
      nowDate.getTime() < task.claimExpiresMs
    ) {
      return Object.freeze({
        callId: task.callId,
        taskId: task.taskId,
        status: "busy",
      });
    }

    if (task.dispatchAttempts >= TASK_DISPATCH_MAX_ATTEMPTS) {
      transaction.update(ref, {
        status: "dead_letter",
        claimToken: null,
        claimExpiresAt: null,
        updatedAt: nowDate,
        lastDispatchError: null,
        lastDispatchErrorCode: "max_dispatch_attempts",
      });
      return Object.freeze({
        callId: task.callId,
        taskId: task.taskId,
        status: "dead_letter",
      });
    }

    const claimToken = validateGeneratedClaimToken(generateClaimToken);
    const claimExpiresAt = addMilliseconds(
      nowDate,
      TASK_DISPATCH_CLAIM_DURATION_MS,
    );
    const dispatchAttempt = task.dispatchAttempts + 1;
    transaction.update(ref, {
      status: "dispatching",
      claimToken,
      claimExpiresAt,
      dispatchAttempts: dispatchAttempt,
      updatedAt: nowDate,
      lastDispatchError: null,
      lastDispatchErrorCode: null,
    });

    return Object.freeze({
      callId: task.callId,
      taskId: task.taskId,
      taskKind: task.taskKind,
      dueAt: task.dueAt,
      payload: task.payload,
      claimToken,
      claimExpiresAt,
      dispatchAttempt,
      deterministicExternalTaskId: deterministicExternalTaskId(task),
      status: "claimed",
      idempotentReplay: false,
    });
  }).catch(wrapTransactionError);
}

function finalizeTaskOutboxDispatchSuccessV2({ db, request, now }) {
  assertDbDependency(db);
  const validatedRequest = validateDispatchSuccessRequest(request);
  const nowDate = resolveNow(now);
  const ref = db
    .collection("callOps")
    .doc(validatedRequest.callId)
    .collection("taskOutbox")
    .doc(validatedRequest.taskId);

  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const task = requireValidTaskOutboxDocument(snapshot, validatedRequest);
    const expectedExternalTaskId = deterministicExternalTaskId(task);

    if (task.status === "dispatched") {
      if (
        task.externalTaskName !== validatedRequest.externalTaskName ||
        !externalTaskNameMatchesId(
          validatedRequest.externalTaskName,
          expectedExternalTaskId,
        )
      ) {
        throw new CallV2Error(
          ERROR_CODES.transactionFailed,
          "The dispatched task external identity is conflicting.",
        );
      }
      return Object.freeze({
        callId: task.callId,
        taskId: task.taskId,
        status: "already_dispatched",
      });
    }

    if (
      task.status !== "dispatching" ||
      task.claimToken !== validatedRequest.claimToken ||
      nowDate.getTime() >= task.claimExpiresMs
    ) {
      return Object.freeze({
        callId: task.callId,
        taskId: task.taskId,
        status: "stale",
      });
    }

    if (
      !externalTaskNameMatchesId(
        validatedRequest.externalTaskName,
        expectedExternalTaskId,
      )
    ) {
      throw new CallV2Error(
        ERROR_CODES.invalidArgument,
        "The external task name does not match the outbox task identity.",
      );
    }

    transaction.update(ref, {
      status: "dispatched",
      externalTaskName: validatedRequest.externalTaskName,
      dispatchedAt: nowDate,
      updatedAt: nowDate,
      claimToken: null,
      claimExpiresAt: null,
      lastDispatchError: null,
      lastDispatchErrorCode: null,
    });

    return Object.freeze({
      callId: task.callId,
      taskId: task.taskId,
      status: "dispatched",
      externalTaskName: validatedRequest.externalTaskName,
      dispatchedAt: nowDate,
      dispatchAttempts: task.dispatchAttempts,
      publisherOutcome: validatedRequest.publisherOutcome,
    });
  }).catch(wrapTransactionError);
}

function finalizeTaskOutboxDispatchFailureV2({ db, request, now }) {
  assertDbDependency(db);
  const validatedRequest = validateDispatchFailureRequest(request);
  const nowDate = resolveNow(now);
  const ref = db
    .collection("callOps")
    .doc(validatedRequest.callId)
    .collection("taskOutbox")
    .doc(validatedRequest.taskId);

  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const task = requireValidTaskOutboxDocument(snapshot, validatedRequest);

    if (
      task.status !== "dispatching" ||
      task.claimToken !== validatedRequest.claimToken ||
      nowDate.getTime() >= task.claimExpiresMs
    ) {
      return Object.freeze({
        callId: task.callId,
        taskId: task.taskId,
        status: "stale",
      });
    }

    const exhausted = task.dispatchAttempts >= TASK_DISPATCH_MAX_ATTEMPTS;
    if (validatedRequest.retryable && !exhausted) {
      transaction.update(ref, {
        status: "pending",
        claimToken: null,
        claimExpiresAt: null,
        updatedAt: nowDate,
        lastDispatchError: null,
        lastDispatchErrorCode: validatedRequest.errorCode,
      });
      return Object.freeze({
        callId: task.callId,
        taskId: task.taskId,
        status: "retryable",
      });
    }

    transaction.update(ref, {
      status: "dead_letter",
      claimToken: null,
      claimExpiresAt: null,
      updatedAt: nowDate,
      lastDispatchError: null,
      lastDispatchErrorCode: exhausted
        ? "max_dispatch_attempts"
        : validatedRequest.errorCode,
    });
    return Object.freeze({
      callId: task.callId,
      taskId: task.taskId,
      status: "dead_letter",
    });
  }).catch(wrapTransactionError);
}

async function dispatchTaskOutboxV2({
  db,
  request,
  now,
  generateClaimToken,
  publisher,
  internalFinalizers = {},
}) {
  if (!publisher || typeof publisher.publishTimeoutTask !== "function") {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A timeout task publisher dependency is required.",
    );
  }
  const finalizeSuccess =
    internalFinalizers.finalizeSuccess || finalizeTaskOutboxDispatchSuccessV2;
  const finalizeFailure =
    internalFinalizers.finalizeFailure || finalizeTaskOutboxDispatchFailureV2;

  const claim = await claimTaskOutboxDispatchV2({
    db,
    request,
    now,
    generateClaimToken,
  });
  if (claim.status !== "claimed") {
    return claim;
  }

  let publishResult;
  try {
    publishResult = normalizePublishResult(
      await publisher.publishTimeoutTask({
        externalTaskId: claim.deterministicExternalTaskId,
        callId: claim.callId,
        outboxTaskId: claim.taskId,
        taskKind: claim.taskKind,
        scheduleTime: claim.dueAt,
        payload: claim.payload,
      }),
    );
  } catch (error) {
    const controlledError =
      error instanceof TaskPublisherError
        ? error
        : new TaskPublisherError({
          code: "publisher_unexpected_error",
          retryable: true,
        });
    const failure = await finalizeFailure({
      db,
      request: {
        callId: claim.callId,
        taskId: claim.taskId,
        claimToken: claim.claimToken,
        errorCode: controlledError.code,
        retryable: controlledError.retryable,
      },
      now,
    });
    return Object.freeze({
      ...failure,
      errorCode: controlledError.code,
      retryable: controlledError.retryable,
    });
  }

  const success = await finalizeSuccess({
    db,
    request: {
      callId: claim.callId,
      taskId: claim.taskId,
      claimToken: claim.claimToken,
      externalTaskName: publishResult.externalTaskName,
      publisherOutcome: publishResult.outcome,
    },
    now,
  });
  return Object.freeze({
    ...success,
    publishOutcome: publishResult.outcome,
  });
}

function acknowledgeTimeoutTaskExecutionV2({ db, request, now }) {
  assertDbDependency(db);
  const validatedRequest = validateExecutionAcknowledgementRequest(request);
  const nowDate = resolveNow(now);
  const ref = db
    .collection("callOps")
    .doc(validatedRequest.callId)
    .collection("taskOutbox")
    .doc(validatedRequest.outboxTaskId);

  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const task = requireValidTaskOutboxDocument(snapshot, {
      callId: validatedRequest.callId,
      taskId: validatedRequest.outboxTaskId,
    });
    requireExecutableDispatchedTaskIdentity(task, validatedRequest);

    if (task.completedAt !== null) {
      if (task.executionOutcome !== validatedRequest.executionOutcome) {
        throw new CallV2Error(
          ERROR_CODES.transactionFailed,
          "The task execution acknowledgement is conflicting.",
        );
      }
      return Object.freeze({
        callId: task.callId,
        outboxTaskId: task.taskId,
        status: "acknowledged",
        executionOutcome: task.executionOutcome,
        completedAt: toDate(task.completedAt),
        idempotentReplay: true,
      });
    }

    const executionAttempts = task.executionAttempts + 1;
    transaction.update(ref, {
      completedAt: nowDate,
      lastExecutionAt: nowDate,
      executionAttempts,
      executionOutcome: validatedRequest.executionOutcome,
      executionErrorCode: null,
      updatedAt: nowDate,
    });
    return Object.freeze({
      callId: task.callId,
      outboxTaskId: task.taskId,
      status: "acknowledged",
      executionOutcome: validatedRequest.executionOutcome,
      completedAt: nowDate,
      idempotentReplay: false,
    });
  }).catch(wrapTransactionError);
}

function recordTimeoutTaskExecutionFailureV2({ db, request, now }) {
  assertDbDependency(db);
  const validatedRequest = validateExecutionFailureRequest(request);
  const nowDate = resolveNow(now);
  const ref = db
    .collection("callOps")
    .doc(validatedRequest.callId)
    .collection("taskOutbox")
    .doc(validatedRequest.outboxTaskId);

  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const task = requireValidTaskOutboxDocument(snapshot, {
      callId: validatedRequest.callId,
      taskId: validatedRequest.outboxTaskId,
    });
    requireExecutableDispatchedTaskIdentity(task, validatedRequest);
    if (task.completedAt !== null) {
      throw new CallV2Error(
        ERROR_CODES.transactionFailed,
        "The task execution has already been acknowledged.",
      );
    }

    const executionAttempts = task.executionAttempts + 1;
    transaction.update(ref, {
      lastExecutionAt: nowDate,
      executionAttempts,
      executionErrorCode: validatedRequest.errorCode,
      updatedAt: nowDate,
    });
    return Object.freeze({
      callId: task.callId,
      outboxTaskId: task.taskId,
      status: "recorded",
      errorCode: validatedRequest.errorCode,
      executionAttempts,
    });
  }).catch(wrapTransactionError);
}

async function executeTimeoutTaskEnvelopeV2({
  db,
  request,
  now,
  internalServices = {},
}) {
  assertDbDependency(db);
  const envelope = validateTimeoutTaskEnvelope(request);
  const nowDate = resolveNow(now);
  const task = await loadExecutableOutboxTask(db, envelope);
  if (task.completedAt !== null) {
    return acknowledgeTimeoutTaskExecutionV2({
      db,
      request: {
        callId: task.callId,
        outboxTaskId: task.taskId,
        externalTaskId: envelope.externalTaskId,
        executionOutcome: task.executionOutcome,
      },
      now: nowDate,
    });
  }

  const processCallTimeout =
    internalServices.processCallTimeout || processCallTimeoutV2;
  const processActiveLeaseTimeout =
    internalServices.processActiveLeaseTimeout || processActiveLeaseTimeoutV2;
  const acknowledgeExecution =
    internalServices.acknowledgeExecution ||
    acknowledgeTimeoutTaskExecutionV2;
  const recordExecutionFailure =
    internalServices.recordExecutionFailure ||
    recordTimeoutTaskExecutionFailureV2;

  let processorResult;
  try {
    if (task.taskKind === TASK_KINDS.activeLeaseTimeout) {
      processorResult = await processActiveLeaseTimeout({
        db,
        request: task.payload,
        now: nowDate,
      });
    } else {
      processorResult = await processCallTimeout({
        db,
        request: task.payload,
        now: nowDate,
      });
    }
  } catch (error) {
    const errorCode =
      error instanceof CallV2Error
        ? error.code
        : "timeout_processor_unexpected_error";
    await recordExecutionFailureIfPossible({
      recordExecutionFailure,
      db,
      task,
      externalTaskId: envelope.externalTaskId,
      errorCode,
      now: nowDate,
    });
    if (error instanceof CallV2Error) {
      throw error;
    }
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The timeout processor failed.",
    );
  }

  if (!processorResult || typeof processorResult.status !== "string") {
    await recordExecutionFailureIfPossible({
      recordExecutionFailure,
      db,
      task,
      externalTaskId: envelope.externalTaskId,
      errorCode: "timeout_processor_invalid_result",
      now: nowDate,
    });
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The timeout processor returned an invalid result.",
    );
  }

  if (processorResult.status === "not_due") {
    await recordExecutionFailureIfPossible({
      recordExecutionFailure,
      db,
      task,
      externalTaskId: envelope.externalTaskId,
      errorCode: "timeout_not_due",
      now: nowDate,
    });
    return Object.freeze({
      callId: task.callId,
      outboxTaskId: task.taskId,
      status: "retry_later",
      retryable: true,
      errorCode: "timeout_not_due",
    });
  }

  if (!TASK_EXECUTION_ACK_OUTCOMES.includes(processorResult.status)) {
    await recordExecutionFailureIfPossible({
      recordExecutionFailure,
      db,
      task,
      externalTaskId: envelope.externalTaskId,
      errorCode: "timeout_processor_invalid_result",
      now: nowDate,
    });
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The timeout processor outcome is unsupported.",
    );
  }

  return acknowledgeExecution({
    db,
    request: {
      callId: task.callId,
      outboxTaskId: task.taskId,
      externalTaskId: envelope.externalTaskId,
      executionOutcome: processorResult.status,
    },
    now: nowDate,
  });
}

function createTimeoutTaskHttpHandlerV2({ db, verifyRequest, now }) {
  assertDbDependency(db);
  if (typeof verifyRequest !== "function") {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A request verification dependency is required.",
    );
  }
  return async function timeoutTaskHttpHandler(request) {
    try {
      if (!request || request.method !== "POST") {
        return httpResult(405, {
          errorCode: "method_not_allowed",
          retryable: false,
        });
      }
      let verified = false;
      try {
        verified = await verifyRequest(request);
      } catch {
        return httpResult(401, {
          errorCode: "unauthorized",
          retryable: false,
        });
      }
      if (verified !== true) {
        return httpResult(401, {
          errorCode: "unauthorized",
          retryable: false,
        });
      }
      if (!request.body || typeof request.body !== "object") {
        return httpResult(400, {
          errorCode: ERROR_CODES.invalidArgument,
          retryable: false,
        });
      }

      const result = await executeTimeoutTaskEnvelopeV2({
        db,
        request: request.body,
        now,
      });
      if (result.status === "retry_later") {
        return httpResult(503, result);
      }
      return httpResult(200, result);
    } catch (error) {
      if (error instanceof CallV2Error) {
        if (error.code === ERROR_CODES.invalidArgument) {
          return httpResult(400, {
            errorCode: error.code,
            retryable: false,
          });
        }
        return httpResult(503, {
          errorCode: error.code,
          retryable: true,
        });
      }
      return httpResult(503, {
        errorCode: ERROR_CODES.transactionFailed,
        retryable: true,
      });
    }
  };
}

function requireMutableV2Call(snapshot, callId) {
  if (!snapshot.exists) {
    throw new CallV2Error(
      ERROR_CODES.callNotFound,
      "The requested call does not exist.",
    );
  }
  const call = {
    ...snapshot.data(),
    id: callId,
  };
  if (call.callSystem !== "v2") {
    throw new CallV2Error(
      ERROR_CODES.callNotFound,
      "The requested call is not a V2 call.",
    );
  }
  validateAuthoritativeCallData(call);
  return call;
}

function requireExistingV2CallForTimeout(snapshot, callId) {
  const call = {
    ...snapshot.data(),
    id: callId,
  };
  if (call.schemaVersion !== CALL_SCHEMA_VERSION || call.callSystem !== "v2") {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The call document is not an authoritative V2 call.",
    );
  }
  validateAuthoritativeCallData(call);
  return call;
}

function validateAuthoritativeCallData(call) {
  const participantUidSet = new Set(
    Array.isArray(call.participantUids) ? call.participantUids : [],
  );
  if (
    call.schemaVersion !== CALL_SCHEMA_VERSION ||
    !isValidIdentifier(call.callerUid, MAX_UID_LENGTH) ||
    !isValidIdentifier(call.calleeUid, MAX_UID_LENGTH) ||
    call.callerUid === call.calleeUid ||
    !Array.isArray(call.participantUids) ||
    call.participantUids.length !== 2 ||
    participantUidSet.size !== 2 ||
    !call.participantUids.every((uid) =>
      isValidIdentifier(uid, MAX_UID_LENGTH),
    ) ||
    !participantUidSet.has(call.callerUid) ||
    !participantUidSet.has(call.calleeUid) ||
    !isIncrementablePositiveInteger(call.version) ||
    typeof call.terminal !== "boolean"
  ) {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The call document is malformed.",
    );
  }

  const nonTerminalStates = new Set(["ringing", "accepted", "active"]);
  const terminalStates = new Set([
    "completed",
    "declined",
    "cancelled",
    "missed",
    "failed",
  ]);
  if (
    (call.terminal && !terminalStates.has(call.lifecycleState)) ||
    (!call.terminal && !nonTerminalStates.has(call.lifecycleState))
  ) {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The call lifecycle and terminal flag are inconsistent.",
    );
  }
}

function requireCallOps(snapshot, callId) {
  if (!snapshot.exists) {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The call operations document is missing.",
    );
  }
  const callOps = snapshot.data();
  if (
    !callOps ||
    callOps.callId !== callId ||
    !isIncrementablePositiveInteger(callOps.latestOpsVersion)
  ) {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The call operations document is malformed.",
    );
  }
  return callOps;
}

async function readParticipantLockSnapshots(transaction, db, call) {
  const entries = sortByDocumentId([
    {
      role: "caller",
      uid: call.callerUid,
      ref: db.collection("activeCallLocks").doc(call.callerUid),
    },
    {
      role: "callee",
      uid: call.calleeUid,
      ref: db.collection("activeCallLocks").doc(call.calleeUid),
    },
  ]);
  const byRole = {};
  for (const entry of entries) {
    byRole[entry.role] = {
      ...entry,
      snapshot: await transaction.get(entry.ref),
    };
  }
  return {
    entries,
    byRole,
  };
}

async function readCallParticipantSnapshots(transaction, callRef, call) {
  const entries = sortByDocumentId([
    {
      role: "caller",
      uid: call.callerUid,
      ref: callRef.collection("participants").doc(call.callerUid),
    },
    {
      role: "callee",
      uid: call.calleeUid,
      ref: callRef.collection("participants").doc(call.calleeUid),
    },
  ]);
  const byRole = {};
  for (const entry of entries) {
    byRole[entry.role] = {
      ...entry,
      snapshot: await transaction.get(entry.ref),
    };
  }
  return {
    entries,
    byRole,
  };
}

function validateMediaParticipantSnapshots(participantSnapshotsByRole, call) {
  const byRole = {};
  for (const role of ["caller", "callee"]) {
    const expectedUid = role === "caller" ? call.callerUid : call.calleeUid;
    const entry = participantSnapshotsByRole[role];
    if (!entry || !entry.snapshot.exists) {
      throw new CallV2Error(
        ERROR_CODES.transactionFailed,
        "A participant document is missing.",
      );
    }
    const participant = entry.snapshot.data();
    if (
      entry.snapshot.id !== expectedUid ||
      !participant ||
      participant.uid !== expectedUid ||
      participant.role !== role ||
      !isSupportedMediaState(participant.mediaState) ||
      !isValidMediaVersion(participant.mediaVersion) ||
      !isValidHeartbeatVersion(participant.heartbeatVersion)
    ) {
      throw new CallV2Error(
        ERROR_CODES.transactionFailed,
        "A participant document is malformed.",
      );
    }
    byRole[role] = {
      ...entry,
      data: participant,
    };
  }
  return {
    byRole,
  };
}

function roleForParticipant(call, uid) {
  if (uid === call.callerUid) {
    return "caller";
  }
  if (uid === call.calleeUid) {
    return "callee";
  }
  return null;
}

function requireParticipantAuthorization(participantSnapshot, call, authUid) {
  if (!call.participantUids.includes(authUid)) {
    throw new CallV2Error(
      ERROR_CODES.forbidden,
      "The actor is not a participant in this call.",
    );
  }
  if (authUid === call.callerUid) {
    validateActorParticipantDocument(participantSnapshot, authUid, "caller");
    return "caller";
  }
  if (authUid === call.calleeUid) {
    validateActorParticipantDocument(participantSnapshot, authUid, "callee");
    return "callee";
  }
  throw new CallV2Error(
    ERROR_CODES.forbidden,
    "The actor is not a participant in this call.",
  );
}

function validateActorParticipantDocument(participantSnapshot, authUid, role) {
  if (!participantSnapshot.exists) {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The actor participant document is missing.",
    );
  }
  const participant = participantSnapshot.data();
  if (
    !participant ||
    participant.uid !== authUid ||
    participant.role !== role
  ) {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The actor participant document is malformed.",
    );
  }
}

function requireLockClaims(callOps, call) {
  const callerClaim = lockClaimForRole(callOps, "caller", call.callerUid);
  const calleeClaim = lockClaimForRole(callOps, "callee", call.calleeUid);
  if (!callerClaim || !calleeClaim) {
    throw new CallV2Error(
      ERROR_CODES.lockRecoveryRequired,
      "The call lock claims are missing or malformed.",
    );
  }
  return {
    caller: callerClaim,
    callee: calleeClaim,
  };
}

function lockClaimForRole(callOps, role, expectedUid) {
  const claim = callOps && callOps.lockClaims && callOps.lockClaims[role];
  if (
    !claim ||
    claim.uid !== expectedUid ||
    !isValidFencingToken(claim.fencingToken)
  ) {
    return null;
  }
  return claim;
}

function requireMatchingLocksForAccept(
  lockSnapshotsByRole,
  claims,
  callId,
  nowDate,
) {
  for (const role of ["caller", "callee"]) {
    const lockEntry = lockSnapshotsByRole[role];
    const claim = claims[role];
    if (!lockEntry || !lockEntry.snapshot.exists) {
      throw new CallV2Error(
        ERROR_CODES.lockRecoveryRequired,
        "A required active call lock is missing.",
      );
    }
    const lock = lockEntry.snapshot.data();
    if (
      !lock ||
      lock.uid !== claim.uid ||
      lock.callId !== callId ||
      lock.fencingToken !== claim.fencingToken ||
      !isValidFencingToken(lock.fencingToken) ||
      lock.state !== "ringing" ||
      !isValidTimestampValue(lock.expiresAt) ||
      toMillis(lock.expiresAt) <= nowDate.getTime()
    ) {
      throw new CallV2Error(
        ERROR_CODES.lockRecoveryRequired,
        "A required active call lock does not match its private claim.",
      );
    }
  }
}

function requireOpenRingingWindow(call, nowDate) {
  if (!isValidTimestampValue(call.ringingDeadlineAt)) {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The ringing deadline is malformed.",
    );
  }
  if (nowDate.getTime() >= toMillis(call.ringingDeadlineAt)) {
    throw new CallV2Error(
      ERROR_CODES.invalidState,
      "The ringing window has expired.",
    );
  }
}

function validateMediaLifecycleAllowsReport({
  call,
  nowDate,
  participantMediaStates,
  currentMediaState,
  requestedMediaState,
}) {
  if (call.lifecycleState === "ringing") {
    requireOpenRingingWindow(call, nowDate);
    requireValidRingingParticipantMediaStates(participantMediaStates);
    requireAllowedRingingMediaTransition(currentMediaState, requestedMediaState);
    return;
  }

  if (call.lifecycleState === "accepted") {
    requireAcceptedTemporalFields(call);
    requireOpenAcceptedJoinWindow(call, nowDate);
    requireAllowedMediaTransition(currentMediaState, requestedMediaState);
    return;
  }

  if (call.lifecycleState === "active") {
    requireActiveTemporalFields(call);
    requireOpenReconnectWindowIfPresent(call, nowDate);
    requireAllowedMediaTransition(currentMediaState, requestedMediaState);
    return;
  }

  throw new CallV2Error(
    ERROR_CODES.invalidState,
    "The call is not in a valid state for media reports.",
  );
}

function requireValidRingingParticipantMediaStates(participantMediaStates) {
  const validRingingStates = new Set([
    "not_joined",
    "preparing",
    "media_failed",
  ]);
  if (
    !validRingingStates.has(participantMediaStates.caller) ||
    !validRingingStates.has(participantMediaStates.callee)
  ) {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The ringing participant media state is malformed.",
    );
  }
}

function requireAllowedRingingMediaTransition(
  currentMediaState,
  requestedMediaState,
) {
  if (currentMediaState === requestedMediaState) {
    return;
  }
  const allowedNextStates = {
    not_joined: ["preparing", "media_failed"],
    preparing: ["media_failed"],
    media_failed: ["preparing"],
  };
  if (
    !(allowedNextStates[currentMediaState] || []).includes(requestedMediaState)
  ) {
    throw new CallV2Error(
      ERROR_CODES.invalidState,
      "The requested media state is not allowed while ringing.",
    );
  }
}

function requireAcceptedTemporalFields(call) {
  if (!isValidTimestampValue(call.acceptedAt)) {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The accepted timestamp is malformed.",
    );
  }
}

function requireOpenAcceptedJoinWindow(call, nowDate) {
  if (!isValidTimestampValue(call.acceptedJoinDeadlineAt)) {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The accepted join deadline is malformed.",
    );
  }
  if (nowDate.getTime() >= toMillis(call.acceptedJoinDeadlineAt)) {
    throw new CallV2Error(
      ERROR_CODES.invalidState,
      "The accepted join window has expired.",
    );
  }
}

function requireActiveTemporalFields(call) {
  if (!isValidTimestampValue(call.activeAt)) {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The active timestamp is malformed.",
    );
  }
  if (!Object.prototype.hasOwnProperty.call(call, "reconnectDeadlineAt")) {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The reconnect deadline is missing.",
    );
  }
  if (
    call.reconnectDeadlineAt !== null &&
    !isValidTimestampValue(call.reconnectDeadlineAt)
  ) {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The reconnect deadline is malformed.",
    );
  }
}

function validateTimeoutTemporalFields(call, timeoutKind) {
  if (timeoutKind === "accepted_join") {
    requireAcceptedTemporalFields(call);
    return;
  }
  if (timeoutKind === "reconnect") {
    requireActiveTemporalFields(call);
  }
}

function requireTimeoutDeadline(call, timeoutKind, config) {
  const deadline = call[config.deadlineField];
  if (deadline === null || deadline === undefined) {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      `The ${timeoutKind} timeout deadline is missing.`,
    );
  }
  const millis = strictTimestampMillis(deadline);
  if (millis === null) {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      `The ${timeoutKind} timeout deadline is malformed.`,
    );
  }
  return {
    value: deadline,
    millis,
  };
}

function requireOpenReconnectWindowIfPresent(call, nowDate) {
  if (
    call.reconnectDeadlineAt !== null &&
    nowDate.getTime() >= strictTimestampMillis(call.reconnectDeadlineAt)
  ) {
    throw new CallV2Error(
      ERROR_CODES.invalidState,
      "The reconnect window has expired.",
    );
  }
}

function requireAllowedMediaTransition(currentMediaState, requestedMediaState) {
  if (currentMediaState === requestedMediaState) {
    return;
  }
  const allowedNextStates = MEDIA_TRANSITIONS[currentMediaState] || [];
  if (!allowedNextStates.includes(requestedMediaState)) {
    throw new CallV2Error(
      ERROR_CODES.invalidState,
      "The requested media state transition is not allowed.",
    );
  }
}

function buildMediaParticipantUpdate({
  participant,
  nextMediaState,
  nextMediaVersion,
  nowDate,
}) {
  const update = {
    mediaState: nextMediaState,
    mediaVersion: nextMediaVersion,
    lastMediaStateAt: nowDate,
  };
  if (nextMediaState === "joining") {
    update.localJoinStartedAt = nowDate;
  }
  if (nextMediaState === "joined") {
    if (participant.mediaJoinedAt === null) {
      update.mediaJoinedAt = nowDate;
    }
    update.failureCode = null;
  }
  if (nextMediaState === "left") {
    update.mediaLeftAt = nowDate;
  }
  if (nextMediaState === "media_failed") {
    update.failureCode = "client_reported_media_failure";
  }
  if (
    participant.mediaState === "media_failed" &&
    ["preparing", "joining", "joined"].includes(nextMediaState)
  ) {
    update.failureCode = null;
  }
  if (["joining", "joined"].includes(nextMediaState)) {
    update.failureCode = null;
  }
  return update;
}

function updateAcceptedLock(transaction, lockRef, { nowDate, lockExpiresAt }) {
  transaction.update(lockRef, {
    state: "accepted",
    updatedAt: nowDate,
    expiresAt: lockExpiresAt,
  });
}

function releaseScopedLocks(transaction, lockSnapshotsByRole, callOps, call) {
  const results = {};
  for (const role of ["caller", "callee"]) {
    const expectedUid = role === "caller" ? call.callerUid : call.calleeUid;
    const claim = lockClaimForRole(callOps, role, expectedUid);
    const lockEntry = lockSnapshotsByRole[role];
    if (!claim) {
      results[role] = "claim_missing";
      continue;
    }
    if (!lockEntry || !lockEntry.snapshot.exists) {
      results[role] = "missing";
      continue;
    }

    const lock = lockEntry.snapshot.data();
    if (!lock || lock.uid !== expectedUid || lock.callId !== call.id) {
      results[role] = "call_mismatch";
      continue;
    }
    if (lock.fencingToken !== claim.fencingToken) {
      results[role] = "fencing_mismatch";
      continue;
    }

    transaction.delete(lockEntry.ref);
    results[role] = "released";
  }
  return results;
}

function requireReportingParticipantLock({
  lockEntry,
  claim,
  call,
  role,
  nowDate,
}) {
  if (!claim || !lockEntry || !lockEntry.snapshot.exists) {
    throw new CallV2Error(
      ERROR_CODES.lockRecoveryRequired,
      "The reporting participant lock is missing.",
    );
  }
  const lock = lockEntry.snapshot.data();
  const expectedState = expectedLockStateForLifecycle(call.lifecycleState);
  if (
    !lock ||
    lock.uid !== claim.uid ||
    lock.uid !== (role === "caller" ? call.callerUid : call.calleeUid) ||
    lock.callId !== call.id ||
    lock.fencingToken !== claim.fencingToken ||
    !isValidFencingToken(lock.fencingToken) ||
    lock.state !== expectedState ||
    !isValidTimestampValue(lock.expiresAt)
  ) {
    throw new CallV2Error(
      ERROR_CODES.lockRecoveryRequired,
      "The reporting participant lock does not match its private claim.",
    );
  }
  if (
    ["ringing", "accepted"].includes(call.lifecycleState) &&
    toMillis(lock.expiresAt) <= nowDate.getTime()
  ) {
    throw new CallV2Error(
      ERROR_CODES.lockRecoveryRequired,
      "The reporting participant lock is expired.",
    );
  }
}

function requireReportingActiveLeaseLock({
  lockEntry,
  claim,
  call,
  role,
  nowDate,
}) {
  if (!claim || !lockEntry || !lockEntry.snapshot.exists) {
    throw new CallV2Error(
      ERROR_CODES.lockRecoveryRequired,
      "The reporting participant active lease lock is missing.",
    );
  }
  const lock = lockEntry.snapshot.data();
  const expectedUid = role === "caller" ? call.callerUid : call.calleeUid;
  if (
    !lock ||
    lock.uid !== expectedUid ||
    lock.uid !== claim.uid ||
    lock.callId !== call.id ||
    lock.fencingToken !== claim.fencingToken ||
    !isValidFencingToken(lock.fencingToken) ||
    lock.state !== "active" ||
    !isValidTimestampValue(lock.expiresAt)
  ) {
    throw new CallV2Error(
      ERROR_CODES.lockRecoveryRequired,
      "The reporting participant active lease lock is malformed.",
    );
  }
  if (nowDate.getTime() >= toMillis(lock.expiresAt)) {
    throw new CallV2Error(
      ERROR_CODES.invalidState,
      "The active lease has expired.",
    );
  }
}

function requireTargetActiveLeaseLock({
  lockEntry,
  claim,
  call,
  role,
}) {
  if (!claim || !lockEntry || !lockEntry.snapshot.exists) {
    throw new CallV2Error(
      ERROR_CODES.lockRecoveryRequired,
      "The target active lease lock is missing.",
    );
  }
  const lock = lockEntry.snapshot.data();
  const expectedUid = role === "caller" ? call.callerUid : call.calleeUid;
  if (
    !lock ||
    lock.uid !== expectedUid ||
    lock.uid !== claim.uid ||
    lock.callId !== call.id ||
    !isValidFencingToken(lock.fencingToken) ||
    lock.state !== "active" ||
    !isValidTimestampValue(lock.expiresAt)
  ) {
    throw new CallV2Error(
      ERROR_CODES.lockRecoveryRequired,
      "The target active lease lock is malformed.",
    );
  }
  if (lock.fencingToken !== claim.fencingToken) {
    throw new CallV2Error(
      ERROR_CODES.lockRecoveryRequired,
      "The target active lease lock does not match its private claim.",
    );
  }
  return lock;
}

function requireTaskActiveLeaseLock({ lockEntry, claim, call, role }) {
  return requireTargetActiveLeaseLock({
    lockEntry,
    claim,
    call,
    role,
  });
}

function computeMediaCallUpdate({
  call,
  callOps,
  claims,
  lockSnapshots,
  resultingMediaStates,
  previousMediaState,
  nextMediaState,
  mediaChanged,
  nowDate,
}) {
  if (
    call.lifecycleState === "accepted" &&
    resultingMediaStates.caller === "joined" &&
    resultingMediaStates.callee === "joined"
  ) {
    requireOpenAcceptedJoinWindow(call, nowDate);
    requirePromotionLocks(lockSnapshots, claims, call, nowDate);
    const callVersion = nextMonotonicVersion(call.version);
    const activeLeaseExpiresAt = addMilliseconds(
      nowDate,
      ACTIVE_LEASE_DURATION_MS,
    );
    return {
      lifecycleState: "active",
      callVersion,
      promotedToActive: true,
      activeAt: nowDate,
      activeLeaseExpiresAt,
      reconnectDeadlineAt: null,
      callFields: {
        lifecycleState: "active",
        version: callVersion,
        activeAt: nowDate,
        updatedAt: nowDate,
        lastPublicEventAt: nowDate,
        reconnectDeadlineAt: null,
      },
      lockUpdates: [
        {
          ref: lockSnapshots.caller.ref,
          fields: {
            state: "active",
            updatedAt: nowDate,
            expiresAt: activeLeaseExpiresAt,
          },
        },
        {
          ref: lockSnapshots.callee.ref,
          fields: {
            state: "active",
            updatedAt: nowDate,
            expiresAt: activeLeaseExpiresAt,
          },
        },
      ],
    };
  }

  if (call.lifecycleState === "active") {
    const reconnectUpdate = computeReconnectDeadlineUpdate({
      call,
      resultingMediaStates,
      previousMediaState,
      nextMediaState,
      mediaChanged,
      nowDate,
    });
    if (reconnectUpdate) {
      const callVersion = nextMonotonicVersion(call.version);
      return {
        lifecycleState: "active",
        callVersion,
        promotedToActive: false,
        activeAt: toDateOrNull(call.activeAt),
        activeLeaseExpiresAt: null,
        reconnectDeadlineAt: reconnectUpdate.reconnectDeadlineAt,
        callFields: {
          version: callVersion,
          reconnectDeadlineAt: reconnectUpdate.reconnectDeadlineAt,
          updatedAt: nowDate,
          lastPublicEventAt: nowDate,
        },
        lockUpdates: [],
      };
    }
  }

  return {
    lifecycleState: call.lifecycleState,
    callVersion: call.version,
    promotedToActive: false,
    activeAt: toDateOrNull(call.activeAt),
    activeLeaseExpiresAt: null,
    reconnectDeadlineAt: toDateOrNull(call.reconnectDeadlineAt),
    callFields: null,
    lockUpdates: [],
  };
}

function buildMediaTaskOutboxIntents({
  call,
  callUpdate,
  participants,
  claims,
  lockSnapshots,
  nowDate,
}) {
  if (!callUpdate.callFields) {
    return [];
  }

  if (callUpdate.promotedToActive) {
    return ["caller", "callee"].map((role) =>
      buildActiveLeaseTimeoutTaskIntent({
        callId: call.id,
        participantUid: role === "caller" ? call.callerUid : call.calleeUid,
        expectedCallVersion: callUpdate.callVersion,
        expectedHeartbeatVersion:
          participants.byRole[role].data.heartbeatVersion,
        expectedFencingToken: claims[role].fencingToken,
        expectedLeaseExpiresAt: callUpdate.activeLeaseExpiresAt,
        createdAt: nowDate,
      }),
    );
  }

  if (
    call.lifecycleState === "active" &&
    call.reconnectDeadlineAt === null &&
    callUpdate.reconnectDeadlineAt !== null
  ) {
    return [
      buildCallTimeoutTaskIntent({
        callId: call.id,
        taskKind: TASK_KINDS.reconnectTimeout,
        expectedCallVersion: callUpdate.callVersion,
        expectedDeadlineAt: callUpdate.reconnectDeadlineAt,
        createdAt: nowDate,
      }),
    ];
  }

  if (
    call.lifecycleState === "active" &&
    call.reconnectDeadlineAt !== null &&
    callUpdate.reconnectDeadlineAt === null
  ) {
    return ["caller", "callee"].map((role) => {
      const lock = requireTaskActiveLeaseLock({
        lockEntry: lockSnapshots[role],
        claim: claims[role],
        call,
        role,
      });
      return buildActiveLeaseTimeoutTaskIntent({
        callId: call.id,
        participantUid: role === "caller" ? call.callerUid : call.calleeUid,
        expectedCallVersion: callUpdate.callVersion,
        expectedHeartbeatVersion:
          participants.byRole[role].data.heartbeatVersion,
        expectedFencingToken: claims[role].fencingToken,
        expectedLeaseExpiresAt: lock.expiresAt,
        createdAt: nowDate,
      });
    });
  }

  return [];
}

function requirePromotionLocks(lockSnapshotsByRole, claims, call, nowDate) {
  for (const role of ["caller", "callee"]) {
    const lockEntry = lockSnapshotsByRole[role];
    const claim = claims[role];
    if (!lockEntry || !lockEntry.snapshot.exists || !claim) {
      throw new CallV2Error(
        ERROR_CODES.lockRecoveryRequired,
        "A promotion lock is missing.",
      );
    }
    const lock = lockEntry.snapshot.data();
    if (
      !lock ||
      lock.uid !== claim.uid ||
      lock.callId !== call.id ||
      lock.fencingToken !== claim.fencingToken ||
      !isValidFencingToken(lock.fencingToken) ||
      lock.state !== "accepted" ||
      !isValidTimestampValue(lock.expiresAt) ||
      toMillis(lock.expiresAt) <= nowDate.getTime()
    ) {
      throw new CallV2Error(
        ERROR_CODES.lockRecoveryRequired,
        "A promotion lock does not match its private claim.",
      );
    }
  }
}

function computeReconnectDeadlineUpdate({
  call,
  resultingMediaStates,
  previousMediaState,
  nextMediaState,
  mediaChanged,
  nowDate,
}) {
  if (
    resultingMediaStates.caller === "joined" &&
    resultingMediaStates.callee === "joined" &&
    call.reconnectDeadlineAt !== null
  ) {
    return {
      reconnectDeadlineAt: null,
    };
  }

  const shouldStartReconnectGrace =
    mediaChanged &&
    ["joined", "reconnecting"].includes(previousMediaState) &&
    ["reconnecting", "disconnected", "left", "media_failed"].includes(
      nextMediaState,
    ) &&
    call.reconnectDeadlineAt === null;

  if (shouldStartReconnectGrace) {
    return {
      reconnectDeadlineAt: addMilliseconds(nowDate, RECONNECT_GRACE_DURATION_MS),
    };
  }

  return null;
}

function expectedLockStateForLifecycle(lifecycleState) {
  if (lifecycleState === "ringing") {
    return "ringing";
  }
  if (lifecycleState === "accepted") {
    return "accepted";
  }
  if (lifecycleState === "active") {
    return "active";
  }
  return null;
}

function createCommandRecords(
  transaction,
  refs,
  { command, actorUid, action, callId, nowDate, result },
) {
  const ttlAt = addMilliseconds(nowDate, COMMAND_TTL_MS);
  transaction.create(refs.commandRef, {
    commandId: command.commandId,
    actorUid,
    action,
    requestHash: command.requestHash,
    idempotencyLookupId: command.idempotencyLookupId,
    callId,
    status: "completed",
    result,
    createdAt: nowDate,
    completedAt: nowDate,
    ttlAt,
  });
  transaction.create(refs.idempotencyRef, {
    actorUid,
    action,
    requestHash: command.requestHash,
    callId,
    result,
    createdAt: nowDate,
    completedAt: nowDate,
    ttlAt,
  });
}

function createTaskOutboxDocument(transaction, callOpsRef, intent) {
  transaction.create(taskOutboxRef(callOpsRef, intent.taskId), {
    schemaVersion: TASK_OUTBOX_SCHEMA_VERSION,
    taskId: intent.taskId,
    callId: intent.callId,
    taskKind: intent.taskKind,
    status: "pending",
    dueAt: intent.dueAt,
    payload: intent.payload,
    createdAt: intent.createdAt,
    updatedAt: intent.updatedAt,
    dispatchAttempts: 0,
    dispatchedAt: null,
    completedAt: null,
    lastDispatchError: null,
    claimToken: null,
    claimExpiresAt: null,
    externalTaskName: null,
    lastDispatchErrorCode: null,
    executionAttempts: 0,
    lastExecutionAt: null,
    executionOutcome: null,
    executionErrorCode: null,
    ttlAt: intent.ttlAt,
  });
}

function requireValidTaskOutboxDocument(snapshot, expected) {
  if (!snapshot.exists) {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The task outbox document is missing.",
    );
  }
  const task = snapshot.data();
  const exactKeys = [
    "callId",
    "claimExpiresAt",
    "claimToken",
    "completedAt",
    "createdAt",
    "dispatchAttempts",
    "dispatchedAt",
    "dueAt",
    "executionAttempts",
    "executionErrorCode",
    "executionOutcome",
    "externalTaskName",
    "lastDispatchError",
    "lastDispatchErrorCode",
    "lastExecutionAt",
    "payload",
    "schemaVersion",
    "status",
    "taskId",
    "taskKind",
    "ttlAt",
    "updatedAt",
  ];
  if (
    !task ||
    snapshot.id !== expected.taskId ||
    task.schemaVersion !== TASK_OUTBOX_SCHEMA_VERSION ||
    task.callId !== expected.callId ||
    task.taskId !== expected.taskId ||
    !TASK_OUTBOX_STATUSES.includes(task.status) ||
    !Object.keys(task).every((key) => exactKeys.includes(key)) ||
    Object.keys(task).length !== exactKeys.length ||
    !Object.values(TASK_KINDS).includes(task.taskKind) ||
    task.lastDispatchError !== null ||
    !Number.isSafeInteger(task.dispatchAttempts) ||
    task.dispatchAttempts < 0 ||
    !Number.isSafeInteger(task.executionAttempts) ||
    task.executionAttempts < 0
  ) {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The task outbox document is malformed.",
    );
  }

  const dueMs = strictTimestampMillis(task.dueAt);
  const createdMs = strictTimestampMillis(task.createdAt);
  const updatedMs = strictTimestampMillis(task.updatedAt);
  const ttlMs = strictTimestampMillis(task.ttlAt);
  if (
    dueMs === null ||
    createdMs === null ||
    updatedMs === null ||
    ttlMs === null ||
    ttlMs < dueMs ||
    !isValidTaskPayload(task.taskKind, task.callId, task.payload)
  ) {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The task outbox document is malformed.",
    );
  }

  const claimExpiresMs =
    task.claimExpiresAt === null
      ? null
      : strictTimestampMillis(task.claimExpiresAt);
  if (task.claimExpiresAt !== null && claimExpiresMs === null) {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The task outbox claim expiry is malformed.",
    );
  }

  if (!taskStatusFieldsAreConsistent(task, claimExpiresMs)) {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The task outbox status fields are inconsistent.",
    );
  }

  return {
    ...task,
    dueMs,
    ttlMs,
    claimExpiresMs,
  };
}

function taskStatusFieldsAreConsistent(task, claimExpiresMs) {
  if (task.status === "pending") {
    return (
      task.claimToken === null &&
      task.claimExpiresAt === null &&
      task.externalTaskName === null &&
      task.dispatchedAt === null &&
      task.completedAt === null &&
      task.executionAttempts === 0 &&
      task.lastExecutionAt === null &&
      task.executionOutcome === null &&
      task.executionErrorCode === null &&
      (task.lastDispatchErrorCode === null ||
        isControlledDispatchErrorCode(task.lastDispatchErrorCode))
    );
  }
  if (task.status === "dispatching") {
    return (
      isValidIdentifier(task.claimToken, 160) &&
      claimExpiresMs !== null &&
      task.externalTaskName === null &&
      task.dispatchedAt === null &&
      task.completedAt === null &&
      task.executionAttempts === 0 &&
      task.lastExecutionAt === null &&
      task.executionOutcome === null &&
      task.executionErrorCode === null &&
      (task.lastDispatchErrorCode === null ||
        isControlledDispatchErrorCode(task.lastDispatchErrorCode))
    );
  }
  if (task.status === "dispatched") {
    const completedMs =
      task.completedAt === null ? null : strictTimestampMillis(task.completedAt);
    const lastExecutionMs =
      task.lastExecutionAt === null
        ? null
        : strictTimestampMillis(task.lastExecutionAt);
    if (
      task.claimToken !== null ||
      task.claimExpiresAt !== null ||
      !isValidExternalTaskName(task.externalTaskName) ||
      strictTimestampMillis(task.dispatchedAt) === null ||
      task.lastDispatchErrorCode !== null
    ) {
      return false;
    }
    if (task.completedAt === null) {
      return (
        task.executionOutcome === null &&
        (task.executionAttempts === 0
          ? task.lastExecutionAt === null
          : lastExecutionMs !== null) &&
        (task.executionErrorCode === null ||
          isControlledDispatchErrorCode(task.executionErrorCode))
      );
    }
    return (
      completedMs !== null &&
      lastExecutionMs !== null &&
      TASK_EXECUTION_ACK_OUTCOMES.includes(task.executionOutcome) &&
      task.executionErrorCode === null
    );
  }
  if (task.status === "dead_letter") {
    return (
      task.claimToken === null &&
      task.claimExpiresAt === null &&
      task.externalTaskName === null &&
      task.dispatchedAt === null &&
      task.completedAt === null &&
      task.executionAttempts === 0 &&
      task.lastExecutionAt === null &&
      task.executionOutcome === null &&
      task.executionErrorCode === null &&
      isControlledDispatchErrorCode(task.lastDispatchErrorCode)
    );
  }
  return false;
}

function isValidTaskPayload(
  taskKind,
  callId,
  payload,
  options = {},
) {
  const timestampMillis = (value) =>
    options.allowJsonTimestamps
      ? taskPayloadTimestampMillis(value)
      : strictTimestampMillis(value);
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    return false;
  }
  if (taskKind === TASK_KINDS.activeLeaseTimeout) {
    return (
      exactObjectKeys(payload, [
        "callId",
        "expectedCallVersion",
        "expectedFencingToken",
        "expectedHeartbeatVersion",
        "expectedLeaseExpiresAt",
        "participantUid",
      ]) &&
      payload.callId === callId &&
      isValidIdentifier(payload.participantUid, MAX_UID_LENGTH) &&
      Number.isSafeInteger(payload.expectedCallVersion) &&
      payload.expectedCallVersion > 0 &&
      isValidHeartbeatVersion(payload.expectedHeartbeatVersion) &&
      isValidFencingToken(payload.expectedFencingToken) &&
      timestampMillis(payload.expectedLeaseExpiresAt) !== null
    );
  }

  const timeoutKind = TASK_TIMEOUT_KIND_BY_TASK_KIND[taskKind];
  return (
    Boolean(timeoutKind) &&
    exactObjectKeys(payload, [
      "callId",
      "expectedCallVersion",
      "expectedDeadlineAt",
      "timeoutKind",
    ]) &&
    payload.callId === callId &&
    payload.timeoutKind === timeoutKind &&
    Number.isSafeInteger(payload.expectedCallVersion) &&
    payload.expectedCallVersion > 0 &&
    timestampMillis(payload.expectedDeadlineAt) !== null
  );
}

function taskPayloadTimestampMillis(value) {
  if (isPlainTimestampObject(value)) {
    return plainTimestampMillis(value);
  }
  return strictTimestampMillis(value);
}

function deterministicExternalTaskId(task) {
  const dueMs = task.dueMs ?? strictTimestampMillis(task.dueAt);
  const payloadHash = sha256Hex(canonicalJson(normalizeTaskPayloadIdentity(
    task.payload,
  )));
  const digest = sha256Hex(
    canonicalJson({
      callId: task.callId,
      taskId: task.taskId,
      taskKind: task.taskKind,
      dueMs,
      payloadHash,
    }),
  ).slice(0, 48);
  return `helperly-call-v2-${digest}`;
}

function normalizeTaskPayloadIdentity(payload) {
  const normalized = {};
  for (const [key, value] of Object.entries(payload)) {
    if (value instanceof Date) {
      normalized[key] = value.getTime();
    } else if (value && typeof value.toMillis === "function") {
      normalized[key] = value.toMillis();
    } else if (isPlainTimestampObject(value)) {
      normalized[key] = plainTimestampMillis(value);
    } else {
      normalized[key] = value;
    }
  }
  return normalized;
}

function validateTaskOutboxRequest(request) {
  requireExactRequestKeys(request, ["callId", "taskId"], "task outbox");
  if (!isValidIdentifier(request.callId, 160)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A valid callId is required.",
    );
  }
  if (!isValidIdentifier(request.taskId, 220)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A valid taskId is required.",
    );
  }
  return {
    callId: request.callId,
    taskId: request.taskId,
  };
}

function validateDispatchSuccessRequest(request) {
  requireExactRequestKeys(
    request,
    ["callId", "claimToken", "externalTaskName", "publisherOutcome", "taskId"],
    "task dispatch success",
  );
  const base = validateTaskOutboxRequest({
    callId: request.callId,
    taskId: request.taskId,
  });
  if (!isValidIdentifier(request.claimToken, 160)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A valid claimToken is required.",
    );
  }
  if (!isValidExternalTaskName(request.externalTaskName)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A valid externalTaskName is required.",
    );
  }
  if (!TASK_PUBLISHER_OUTCOMES.includes(request.publisherOutcome)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A supported publisherOutcome is required.",
    );
  }
  return {
    ...base,
    claimToken: request.claimToken,
    externalTaskName: request.externalTaskName,
    publisherOutcome: request.publisherOutcome,
  };
}

function validateDispatchFailureRequest(request) {
  requireExactRequestKeys(
    request,
    ["callId", "claimToken", "errorCode", "retryable", "taskId"],
    "task dispatch failure",
  );
  const base = validateTaskOutboxRequest({
    callId: request.callId,
    taskId: request.taskId,
  });
  if (!isValidIdentifier(request.claimToken, 160)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A valid claimToken is required.",
    );
  }
  if (!isControlledDispatchErrorCode(request.errorCode)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A controlled errorCode is required.",
    );
  }
  if (typeof request.retryable !== "boolean") {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A retryable boolean is required.",
    );
  }
  return {
    ...base,
    claimToken: request.claimToken,
    errorCode: request.errorCode,
    retryable: request.retryable,
  };
}

function validateTimeoutTaskEnvelope(request) {
  requireExactRequestKeys(
    request,
    [
      "callId",
      "externalTaskId",
      "outboxTaskId",
      "payload",
      "schemaVersion",
      "taskKind",
    ],
    "timeout task envelope",
  );
  if (request.schemaVersion !== 1) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A supported timeout task envelope schemaVersion is required.",
    );
  }
  if (!isValidIdentifier(request.callId, 160)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A valid callId is required.",
    );
  }
  if (!isValidIdentifier(request.outboxTaskId, 220)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A valid outboxTaskId is required.",
    );
  }
  if (!isValidIdentifier(request.externalTaskId, 220)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A valid externalTaskId is required.",
    );
  }
  if (!Object.values(TASK_KINDS).includes(request.taskKind)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A supported taskKind is required.",
    );
  }
  if (
    !isValidTaskPayload(
      request.taskKind,
      request.callId,
      request.payload,
      { allowJsonTimestamps: true },
    )
  ) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A valid timeout payload is required.",
    );
  }
  return {
    schemaVersion: request.schemaVersion,
    externalTaskId: request.externalTaskId,
    callId: request.callId,
    outboxTaskId: request.outboxTaskId,
    taskKind: request.taskKind,
    payload: request.payload,
  };
}

function validateExecutionAcknowledgementRequest(request) {
  requireExactRequestKeys(
    request,
    ["callId", "executionOutcome", "externalTaskId", "outboxTaskId"],
    "task execution acknowledgement",
  );
  const base = validateExecutionTaskIdentityRequest(request);
  if (!TASK_EXECUTION_ACK_OUTCOMES.includes(request.executionOutcome)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A supported executionOutcome is required.",
    );
  }
  return {
    ...base,
    executionOutcome: request.executionOutcome,
  };
}

function validateExecutionFailureRequest(request) {
  requireExactRequestKeys(
    request,
    ["callId", "errorCode", "externalTaskId", "outboxTaskId"],
    "task execution failure",
  );
  const base = validateExecutionTaskIdentityRequest(request);
  if (!isControlledDispatchErrorCode(request.errorCode)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A controlled execution errorCode is required.",
    );
  }
  return {
    ...base,
    errorCode: request.errorCode,
  };
}

function validateExecutionTaskIdentityRequest(request) {
  if (!isValidIdentifier(request.callId, 160)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A valid callId is required.",
    );
  }
  if (!isValidIdentifier(request.outboxTaskId, 220)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A valid outboxTaskId is required.",
    );
  }
  if (!isValidIdentifier(request.externalTaskId, 220)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A valid externalTaskId is required.",
    );
  }
  return {
    callId: request.callId,
    outboxTaskId: request.outboxTaskId,
    externalTaskId: request.externalTaskId,
  };
}

async function loadExecutableOutboxTask(db, envelope) {
  const snapshot = await db
    .collection("callOps")
    .doc(envelope.callId)
    .collection("taskOutbox")
    .doc(envelope.outboxTaskId)
    .get();
  const task = requireValidTaskOutboxDocument(snapshot, {
    callId: envelope.callId,
    taskId: envelope.outboxTaskId,
  });
  if (task.status !== "dispatched") {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "Only dispatched timeout tasks can execute.",
    );
  }
  requireExecutableDispatchedTaskIdentity(task, envelope);
  if (task.taskKind !== envelope.taskKind) {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The timeout task kind does not match the outbox task.",
    );
  }
  if (!taskPayloadsCanonicallyEqual(task.payload, envelope.payload)) {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The timeout task payload does not match the outbox task.",
    );
  }
  return task;
}

function requireExecutableDispatchedTaskIdentity(task, request) {
  if (task.status !== "dispatched") {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The timeout task is not dispatched.",
    );
  }
  const expectedExternalTaskId = deterministicExternalTaskId(task);
  if (
    request.externalTaskId !== expectedExternalTaskId ||
    !externalTaskNameMatchesId(task.externalTaskName, expectedExternalTaskId)
  ) {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The timeout task external identity is invalid.",
    );
  }
}

function taskPayloadsCanonicallyEqual(left, right) {
  return (
    canonicalJson(normalizeTaskPayloadIdentity(left)) ===
    canonicalJson(normalizeTaskPayloadIdentity(right))
  );
}

async function recordExecutionFailureIfPossible({
  recordExecutionFailure,
  db,
  task,
  externalTaskId,
  errorCode,
  now,
}) {
  try {
    await recordExecutionFailure({
      db,
      request: {
        callId: task.callId,
        outboxTaskId: task.taskId,
        externalTaskId,
        errorCode,
      },
      now,
    });
  } catch {
    // Execution failure recording is best-effort; the processor failure remains
    // the authoritative error for the delivery attempt.
  }
}

function httpResult(statusCode, body) {
  return Object.freeze({
    statusCode,
    body: Object.freeze(body),
  });
}

function requireExactRequestKeys(request, allowedKeys, label) {
  if (!request || typeof request !== "object" || Array.isArray(request)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      `A ${label} request object is required.`,
    );
  }
  for (const key of Object.keys(request)) {
    if (!allowedKeys.includes(key)) {
      throw new CallV2Error(
        ERROR_CODES.invalidArgument,
        `Unsupported ${label} field: ${key}.`,
      );
    }
  }
  for (const key of allowedKeys) {
    if (!Object.prototype.hasOwnProperty.call(request, key)) {
      throw new CallV2Error(
        ERROR_CODES.invalidArgument,
        `Missing ${label} field: ${key}.`,
      );
    }
  }
}

function validateGeneratedClaimToken(generateClaimToken) {
  const claimToken = generateClaimToken();
  if (!isValidIdentifier(claimToken, 160)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "The generated claim token is invalid.",
    );
  }
  return claimToken;
}

function normalizePublishResult(result) {
  if (
    !result ||
    typeof result !== "object" ||
    Array.isArray(result) ||
    !TASK_PUBLISHER_OUTCOMES.includes(result.outcome) ||
    !isValidExternalTaskName(result.externalTaskName)
  ) {
    throw new TaskPublisherError({
      code: "publisher_invalid_result",
      retryable: true,
    });
  }
  return {
    outcome: result.outcome,
    externalTaskName: result.externalTaskName,
  };
}

function externalTaskNameMatchesId(externalTaskName, externalTaskId) {
  return (
    externalTaskName === externalTaskId ||
    externalTaskName.endsWith(`/tasks/${externalTaskId}`)
  );
}

function isValidExternalTaskName(value) {
  return (
    typeof value === "string" &&
    value.length > 0 &&
    value.length <= 512 &&
    value.trim() === value &&
    !/[\r\n]/.test(value)
  );
}

function isControlledDispatchErrorCode(value) {
  return (
    typeof value === "string" &&
    value.length > 0 &&
    value.length <= TASK_DISPATCH_ERROR_CODE_MAX_LENGTH &&
    value.trim() === value &&
    /^[a-z][a-z0-9_]*$/.test(value)
  );
}

function exactObjectKeys(value, expectedKeys) {
  const keys = Object.keys(value).sort();
  return (
    keys.length === expectedKeys.length &&
    keys.every((key, index) => key === [...expectedKeys].sort()[index])
  );
}

function createTimeoutCommandRecord(
  transaction,
  commandRef,
  {
    command,
    timeoutKind,
    expectedCallVersion,
    timeoutDeadlineAt,
    callId,
    nowDate,
    result,
  },
) {
  const ttlAt = addMilliseconds(nowDate, COMMAND_TTL_MS);
  transaction.create(commandRef, {
    commandId: command.commandId,
    actorType: "system",
    actorUid: null,
    action: ACTION_PROCESS_CALL_TIMEOUT,
    requestHash: command.requestHash,
    callId,
    timeoutKind,
    expectedCallVersion,
    timeoutDeadlineAt,
    status: "completed",
    result,
    createdAt: nowDate,
    completedAt: nowDate,
    ttlAt,
  });
}

function createActiveLeaseTimeoutCommandRecord(
  transaction,
  commandRef,
  {
    command,
    callId,
    participantUid,
    expectedCallVersion,
    expectedHeartbeatVersion,
    expectedFencingToken,
    timeoutDeadlineAt,
    nowDate,
    result,
  },
) {
  const ttlAt = addMilliseconds(nowDate, COMMAND_TTL_MS);
  transaction.create(commandRef, {
    commandId: command.commandId,
    actorType: "system",
    actorUid: null,
    action: ACTION_PROCESS_ACTIVE_LEASE_TIMEOUT,
    requestHash: command.requestHash,
    callId,
    participantUid,
    expectedCallVersion,
    expectedHeartbeatVersion,
    expectedFencingToken,
    timeoutDeadlineAt,
    status: "completed",
    result,
    createdAt: nowDate,
    completedAt: nowDate,
    ttlAt,
  });
}

function buildTimeoutNoopResult({
  callId,
  timeoutKind,
  status,
  call = null,
}) {
  return Object.freeze({
    callId,
    timeoutKind,
    status,
    lifecycleState: call ? call.lifecycleState : null,
    terminal: call ? call.terminal : null,
    version: call ? call.version : null,
    endedAt: call ? toDateOrNull(call.endedAt) : null,
    endReason: call ? call.endReason ?? null : null,
    failureCode: call ? call.failureCode ?? null : null,
    lockReleaseResults: null,
    idempotentReplay: false,
  });
}

function buildActiveLeaseTimeoutNoopResult({
  callId,
  participantUid,
  status,
  call = null,
}) {
  return Object.freeze({
    callId,
    participantUid,
    timeoutKind: "active_lease",
    status,
    lifecycleState: call ? call.lifecycleState : null,
    terminal: call ? call.terminal : null,
    version: call ? call.version : null,
    endedAt: call ? toDateOrNull(call.endedAt) : null,
    endReason: call ? call.endReason ?? null : null,
    failureCode: call ? call.failureCode ?? null : null,
    lockReleaseResults: null,
    idempotentReplay: false,
  });
}

function nextMonotonicVersion(value) {
  if (!isIncrementablePositiveInteger(value)) {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The version cannot be safely incremented.",
    );
  }
  return value + 1;
}

function isIncrementablePositiveInteger(value) {
  return (
    Number.isSafeInteger(value) &&
    value > 0 &&
    value < Number.MAX_SAFE_INTEGER
  );
}

function wrapTransactionError(error) {
  if (error instanceof CallV2Error) {
    throw error;
  }
  throw new CallV2Error(
    ERROR_CODES.transactionFailed,
    "The call command transaction failed.",
    {
      causeMessage: error && error.message ? error.message : String(error),
    },
  );
}

async function recoverIdempotencyCreateConflictOrThrow({
  error,
  idempotencyRef,
  expected,
  requestHash,
  fallbackMessage,
}) {
  if (error instanceof CallV2Error) {
    throw error;
  }
  const idempotencySnapshot = await idempotencyRef.get();
  if (idempotencySnapshot.exists) {
    return handleExistingIdempotencyRecord(
      idempotencySnapshot.data(),
      expected,
      requestHash,
    );
  }
  throw new CallV2Error(
    ERROR_CODES.transactionFailed,
    fallbackMessage,
    {
      causeMessage: error && error.message ? error.message : String(error),
    },
  );
}

async function recoverTimeoutCommandCreateConflictOrThrow({
  error,
  commandRef,
  expected,
  fallbackMessage,
}) {
  if (error instanceof CallV2Error) {
    throw error;
  }
  if (isAlreadyExistsError(error)) {
    const commandSnapshot = await commandRef.get();
    if (commandSnapshot.exists) {
      return handleExistingTimeoutCommandRecord(
        commandSnapshot.data(),
        expected,
      );
    }
  }
  throw new CallV2Error(
    ERROR_CODES.transactionFailed,
    fallbackMessage,
    {
      causeMessage: error && error.message ? error.message : String(error),
    },
  );
}

async function recoverActiveLeaseTimeoutCommandCreateConflictOrThrow({
  error,
  commandRef,
  expected,
  fallbackMessage,
}) {
  if (error instanceof CallV2Error) {
    throw error;
  }
  if (isAlreadyExistsError(error)) {
    const commandSnapshot = await commandRef.get();
    if (commandSnapshot.exists) {
      return handleExistingActiveLeaseTimeoutCommandRecord(
        commandSnapshot.data(),
        expected,
      );
    }
  }
  throw new CallV2Error(
    ERROR_CODES.transactionFailed,
    fallbackMessage,
    {
      causeMessage: error && error.message ? error.message : String(error),
    },
  );
}

function isAlreadyExistsError(error) {
  return (
    error &&
    (error.code === 6 ||
      error.code === "already-exists" ||
      /already exists|ALREADY_EXISTS/i.test(error.message || ""))
  );
}

function handleExistingIdempotencyRecord(
  record,
  expected,
  requestHash,
) {
  if (
    !record ||
    record.actorUid !== expected.actorUid ||
    record.action !== expected.action ||
    record.requestHash !== requestHash
  ) {
    throw new CallV2Error(
      ERROR_CODES.idempotencyConflict,
      "The idempotency key was already used for a different request.",
    );
  }

  if (!record.result || record.callId !== record.result.callId) {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The idempotency record is incomplete.",
    );
  }

  return normalizeReplayResult(record.result);
}

function handleExistingTimeoutCommandRecord(record, expected) {
  if (
    !record ||
    record.actorType !== "system" ||
    record.actorUid !== null ||
    record.action !== ACTION_PROCESS_CALL_TIMEOUT ||
    record.callId !== expected.callId ||
    record.timeoutKind !== expected.timeoutKind ||
    record.requestHash !== expected.requestHash ||
    record.status !== "completed" ||
    !record.result ||
    record.result.callId !== expected.callId ||
    record.result.timeoutKind !== expected.timeoutKind ||
    record.result.status !== "terminalized"
  ) {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The timeout command record is malformed or conflicting.",
    );
  }

  return normalizeReplayResult(record.result);
}

function handleExistingActiveLeaseTimeoutCommandRecord(record, expected) {
  if (
    !record ||
    record.actorType !== "system" ||
    record.actorUid !== null ||
    record.action !== ACTION_PROCESS_ACTIVE_LEASE_TIMEOUT ||
    record.callId !== expected.callId ||
    record.participantUid !== expected.participantUid ||
    record.requestHash !== expected.requestHash ||
    record.status !== "completed" ||
    !record.result ||
    record.result.callId !== expected.callId ||
    record.result.participantUid !== expected.participantUid ||
    record.result.timeoutKind !== "active_lease" ||
    record.result.status !== "terminalized"
  ) {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      "The active lease timeout command record is malformed or conflicting.",
    );
  }

  return normalizeReplayResult(record.result);
}

function validateStartCallInput(authUid, request) {
  if (!isNonEmptyString(authUid)) {
    throw new CallV2Error(
      ERROR_CODES.unauthenticated,
      "An authenticated caller is required.",
    );
  }
  if (!request || typeof request !== "object" || Array.isArray(request)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A start-call request object is required.",
    );
  }

  const allowedKeys = new Set(["calleeUid", "isVideo", "idempotencyKey"]);
  for (const key of Object.keys(request)) {
    if (!allowedKeys.has(key)) {
      throw new CallV2Error(
        ERROR_CODES.invalidArgument,
        `Unsupported start-call field: ${key}.`,
      );
    }
  }

  if (!isValidIdentifier(authUid, MAX_UID_LENGTH)) {
    throw new CallV2Error(
      ERROR_CODES.unauthenticated,
      "The authenticated caller is invalid.",
    );
  }
  if (!isValidIdentifier(request.calleeUid, MAX_UID_LENGTH)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A valid calleeUid is required.",
    );
  }
  if (authUid === request.calleeUid) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "The caller cannot start a call with themself.",
    );
  }
  if (typeof request.isVideo !== "boolean") {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A boolean isVideo value is required.",
    );
  }
  if (!isValidIdentifier(request.idempotencyKey, MAX_IDEMPOTENCY_KEY_LENGTH)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A valid idempotencyKey is required.",
    );
  }

  return {
    callerUid: authUid,
    calleeUid: request.calleeUid,
    isVideo: request.isVideo,
    idempotencyKey: request.idempotencyKey,
  };
}

function buildRefs(
  db,
  { callerUid, calleeUid, callId, idempotencyLookupId, commandId },
) {
  const callRef = db.collection("calls").doc(callId);
  return {
    callRef,
    callerParticipantRef: callRef.collection("participants").doc(callerUid),
    calleeParticipantRef: callRef.collection("participants").doc(calleeUid),
    callerLockRef: db.collection("activeCallLocks").doc(callerUid),
    calleeLockRef: db.collection("activeCallLocks").doc(calleeUid),
    calleeUserRef: db.collection("users").doc(calleeUid),
    idempotencyRef: db.collection("callCommandKeys").doc(idempotencyLookupId),
    callOpsRef: db.collection("callOps").doc(callId),
    commandRef: db
      .collection("callOps")
      .doc(callId)
      .collection("commands")
      .doc(commandId),
  };
}

function buildLockDocument({
  uid,
  peerUid,
  callId,
  nowDate,
  lockExpiresAt,
  commandId,
  fencingToken,
}) {
  return {
    uid,
    callId,
    peerUids: [peerUid],
    state: "ringing",
    acquiredAt: nowDate,
    updatedAt: nowDate,
    expiresAt: lockExpiresAt,
    fencingToken,
    acquiredByCommandId: commandId,
  };
}

function buildParticipantDocument({ uid, role, rtcUid }) {
  return {
    uid,
    role,
    mediaState: "not_joined",
    mediaVersion: 0,
    heartbeatVersion: 0,
    rtcUid,
    acceptedAt: null,
    localJoinStartedAt: null,
    mediaJoinedAt: null,
    mediaLeftAt: null,
    lastMediaStateAt: null,
    lastHeartbeatAt: null,
    failureCode: null,
  };
}

function sortByDocumentId(entries) {
  return [...entries].sort((left, right) =>
    left.ref.id.localeCompare(right.ref.id),
  );
}

async function readGeneratedIdCollisionTargets(transaction, refs) {
  const targets = [
    { label: "call", ref: refs.callRef },
    { label: "callerParticipant", ref: refs.callerParticipantRef },
    { label: "calleeParticipant", ref: refs.calleeParticipantRef },
    { label: "callOps", ref: refs.callOpsRef },
    { label: "command", ref: refs.commandRef },
  ];

  const snapshots = [];
  for (const target of targets) {
    snapshots.push({
      label: target.label,
      snapshot: await transaction.get(target.ref),
    });
  }
  return snapshots;
}

function verifyGeneratedIdIsUnused(collisionSnapshots) {
  const collision = collisionSnapshots.find((entry) => entry.snapshot.exists);
  if (collision) {
    throw new CallV2Error(
      ERROR_CODES.callIdConflict,
      `The generated call ID conflicts with an existing ${collision.label} document.`,
    );
  }
}

function expiredLockCallRefs(db, lockSnapshots, nowDate) {
  const callIds = new Set();
  for (const entry of lockSnapshots) {
    if (!entry.snapshot.exists) {
      continue;
    }
    const lock = entry.snapshot.data();
    if (isExpiredLock(lock, nowDate) && isNonEmptyString(lock.callId)) {
      callIds.add(lock.callId);
    }
  }
  return [...callIds]
    .sort()
    .map((callId) => db.collection("calls").doc(callId));
}

function verifyLocksCanBeAcquired(
  lockSnapshots,
  referencedCallSnapshots,
  nowDate,
) {
  for (const entry of lockSnapshots) {
    if (!entry.snapshot.exists) {
      continue;
    }
    const lock = entry.snapshot.data();
    if (!isExpiredLock(lock, nowDate)) {
      throw new CallV2Error(
        ERROR_CODES.userBusy,
        "A participant already has an active call lock.",
      );
    }
    if (!isIncrementableFencingToken(lock.fencingToken)) {
      throw new CallV2Error(
        ERROR_CODES.lockRecoveryRequired,
        "An expired lock has a fencing token that cannot be safely incremented.",
      );
    }

    const referencedCall =
      lock && isNonEmptyString(lock.callId)
        ? referencedCallSnapshots.get(lock.callId)
        : undefined;
    if (referencedCall && referencedCall.exists) {
      const call = referencedCall.data();
      if (!call || call.terminal !== true) {
        throw new CallV2Error(
          ERROR_CODES.lockRecoveryRequired,
          "An expired lock references a non-terminal call.",
        );
      }
    }
  }
}

function nextFencingToken(lockSnapshots, uid) {
  const entry = lockSnapshots.find((candidate) => candidate.uid === uid);
  if (!entry || !entry.snapshot.exists) {
    return 1;
  }
  const previous = entry.snapshot.data().fencingToken;
  if (!isIncrementableFencingToken(previous)) {
    throw new CallV2Error(
      ERROR_CODES.lockRecoveryRequired,
      "An expired lock has a fencing token that cannot be safely incremented.",
    );
  }
  return previous + 1;
}

function isExpiredLock(lock, nowDate) {
  if (!lock || !isValidTimestampValue(lock.expiresAt)) {
    throw new CallV2Error(
      ERROR_CODES.lockRecoveryRequired,
      "An existing lock has a malformed expiry.",
    );
  }
  return toMillis(lock.expiresAt) <= nowDate.getTime();
}

function isValidFencingToken(value) {
  return (
    Number.isSafeInteger(value) &&
    value > 0
  );
}

function isIncrementableFencingToken(value) {
  return isValidFencingToken(value) && value < Number.MAX_SAFE_INTEGER;
}

function isValidTimestampValue(value) {
  return strictTimestampMillis(value) !== null;
}

function strictTimestampMillis(value) {
  if (value instanceof Date) {
    const millis = value.getTime();
    return Number.isFinite(millis) ? millis : null;
  }
  if (!value || typeof value.toMillis !== "function") {
    return null;
  }
  try {
    const millis = value.toMillis();
    return Number.isFinite(millis) ? millis : null;
  } catch {
    return null;
  }
}

function isPlainTimestampObject(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return false;
  }
  const keys = Object.keys(value).sort();
  const hasPublicKeys = keys[0] === "nanoseconds" && keys[1] === "seconds";
  const hasPrivateKeys = keys[0] === "_nanoseconds" && keys[1] === "_seconds";
  return (
    (hasPublicKeys || hasPrivateKeys) &&
    Number.isSafeInteger(value.seconds ?? value._seconds) &&
    Number.isSafeInteger(value.nanoseconds ?? value._nanoseconds)
  );
}

function plainTimestampMillis(value) {
  const seconds = value.seconds ?? value._seconds;
  const nanoseconds = value.nanoseconds ?? value._nanoseconds;
  if (
    !Number.isSafeInteger(seconds) ||
    !Number.isSafeInteger(nanoseconds) ||
    nanoseconds < 0 ||
    nanoseconds > 999999999 ||
    nanoseconds % 1000000 !== 0
  ) {
    return null;
  }
  const millis = seconds * 1000 + nanoseconds / 1000000;
  return Number.isSafeInteger(millis) ? millis : null;
}

function isSupportedMediaState(value) {
  return SUPPORTED_MEDIA_STATES.includes(value);
}

function isValidMediaVersion(value) {
  return Number.isSafeInteger(value) && value >= 0;
}

function isIncrementableMediaVersion(value) {
  return isValidMediaVersion(value) && value < Number.MAX_SAFE_INTEGER;
}

function isValidHeartbeatVersion(value) {
  return Number.isSafeInteger(value) && value >= 0;
}

function isIncrementableHeartbeatVersion(value) {
  return isValidHeartbeatVersion(value) && value < Number.MAX_SAFE_INTEGER;
}

function normalizeReplayResult(result) {
  const normalized = {
    ...result,
    idempotentReplay: true,
  };
  for (const field of [
    "ringingDeadlineAt",
    "acceptedAt",
    "acceptedJoinDeadlineAt",
    "endedAt",
    "activeAt",
    "reconnectDeadlineAt",
    "lastHeartbeatAt",
    "leaseExpiresAt",
    "timeoutDeadlineAt",
  ]) {
    if (normalized[field]) {
      normalized[field] = toDate(normalized[field]);
    }
  }
  return normalized;
}

function toDateOrNull(value) {
  if (value === null || value === undefined) {
    return null;
  }
  return toDate(value);
}

function deriveAgoraChannel(callId) {
  return `call_v2_${sha256Hex(callId).slice(0, 32)}`;
}

function deriveRtcUid(callId, uid, role) {
  const digest = crypto
    .createHash("sha256")
    .update(`${callId}\u0000${uid}\u0000${role}`)
    .digest();
  const value = digest.readUInt32BE(0) & 0x7fffffff;
  return value === 0 ? 1 : value;
}

function deriveDistinctRtcUid(callId, uid, role, reservedRtcUid) {
  let rtcUid = deriveRtcUid(callId, uid, role);
  while (rtcUid === reservedRtcUid) {
    rtcUid = rtcUid === 0x7fffffff ? 1 : rtcUid + 1;
  }
  return rtcUid;
}

function validateGeneratedId(generateCallId, label) {
  if (typeof generateCallId !== "function") {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      `A ${label} generator is required.`,
    );
  }
  const id = generateCallId();
  if (!isValidIdentifier(id, 160)) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      `The generated ${label} is invalid.`,
    );
  }
  return id;
}

function resolveNow(now) {
  const value = typeof now === "function" ? now() : now;
  if (!(value instanceof Date) || Number.isNaN(value.getTime())) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A valid server-controlled now value is required.",
    );
  }
  return new Date(value.getTime());
}

function addMilliseconds(date, milliseconds) {
  return new Date(date.getTime() + milliseconds);
}

function isValidIdentifier(value, maxLength) {
  return (
    isNonEmptyString(value) &&
    value.length <= maxLength &&
    value.trim() === value &&
    !value.includes("/")
  );
}

function isNonEmptyString(value) {
  return typeof value === "string" && value.length > 0;
}

function canonicalJson(value) {
  if (Array.isArray(value)) {
    return `[${value.map((entry) => canonicalJson(entry)).join(",")}]`;
  }
  if (value && typeof value === "object") {
    return `{${Object.keys(value)
      .sort()
      .map((key) => `${JSON.stringify(key)}:${canonicalJson(value[key])}`)
      .join(",")}}`;
  }
  return JSON.stringify(value);
}

function sha256Hex(input) {
  return crypto.createHash("sha256").update(input).digest("hex");
}

function toMillis(value) {
  if (value instanceof Date) {
    return value.getTime();
  }
  if (value && typeof value.toMillis === "function") {
    return value.toMillis();
  }
  if (value && typeof value.toDate === "function") {
    return value.toDate().getTime();
  }
  return new Date(value).getTime();
}

function toDate(value) {
  if (value instanceof Date) {
    return new Date(value.getTime());
  }
  if (value && typeof value.toDate === "function") {
    return value.toDate();
  }
  return new Date(value);
}

module.exports = {
  ACCEPTED_JOIN_DURATION_MS,
  ACTIVE_LEASE_DURATION_MS,
  ACTION_START_CALL,
  ACTION_ACCEPT_CALL,
  ACTION_CANCEL_CALL,
  ACTION_DECLINE_CALL,
  ACTION_END_CALL,
  ACTION_PROCESS_ACTIVE_LEASE_TIMEOUT,
  ACTION_PROCESS_CALL_TIMEOUT,
  ACTION_REPORT_PARTICIPANT_MEDIA,
  ACTION_RENEW_ACTIVE_CALL_LEASE,
  CALL_SCHEMA_VERSION,
  COMMAND_TTL_MS,
  ERROR_CODES,
  LOCK_EXPIRY_SAFETY_BUFFER_MS,
  OPS_RETENTION_MS,
  PUBLIC_HISTORY_RETENTION_MS,
  RECONNECT_GRACE_DURATION_MS,
  RINGING_DURATION_MS,
  TASK_DISPATCH_CLAIM_DURATION_MS,
  TASK_DISPATCH_ERROR_CODE_MAX_LENGTH,
  TASK_DISPATCH_MAX_ATTEMPTS,
  TASK_EXECUTION_ACK_OUTCOMES,
  TASK_OUTBOX_RETENTION_MS,
  TASK_OUTBOX_SCHEMA_VERSION,
  CallV2Error,
  TaskPublisherError,
  acceptCallV2,
  acknowledgeTimeoutTaskExecutionV2,
  cancelCallV2,
  claimTaskOutboxDispatchV2,
  createTimeoutTaskHttpHandlerV2,
  declineCallV2,
  deterministicExternalTaskId,
  dispatchTaskOutboxV2,
  deriveRtcUid,
  endCallV2,
  executeTimeoutTaskEnvelopeV2,
  finalizeTaskOutboxDispatchFailureV2,
  finalizeTaskOutboxDispatchSuccessV2,
  processActiveLeaseTimeoutV2,
  processCallTimeoutV2,
  recordTimeoutTaskExecutionFailureV2,
  reportParticipantMediaV2,
  renewActiveCallLeaseV2,
  startCallV2,
};
