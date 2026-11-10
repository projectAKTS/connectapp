// Read-only usage and cost check: how much the app stores and how much it
// was used over the last 7 days, next to the Firebase free allowances.
//   node tool/usage_report.mjs [--project=connectapp-278b4]
// Changes nothing. Prices are list prices for orientation, not a bill.
import { execFileSync } from "node:child_process";
import { PROJECT, count, metricSum } from "./gcp_read.mjs";

const n = (x) => Math.round(x).toLocaleString("en-US");
const gb = (bytes) => (bytes / 1024 ** 3).toFixed(2);

console.log(`# Usage report · ${PROJECT} · ${new Date().toISOString().slice(0, 10)}\n`);

console.log("## Stored documents\n");
for (const [name, all] of [["users", false], ["posts", false], ["comments", true],
  ["chats", false], ["messages", true], ["callInvites", false], ["consultations", false],
  ["reports", false], ["reviews", false]]) {
  try {
    console.log(`- ${name}: ${n(await count(name, all))}`);
  } catch (e) {
    console.log(`- ${name}: could not count (${e.message})`);
  }
}

console.log("\n## Storage (photos, videos)\n");
const bucket = `gs://${PROJECT}.firebasestorage.app`;
let totalBytes = 0;
for (const prefix of ["post_images", "post_videos", "post_video_thumbs", "chat_images", "profile_pictures"]) {
  try {
    const out = execFileSync("gcloud", ["storage", "du", "--summarize", `${bucket}/${prefix}`],
      { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] });
    const bytes = Number(out.trim().split(/\s+/)[0]) || 0;
    totalBytes += bytes;
    console.log(`- ${prefix}: ${gb(bytes)} GB`);
  } catch {
    console.log(`- ${prefix}: none`);
  }
}
console.log(`- total in these folders: ${gb(totalBytes)} GB (free: 5 GB)`);

console.log("\n## Last 7 days\n");
const rows = [
  ["Firestore reads", "firestore.googleapis.com/document/read_count", 50000 * 7],
  ["Firestore writes", "firestore.googleapis.com/document/write_count", 20000 * 7],
  ["Firestore deletes", "firestore.googleapis.com/document/delete_count", 20000 * 7],
  ["Function calls (Cloud Run requests)", "run.googleapis.com/request_count", 2e6 / 4.3],
];
for (const [label, type, free] of rows) {
  try {
    const v = await metricSum(type);
    console.log(`- ${label}: ${n(v)} (free about ${n(free)} a week) ${v > free ? "⚠️ over free" : "✓"}`);
  } catch (e) {
    console.log(`- ${label}: unavailable (${e.message})`);
  }
}
try {
  const sent = await metricSum("storage.googleapis.com/network/sent_bytes_count");
  console.log(`- Storage downloads: ${gb(sent)} GB (photos and videos people watched)`);
} catch (e) {
  console.log(`- Storage downloads: unavailable (${e.message})`);
}
