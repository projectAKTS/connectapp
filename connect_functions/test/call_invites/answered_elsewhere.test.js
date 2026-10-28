"use strict";

const assert = require("node:assert/strict");
const { test } = require("node:test");

const {
  answeredElsewhereFcmMessage,
  answeredElsewherePayload,
  answeredElsewhereTargets,
  isAnsweredElsewhereTransition,
} = require("../../call_invites/answered_elsewhere");
const { __testOnlyMergeUserPushTokenSets: mergeTokenSets } = require("../../index");

const PHONE = "phone_installation_1";
const TABLET = "tablet_installation_2";

test("only ringing -> accepted with an answering installation qualifies", () => {
  const accepted = { status: "accepted", acceptedInstallationId: PHONE };
  assert.equal(isAnsweredElsewhereTransition({ status: "ringing" }, accepted), true);
  assert.equal(
    isAnsweredElsewhereTransition({ status: "ringing" }, { status: "accepted" }),
    false,
    "old clients record no installation: send nothing",
  );
  assert.equal(isAnsweredElsewhereTransition({ status: "accepted" }, accepted), false);
  assert.equal(
    isAnsweredElsewhereTransition({ status: "ringing" }, { ...accepted, status: "ended" }),
    false,
  );
});

test("the answering installation's tokens are excluded, including legacy copies", () => {
  const targets = answeredElsewhereTargets({
    installations: [
      {
        id: PHONE,
        data: {
          installationId: PHONE,
          platform: "ios",
          active: true,
          fcmToken: "fcm_phone",
          voipToken: "voip_phone",
        },
      },
      {
        id: TABLET,
        data: {
          installationId: TABLET,
          platform: "android",
          active: true,
          fcmToken: "fcm_tablet",
        },
      },
    ],
    userData: {
      fcmTokens: ["fcm_phone", "fcm_legacy_other"],
      voipToken: "voip_phone",
    },
    acceptedInstallationId: PHONE,
    mergeTokenSets,
  });
  assert.deepEqual(targets.fcm.sort(), ["fcm_legacy_other", "fcm_tablet"]);
  assert.deepEqual(targets.voip, []);
});

test("no answering installation means no targets", () => {
  const targets = answeredElsewhereTargets({
    installations: [{ id: TABLET, data: { active: true, fcmToken: "fcm_tablet" } }],
    userData: {},
    acceptedInstallationId: "",
    mergeTokenSets,
  });
  assert.deepEqual(targets, { fcm: [], voip: [] });
});

test("payload reuses the call_end shape with answered_elsewhere", () => {
  const payload = answeredElsewherePayload(
    "inv1",
    { status: "ringing", channel: "c_channel", fromName: "Baris" },
    {
      status: "accepted",
      channel: "c_channel",
      isVideo: true,
      fromUid: "caller",
      toUid: "callee",
      acceptedInstallationId: PHONE,
    },
  );
  assert.deepEqual(payload, {
    type: "call_end",
    action: "call_end",
    status: "answered_elsewhere",
    channel: "c_channel",
    isVideo: "true",
    fromName: "Baris",
    fromUid: "caller",
    toUid: "callee",
    callId: "inv1",
    inviteId: "inv1",
    acceptedInstallationId: PHONE,
  });
  const message = answeredElsewhereFcmMessage(payload);
  assert.equal(message.notification, undefined, "data-only");
  assert.equal(message.android.priority, "high");
  assert.equal(message.data, payload);
});
