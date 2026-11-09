"use strict";

const assert = require("node:assert/strict");
const { test } = require("node:test");

const { commentNotificationFor } = require("../../posts/post_comment");
const { pushText } = require("../../i18n/push_text");

test("a comment notifies the post's author", () => {
  assert.deepEqual(
    commentNotificationFor({
      post: { userID: "author" },
      comment: { userID: "reader", authorName: "Sam", text: " Great\n  tip " },
      authorBlockedUids: [],
    }),
    { toUid: "author", commenterName: "Sam", snippet: "Great tip" },
  );
});

test("no notification for your own comment or a blocked commenter", () => {
  const post = { userID: "author" };
  assert.equal(commentNotificationFor({ post, comment: { userID: "author" } }), null);
  assert.equal(
    commentNotificationFor({ post, comment: { userID: "reader" }, authorBlockedUids: ["reader"] }),
    null,
  );
  assert.equal(commentNotificationFor({ post: {}, comment: { userID: "reader" } }), null);
});

test("long comments are cut for the notification", () => {
  const note = commentNotificationFor({
    post: { userID: "a" },
    comment: { userID: "b", text: "x".repeat(300) },
  });
  assert.equal(note.snippet.length, 100);
  assert.equal(pushText("fr", "commentedOnYourPost"), "A commenté votre publication");
});
