"use strict";

// Two different people reporting the same post hide it from feeds until the
// operator reviews it (docs/SAFETY_ROADMAP.md). Only open reports count, so
// a post restored after review (reports closed, `hiddenByReports` removed)
// is not hidden again by the same reports.
//
// To make it harder for one person with two fresh accounts to hide any
// post, a report counts toward the threshold only when its account is at
// least MIN_REPORTER_AGE_MS old and is not the post's author. Every report
// still reaches moderation, and the reporter never sees the post again.

const POST_HIDE_THRESHOLD = 2;
const MIN_REPORTER_AGE_MS = 3 * 24 * 60 * 60 * 1000;

/**
 * The number of different eligible people with an open report in
 * `reports`. [isEligible] (uid -> boolean) defaults to everyone.
 */
function openReporterCount(reports, isEligible = () => true) {
  const reporters = new Set();
  for (const r of reports) {
    if ((r.status || "open") !== "open") continue;
    const uid = `${r.reporterUid || ""}`.trim();
    if (uid && isEligible(uid)) reporters.add(uid);
  }
  return reporters.size;
}

/** Whether an account created at [createdMs] counts at [nowMs]. */
function oldEnough(createdMs, nowMs) {
  return Number.isFinite(createdMs) && nowMs - createdMs >= MIN_REPORTER_AGE_MS;
}

module.exports = { MIN_REPORTER_AGE_MS, POST_HIDE_THRESHOLD, oldEnough, openReporterCount };
