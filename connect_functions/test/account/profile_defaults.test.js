"use strict";

const assert = require("node:assert/strict");
const { test } = require("node:test");

const { missingFields } = require("../../account/profile_defaults");

test("a new profile gets every default", () => {
  assert.deepEqual(missingFields(undefined, { fullName: "jo", bio: "" }), { fullName: "jo", bio: "" });
});

test("what the app already wrote is never overwritten", () => {
  const existing = { fullName: "Zoe", profilePicture: "https://x/p.jpg", followers: ["a"], ageDeclaration: "adult" };
  const defaults = { fullName: "Stg Zoe Abc", profilePicture: "", followers: [], bio: "", postsCount: 0 };
  assert.deepEqual(missingFields(existing, defaults), { bio: "", postsCount: 0 });
});

test("a field the app set to null or empty stays as it is", () => {
  assert.deepEqual(missingFields({ bio: "", lastLoginDate: null }, { bio: "x", lastLoginDate: null }), {});
});
