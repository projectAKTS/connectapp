"use strict";

const assert = require("node:assert/strict");
const { test } = require("node:test");

const { __testOnlyMergeUserPushTokenSets: mergeUserPushTokenSets } =
  require("../../index");

test("inactive installation suppresses matching legacy scalar token", () => {
  const result = mergeUserPushTokenSets({
    installationDocs: [
      {
        active: false,
        platform: "ios",
        fcmToken: "inactive_fcm",
        apnsToken: "inactive_apns",
        voipToken: "inactive_voip",
      },
    ],
    userData: {
      fcmToken: "inactive_fcm",
      apnsToken: "inactive_apns",
      voipToken: "inactive_voip",
    },
  });

  assert.deepEqual(result, {
    fcmAll: [],
    fcmForFallback: [],
    apns: [],
    voip: [],
  });
});

test("active installation matching legacy scalar is preserved once", () => {
  const result = mergeUserPushTokenSets({
    installationDocs: [
      {
        active: true,
        platform: "android",
        fcmToken: "active_fcm",
        apnsToken: "active_apns",
        voipToken: "active_voip",
      },
    ],
    userData: {
      fcmToken: "active_fcm",
      apnsToken: "active_apns",
      voipToken: "active_voip",
    },
  });

  assert.deepEqual(result, {
    fcmAll: ["active_fcm"],
    fcmForFallback: ["active_fcm"],
    apns: ["active_apns"],
    voip: ["active_voip"],
  });
});

test("active new installation preserves unrelated legacy old-build device", () => {
  const result = mergeUserPushTokenSets({
    installationDocs: [
      {
        active: true,
        platform: "ios",
        fcmToken: "new_ios_fcm",
        apnsToken: "new_apns",
        voipToken: "new_voip",
      },
    ],
    userData: {
      fcmToken: "legacy_fcm",
      apnsToken: "legacy_apns",
      voipToken: "legacy_voip",
    },
  });

  assert.deepEqual(result, {
    fcmAll: ["new_ios_fcm", "legacy_fcm"],
    fcmForFallback: ["legacy_fcm"],
    apns: ["new_apns", "legacy_apns"],
    voip: ["new_voip", "legacy_voip"],
  });
});

test("same token active and inactive is preserved by active installation", () => {
  const result = mergeUserPushTokenSets({
    installationDocs: [
      { active: false, platform: "ios", voipToken: "shared_voip" },
      { active: true, platform: "ios", voipToken: "shared_voip" },
    ],
    userData: {
      voipToken: "shared_voip",
    },
  });

  assert.deepEqual(result.voip, ["shared_voip"]);
});

test("no installation documents preserves legacy behavior", () => {
  const result = mergeUserPushTokenSets({
    installationDocs: [],
    userData: {
      fcmToken: "legacy_fcm",
      fcmTokenIos: "legacy_ios_fcm",
      apnsToken: "legacy_apns",
      voipToken: "legacy_voip",
    },
  });

  assert.deepEqual(result, {
    fcmAll: ["legacy_fcm"],
    fcmForFallback: ["legacy_fcm"],
    apns: ["legacy_apns"],
    voip: ["legacy_voip"],
  });
});
