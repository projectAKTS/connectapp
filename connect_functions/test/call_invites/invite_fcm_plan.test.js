"use strict";

const assert = require("node:assert/strict");
const { test } = require("node:test");

const { inviteFcmPlan } = require("../../call_invites/invite_fcm_plan");

test("Android tokens go at the start; iOS FCM tokens wait as the fallback", () => {
  const plan = inviteFcmPlan({
    fcmAll: ["android-1", "ios-1", "android-2"],
    fcmForFallback: ["android-1", "android-2"],
  });
  assert.deepEqual(plan.immediate, ["android-1", "android-2"]);
  assert.deepEqual(plan.iosFallback, ["ios-1"]);
});

test("no token is sent twice", () => {
  const plan = inviteFcmPlan({
    fcmAll: ["a", "a", "ios", " ios "],
    fcmForFallback: ["a", "a", ""],
  });
  assert.deepEqual(plan.immediate, ["a"]);
  assert.deepEqual(plan.iosFallback, ["ios"]);
});

test("an iOS-only callee gets no immediate FCM", () => {
  const plan = inviteFcmPlan({ fcmAll: ["ios-1"], fcmForFallback: [] });
  assert.deepEqual(plan.immediate, []);
  assert.deepEqual(plan.iosFallback, ["ios-1"]);
});

test("missing token sets are empty", () => {
  assert.deepEqual(inviteFcmPlan(undefined), { immediate: [], iosFallback: [] });
});
