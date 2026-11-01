"use strict";

const assert = require("node:assert/strict");
const { test } = require("node:test");

const { minutesUntil, pushLanguage, pushText } = require("../../i18n/push_text");

test("app locales map to a push language, English by default", () => {
  assert.equal(pushLanguage("fr"), "fr");
  assert.equal(pushLanguage("fr-CA"), "fr");
  assert.equal(pushLanguage("fr_CA"), "fr");
  for (const other of ["en", "tr", "", null, undefined, "xx"]) {
    assert.equal(pushLanguage(other), "en", `${other}`);
  }
});

test("English call and chat texts are unchanged", () => {
  assert.equal(pushText(undefined, "incomingVideoCall"), "Incoming Video Call");
  assert.equal(pushText("en", "incomingAudioCall"), "Incoming Audio Call");
  assert.equal(pushText("en", "callFrom", { name: "Baris" }), "From Baris");
  assert.equal(pushText("en", "someone"), "Someone");
  assert.equal(pushText("en", "sentYouAMessage"), "Sent you a message");
  assert.equal(pushText("en", "upcomingConsultation"), "Upcoming Consultation");
});

test("French texts", () => {
  assert.equal(pushText("fr", "incomingVideoCall"), "Appel vidéo entrant");
  assert.equal(pushText("fr", "callFrom", { name: "Baris" }), "De Baris");
  assert.equal(pushText("fr", "sentYouAMessage"), "Vous a envoyé un message");
  assert.equal(pushText("fr", "startsInMinutes", { minutes: 5 }), "Commence dans 5 minutes");
  assert.equal(pushText("fr", "startsInMinutes", { minutes: 1 }), "Commence dans 1 minute");
});

test("reminders say how soon, not a server-time clock", () => {
  const now = new Date("2026-10-31T18:00:00Z");
  assert.equal(minutesUntil(new Date("2026-10-31T18:04:10Z"), now), 5);
  assert.equal(minutesUntil(new Date("2026-10-31T18:00:20Z"), now), 1);
  assert.equal(minutesUntil(new Date("2026-10-31T17:59:00Z"), now), 1);
  assert.equal(pushText("en", "startsInMinutes", { minutes: 5 }), "Starts in 5 minutes");
});

test("unknown keys fail loudly", () => {
  assert.throws(() => pushText("fr", "nope"));
});
