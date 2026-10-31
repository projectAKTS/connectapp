"use strict";

const assert = require("node:assert/strict");
const { test } = require("node:test");

const { addReviewToRating, validStars } = require("../../reviews/review_aggregate");

test("only whole stars from 1 to 5 count", () => {
  for (const ok of [1, 3, 5]) assert.equal(validStars(ok), ok);
  for (const bad of [0, 6, 4.5, "5", null, undefined, -1]) {
    assert.equal(validStars(bad), null, `${bad}`);
  }
});

test("the first review sets the rating", () => {
  assert.deepEqual(addReviewToRating({}, 4), { ratingSum: 4, ratingCount: 1, rating: 4 });
  assert.deepEqual(addReviewToRating(undefined, 5), { ratingSum: 5, ratingCount: 1, rating: 5 });
});

test("later reviews update the average, rounded to one decimal", () => {
  const after = addReviewToRating({ ratingSum: 9, ratingCount: 2, rating: 4.5 }, 5);
  assert.deepEqual(after, { ratingSum: 14, ratingCount: 3, rating: 4.7 });
});

test("older docs without a sum keep their history", () => {
  const after = addReviewToRating({ rating: 4, ratingCount: 2 }, 1);
  assert.deepEqual(after, { ratingSum: 9, ratingCount: 3, rating: 3 });
});
