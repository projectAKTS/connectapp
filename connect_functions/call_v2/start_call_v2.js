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
const CALL_SCHEMA_VERSION = 2;
const RINGING_DURATION_MS = 45 * 1000;
const ACCEPTED_JOIN_DURATION_MS = 30 * 1000;
const RECONNECT_GRACE_DURATION_MS = 25 * 1000;
const LOCK_EXPIRY_SAFETY_BUFFER_MS = 5 * 1000;
const COMMAND_TTL_MS = 7 * 24 * 60 * 60 * 1000;
const OPS_RETENTION_MS = 30 * 24 * 60 * 60 * 1000;
const PUBLIC_HISTORY_RETENTION_MS = 90 * 24 * 60 * 60 * 1000;
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

      validateMediaLifecycleAllowsReport(
        call,
        nowDate,
        participants.byRole[actorRole].data.mediaState,
        validatedRequest.mediaState,
      );
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
      !isValidMediaVersion(participant.mediaVersion)
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

function validateMediaLifecycleAllowsReport(
  call,
  nowDate,
  currentMediaState,
  requestedMediaState,
) {
  if (call.lifecycleState === "ringing") {
    requireOpenRingingWindow(call, nowDate);
    if (
      currentMediaState === requestedMediaState ||
      requestedMediaState === "preparing" ||
      requestedMediaState === "media_failed"
    ) {
      return;
    }
    throw new CallV2Error(
      ERROR_CODES.invalidState,
      "The requested media state is not allowed while ringing.",
    );
  }

  if (call.lifecycleState === "accepted") {
    requireOpenAcceptedJoinWindow(call, nowDate);
    requireAllowedMediaTransition(currentMediaState, requestedMediaState);
    return;
  }

  if (call.lifecycleState === "active") {
    requireAllowedMediaTransition(currentMediaState, requestedMediaState);
    return;
  }

  throw new CallV2Error(
    ERROR_CODES.invalidState,
    "The call is not in a valid state for media reports.",
  );
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
    return {
      lifecycleState: "active",
      callVersion,
      promotedToActive: true,
      activeAt: nowDate,
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
          },
        },
        {
          ref: lockSnapshots.callee.ref,
          fields: {
            state: "active",
            updatedAt: nowDate,
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
    reconnectDeadlineAt: toDateOrNull(call.reconnectDeadlineAt),
    callFields: null,
    lockUpdates: [],
  };
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
    !isValidTimestampValue(call.reconnectDeadlineAt);

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
  if (isAlreadyExistsError(error)) {
    const idempotencySnapshot = await idempotencyRef.get();
    if (idempotencySnapshot.exists) {
      return handleExistingIdempotencyRecord(
        idempotencySnapshot.data(),
        expected,
        requestHash,
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
  if (!lock || !lock.expiresAt) {
    return false;
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
  return value !== null && value !== undefined && Number.isFinite(toMillis(value));
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
  ACTION_START_CALL,
  ACTION_ACCEPT_CALL,
  ACTION_CANCEL_CALL,
  ACTION_DECLINE_CALL,
  ACTION_END_CALL,
  ACTION_REPORT_PARTICIPANT_MEDIA,
  CALL_SCHEMA_VERSION,
  COMMAND_TTL_MS,
  ERROR_CODES,
  LOCK_EXPIRY_SAFETY_BUFFER_MS,
  OPS_RETENTION_MS,
  PUBLIC_HISTORY_RETENTION_MS,
  RECONNECT_GRACE_DURATION_MS,
  RINGING_DURATION_MS,
  CallV2Error,
  acceptCallV2,
  cancelCallV2,
  declineCallV2,
  deriveRtcUid,
  endCallV2,
  reportParticipantMediaV2,
  startCallV2,
};
