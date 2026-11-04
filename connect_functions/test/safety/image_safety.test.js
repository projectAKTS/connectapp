"use strict";

const assert = require("node:assert/strict");
const { test } = require("node:test");

const { verdictFor, worstVerdict, gcsUriFromDownloadUrl, postImageUrls } = require("../../safety/image_safety");

test("SafeSearch likelihoods map to ok, sensitive or blocked", () => {
  assert.equal(verdictFor({ adult: "VERY_UNLIKELY", racy: "POSSIBLE", violence: "UNLIKELY" }), "ok");
  assert.equal(verdictFor({ racy: "LIKELY" }), "sensitive");
  assert.equal(verdictFor({ adult: "LIKELY" }), "sensitive");
  assert.equal(verdictFor({ violence: "LIKELY" }), "sensitive");
  assert.equal(verdictFor({ adult: "VERY_LIKELY" }), "blocked");
  assert.equal(verdictFor({ violence: "VERY_LIKELY", adult: "UNLIKELY" }), "blocked");
  assert.equal(verdictFor(undefined), "ok");
});

test("the strictest photo decides", () => {
  assert.equal(worstVerdict(["ok", "sensitive"]), "sensitive");
  assert.equal(worstVerdict(["sensitive", "blocked", "ok"]), "blocked");
  assert.equal(worstVerdict([]), "ok");
});

test("only our bucket's download URLs are checked", () => {
  const url = "https://firebasestorage.googleapis.com/v0/b/b1.appspot.com/o/post_images%2Fu1%2F17_0.jpg?alt=media&token=t";
  assert.equal(gcsUriFromDownloadUrl(url, "b1.appspot.com"), "gs://b1.appspot.com/post_images/u1/17_0.jpg");
  assert.equal(gcsUriFromDownloadUrl(url, "other"), null);
  assert.equal(gcsUriFromDownloadUrl("https://example.com/x.jpg", "b1.appspot.com"), null);
});

test("post photos come from imageUrls or the older imageUrl", () => {
  assert.deepEqual(postImageUrls({ imageUrls: ["a", "b"] }), ["a", "b"]);
  assert.deepEqual(postImageUrls({ imageUrl: "c" }), ["c"]);
  assert.deepEqual(postImageUrls({}), []);
});
