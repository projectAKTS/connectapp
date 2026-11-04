"use strict";

// Automatic check of post photos with Google Cloud Vision SafeSearch
// (docs/SAFETY_ROADMAP.md #6). The verdict is stored on the post:
// - "blocked": very likely adult or violent; hidden until the operator
//   reviews (`hiddenBySafety`);
// - "sensitive": likely adult, racy or violent; shown blurred with
//   "Tap to view";
// - "ok": nothing to do.

const RANK = { UNKNOWN: 0, VERY_UNLIKELY: 1, UNLIKELY: 2, POSSIBLE: 3, LIKELY: 4, VERY_LIKELY: 5 };
const level = (v) => RANK[v] || 0;

/** The verdict for one SafeSearch annotation. */
function verdictFor(safe) {
  const s = safe || {};
  if (level(s.adult) >= RANK.VERY_LIKELY || level(s.violence) >= RANK.VERY_LIKELY) return "blocked";
  if (level(s.adult) >= RANK.LIKELY || level(s.racy) >= RANK.LIKELY || level(s.violence) >= RANK.LIKELY) {
    return "sensitive";
  }
  return "ok";
}

/** The strictest verdict of several photos. */
function worstVerdict(verdicts) {
  if (verdicts.includes("blocked")) return "blocked";
  if (verdicts.includes("sensitive")) return "sensitive";
  return "ok";
}

/**
 * gs:// URI for a Firebase Storage download URL in `bucket`, or null for
 * anything else (we only check files of our own bucket).
 */
function gcsUriFromDownloadUrl(url, bucket) {
  const m = /^https:\/\/firebasestorage\.googleapis\.com\/v0\/b\/([^/]+)\/o\/([^?]+)/.exec(`${url || ""}`);
  if (!m || m[1] !== bucket) return null;
  return `gs://${bucket}/${decodeURIComponent(m[2])}`;
}

/** The post's photo URLs (`imageUrls`, or the older single `imageUrl`). */
function postImageUrls(post) {
  const p = post || {};
  const urls = Array.isArray(p.imageUrls) ? p.imageUrls : [];
  const all = urls.length ? urls : p.imageUrl ? [p.imageUrl] : [];
  return all.map((u) => `${u}`).filter(Boolean);
}

module.exports = { verdictFor, worstVerdict, gcsUriFromDownloadUrl, postImageUrls };
