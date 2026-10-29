"use strict";

const assert = require("node:assert/strict");
const { test } = require("node:test");

const { declinedElsewhereFcmRecipients } = require("../../call_invites/declined_elsewhere");

test("a decline also reaches the callee's other devices", () => {
  const invite = { fromUid: "caller", toUid: "callee", status: "ringing" };
  assert.deepEqual(
    declinedElsewhereFcmRecipients(invite, { ...invite, status: "declined" }, "declined"),
    ["callee"],
  );
  assert.deepEqual(
    declinedElsewhereFcmRecipients(invite, { status: "declined" }, " Declined "),
    ["callee"],
    "falls back to the before snapshot and normalizes the status",
  );
});

test("other terminal statuses add no recipients", () => {
  const invite = { fromUid: "caller", toUid: "callee" };
  for (const status of ["cancelled", "missed", "ended", "accepted", ""]) {
    assert.deepEqual(declinedElsewhereFcmRecipients(invite, invite, status), [], status);
  }
});

test("no callee, no recipient", () => {
  assert.deepEqual(declinedElsewhereFcmRecipients({}, {}, "declined"), []);
});
