"use strict";

const assert = require("node:assert/strict");
const { test } = require("node:test");

const { callerMayJoinChannel } = require("../../call_invites/channel_access");

// Mirrors lib/services/call_session_manager.dart generateChannelName.
function channelFor(a, b, ts = "mhx2k3ab") {
  const clean = (s) => s.replace(/[^A-Za-z0-9_]/g, "").slice(0, 12);
  const [x, y] = [clean(a), clean(b)].sort();
  return `c_${x}_${y}_${ts}`.slice(0, 64);
}

const ALICE = "Zk3fQ9aLmN8pR2sT5vW7xY1bC4dE";
const BOB = "aB1cD2eF3gH4iJ5kL6mN7oP8qR9s";
const MALLORY = "Qw8eR7tY6uI5oP4aS3dF2gH1jK0l";

test("the two people in a pair call may join its channel", () => {
  const channel = channelFor(ALICE, BOB);
  assert.equal(callerMayJoinChannel(channel, ALICE), true);
  assert.equal(callerMayJoinChannel(channel, BOB), true);
});

test("anyone else is refused", () => {
  const channel = channelFor(ALICE, BOB);
  assert.equal(callerMayJoinChannel(channel, MALLORY), false);
  assert.equal(callerMayJoinChannel(channel, ""), false);
  assert.equal(callerMayJoinChannel(channel, undefined), false);
  // A uid that merely appears inside another segment does not count.
  assert.equal(callerMayJoinChannel(`c_x${ALICE.slice(0, 11)}_${BOB.slice(0, 12)}_abc`, ALICE), false);
  assert.equal(callerMayJoinChannel(`c_${BOB.slice(0, 12)}_${BOB.slice(0, 12)}_${ALICE.slice(0, 12)}`, ALICE), false);
});

test("short uids are matched whole", () => {
  assert.equal(callerMayJoinChannel(channelFor("amy", "bo"), "amy"), true);
  assert.equal(callerMayJoinChannel(channelFor("amy", "bo"), "bo"), true);
  assert.equal(callerMayJoinChannel(channelFor("amy", "bo"), "am"), false);
  assert.equal(callerMayJoinChannel(channelFor("amy", "bo"), "o"), false);
});

test("channels that are not pair-call channels are left to their own checks", () => {
  assert.equal(callerMayJoinChannel("9b2f6c1e4d7a4f0b8c3d5e6f7a8b9c0d", MALLORY), true);
  assert.equal(callerMayJoinChannel("v2_abcdef", MALLORY), true);
});
