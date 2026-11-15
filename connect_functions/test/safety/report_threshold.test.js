"use strict";

const assert = require("node:assert/strict");
const { test } = require("node:test");

const { POST_HIDE_THRESHOLD, openReporterCount } = require("../../safety/report_threshold");

test("two different people are needed to hide a post", () => {
  assert.equal(POST_HIDE_THRESHOLD, 2);
  assert.equal(openReporterCount([{ reporterUid: "a" }]), 1);
  assert.equal(openReporterCount([{ reporterUid: "a" }, { reporterUid: "a" }]), 1);
  assert.equal(openReporterCount([{ reporterUid: "a" }, { reporterUid: "b" }]), 2);
});

test("closed reports do not count, so a reviewed post is not hidden again", () => {
  assert.equal(openReporterCount([
    { reporterUid: "a", status: "closed" },
    { reporterUid: "b", status: "dismissed" },
    { reporterUid: "c", status: "open" },
  ]), 1);
});

const { MIN_REPORTER_AGE_MS, oldEnough } = require("../../safety/report_threshold");

test("only eligible reporters count toward hiding", () => {
  const reports = [
    { reporterUid: "old1", status: "open" },
    { reporterUid: "fresh", status: "open" },
    { reporterUid: "old2", status: "open" },
  ];
  const eligible = new Set(["old1", "old2"]);
  assert.equal(openReporterCount(reports, (u) => eligible.has(u)), 2);
  assert.equal(openReporterCount(reports, (u) => u === "old1"), 1);
});

test("an account counts only after three days", () => {
  const now = Date.parse("2026-11-15T12:00:00Z");
  assert.equal(oldEnough(now - MIN_REPORTER_AGE_MS, now), true);
  assert.equal(oldEnough(now - MIN_REPORTER_AGE_MS + 1000, now), false);
  assert.equal(oldEnough(NaN, now), false);
});
