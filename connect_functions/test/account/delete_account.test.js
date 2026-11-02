"use strict";

const assert = require("node:assert/strict");
const { test } = require("node:test");

const { deleteUserData } = require("../../account/delete_account");

function fakes({ posts = [], reviews = [], authError = null } = {}) {
  const calls = { recursive: [], prefixes: [], authDeleted: [], updated: [], set: [], deleted: [] };
  const ref = (p) => ({
    path: p,
    update: async (data) => calls.updated.push({ path: p, data }),
    set: async (data) => calls.set.push({ path: p, data }),
    delete: async () => calls.deleted.push(p),
  });
  const rows = { posts, reviews };
  const db = {
    collection(name) {
      return {
        doc: (id) => ref(`${name}/${id}`),
        where: (field, op, value) => ({
          get: async () => ({
            docs: (rows[name] || [])
              .filter((p) => op === "==" && p[field] === value)
              .map((p) => ({ ref: ref(`${name}/${p.id}`) })),
          }),
        }),
      };
    },
    recursiveDelete: async (r) => calls.recursive.push(r.path),
  };
  const bucket = { deleteFiles: async ({ prefix }) => calls.prefixes.push(prefix) };
  const auth = {
    deleteUser: async (uid) => {
      if (authError) throw authError;
      calls.authDeleted.push(uid);
    },
  };
  return { db, bucket, auth, calls };
}

test("deletes the user's doc, posts, followers, media and auth user", async () => {
  const f = fakes({
    posts: [
      { id: "p1", userID: "u1" },
      { id: "p2", userID: "other" },
      { id: "p3", userId: "u1" },
    ],
  });
  const summary = await deleteUserData({ ...f, uid: "u1" });
  assert.deepEqual(f.calls.recursive, ["posts/p1", "posts/p3", "followers/u1", "users/u1"]);
  assert.deepEqual(f.calls.prefixes, [
    "users/u1/",
    "post_images/u1/",
    "post_videos/u1/",
    "post_video_thumbs/u1/",
  ]);
  assert.deepEqual(f.calls.authDeleted, ["u1"]);
  assert.equal(summary.posts, 2);
});

test("reviews the user wrote lose their text but keep their stars", async () => {
  const f = fakes({
    reviews: [
      { id: "c1", reviewerUid: "u1" },
      { id: "c2", reviewerUid: "other" },
    ],
  });
  const summary = await deleteUserData({ ...f, uid: "u1" });
  assert.deepEqual(f.calls.updated, [
    { path: "reviews/c1", data: { text: "", reviewerDeleted: true } },
  ]);
  assert.equal(summary.reviews, 1);
});

test("an already deleted auth user is fine", async () => {
  const f = fakes({ authError: { code: "auth/user-not-found" } });
  const summary = await deleteUserData({ ...f, uid: "u1" });
  assert.equal(summary.authDeleted, false);
});

test("other auth errors surface", async () => {
  const f = fakes({ authError: { code: "auth/internal-error" } });
  await assert.rejects(deleteUserData({ ...f, uid: "u1" }));
});

test("a missing uid is rejected before anything is deleted", async () => {
  const f = fakes();
  await assert.rejects(deleteUserData({ ...f, uid: " " }));
  assert.deepEqual(f.calls.recursive, []);
});

test("a failed reference cleanup (e.g. a missing index) never blocks deletion", async () => {
  const f = fakes();
  f.db.collectionGroup = () => ({
    where: () => ({
      get: async () => {
        throw new Error("FAILED_PRECONDITION: index required");
      },
    }),
  });
  const logged = [];
  const summary = await deleteUserData({
    ...f,
    uid: "u1",
    FieldValue: {
      delete: () => null,
      arrayRemove: () => null,
      increment: () => 1,
      serverTimestamp: () => "TS",
    },
    log: (stage, meta) => logged.push([stage, meta]),
  });
  assert.ok(summary.references.error.includes("index required"));
  assert.ok(logged.some(([stage]) => stage === "account_delete_scrub_failed"));
  assert.ok(f.calls.recursive.includes("users/u1"), "the account is still deleted");
  assert.deepEqual(f.calls.authDeleted, ["u1"]);
  assert.equal(summary.complete, false, "never claimed complete");
  const last = f.calls.set.filter((c) => c.path === "accountDeletions/u1").pop();
  assert.equal(last.data.status, "cleanup_pending", "durable record kept for retry");
  assert.equal(f.calls.deleted.includes("accountDeletions/u1"), false);
});
