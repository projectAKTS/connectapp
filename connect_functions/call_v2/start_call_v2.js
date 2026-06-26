"use strict";

const crypto = require("node:crypto");

const ERROR_CODES = Object.freeze({
  unauthenticated: "unauthenticated",
  invalidArgument: "invalid_argument",
  calleeNotFound: "callee_not_found",
  userBusy: "user_busy",
  idempotencyConflict: "idempotency_conflict",
  lockRecoveryRequired: "lock_recovery_required",
  transactionFailed: "transaction_failed",
});

const ACTION_START_CALL = "startCall";
const CALL_SCHEMA_VERSION = 2;
const RINGING_DURATION_MS = 45 * 1000;
const LOCK_EXPIRY_SAFETY_BUFFER_MS = 5 * 1000;
const COMMAND_TTL_MS = 7 * 24 * 60 * 60 * 1000;
const OPS_RETENTION_MS = 30 * 24 * 60 * 60 * 1000;
const MAX_IDEMPOTENCY_KEY_LENGTH = 160;
const MAX_UID_LENGTH = 160;

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
  beforeWrites,
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
          validatedRequest,
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

      const calleeSnapshot = await transaction.get(refs.calleeUserRef);
      if (!calleeSnapshot.exists) {
        throw new CallV2Error(
          ERROR_CODES.calleeNotFound,
          "The requested callee does not exist.",
        );
      }

      if (beforeWrites) {
        await beforeWrites();
      }

      const callerLock = buildLockDocument({
        uid: validatedRequest.callerUid,
        peerUid: validatedRequest.calleeUid,
        callId,
        nowDate,
        lockExpiresAt,
        commandId,
        fencingToken: nextFencingToken(
          lockSnapshots,
          validatedRequest.callerUid,
        ),
      });
      const calleeLock = buildLockDocument({
        uid: validatedRequest.calleeUid,
        peerUid: validatedRequest.callerUid,
        callId,
        nowDate,
        lockExpiresAt,
        commandId,
        fencingToken: nextFencingToken(
          lockSnapshots,
          validatedRequest.calleeUid,
        ),
      });

      transaction.set(refs.callRef, {
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
        acceptedByUid: null,
        activeAt: null,
        reconnectGraceEndsAt: null,
        endedAt: null,
        endedByUid: null,
        endReason: null,
        failureCode: null,
        historyVisible: true,
        historyExpiresAt: null,
        lastPublicEventAt: nowDate,
      });

      transaction.set(
        refs.callerParticipantRef,
        buildParticipantDocument({
          uid: validatedRequest.callerUid,
          role: "caller",
          rtcUid: callerRtcUid,
        }),
      );
      transaction.set(
        refs.calleeParticipantRef,
        buildParticipantDocument({
          uid: validatedRequest.calleeUid,
          role: "callee",
          rtcUid: calleeRtcUid,
        }),
      );

      transaction.set(refs.callerLockRef, callerLock);
      transaction.set(refs.calleeLockRef, calleeLock);

      transaction.set(refs.callOpsRef, {
        callId,
        createdAt: nowDate,
        terminalAt: null,
        latestOpsVersion: 1,
        opsRetentionExpiresAt,
      });

      transaction.set(refs.commandRef, {
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

      transaction.set(refs.idempotencyRef, {
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
      if (error instanceof CallV2Error) {
        throw error;
      }
      throw new CallV2Error(
        ERROR_CODES.transactionFailed,
        "The start-call transaction failed.",
        {
          causeMessage: error && error.message ? error.message : String(error),
        },
      );
    });
}

function handleExistingIdempotencyRecord(
  record,
  validatedRequest,
  requestHash,
) {
  if (
    !record ||
    record.actorUid !== validatedRequest.callerUid ||
    record.action !== ACTION_START_CALL ||
    record.requestHash !== requestHash
  ) {
    throw new CallV2Error(
      ERROR_CODES.idempotencyConflict,
      "The idempotency key was already used for a different start-call request.",
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
    localJoinRequestedAt: null,
    mediaJoinedAt: null,
    mediaUpdatedAt: null,
    failureCode: null,
  };
}

function sortByDocumentId(entries) {
  return [...entries].sort((left, right) =>
    left.ref.id.localeCompare(right.ref.id),
  );
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
  return Number.isSafeInteger(previous) && previous > 0 ? previous + 1 : 1;
}

function isExpiredLock(lock, nowDate) {
  if (!lock || !lock.expiresAt) {
    return false;
  }
  return toMillis(lock.expiresAt) <= nowDate.getTime();
}

function normalizeReplayResult(result) {
  return {
    callId: result.callId,
    lifecycleState: result.lifecycleState,
    version: result.version,
    ringingDeadlineAt: toDate(result.ringingDeadlineAt),
    callerRtcUid: result.callerRtcUid,
    calleeRtcUid: result.calleeRtcUid,
    idempotentReplay: true,
  };
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
  ACTION_START_CALL,
  CALL_SCHEMA_VERSION,
  COMMAND_TTL_MS,
  ERROR_CODES,
  LOCK_EXPIRY_SAFETY_BUFFER_MS,
  OPS_RETENTION_MS,
  RINGING_DURATION_MS,
  CallV2Error,
  deriveRtcUid,
  startCallV2,
};
