"use strict";

const assert = require("node:assert/strict");
const { test } = require("node:test");

const { missedCallNoteFor } = require("../../call_invites/missed_call_note");
const { pushText } = require("../../i18n/push_text");

const ringing = { fromUid: "zcaller", toUid: "acallee", status: "ringing", isVideo: false };

test("an unanswered call (timeout or caller hang-up) leaves a note for the callee", () => {
  for (const status of ["missed", "cancelled"]) {
    assert.deepEqual(missedCallNoteFor(ringing, { ...ringing, status }), {
      chatId: "acallee_zcaller",
      callerUid: "zcaller",
      calleeUid: "acallee",
      isVideo: false,
      text: "Missed audio call",
      notify: true,
    }, status);
  }
  assert.equal(
    missedCallNoteFor(ringing, { ...ringing, isVideo: true, status: "missed" }).text,
    "Missed video call",
  );
});

test("a declined call leaves a silent note (no push, no unread)", () => {
  const note = missedCallNoteFor(ringing, { ...ringing, status: "declined" });
  assert.equal(note.chatId, "acallee_zcaller");
  assert.equal(note.notify, false);
});

test("no note when the callee answered or blocked the caller", () => {
  assert.equal(missedCallNoteFor(ringing, { ...ringing, status: "ended" }), null);
  assert.equal(
    missedCallNoteFor(ringing, { ...ringing, status: "cancelled", acceptedAt: 1 }),
    null,
  );
  assert.equal(
    missedCallNoteFor(ringing, { ...ringing, status: "missed", endReason: "callee_unavailable" }),
    null,
  );
});

test("no note without both users or on a repeated status", () => {
  assert.equal(missedCallNoteFor({}, { status: "missed", fromUid: "a" }), null);
  assert.equal(missedCallNoteFor(ringing, { ...ringing, status: "missed", toUid: "zcaller" }), null);
  const missed = { ...ringing, status: "missed" };
  assert.equal(missedCallNoteFor(missed, missed), null);
});

test("the push text is in the callee's language", () => {
  assert.equal(pushText("fr", "missedVideoCall"), "Appel vidéo manqué");
  assert.equal(pushText("en", "missedAudioCall"), "Missed audio call");
});
