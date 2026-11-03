"use strict";

// onAuthUserCreated runs a few seconds after sign-up, often after the app has
// already written the profile (name, photo, onboarding). It must only fill
// fields that are still missing, never overwrite what the app wrote.

/** The entries of `defaults` whose keys `existing` does not have. */
function missingFields(existing, defaults) {
  const have = existing || {};
  const out = {};
  for (const [key, value] of Object.entries(defaults)) {
    if (have[key] === undefined) out[key] = value;
  }
  return out;
}

module.exports = { missingFields };
