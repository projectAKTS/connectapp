"use strict";

const assert = require("node:assert/strict");
const { test } = require("node:test");

const { claimOnce } = require("../../notifications/claim_once");

function fakeDb(initial) {
  const docs = new Map(Object.entries(initial));
  let chain = Promise.resolve();
  return {
    docs,
    runTransaction(fn) {
      const run = chain.then(async () => {
        const writes = [];
        const tx = {
          get: async (r) => ({ exists: docs.has(r.path), data: () => ({ ...docs.get(r.path) }) }),
          update: (r, v) => writes.push(() => docs.set(r.path, { ...docs.get(r.path), ...v })),
        };
        const res = await fn(tx);
        writes.forEach((w) => w());
        return res;
      });
      chain = run.catch(() => {});
      return run;
    },
  };
}

const ts = () => "TS";
const msg = { path: "chats/a_b/messages/m1" };

test("only the first delivery of an event proceeds", async () => {
  const db = fakeDb({ [msg.path]: { text: "hi" } });
  assert.equal(await claimOnce(db, msg, "notifiedAt", ts), true);
  assert.equal(await claimOnce(db, msg, "notifiedAt", ts), false);
  assert.equal(db.docs.get(msg.path).notifiedAt, "TS");
});

test("concurrent duplicate deliveries: exactly one wins", async () => {
  const db = fakeDb({ [msg.path]: { text: "hi" } });
  const results = await Promise.all(
    Array.from({ length: 5 }, () => claimOnce(db, msg, "notifiedAt", ts)),
  );
  assert.equal(results.filter(Boolean).length, 1);
});

test("deleted source documents are not claimed", async () => {
  const db = fakeDb({});
  assert.equal(await claimOnce(db, msg, "notifiedAt", ts), false);
});

test("separate fields claim separately (reminder vs other markers)", async () => {
  const c = { path: "consultations/c1" };
  const db = fakeDb({ [c.path]: {} });
  assert.equal(await claimOnce(db, c, "reminderSentAt", ts), true);
  assert.equal(await claimOnce(db, c, "reminderSentAt", ts), false);
  assert.equal(await claimOnce(db, c, "otherMarker", ts), true);
});
