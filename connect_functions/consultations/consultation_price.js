"use strict";

/**
 * Server-side consultation prices (CAD). Mirrors lib/screens/pricing/
 * pricing_config.dart; keep both in sync.
 *
 * The charge used to take any client-sent amount, so a modified client could
 * book 30 minutes for one cent. The server now prices the session itself.
 */

const PRICING_VERSION = "2026-10-audio-video-v1";

const AUDIO_PRICES = Object.freeze({
  1: 0.0,
  5: 2.99,
  10: 4.49,
  15: 6.99,
  30: 12.99,
  45: 17.99,
  60: 22.99,
});

const VIDEO_MULTIPLIER = 1.3;

function round2(value) {
  return Math.round(value * 100) / 100;
}

/** Price in CAD for a session, or null when the duration is not offered. */
function consultationPrice(durationMinutes, callType) {
  const duration = Number(durationMinutes);
  if (!Object.prototype.hasOwnProperty.call(AUDIO_PRICES, duration)) return null;
  const base = AUDIO_PRICES[duration];
  if (callType === "video") return round2(base * VIDEO_MULTIPLIER);
  if (callType === "audio") return base;
  return null;
}

/** Every price a client can legitimately show, for legacy amount-only calls. */
function allOfferedPrices() {
  const prices = new Set();
  for (const duration of Object.keys(AUDIO_PRICES)) {
    prices.add(consultationPrice(duration, "audio"));
    prices.add(consultationPrice(duration, "video"));
  }
  return prices;
}

/**
 * Resolves what to charge from a charge request.
 * Returns { amount, durationMinutes, callType, legacy } or { error }.
 */
function resolveChargeAmount(data) {
  const request = data || {};
  if (request.durationMinutes !== undefined || request.callType !== undefined) {
    const amount = consultationPrice(request.durationMinutes, request.callType);
    if (amount === null) return { error: "Unknown duration or call type" };
    if (amount <= 0) return { error: "Free sessions are not charged" };
    return {
      amount,
      durationMinutes: Number(request.durationMinutes),
      callType: request.callType,
      legacy: false,
    };
  }
  // Builds before the server-side price send only an amount; accept it only
  // when it is one of the offered prices.
  const amount = round2(Number(request.amount));
  if (!(amount > 0) || !allOfferedPrices().has(amount)) {
    return { error: "Invalid amount" };
  }
  return { amount, durationMinutes: null, callType: null, legacy: true };
}

module.exports = {
  PRICING_VERSION,
  AUDIO_PRICES,
  consultationPrice,
  resolveChargeAmount,
};
