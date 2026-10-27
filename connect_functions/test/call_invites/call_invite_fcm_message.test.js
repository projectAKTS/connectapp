"use strict";

const assert = require("node:assert/strict");
const { test } = require("node:test");

const {
  CALL_INVITE_ANDROID_TTL_MS,
  buildCallInviteFcmMessage,
} = require("../../call_invites/call_invite_fcm_message");

const payloadData = {
  channel: "c_channel",
  isVideo: "false",
  fromName: "Caller",
  fromUid: "caller_uid",
  toUid: "callee_uid",
  callId: "inv1",
};

test("Android receives a data-only high-priority call invite", () => {
  const message = buildCallInviteFcmMessage({ isVideo: false, fromName: "Caller", payloadData });
  assert.equal(message.notification, undefined, "a top-level notification would be shown by Android itself");
  assert.deepEqual(message.android, { priority: "high", ttl: CALL_INVITE_ANDROID_TTL_MS });
  assert.equal(message.android.notification, undefined);
  assert.deepEqual(message.data, { type: "call_invite", ...payloadData });
  assert.ok(CALL_INVITE_ANDROID_TTL_MS < 45 * 1000, "TTL stays under the ringing timeout");
});

test("iOS keeps the visible alert, sound, and priority", () => {
  const audio = buildCallInviteFcmMessage({ isVideo: false, fromName: "Ayse", payloadData });
  assert.deepEqual(audio.apns, {
    headers: { "apns-priority": "10" },
    payload: {
      aps: {
        alert: { title: "Incoming Audio Call", body: "From Ayse" },
        sound: "default",
        contentAvailable: true,
      },
    },
  });
  const video = buildCallInviteFcmMessage({ isVideo: true, fromName: "", payloadData });
  assert.deepEqual(video.apns.payload.aps.alert, { title: "Incoming Video Call", body: "From Someone" });
});

test("all data values stay strings for FCM", () => {
  const message = buildCallInviteFcmMessage({ isVideo: true, fromName: "Caller", payloadData });
  for (const [key, value] of Object.entries(message.data)) {
    assert.equal(typeof value, "string", `${key} must be a string`);
  }
});
