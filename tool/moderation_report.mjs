// Read-only moderation report: open reports grouped by what was reported,
// and posts already hidden by reports or by the photo check.
//   node tool/moderation_report.mjs [--project=connectapp-278b4]
// Changes nothing. Acting on a report (hiding, deleting, suspending) is a
// separate, deliberate step; see docs/MODERATION_ROUTINE.md.
import { PROJECT, query, mask } from "./gcp_read.mjs";

const day = (t) => (t ? `${t}`.slice(0, 10) : "?");
const ageDays = (t) => (t ? Math.floor((Date.now() - Date.parse(t)) / 864e5) : null);

const open = await query("reports", ["status", "open"], 1000);
const groups = new Map();
for (const r of open) {
  const key = `${r.type || "?"}:${r.targetId || ""}`;
  const g = groups.get(key) || { type: r.type, targetId: r.targetId, targetUid: r.targetUid,
    reasons: new Map(), reporters: new Set(), first: r.createdAt, last: r.createdAt };
  g.reasons.set(r.reason || "?", (g.reasons.get(r.reason || "?") || 0) + 1);
  g.reporters.add(r.reporterUid);
  if (r.createdAt && (!g.first || r.createdAt < g.first)) g.first = r.createdAt;
  if (r.createdAt && (!g.last || r.createdAt > g.last)) g.last = r.createdAt;
  groups.set(key, g);
}

// Harassment and danger first (24 h target), then by number of reporters.
const urgent = (g) => [...g.reasons.keys()].some((k) => /harass|threat|danger|violen|self|minor|sexual/i.test(k));
const list = [...groups.values()].sort((a, b) =>
  (urgent(b) - urgent(a)) || (b.reporters.size - a.reporters.size));

console.log(`# Moderation report · ${PROJECT} · ${new Date().toISOString().slice(0, 16)}Z\n`);
console.log(`Open reports: ${open.length} about ${list.length} target(s).\n`);
if (list.length) {
  console.log("| ! | Type | Target | Owner | Reporters | Reasons | First | Waiting |");
  console.log("|---|---|---|---|---|---|---|---|");
  for (const g of list) {
    const reasons = [...g.reasons].map(([k, n]) => (n > 1 ? `${k} ×${n}` : k)).join(", ");
    const wait = ageDays(g.first);
    const late = (urgent(g) && wait >= 1) || wait >= 3;
    console.log(`| ${urgent(g) ? "🔴" : late ? "🟠" : ""} | ${g.type} | ${g.type === "user" ? mask(g.targetId) : g.targetId} | ${mask(g.targetUid)} | ${g.reporters.size} | ${reasons} | ${day(g.first)} | ${wait ?? "?"} d |`);
  }
  console.log("\n🔴 harassment or danger: act within 24 h. 🟠 other report waiting over 3 days.");
}

const byReports = await query("posts", ["hiddenByReports", true]);
const bySafety = await query("posts", ["hiddenBySafety", true]);
const sensitive = await query("posts", ["sensitive", true]);
console.log("\n## Posts already hidden or covered\n");
console.log(`Hidden by reports: ${byReports.length}. Hidden by the photo check: ${bySafety.length}. Shown behind a "sensitive" cover: ${sensitive.length}.`);
for (const p of [...byReports, ...bySafety]) {
  console.log(`- ${p.id} · owner ${mask(p.userID)} · ${p.hiddenByReports ? `reports (${p.hiddenByReportsCount ?? "?"})` : "photo check"} · ${day(p.timestamp)}`);
}
