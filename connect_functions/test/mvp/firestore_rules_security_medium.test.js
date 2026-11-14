"use strict";

// Security review 2026-11-13, medium findings: a chat must have exactly two
// people (so the block, minor and first-contact checks always apply), a post
// cannot be created with server-only flags or fake counters, and neither
// side of a call invite can rewrite who is calling whom.

const fs = require("node:fs");
const path = require("node:path");
const { after, before, beforeEach, test } = require("node:test");

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  arrayUnion, doc, serverTimestamp, setDoc, updateDoc,
} = require("firebase/firestore");

let testEnv;

function firestorePort() {
  const host = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
  return Number(host.split(":").pop());
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "demo-helperly-mvp-security-medium",
    firestore: {
      rules: fs.readFileSync(path.resolve(__dirname, "../../../firestore.rules"), "utf8"),
      host: "127.0.0.1",
      port: firestorePort(),
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const uid of ["alice", "bob", "mallory", "sidekick"]) {
      await setDoc(doc(db, `users/${uid}`), { fullName: uid, ageDeclaration: "adult" });
    }
    await setDoc(doc(db, "users/alice"), { blockedUids: ["mallory"] }, { merge: true });
    await setDoc(doc(db, "users/kid"), { fullName: "kid", ageDeclaration: "minor" });
    await setDoc(doc(db, "chats/alice_bob"), { participants: ["alice", "bob"], users: ["alice", "bob"] });
    // A three-person chat written before this fix (or by the server).
    await setDoc(doc(db, "chats/trio"), {
      participants: ["mallory", "alice", "sidekick"],
      users: ["mallory", "alice", "sidekick"],
      repliedBy: ["sidekick"],
    });
    await setDoc(doc(db, "callInvites/i1"), {
      fromUid: "alice", fromName: "Alice", toUid: "bob", toName: "Bob",
      channel: "c_alice_bob_abc", isVideo: false, status: "ringing",
    });
  });
});

after(async () => {
  await testEnv?.cleanup();
});

const as = (uid) => testEnv.authenticatedContext(uid).firestore();

// ---- Chats ----

test("a chat cannot be created with more or fewer than two people", async () => {
  const mallory = as("mallory");
  const three = ["alice", "mallory", "sidekick"];
  await assertFails(setDoc(doc(mallory, "chats/x1"), { participants: three, users: three }));
  await assertFails(setDoc(doc(mallory, "chats/x2"), { participants: ["mallory"], users: ["mallory"] }));
  await assertFails(setDoc(doc(mallory, "chats/x3"), { participants: ["mallory", "mallory"] }));
});

test("a chat's two lists must name the same two people", async () => {
  const mallory = as("mallory");
  await assertFails(setDoc(doc(mallory, "chats/x4"), {
    participants: ["alice", "mallory"], users: ["mallory", "sidekick"],
  }));
});

test("the people in a chat cannot add or swap anyone", async () => {
  const alice = as("alice");
  await assertFails(updateDoc(doc(alice, "chats/alice_bob"), { participants: arrayUnion("mallory") }));
  await assertFails(updateDoc(doc(alice, "chats/alice_bob"), {
    participants: ["alice", "mallory"], users: ["alice", "mallory"],
  }));
});

test("no message can be sent in a chat that does not have exactly two people", async () => {
  const mallory = as("mallory");
  // Alice blocked Mallory; a third person must not switch that check off.
  await assertFails(setDoc(doc(mallory, "chats/trio/messages/m1"), {
    authorId: "mallory", type: "image", text: "", imageUrl: "https://x/y.jpg",
  }));
  await assertFails(setDoc(doc(mallory, "chats/trio/messages/m2"), {
    authorId: "mallory", type: "text", text: "hi",
  }));
});

test("what the app writes for a two-person chat still works", async () => {
  const bob = as("bob");
  // Chat screen, first message: create with the sorted pair.
  await assertSucceeds(setDoc(doc(bob, "chats/bob_mallory"), {
    users: ["bob", "mallory"], participants: ["bob", "mallory"],
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(), unreadBy: { bob: 0, mallory: 0 },
  }, { merge: true }));
  // Chat screen, reopening: the same pair again.
  await assertSucceeds(setDoc(doc(bob, "chats/bob_mallory"), {
    users: ["bob", "mallory"], participants: ["bob", "mallory"],
  }, { merge: true }));
  // Missed-call note: arrayUnion of the same pair.
  await assertSucceeds(setDoc(doc(bob, "chats/bob_mallory"), {
    users: arrayUnion("bob", "mallory"), participants: arrayUnion("bob", "mallory"),
    lastMessageType: "missed_call", unreadBy: { bob: 0 },
  }, { merge: true }));
  // Missed-call note on a chat that does not exist yet.
  await assertSucceeds(setDoc(doc(bob, "chats/bob_sidekick"), {
    users: arrayUnion("bob", "sidekick"), participants: arrayUnion("bob", "sidekick"),
    lastMessageType: "missed_call",
  }, { merge: true }));
  await assertSucceeds(setDoc(doc(bob, "chats/alice_bob/messages/m1"), {
    authorId: "bob", type: "text", text: "hello",
  }));
});

// ---- Posts ----

function appPostShell(uid) {
  // What PostService.createPostShell writes.
  return {
    id: "p", userID: uid, userName: uid, userAvatar: "", content: "hi", postType: "general",
    tags: [], timestamp: serverTimestamp(), likes: 0, commentsCount: 0, helpfulVotes: 0,
    engagementScore: 0, isBoosted: false, boostExpiresAt: null, boostScore: 0, likedBy: [],
    isFeatured: false, mediaUploadStatus: "uploading", mediaCount: 1, hasVideo: false,
    mediaAspectRatio: 1.5, mediaUploadStartedAt: serverTimestamp(),
  };
}

test("the app's own new posts are still accepted", async () => {
  const bob = as("bob");
  await assertSucceeds(setDoc(doc(bob, "posts/p1"), appPostShell("bob")));
  await assertSucceeds(setDoc(doc(bob, "posts/p2"), {
    ...appPostShell("bob"), mediaUploadStatus: "ready", imageUrl: "https://x/a.jpg",
    imageUrls: ["https://x/a.jpg"],
  }));
});

test("a new post cannot carry server-only flags or fake counters", async () => {
  const bob = as("bob");
  const bad = {
    isBoosted: true, boostExpiresAt: new Date(Date.now() + 864e5), boostScore: 99, isFeatured: true,
    likes: 500, likedBy: ["alice"], commentsCount: 40, helpfulVotes: 12, engagementScore: 999,
    imageSafety: "ok", imageSafetyCheckedAt: new Date(), sensitive: false, hiddenBySafety: false,
    hiddenByReports: false, hiddenByReportsAt: null, hiddenByReportsCount: 0, countedAt: new Date(),
    reports: [],
  };
  for (const [key, value] of Object.entries(bad)) {
    await assertFails(setDoc(doc(bob, `posts/bad_${key}`), { ...appPostShell("bob"), [key]: value }), key);
  }
});

// ---- Call invites ----

test("neither side of a call can rewrite who is calling whom", async () => {
  const alice = as("alice");
  const bob = as("bob");
  await assertFails(updateDoc(doc(bob, "callInvites/i1"), { toUid: "mallory" }));
  await assertFails(updateDoc(doc(bob, "callInvites/i1"), { fromUid: "mallory" }));
  await assertFails(updateDoc(doc(alice, "callInvites/i1"), { toUid: "kid" }));
  await assertFails(updateDoc(doc(alice, "callInvites/i1"), { channel: "c_alice_kid_abc" }));
  await assertFails(updateDoc(doc(alice, "callInvites/i1"), { fromName: "Support Team" }));
  await assertFails(updateDoc(doc(bob, "callInvites/i1"), { toName: "Someone" }));
  await assertFails(updateDoc(doc(bob, "callInvites/i1"), { createdAt: new Date(0) }));
});

test("the call screens can still decline, cancel and report progress", async () => {
  const alice = as("alice");
  const bob = as("bob");
  await assertSucceeds(updateDoc(doc(bob, "callInvites/i1"), {
    calleeStage: "ringing", acceptedNativeWatchActive: true,
  }));
  await assertSucceeds(setDoc(doc(bob, "callInvites/i1"), {
    status: "declined", declinedAt: serverTimestamp(), endedAt: serverTimestamp(),
    endedBy: "bob", endReason: "declined", calleeStage: "declined",
  }, { merge: true }));
  await assertSucceeds(setDoc(doc(alice, "callInvites/i1"), {
    status: "cancelled", cancelledAt: serverTimestamp(), endedAt: serverTimestamp(),
    endedBy: "alice", endReason: "cancelled", callerStage: "cancelled",
  }, { merge: true }));
  // A merge that repeats the unchanged identity fields is not a change.
  await assertSucceeds(setDoc(doc(alice, "callInvites/i1"), {
    fromUid: "alice", toUid: "bob", channel: "c_alice_bob_abc", callerLastError: "",
  }, { merge: true }));
});
