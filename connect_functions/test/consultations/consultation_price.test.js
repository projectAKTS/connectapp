"use strict";

const assert = require("node:assert/strict");
const { test } = require("node:test");

const {
  consultationPrice,
  resolveChargeAmount,
} = require("../../consultations/consultation_price");

test("prices match the app's pricing table", () => {
  assert.equal(consultationPrice(5, "audio"), 2.99);
  assert.equal(consultationPrice(30, "audio"), 12.99);
  assert.equal(consultationPrice(60, "audio"), 22.99);
  assert.equal(consultationPrice(15, "video"), 9.09);
  assert.equal(consultationPrice(60, "video"), 29.89);
});

test("unknown durations and call types have no price", () => {
  assert.equal(consultationPrice(7, "audio"), null);
  assert.equal(consultationPrice(30, "phone"), null);
});

test("the server prices the session, ignoring a client amount", () => {
  const r = resolveChargeAmount({ durationMinutes: 30, callType: "audio", amount: 0.01 });
  assert.deepEqual(r, { amount: 12.99, durationMinutes: 30, callType: "audio", legacy: false });
});

test("free and invalid sessions are not charged", () => {
  assert.ok(resolveChargeAmount({ durationMinutes: 1, callType: "audio" }).error);
  assert.ok(resolveChargeAmount({ durationMinutes: 30, callType: "fax" }).error);
});

test("legacy amount-only calls must use an offered price", () => {
  assert.equal(resolveChargeAmount({ amount: 6.99 }).amount, 6.99);
  assert.equal(resolveChargeAmount({ amount: 16.89 }).amount, 16.89);
  assert.ok(resolveChargeAmount({ amount: 0.01 }).error);
  assert.ok(resolveChargeAmount({ amount: -5 }).error);
  assert.ok(resolveChargeAmount({}).error);
});
