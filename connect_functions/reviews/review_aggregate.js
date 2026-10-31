"use strict";

/**
 * Helper ratings. A seeker rates a finished consultation once (rules
 * enforce who and when); the server keeps the helper's running average on
 * the user doc, where clients cannot write it.
 */

/** Whole stars 1-5, or null. */
function validStars(value) {
  return Number.isInteger(value) && value >= 1 && value <= 5 ? value : null;
}

/**
 * The helper's rating fields after adding one review. [current] is the
 * helper's user doc data. Older docs may have `rating`/`ratingCount` but no
 * `ratingSum`; the sum is rebuilt from them.
 */
function addReviewToRating(current, stars) {
  const count = Math.max(0, Math.trunc(Number(current?.ratingCount) || 0));
  const average = Number(current?.rating) || 0;
  const sum = Number.isFinite(Number(current?.ratingSum))
    ? Number(current.ratingSum)
    : average * count;
  const nextCount = count + 1;
  const nextSum = sum + stars;
  return {
    ratingSum: nextSum,
    ratingCount: nextCount,
    rating: Math.round((nextSum / nextCount) * 10) / 10,
  };
}

module.exports = { addReviewToRating, validStars };
