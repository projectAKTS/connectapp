"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { after, before, beforeEach, test } = require("node:test");

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  deleteDoc,
  doc,
  getDoc,
  setDoc,
  updateDoc,
} = require("firebase/firestore");

const PROJECT_ID = "demo-helperly-call-v2-rules";
let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(
        path.resolve(__dirname, "../../../firestore.rules"),
        "utf8",
      ),
      host: "127.0.0.1",
      port: firestorePort(),
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await seedV2Call();
  await seedPrivateV2Docs();
});

after(async () => {
  if (testEnv) {
    await testEnv.cleanup();
  }
});

test("V2 call reads are participant-only", async () => {
  await assertSucceeds(getDoc(callDoc("caller", "call_v2")));
  await assertSucceeds(getDoc(callDoc("callee", "call_v2")));
  await assertFails(getDoc(callDoc("other", "call_v2")));
  await assertFails(getDoc(unauthDoc("calls/call_v2")));
});

test("malformed duplicate role sets do not grant V2 call access", async () => {
  await seedMalformedDuplicateRoleCall();

  await assertFails(getDoc(callDoc("other", "call_malformed_roles")));
  await assertFails(getDoc(callDoc("caller", "call_malformed_roles")));
  await assertFails(getDoc(
    userDoc("other", "calls/call_malformed_roles/participants/other"),
  ));
});

test("V2 participant reads are visible only to call participants", async () => {
  for (const uid of ["caller", "callee"]) {
    await assertSucceeds(getDoc(
      userDoc(uid, "calls/call_v2/participants/caller"),
    ));
    await assertSucceeds(getDoc(
      userDoc(uid, "calls/call_v2/participants/callee"),
    ));
  }
  await assertFails(getDoc(userDoc("other", "calls/call_v2/participants/caller")));
  await assertFails(getDoc(userDoc("other", "calls/call_v2/participants/callee")));
});

test("clients cannot write V2 calls or direct lifecycle fields", async () => {
  await assertFails(setDoc(callDoc("caller", "new_call"), v2CallData()));
  await assertFails(updateDoc(callDoc("caller", "call_v2"), {
    lifecycleState: "active",
  }));
  await assertFails(updateDoc(callDoc("caller", "call_v2"), {
    ringingDeadlineAt: new Date(),
  }));
  await assertFails(updateDoc(callDoc("caller", "call_v2"), {
    terminal: true,
  }));
  await assertFails(updateDoc(callDoc("caller", "call_v2"), {
    version: 2,
  }));
  await assertFails(deleteDoc(callDoc("caller", "call_v2")));
});

test("clients cannot write media or heartbeat directly to participants", async () => {
  await assertFails(updateDoc(userDoc("caller", "calls/call_v2/participants/caller"), {
    mediaState: "joined",
  }));
  await assertFails(updateDoc(userDoc("caller", "calls/call_v2/participants/caller"), {
    heartbeatVersion: 1,
  }));
  await assertFails(setDoc(
    userDoc("caller", "calls/call_v2/participants/new_participant"),
    participantData("new_participant", "caller"),
  ));
});

test("all private V2 operational collections deny client reads and writes", async () => {
  for (const pathValue of [
    "callOps/call_v2",
    "callOps/call_v2/taskOutbox/task_1",
    "callOps/call_v2/commands/command_1",
    "activeCallLocks/caller",
    "callCommandKeys/key_1",
  ]) {
    await assertFails(getDoc(userDoc("caller", pathValue)));
    await assertFails(setDoc(userDoc("caller", pathValue), { blocked: true }));
    await assertFails(updateDoc(userDoc("caller", pathValue), { blocked: true }));
  }
});

test("representative V1 call-invite access remains unchanged", async () => {
  await assertSucceeds(setDoc(userDoc("caller", "callInvites/invite_1"), {
    fromUid: "caller",
    toUid: "callee",
    status: "ringing",
  }));
  await assertSucceeds(getDoc(userDoc("caller", "callInvites/invite_1")));
  await assertSucceeds(getDoc(userDoc("callee", "callInvites/invite_1")));
  await assertFails(getDoc(userDoc("other", "callInvites/invite_1")));
  await assertSucceeds(updateDoc(userDoc("callee", "callInvites/invite_1"), {
    status: "declined",
  }));
});

test("push installation owner can create and update only expected metadata", async () => {
  const ownerInstallation = doc(
    testEnv.authenticatedContext("caller").firestore(),
    "users/caller/pushInstallations/install_owner_1",
  );
  await assertSucceeds(setDoc(ownerInstallation, {
    installationId: "install_owner_1",
    ownerUid: "caller",
    active: true,
    platform: "ios",
    fcmToken: "fcm_owner",
    apnsToken: "apns_owner",
    voipToken: "voip_owner",
    lastSeenAt: new Date(),
    updatedAt: new Date(),
  }));
  await assertSucceeds(updateDoc(ownerInstallation, {
    active: false,
    updatedAt: new Date(),
  }));
  await assertFails(updateDoc(ownerInstallation, {
    active: true,
    unexpected: true,
  }));
});

test("push installation rejects cross-user and malformed writes", async () => {
  const otherWrite = doc(
    testEnv.authenticatedContext("other").firestore(),
    "users/caller/pushInstallations/install_owner_2",
  );
  await assertFails(setDoc(otherWrite, {
    installationId: "install_owner_2",
    ownerUid: "caller",
    active: true,
    platform: "ios",
  }));

  const ownerDb = testEnv.authenticatedContext("caller").firestore();
  await assertFails(setDoc(
    doc(ownerDb, "users/caller/pushInstallations/install_owner_3"),
    {
      installationId: "wrong_installation",
      ownerUid: "caller",
      active: true,
      platform: "ios",
    },
  ));
  await assertFails(setDoc(
    doc(ownerDb, "users/caller/pushInstallations/install_owner_4"),
    {
      installationId: "install_owner_4",
      ownerUid: "caller",
      active: true,
      platform: "web",
    },
  ));
  await assertFails(setDoc(
    doc(ownerDb, "users/caller/pushInstallations/install_owner_5"),
    {
      installationId: "install_owner_5",
      ownerUid: "caller",
      active: true,
      platform: "ios",
      voipToken: 42,
    },
  ));
});

async function seedV2Call() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "calls/call_v2"), v2CallData());
    await setDoc(
      doc(db, "calls/call_v2/participants/caller"),
      participantData("caller", "caller"),
    );
    await setDoc(
      doc(db, "calls/call_v2/participants/callee"),
      participantData("callee", "callee"),
    );
  });
}

async function seedMalformedDuplicateRoleCall() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "calls/call_malformed_roles"), {
      ...v2CallData(),
      callerUid: "caller",
      calleeUid: "caller",
      participantUids: ["caller", "other"],
    });
    await setDoc(
      doc(db, "calls/call_malformed_roles/participants/caller"),
      participantData("caller", "caller"),
    );
    await setDoc(
      doc(db, "calls/call_malformed_roles/participants/other"),
      participantData("other", "callee"),
    );
  });
}

async function seedPrivateV2Docs() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "callOps/call_v2"), {
      callId: "call_v2",
      opsRetentionExpiresAt: new Date(),
    });
    await setDoc(doc(db, "callOps/call_v2/taskOutbox/task_1"), {
      taskId: "task_1",
      callId: "call_v2",
      status: "pending",
      ttlAt: new Date(),
    });
    await setDoc(doc(db, "callOps/call_v2/commands/command_1"), {
      commandId: "command_1",
      ttlAt: new Date(),
    });
    await setDoc(doc(db, "activeCallLocks/caller"), {
      uid: "caller",
      callId: "call_v2",
      fencingToken: 1,
    });
    await setDoc(doc(db, "callCommandKeys/key_1"), {
      ttlAt: new Date(),
      callId: "call_v2",
    });
  });
}

function v2CallData() {
  return {
    callSystem: "v2",
    schemaVersion: 2,
    callerUid: "caller",
    calleeUid: "callee",
    participantUids: ["caller", "callee"],
    lifecycleState: "ringing",
    terminal: false,
    version: 1,
  };
}

function participantData(uid, role) {
  return {
    uid,
    role,
    mediaState: "not_joined",
    heartbeatVersion: 0,
  };
}

function callDoc(uid, callId) {
  return userDoc(uid, `calls/${callId}`);
}

function userDoc(uid, pathValue) {
  return doc(testEnv.authenticatedContext(uid).firestore(), pathValue);
}

function unauthDoc(pathValue) {
  return doc(testEnv.unauthenticatedContext().firestore(), pathValue);
}

function firestorePort() {
  const host = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
  return Number.parseInt(host.split(":").pop(), 10);
}
