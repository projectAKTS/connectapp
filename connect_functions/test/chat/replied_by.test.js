"use strict";

const assert = require("node:assert/strict");
const { test } = require("node:test");

const { repliedByUpdate } = require("../../chat/replied_by");

const FieldValue = { arrayUnion: (...v) => ({ arrayUnion: v }) };

// A chat whose history holds `messages` ({ authorId, system }).
function fakeChatRef(messages) {
  return {
    collection: () => ({
      where: (_field, _op, uid) => ({
        limit: () => ({
          get: async () => ({
            docs: messages
              .filter((m) => m.authorId === uid)
              .map((m) => ({ get: (k) => m[k] })),
          }),
        }),
      }),
    }),
  };
}

const base = { users: ["a", "b"], FieldValue };

test("adds a new writer to an existing list", async () => {
  const v = await repliedByUpdate({ ...base, chatRef: fakeChatRef([]), chat: { repliedBy: ["a"] }, authorId: "b", isSystem: false });
  assert.deepEqual(v, { arrayUnion: ["b"] });
});

test("no change when the author is already listed or the message is a system one", async () => {
  const chatRef = fakeChatRef([]);
  assert.equal(await repliedByUpdate({ ...base, chatRef, chat: { repliedBy: ["a"] }, authorId: "a", isSystem: false }), null);
  assert.equal(await repliedByUpdate({ ...base, chatRef, chat: { repliedBy: ["a"] }, authorId: "b", isSystem: true }), null);
});

test("a new chat starts with its first author", async () => {
  const v = await repliedByUpdate({ ...base, chatRef: fakeChatRef([]), chat: {}, authorId: "a", isSystem: false });
  assert.deepEqual(v, ["a"]);
});

test("an older chat is rebuilt from history; missed-call notes do not count", async () => {
  const history = [
    { authorId: "b", system: false },
    { authorId: "a", system: true },
  ];
  const v = await repliedByUpdate({ ...base, chatRef: fakeChatRef(history), chat: {}, authorId: "a", isSystem: true });
  assert.deepEqual(v, ["b"]);
  const both = await repliedByUpdate({
    ...base,
    chatRef: fakeChatRef([...history, { authorId: "a" }]),
    chat: {},
    authorId: "b",
    isSystem: false,
  });
  assert.deepEqual(both, ["a", "b"]);
});
