// One-time move of block lists off the public profile: for every user with
// `users/{uid}.blockedUids`, merge the list into the owner-only
// `users/{uid}/private/safety.blockedUids`, then remove the public field.
// Both writes go in one commit per user, so no block is ever lost. Rules,
// server and app read both places, so it is safe to run at any time and to
// run again.
//
//   node tool/migrate_blocked_uids.mjs --project helperly-call-v2-dev           # dry run
//   node tool/migrate_blocked_uids.mjs --project helperly-call-v2-dev --apply   # write
//
// Uses the gcloud credentials of whoever runs it. It prints counts only,
// never who blocked whom.
import { execSync } from "node:child_process";

const args = process.argv.slice(2);
const project = args[args.indexOf("--project") + 1];
const apply = args.includes("--apply");
if (!["helperly-call-v2-dev", "connectapp-278b4"].includes(project)) {
  throw new Error("pass --project helperly-call-v2-dev or --project connectapp-278b4");
}
const token = execSync("gcloud auth print-access-token", { encoding: "utf8" }).trim();
const root = `projects/${project}/databases/(default)/documents`;
const base = `https://firestore.googleapis.com/v1/${root}`;
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
let toMove = 0;
let moved = 0;
for await (const user of list("users", ["blockedUids"])) {
  scanned += 1;
  const f = user.fields || {};
  if (!("blockedUids" in f)) continue;
  toMove += 1;
  const uid = user.name.split("/").pop();
  const legacy = strings(f.blockedUids);
  if (!apply) continue;
  const write = {
    writes: [
      {
        // Adds the old list to whatever the private document already holds.
        transform: {
          document: `${root}/users/${uid}/private/safety`,
          fieldTransforms: [{
            fieldPath: "blockedUids",
            appendMissingElements: { values: legacy.map((u) => ({ stringValue: u })) },
          }],
        },
      },
      {
        // Removes the public field only (the update mask names it, the
        // document carries no value for it).
        update: { name: `${root}/users/${uid}`, fields: {} },
        updateMask: { fieldPaths: ["blockedUids"] },
        currentDocument: { exists: true },
      },
    ],
  };
  const res = await fetch(`${base}:commit`, { method: "POST", headers, body: JSON.stringify(write) });
  if (!res.ok) throw new Error(`user ${moved + 1}: ${res.status} ${await res.text()}`);
  moved += 1;
}
console.log(`${project}: ${scanned} users, ${toMove} with a public block list, ${apply ? `${moved} moved` : "dry run (nothing written)"}.`);
