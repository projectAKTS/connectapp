"use strict";

/**
 * Server-side call-invite transitions for the `callInvites` model.
 *
 * Each action mirrors the client Firestore transaction in
 * lib/services/call_session_manager.dart exactly, so the app can move its
 * call-critical writes off the iOS Firestore client (which can wedge its
 * worker queue; firebase-ios-sdk#12522) without changing call semantics.
 * The actor's role is always derived from the authenticated uid, never from
 * the request, and only allowlisted fields are written.
 */

const PROGRESS_STATUSES = Object.freeze([
  "ringing",
  "accepted",
  "joining",
  "connected",
]);
const TERMINAL_STATUSES = Object.freeze([
  "declined",
  "missed",
  "cancelled",
  "ended",
  "failed",
]);
const STAGES = Object.freeze({
  joining: Object.freeze({
    expectedStatuses: ["ringing", "accepted", "joining"],
    calleeStatus: "joining",
    calleeTimestamp: "joiningAt",
  }),
  joined_local: Object.freeze({
    expectedStatuses: ["ringing", "accepted", "joining", "connected"],
  }),
  connected: Object.freeze({
    expectedStatuses: ["ringing", "accepted", "joining", "connected"],
    status: "connected",
    timestamp: "connectedAt",
  }),
});
const TERMINAL_TIMESTAMP_FIELDS = Object.freeze({
  declined: "declinedAt",
  missed: "missedAt",
  cancelled: "cancelledAt",
  failed: "failedAt",
});
const INVITE_ID_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;
const REASON_PATTERN = /^[A-Za-z0-9_.:-]{1,120}$/;

class CallInviteTransitionError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "CallInviteTransitionError";
    this.code = code;
  }
}

function parseStatus(raw) {
  const value = String(raw ?? "").trim().toLowerCase();
  return PROGRESS_STATUSES.includes(value) || TERMINAL_STATUSES.includes(value)
    ? value
    : "unknown";
}

function isTerminal(status) {
  return TERMINAL_STATUSES.includes(status);
}

function isProgress(status) {
  return PROGRESS_STATUSES.includes(status);
}

function truncate(value, max = 300) {
  const normalized = String(value ?? "").trim();
  return normalized.length <= max ? normalized : normalized.slice(0, max);
}

function requireInviteId(data) {
  const inviteId = String(data?.inviteId ?? "").trim();
  if (!INVITE_ID_PATTERN.test(inviteId)) {
    throw new CallInviteTransitionError(
      "invalid-argument",
      "A valid inviteId is required.",
    );
  }
  return inviteId;
}

function requireReason(raw, fallback) {
  const reason = String(raw ?? "").trim() || fallback;
  if (!REASON_PATTERN.test(reason)) {
    throw new CallInviteTransitionError(
      "invalid-argument",
      "endReason must be a short identifier.",
    );
  }
  return reason;
}

function participantRole(data, authUid) {
  const fromUid = String(data.fromUid ?? "").trim();
  const toUid = String(data.toUid ?? "").trim();
  if (fromUid && fromUid === authUid) return "caller";
  if (toUid && toUid === authUid) return "callee";
  return null;
}

function invitePayload(data, status) {
  return {
    status,
    channel: String(data.channel ?? "").trim(),
    isVideo: data.isVideo === true || String(data.isVideo) === "true",
    fromName: data.fromName == null ? null : String(data.fromName),
    fromUid: String(data.fromUid ?? "").trim(),
    toUid: String(data.toUid ?? "").trim(),
    callSystem: data.callSystem == null ? null : String(data.callSystem),
    endReason: data.endReason == null ? null : String(data.endReason),
  };
}

/** Mirrors `_acceptInviteTransactionWithRetry`'s transaction body. */
function planAccept(data, authUid) {
  if (!data) return { result: { decision: "missing" } };
  const status = parseStatus(data.status);
  const toUid = String(data.toUid ?? "").trim();
  if (!authUid || toUid !== authUid) {
    return { result: { decision: "wrongRecipient" } };
  }
  if (isTerminal(status)) {
    return { result: { decision: "terminal", invite: invitePayload(data, status) } };
  }
  if (!isProgress(status)) {
    return { result: { decision: "invalidStatus", invite: invitePayload(data, status) } };
  }
  const invite = invitePayload(data, status);
  if (!invite.channel || !invite.fromUid) {
    return { result: { decision: "invalidPayload", invite } };
  }
  if (status === "ringing") {
    return {
      update: (ts) => ({
        status: "accepted",
        acceptedAt: ts,
        calleeStage: "accepted",
        calleeLastError: "",
      }),
      result: { decision: "accepted", invite: { ...invite, status: "accepted" } },
    };
  }
  return { result: { decision: "alreadyAccepted", invite } };
}

/** Mirrors `_declineInviteTransaction`; only the callee may decline. */
function planDecline(data, authUid, request) {
  if (!data) return { result: { applied: false, status: "missing" } };
  const status = parseStatus(data.status);
  if (participantRole(data, authUid) !== "callee") {
    return { result: { applied: false, status, reason: "not_callee" } };
  }
  if (status !== "ringing") return { result: { applied: false, status } };
  const endReason = requireReason(request?.endReason, "callkit_decline");
  return {
    update: (ts) => ({
      status: "declined",
      declinedAt: ts,
      endedAt: ts,
      endedBy: authUid,
      endReason,
      calleeStage: "declined",
    }),
    result: { applied: true, status: "declined" },
  };
}

/** Mirrors `_resolveAuthoritativeTerminalTransition`. */
function planTerminal(data, authUid, request) {
  const requestedStatus = parseStatus(request?.requestedStatus);
  if (!isTerminal(requestedStatus)) {
    throw new CallInviteTransitionError(
      "invalid-argument",
      "requestedStatus must be a terminal status.",
    );
  }
  const endReason = requireReason(request?.endReason, "local_end");
  const fallback = {
    status: requestedStatus,
    endReason,
    writeApplied: false,
    preservedExistingTerminal: false,
  };
  if (!data) return { result: fallback };
  const authoritativeStatus = parseStatus(data.status);
  if (isTerminal(authoritativeStatus)) {
    return {
      result: {
        status: authoritativeStatus,
        endReason: String(data.endReason ?? endReason),
        writeApplied: false,
        preservedExistingTerminal: true,
      },
    };
  }
  const role = participantRole(data, authUid);
  if (!role) return { result: { ...fallback, reason: "not_participant" } };
  const actorIsCaller = role === "caller";

  let effectiveStatus = requestedStatus;
  if (request?.authoritativeLocalExit === true) {
    effectiveStatus =
      actorIsCaller && authoritativeStatus === "ringing" ? "cancelled" : "ended";
  } else if (
    authoritativeStatus !== "ringing" &&
    ["cancelled", "declined", "missed"].includes(requestedStatus)
  ) {
    effectiveStatus = "ended";
  }
  if (!isProgress(authoritativeStatus)) return { result: fallback };

  const prefix = actorIsCaller ? "caller" : "callee";
  const error = truncate(request?.error ?? "");
  const timestampField = TERMINAL_TIMESTAMP_FIELDS[effectiveStatus];
  return {
    update: (ts) => ({
      status: effectiveStatus,
      [`${prefix}Stage`]: effectiveStatus,
      endedAt: ts,
      endedBy: authUid,
      endReason,
      ...(timestampField ? { [timestampField]: ts } : {}),
      ...(error ? { [`${prefix}LastError`]: error } : {}),
    }),
    result: {
      status: effectiveStatus,
      endReason,
      writeApplied: true,
      preservedExistingTerminal: false,
    },
  };
}

/** Mirrors `_updateInviteForActor` for the three media progress stages. */
function planStage(data, authUid, request) {
  const stageName = String(request?.stage ?? "").trim();
  const stage = STAGES[stageName];
  if (!stage) {
    throw new CallInviteTransitionError(
      "invalid-argument",
      "stage must be joining, joined_local, or connected.",
    );
  }
  if (!data) return { result: { applied: false, status: "missing" } };
  const status = parseStatus(data.status);
  const role = participantRole(data, authUid);
  if (!role) return { result: { applied: false, status, reason: "not_participant" } };
  if (!stage.expectedStatuses.includes(status)) {
    return { result: { applied: false, status } };
  }
  const isCaller = role === "caller";
  return {
    update: (ts) => ({
      [`${isCaller ? "caller" : "callee"}Stage`]: stageName,
      ...(!isCaller && stage.calleeStatus
        ? { status: stage.calleeStatus, [stage.calleeTimestamp]: ts }
        : {}),
      ...(stage.status ? { status: stage.status, [stage.timestamp]: ts } : {}),
    }),
    result: { applied: true, status },
  };
}

const PLANNERS = Object.freeze({
  accept: (data, authUid) => planAccept(data, authUid),
  decline: planDecline,
  terminal: planTerminal,
  stage: planStage,
});

/**
 * @param {{db: object, serverTimestamp: () => unknown}} deps
 */
function createCallInviteTransitionHandler({ db, serverTimestamp }) {
  return async function handleCallInviteTransition({ authUid, data }) {
    const uid = String(authUid ?? "").trim();
    if (!uid) {
      throw new CallInviteTransitionError(
        "unauthenticated",
        "Sign in is required.",
      );
    }
    const action = String(data?.action ?? "").trim();
    const planner = PLANNERS[action];
    if (!planner) {
      throw new CallInviteTransitionError(
        "invalid-argument",
        "Unknown call invite action.",
      );
    }
    const inviteId = requireInviteId(data);
    const ref = db.collection("callInvites").doc(inviteId);
    return db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const current = snap.exists ? snap.data() || {} : null;
      const plan = planner(current, uid, data);
      if (plan.update) {
        tx.set(ref, plan.update(serverTimestamp()), { merge: true });
      }
      return { action, ...plan.result };
    });
  };
}

module.exports = {
  CallInviteTransitionError,
  createCallInviteTransitionHandler,
};
