"use strict";

// iOS requires every VoIP push to report a new incoming call to CallKit. A
// VoIP push for a call that ended, was cancelled or was answered elsewhere
// cannot, and iOS then stops delivering VoIP pushes to the app (calls stop
// ringing). VoIP is therefore sent only for a new invite.

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");

const source = fs.readFileSync(path.join(__dirname, "../../index.js"), "utf8");

test("VoIP pushes are sent only from onCallInviteCreated", () => {
  const callSites = [...source.matchAll(/await sendVoipPushToTokens\(/g)].map((m) => m.index);
  assert.equal(callSites.length, 1);
  const created = source.indexOf("exports.onCallInviteCreated");
  const nextExport = source.indexOf("\nexports.", created + 1);
  assert.ok(created >= 0 && callSites[0] > created && callSites[0] < nextExport);
});
