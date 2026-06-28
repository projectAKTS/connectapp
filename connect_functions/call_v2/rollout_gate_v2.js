"use strict";

const crypto = require("node:crypto");

const ROLLOUT_MODES = Object.freeze([
  "off",
  "staff",
  "allowlist",
  "percentage",
  "all",
]);
const ROLLOUT_REASONS = Object.freeze({
  globalDisabled: "global_disabled",
  modeOff: "mode_off",
  staffRequired: "staff_required",
  uidNotAllowlisted: "uid_not_allowlisted",
  percentageNotSelected: "percentage_not_selected",
  eligible: "eligible",
  invalidConfiguration: "invalid_configuration",
});
const ROLLOUT_ALLOWLIST_MAX_UIDS = 500;
const MAX_UID_LENGTH = 160;
const ROLLOUT_BUCKET_COUNT = 10000;
const ROLLOUT_HASH_NAMESPACE = "helperly-call-v2-rollout:v1";

function evaluateCallV2ClientEligibility({
  uid,
  authToken,
  globalEnabled,
  mode,
  percentage,
  salt,
  allowlist,
}) {
  const policy = normalizeRolloutPolicy({
    globalEnabled,
    mode,
    percentage,
    salt,
    allowlist,
  });
  if (!policy.valid) {
    return eligibilityResult(false, ROLLOUT_REASONS.invalidConfiguration, mode);
  }
  if (!policy.globalEnabled) {
    return eligibilityResult(false, ROLLOUT_REASONS.globalDisabled, policy.mode);
  }
  return evaluateNormalizedPolicy({
    uid,
    authToken,
    policy,
  });
}

function evaluateNormalizedPolicy({ uid, authToken, policy }) {
  if (!isValidUid(uid)) {
    return eligibilityResult(
      false,
      ROLLOUT_REASONS.invalidConfiguration,
      policy.mode,
    );
  }
  if (policy.mode === "off") {
    return eligibilityResult(false, ROLLOUT_REASONS.modeOff, policy.mode);
  }
  if (policy.mode === "all") {
    return eligibilityResult(true, ROLLOUT_REASONS.eligible, policy.mode);
  }
  if (policy.mode === "staff") {
    return eligibilityResult(
      authToken && authToken.callV2Staff === true,
      authToken && authToken.callV2Staff === true
        ? ROLLOUT_REASONS.eligible
        : ROLLOUT_REASONS.staffRequired,
      policy.mode,
    );
  }
  if (policy.mode === "allowlist") {
    return eligibilityResult(
      policy.allowlistSet.has(uid),
      policy.allowlistSet.has(uid)
        ? ROLLOUT_REASONS.eligible
        : ROLLOUT_REASONS.uidNotAllowlisted,
      policy.mode,
    );
  }
  if (policy.mode === "percentage") {
    const bucket = deterministicRolloutBucketV2({
      uid,
      salt: policy.salt,
    });
    const eligible = bucket < (policy.percentage * 100);
    return eligibilityResult(
      eligible,
      eligible
        ? ROLLOUT_REASONS.eligible
        : ROLLOUT_REASONS.percentageNotSelected,
      policy.mode,
    );
  }
  return eligibilityResult(
    false,
    ROLLOUT_REASONS.invalidConfiguration,
    policy.mode,
  );
}

async function resolveTargetEligibilityV2({
  uid,
  rolloutPolicy,
  getUser,
}) {
  const policy = normalizeRolloutPolicy(rolloutPolicy || {});
  if (!policy.valid || !policy.globalEnabled) {
    return eligibilityResult(
      false,
      policy.valid
        ? ROLLOUT_REASONS.globalDisabled
        : ROLLOUT_REASONS.invalidConfiguration,
      policy.mode,
    );
  }
  if (!isValidUid(uid)) {
    return eligibilityResult(
      false,
      ROLLOUT_REASONS.invalidConfiguration,
      policy.mode,
    );
  }
  if (policy.mode !== "staff") {
    return evaluateNormalizedPolicy({
      uid,
      authToken: {},
      policy,
    });
  }
  if (typeof getUser !== "function") {
    return eligibilityResult(false, ROLLOUT_REASONS.staffRequired, policy.mode);
  }
  try {
    const userRecord = await getUser(uid);
    return evaluateNormalizedPolicy({
      uid,
      authToken: userRecord && userRecord.customClaims
        ? userRecord.customClaims
        : {},
      policy,
    });
  } catch {
    return eligibilityResult(false, ROLLOUT_REASONS.staffRequired, policy.mode);
  }
}

function normalizeRolloutPolicy({
  globalEnabled,
  mode,
  percentage,
  salt,
  allowlist,
}) {
  const normalizedMode = normalizeMode(mode);
  const normalizedPercentage = parsePercentage(percentage);
  const allowlistResult = parseRolloutAllowlistV2(allowlist);
  const normalizedSalt = typeof salt === "string" ? salt.trim() : "";
  let valid = true;
  if (!ROLLOUT_MODES.includes(normalizedMode)) {
    valid = false;
  }
  if (!Number.isInteger(normalizedPercentage)) {
    valid = false;
  }
  if (normalizedMode === "percentage" && !normalizedSalt) {
    valid = false;
  }
  if (normalizedMode === "allowlist" && !allowlistResult.valid) {
    valid = false;
  }
  return Object.freeze({
    valid,
    globalEnabled: globalEnabled === true || globalEnabled === "true",
    mode: normalizedMode,
    percentage: normalizedPercentage,
    salt: normalizedSalt,
    allowlist: allowlistResult.uids,
    allowlistSet: new Set(allowlistResult.uids),
  });
}

function validateRolloutReadinessV2({
  clientEnabled,
  mode,
  percentage,
  salt,
  allowlist,
  staffClaimsManaged,
  allowGlobalClientRollout,
}) {
  if (clientEnabled !== true) {
    return sanitizedRolloutReadiness({
      rolloutConfigRequired: false,
      mode: "off",
      percentage: 0,
      allowlistCount: 0,
      staffClaimsManaged: false,
      globalClientRolloutApproved: false,
    });
  }
  const normalizedMode = normalizeMode(mode);
  if (!ROLLOUT_MODES.includes(normalizedMode) || normalizedMode === "off") {
    throw new Error("A non-off Call V2 rollout mode is required.");
  }
  const normalizedPercentage = parsePercentage(percentage);
  if (!Number.isInteger(normalizedPercentage)) {
    throw new Error("A valid Call V2 rollout percentage is required.");
  }
  if (normalizedMode === "staff" && staffClaimsManaged !== true) {
    throw new Error("Staff custom-claim management acknowledgement is required.");
  }
  let allowlistCount = 0;
  if (normalizedMode === "allowlist") {
    const parsed = parseRolloutAllowlistV2(allowlist);
    if (!parsed.valid || parsed.uids.length === 0) {
      throw new Error("A valid non-empty Call V2 rollout allowlist is required.");
    }
    allowlistCount = parsed.uids.length;
  }
  if (
    normalizedMode === "percentage" &&
    (normalizedPercentage < 1 || normalizedPercentage > 100 ||
      typeof salt !== "string" || !salt.trim())
  ) {
    throw new Error("A valid percentage rollout and explicit salt are required.");
  }
  if (normalizedMode === "all" && allowGlobalClientRollout !== true) {
    throw new Error("Global client rollout requires explicit approval.");
  }
  return sanitizedRolloutReadiness({
    rolloutConfigRequired: true,
    mode: normalizedMode,
    percentage: normalizedPercentage,
    allowlistCount,
    staffClaimsManaged: staffClaimsManaged === true,
    globalClientRolloutApproved: allowGlobalClientRollout === true,
  });
}

function deterministicRolloutBucketV2({ uid, salt }) {
  if (!isValidUid(uid) || typeof salt !== "string" || !salt) {
    throw new Error("A valid UID and rollout salt are required.");
  }
  const unbiasedLimit = Math.floor(0x100000000 / ROLLOUT_BUCKET_COUNT) *
    ROLLOUT_BUCKET_COUNT;
  let attempt = 0;
  while (attempt < 8) {
    const digest = crypto
      .createHash("sha256")
      .update(canonicalRolloutInput({ uid, salt, attempt }), "utf8")
      .digest();
    for (let offset = 0; offset <= digest.length - 4; offset += 4) {
      const value = digest.readUInt32BE(offset);
      if (value < unbiasedLimit) {
        return value % ROLLOUT_BUCKET_COUNT;
      }
    }
    attempt += 1;
  }
  throw new Error("Unable to derive a deterministic rollout bucket.");
}

function parseRolloutAllowlistV2(value) {
  if (typeof value !== "string" || !value.trim()) {
    return Object.freeze({ valid: false, uids: Object.freeze([]) });
  }
  const rawEntries = value.split(",");
  const seen = new Set();
  const uids = [];
  for (const rawEntry of rawEntries) {
    const uid = rawEntry.trim();
    if (!uid) {
      return Object.freeze({ valid: false, uids: Object.freeze([]) });
    }
    if (!isValidUid(uid)) {
      return Object.freeze({ valid: false, uids: Object.freeze([]) });
    }
    if (!seen.has(uid)) {
      seen.add(uid);
      uids.push(uid);
    }
  }
  if (uids.length > ROLLOUT_ALLOWLIST_MAX_UIDS) {
    return Object.freeze({ valid: false, uids: Object.freeze([]) });
  }
  return Object.freeze({ valid: true, uids: Object.freeze(uids) });
}

function canonicalRolloutInput({ uid, salt, attempt }) {
  return JSON.stringify({
    namespace: ROLLOUT_HASH_NAMESPACE,
    uid,
    salt,
    attempt,
  });
}

function normalizeMode(mode) {
  return typeof mode === "string" && mode.trim()
    ? mode.trim()
    : "off";
}

function parsePercentage(value) {
  let numberValue;
  if (typeof value === "number") {
    numberValue = value;
  } else {
    const raw = `${value ?? 0}`.trim();
    if (!/^\d+$/.test(raw)) {
      return NaN;
    }
    numberValue = Number(raw);
  }
  if (!Number.isInteger(numberValue) || numberValue < 0 || numberValue > 100) {
    return NaN;
  }
  return numberValue;
}

function isValidUid(uid) {
  return (
    typeof uid === "string" &&
    uid.length > 0 &&
    uid.length <= MAX_UID_LENGTH &&
    uid.trim() === uid &&
    /^[A-Za-z0-9][A-Za-z0-9_-]*$/.test(uid)
  );
}

function eligibilityResult(eligible, reason, mode) {
  return Object.freeze({
    eligible,
    reason,
    mode,
  });
}

function sanitizedRolloutReadiness({
  rolloutConfigRequired,
  mode,
  percentage,
  allowlistCount,
  staffClaimsManaged,
  globalClientRolloutApproved,
}) {
  return Object.freeze({
    rolloutConfigRequired,
    rolloutMode: mode,
    rolloutPercentage: percentage,
    rolloutAllowlistCount: allowlistCount,
    staffClaimsManaged,
    globalClientRolloutApproved,
  });
}

module.exports = {
  ROLLOUT_ALLOWLIST_MAX_UIDS,
  ROLLOUT_BUCKET_COUNT,
  ROLLOUT_MODES,
  ROLLOUT_REASONS,
  deterministicRolloutBucketV2,
  evaluateCallV2ClientEligibility,
  normalizeRolloutPolicy,
  parseRolloutAllowlistV2,
  resolveTargetEligibilityV2,
  validateRolloutReadinessV2,
};
