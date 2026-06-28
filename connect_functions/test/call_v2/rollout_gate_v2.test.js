"use strict";

const assert = require("node:assert/strict");
const { test } = require("node:test");

const {
  ROLLOUT_ALLOWLIST_MAX_UIDS,
  ROLLOUT_REASONS,
  deterministicRolloutBucketV2,
  evaluateCallV2ClientEligibility,
  parseRolloutAllowlistV2,
  resolveTargetEligibilityV2,
} = require("../../call_v2/rollout_gate_v2");

test("global disabled and off rollout reject every client", () => {
  for (const mode of ["off", "staff", "allowlist", "percentage", "all"]) {
    const result = evaluateCallV2ClientEligibility({
      uid: "user_a",
      authToken: { callV2Staff: true },
      globalEnabled: false,
      mode,
      percentage: 100,
      salt: "salt",
      allowlist: "user_a",
    });
    assert.equal(result.eligible, false);
    assert.equal(result.reason, ROLLOUT_REASONS.globalDisabled);
  }

  const off = evaluateCallV2ClientEligibility({
    uid: "user_a",
    authToken: { callV2Staff: true },
    globalEnabled: true,
    mode: "off",
    percentage: 100,
    salt: "salt",
    allowlist: "user_a",
  });
  assert.equal(off.eligible, false);
  assert.equal(off.reason, ROLLOUT_REASONS.modeOff);
});

test("staff mode requires exact trusted boolean claim", () => {
  assert.equal(staffEligibility({ callV2Staff: true }).eligible, true);
  assert.equal(staffEligibility({}).eligible, false);
  assert.equal(staffEligibility({ callV2Staff: false }).eligible, false);
  assert.equal(staffEligibility({ callV2Staff: "true" }).eligible, false);
});

test("allowlist parsing and matching are strict", () => {
  assert.equal(allowlistEligibility("user_a, user_b", "user_a").eligible, true);
  assert.equal(allowlistEligibility("user_a,user_b", "user_c").eligible, false);
  assert.deepEqual(parseRolloutAllowlistV2(" user_a, user_a,user_b ").uids, [
    "user_a",
    "user_b",
  ]);
  assert.equal(parseRolloutAllowlistV2("user_a,,user_b").valid, false);
  assert.equal(parseRolloutAllowlistV2("user_*").valid, false);

  const tooMany = Array.from(
    { length: ROLLOUT_ALLOWLIST_MAX_UIDS + 1 },
    (_, index) => `user_${index}`,
  ).join(",");
  assert.equal(parseRolloutAllowlistV2(tooMany).valid, false);
});

test("percentage mode uses deterministic bounded buckets", () => {
  assert.equal(percentageEligibility(0, "user_a", "salt_a").eligible, false);
  assert.equal(percentageEligibility(100, "user_a", "salt_a").eligible, true);

  const bucket = deterministicRolloutBucketV2({
    uid: "user_a",
    salt: "salt_a",
  });
  assert.equal(Number.isInteger(bucket), true);
  assert.equal(bucket >= 0 && bucket <= 9999, true);
  assert.equal(
    deterministicRolloutBucketV2({ uid: "user_a", salt: "salt_a" }),
    bucket,
  );
  assert.equal(
    percentageEligibility(25, "user_a", "salt_a").reason,
    bucket < 2500
      ? ROLLOUT_REASONS.eligible
      : ROLLOUT_REASONS.percentageNotSelected,
  );
  assert.equal(
    deterministicRolloutBucketV2({ uid: "user_a", salt: "salt_a" }),
    bucket,
  );
  assert.equal(findSaltReshuffle(), true);
});

test("client-controlled fields do not affect eligibility", () => {
  const base = evaluateCallV2ClientEligibility({
    uid: "user_a",
    authToken: {},
    globalEnabled: true,
    mode: "allowlist",
    percentage: 0,
    salt: "",
    allowlist: "user_a",
    requestData: {
      callV2Staff: false,
      mode: "off",
      percentage: 0,
      allowlist: "",
    },
  });
  const spoofed = evaluateCallV2ClientEligibility({
    uid: "user_a",
    authToken: {},
    globalEnabled: true,
    mode: "allowlist",
    percentage: 0,
    salt: "",
    allowlist: "user_a",
    requestData: {
      callV2Staff: true,
      mode: "all",
      percentage: 100,
      allowlist: "other",
    },
  });
  assert.deepEqual(spoofed, base);
});

test("target eligibility avoids Auth lookup except staff mode", async () => {
  for (const mode of ["all", "off", "allowlist", "percentage"]) {
    let lookupCount = 0;
    const result = await resolveTargetEligibilityV2({
      uid: "target_a",
      rolloutPolicy: policyForMode(mode),
      async getUser() {
        lookupCount += 1;
        return { customClaims: { callV2Staff: true } };
      },
    });
    assert.equal(lookupCount, 0, mode);
    assert.equal(typeof result.eligible, "boolean");
  }
});

test("target staff eligibility uses trusted Admin Auth lookup", async () => {
  let lookupCount = 0;
  let result = await resolveTargetEligibilityV2({
    uid: "target_a",
    rolloutPolicy: policyForMode("staff"),
    async getUser(uid) {
      lookupCount += 1;
      assert.equal(uid, "target_a");
      return { customClaims: { callV2Staff: true } };
    },
  });
  assert.equal(lookupCount, 1);
  assert.equal(result.eligible, true);

  result = await resolveTargetEligibilityV2({
    uid: "target_a",
    rolloutPolicy: policyForMode("staff"),
    async getUser() {
      return { customClaims: {} };
    },
  });
  assert.equal(result.eligible, false);

  result = await resolveTargetEligibilityV2({
    uid: "target_a",
    rolloutPolicy: policyForMode("staff"),
    async getUser() {
      throw new Error("lookup failed");
    },
  });
  assert.equal(result.eligible, false);
});

function staffEligibility(authToken) {
  return evaluateCallV2ClientEligibility({
    uid: "user_a",
    authToken,
    globalEnabled: true,
    mode: "staff",
    percentage: 0,
    salt: "",
    allowlist: "",
  });
}

function allowlistEligibility(allowlist, uid) {
  return evaluateCallV2ClientEligibility({
    uid,
    authToken: {},
    globalEnabled: true,
    mode: "allowlist",
    percentage: 0,
    salt: "",
    allowlist,
  });
}

function percentageEligibility(percentage, uid, salt) {
  return evaluateCallV2ClientEligibility({
    uid,
    authToken: {},
    globalEnabled: true,
    mode: "percentage",
    percentage,
    salt,
    allowlist: "",
  });
}

function policyForMode(mode) {
  return {
    globalEnabled: true,
    mode,
    percentage: mode === "percentage" ? 100 : 0,
    salt: mode === "percentage" ? "salt_a" : "",
    allowlist: mode === "allowlist" ? "target_a" : "",
  };
}

function findSaltReshuffle() {
  for (let index = 0; index < 100; index += 1) {
    const uid = `user_${index}`;
    if (
      deterministicRolloutBucketV2({ uid, salt: "salt_a" }) !==
      deterministicRolloutBucketV2({ uid, salt: "salt_b" })
    ) {
      return true;
    }
  }
  return false;
}
