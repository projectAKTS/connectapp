"use strict";

/**
 * Push notification text in the recipient's app language
 * (`users/{uid}.appLocale`, written by the app). English is the default
 * and keeps the exact wording older builds have always shown.
 */

const TEXT = {
  en: {
    incomingVideoCall: () => "Incoming Video Call",
    incomingAudioCall: () => "Incoming Audio Call",
    callFrom: ({ name }) => `From ${name}`,
    someone: () => "Someone",
    sentYouAMessage: () => "Sent you a message",
    upcomingConsultation: () => "Upcoming Consultation",
    startsInMinutes: ({ minutes }) =>
      minutes <= 1 ? "Starts in 1 minute" : `Starts in ${minutes} minutes`,
  },
  fr: {
    incomingVideoCall: () => "Appel vidéo entrant",
    incomingAudioCall: () => "Appel audio entrant",
    callFrom: ({ name }) => `De ${name}`,
    someone: () => "Quelqu'un",
    sentYouAMessage: () => "Vous a envoyé un message",
    upcomingConsultation: () => "Consultation à venir",
    startsInMinutes: ({ minutes }) =>
      minutes <= 1 ? "Commence dans 1 minute" : `Commence dans ${minutes} minutes`,
  },
};

/** 'fr', 'fr-CA', 'fr_CA' -> 'fr'; anything else -> 'en'. */
function pushLanguage(appLocale) {
  const code = `${appLocale || ""}`.trim().toLowerCase().split(/[-_]/)[0];
  return Object.prototype.hasOwnProperty.call(TEXT, code) ? code : "en";
}

function pushText(appLocale, key, params = {}) {
  const table = TEXT[pushLanguage(appLocale)];
  const fn = table[key] || TEXT.en[key];
  if (!fn) throw new Error(`unknown push text: ${key}`);
  return fn(params);
}

/** Whole minutes from [now] until [startsAt], at least 1. */
function minutesUntil(startsAt, now) {
  const ms = startsAt.getTime() - now.getTime();
  return Math.max(1, Math.ceil(ms / 60000));
}

module.exports = { minutesUntil, pushLanguage, pushText };
