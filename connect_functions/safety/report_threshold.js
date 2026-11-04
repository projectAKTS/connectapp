"use strict";

// Two different people reporting the same post hide it from feeds until the
// operator reviews it (docs/SAFETY_ROADMAP.md). Only open reports count, so
// a post restored after review (reports closed, `hiddenByReports` removed)
// is not hidden again by the same reports.

const POST_HIDE_THRESHOLD = 2;

/** The number of different people with an open report in `reports`. */
function openReporterCount(reports) {
  const reporters = new Set();
  for (const r of reports) {
    if ((r.status || "open") !== "open") continue;
    const uid = `${r.reporterUid || ""}`.trim();
    if (uid) reporters.add(uid);
  }
  return reporters.size;
}

module.exports = { POST_HIDE_THRESHOLD, openReporterCount };
