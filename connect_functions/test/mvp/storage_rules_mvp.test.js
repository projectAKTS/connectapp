"use strict";

// MVP-2 storage rules: chat files for participants only, post media in
// per-owner folders, size and type limits.

const fs = require("node:fs");
const path = require("node:path");
const { after, before, beforeEach, test } = require("node:test");

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const { doc, setDoc } = require("firebase/firestore");
const { ref, uploadBytes, getBytes, deleteObject } = require("firebase/storage");

let testEnv;

function port(envName, fallback) {
  const host = process.env[envName] || `127.0.0.1:${fallback}`;
  return Number(host.split(":").pop());
}

const JPEG = { contentType: "image/jpeg" };
const MP4 = { contentType: "video/mp4" };
const PDF = { contentType: "application/pdf" };
const small = new Uint8Array([1, 2, 3]);

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "demo-helperly-mvp-storage",
    firestore: {
      rules: fs.readFileSync(path.resolve(__dirname, "../../../firestore.rules"), "utf8"),
      host: "127.0.0.1",
      port: port("FIRESTORE_EMULATOR_HOST", 8080),
    },
    storage: {
      rules: fs.readFileSync(path.resolve(__dirname, "../../../storage.rules"), "utf8"),
      host: "127.0.0.1",
      port: port("FIREBASE_STORAGE_EMULATOR_HOST", 9199),
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.clearStorage();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), "chats/alice_bob"), { participants: ["alice", "bob"] });
    await uploadBytes(ref(ctx.storage(), "chats/alice_bob/images/a.jpg"), small, JPEG);
    await uploadBytes(ref(ctx.storage(), "post_images/legacy.jpg"), small, JPEG);
  });
});

after(async () => {
  await testEnv?.cleanup();
});

const as = (uid) => testEnv.authenticatedContext(uid).storage();

test("chat files are for the chat's participants only", async () => {
  await assertSucceeds(getBytes(ref(as("bob"), "chats/alice_bob/images/a.jpg")));
  await assertFails(getBytes(ref(as("mallory"), "chats/alice_bob/images/a.jpg")));
  await assertSucceeds(uploadBytes(ref(as("alice"), "chats/alice_bob/images/b.jpg"), small, JPEG));
  await assertFails(uploadBytes(ref(as("mallory"), "chats/alice_bob/images/c.jpg"), small, JPEG));
  await assertFails(uploadBytes(ref(as("alice"), "chats/alice_bob/files/x.pdf"), small, PDF));
  await assertFails(deleteObject(ref(as("bob"), "chats/alice_bob/images/a.jpg")));
});

test("post media goes into the owner's folder only", async () => {
  await assertSucceeds(uploadBytes(ref(as("alice"), "post_images/alice/1.jpg"), small, JPEG));
  await assertSucceeds(uploadBytes(ref(as("alice"), "post_videos/alice/1.mp4"), small, MP4));
  await assertFails(uploadBytes(ref(as("mallory"), "post_images/alice/2.jpg"), small, JPEG));
  await assertFails(uploadBytes(ref(as("alice"), "post_images/alice/3.pdf"), small, PDF));
  await assertSucceeds(getBytes(ref(as("mallory"), "post_images/alice/1.jpg")));
  await assertFails(deleteObject(ref(as("mallory"), "post_images/alice/1.jpg")));
  await assertSucceeds(deleteObject(ref(as("alice"), "post_images/alice/1.jpg")));
});

test("legacy flat post media is read-only", async () => {
  await assertSucceeds(getBytes(ref(as("bob"), "post_images/legacy.jpg")));
  await assertFails(uploadBytes(ref(as("bob"), "post_images/new.jpg"), small, JPEG));
  await assertFails(deleteObject(ref(as("bob"), "post_images/legacy.jpg")));
});

test("profile photos: owner writes images, others read", async () => {
  await assertSucceeds(uploadBytes(ref(as("alice"), "users/alice/p.jpg"), small, JPEG));
  await assertFails(uploadBytes(ref(as("mallory"), "users/alice/p.jpg"), small, JPEG));
  await assertFails(uploadBytes(ref(as("alice"), "users/alice/p.pdf"), small, PDF));
  await assertSucceeds(getBytes(ref(as("bob"), "users/alice/p.jpg")));
});

test("signed-out users read nothing", async () => {
  const anon = testEnv.unauthenticatedContext().storage();
  await assertFails(getBytes(ref(anon, "post_images/legacy.jpg")));
});
