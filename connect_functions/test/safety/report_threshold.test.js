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
