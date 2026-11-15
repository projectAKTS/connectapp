"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { blockedUidsOf, withBlockedUids } = require("../../safety/blocked_uids");

function fakeDb(privateDocs) {
  return {
    collection: () => ({ doc: (uid) => ({ collection: () => ({ doc: () => ({
      get: async () => ({ exists: privateDocs.has(uid), data: () => privateDocs.get(uid) }),
    }) }) }) }),
  };
}

test("combines the old public list and the private list, without duplicates", async () => {
  const db = fakeDb(new Map([["u1", { blockedUids: ["b", "c"] }]]));
  assert.deepEqual((await blockedUidsOf(db, "u1", { blockedUids: ["a", "b"] })).sort(), ["a", "b", "c"]);
});

test("works with only one of the two places, or none", async () => {
  const db = fakeDb(new Map([["u2", { blockedUids: ["x"] }]]));
  assert.deepEqual(await blockedUidsOf(db, "u2", {}), ["x"]);
  assert.deepEqual(await blockedUidsOf(db, "u3", { blockedUids: ["y"] }), ["y"]);
  assert.deepEqual(await blockedUidsOf(db, "u3", undefined), []);
});

test("withBlockedUids keeps the other profile fields", async () => {
  const db = fakeDb(new Map([["u4", { blockedUids: ["z"] }]]));
  const out = await withBlockedUids(db, "u4", { appLocale: "fr" });
  assert.equal(out.appLocale, "fr");
  assert.deepEqual(out.blockedUids, ["z"]);
});
