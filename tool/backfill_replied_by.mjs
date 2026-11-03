// One-time backfill for first-contact safety: set `repliedBy` on chats that
// predate it, from their message history (system messages do not count).
// The server keeps it up to date afterwards (chat/replied_by.js).
//
//   node tool/backfill_replied_by.mjs --project helperly-call-v2-dev           # dry run
//   node tool/backfill_replied_by.mjs --project helperly-call-v2-dev --apply   # write
//
// Uses the gcloud credentials of whoever runs it. It only adds the field to
// chats that lack it; it never changes messages or other fields.
import { execSync } from "node:child_process";

const args = process.argv.slice(2);
const project = args[args.indexOf("--project") + 1];
const apply = args.includes("--apply");
if (!["helperly-call-v2-dev", "connectapp-278b4"].includes(project)) {
  throw new Error("pass --project helperly-call-v2-dev or --project connectapp-278b4");
}
const token = execSync("gcloud auth print-access-token", { encoding: "utf8" }).trim();
const base = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;
const headers = { authorization: `Bearer ${token}`, "content-type": "application/json" };

async function* list(path, mask) {
  let pageToken = "";
  do {
    const q = new URLSearchParams({ pageSize: "300", ...(pageToken ? { pageToken } : {}) });
    for (const m of mask) q.append("mask.fieldPaths", m);
    const res = await (await fetch(`${base}/${path}?${q}`, { headers })).json();
    if (res.error) throw new Error(`${path}: ${res.error.message}`);
    yield* res.documents || [];
    pageToken = res.nextPageToken || "";
  } while (pageToken);
}

const strings = (f) => (f?.arrayValue?.values || []).map((v) => v.stringValue).filter(Boolean);

let scanned = 0;
let missing = 0;
let written = 0;
for await (const chat of list("chats", ["participants", "users", "repliedBy"])) {
  scanned += 1;
  const f = chat.fields || {};
  if (f.repliedBy) continue;
  missing += 1;
  const id = chat.name.split("/").pop();
  const people = new Set([...strings(f.participants), ...strings(f.users)]);
  const writers = new Set();
  for await (const m of list(`chats/${id}/messages`, ["authorId", "system"])) {
    const author = m.fields?.authorId?.stringValue;
    if (author && people.has(author) && m.fields?.system?.booleanValue !== true) writers.add(author);
  }
  const repliedBy = [...people].filter((u) => writers.has(u));
  console.log(`${apply ? "set" : "would set"} chats/${id} repliedBy=[${repliedBy.length} of ${people.size}]`);
  if (apply) {
    const body = { fields: { repliedBy: { arrayValue: { values: repliedBy.map((u) => ({ stringValue: u })) } } } };
    const res = await fetch(`${base}/chats/${id}?updateMask.fieldPaths=repliedBy&currentDocument.exists=true`, {
      method: "PATCH",
      headers,
      body: JSON.stringify(body),
    });
    if (!res.ok) throw new Error(`chats/${id}: ${res.status} ${await res.text()}`);
    written += 1;
  }
}
console.log(`${project}: ${scanned} chats, ${missing} without repliedBy, ${written} written${apply ? "" : " (dry run)"}`);
