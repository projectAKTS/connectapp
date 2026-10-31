"use strict";

const assert = require("node:assert/strict");
const { test } = require("node:test");

const { calleeBlockedCaller } = require("../../call_invites/blocked_caller");

test("a blocked caller is detected", () => {
  assert.equal(calleeBlockedCaller({ blockedUids: ["a", "b"] }, "b"), true);
});

test("everyone else gets through", () => {
  assert.equal(calleeBlockedCaller({ blockedUids: ["a"] }, "b"), false);
  assert.equal(calleeBlockedCaller({}, "b"), false);
  assert.equal(calleeBlockedCaller(undefined, "b"), false);
  assert.equal(calleeBlockedCaller({ blockedUids: "b" }, "b"), false);
  assert.equal(calleeBlockedCaller({ blockedUids: ["b"] }, ""), false);
});
