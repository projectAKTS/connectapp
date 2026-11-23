// Deletes every Firebase Auth account in a project. Used once to clear test
// accounts before launch, together with `firebase firestore:delete
// --all-collections` and `gcloud storage rm`. Dry run by default.
//
//   node tool/delete_all_auth_users.mjs --project connectapp-278b4           # count only
//   node tool/delete_all_auth_users.mjs --project connectapp-278b4 --apply   # delete
//
// Uses the gcloud credentials of whoever runs it. Prints counts only.
import { execSync } from "node:child_process";

const args = process.argv.slice(2);
const project = args[args.indexOf("--project") + 1];
const apply = args.includes("--apply");
if (!["helperly-call-v2-dev", "connectapp-278b4"].includes(project)) {
  throw new Error("pass --project helperly-call-v2-dev or --project connectapp-278b4");
}
const token = execSync("gcloud auth print-access-token", { encoding: "utf8" }).trim();
const headers = {
  authorization: `Bearer ${token}`,
  "x-goog-user-project": project,
  "content-type": "application/json",
};
const api = `https://identitytoolkit.googleapis.com/v1/projects/${project}/accounts`;

const ids = [];
let pageToken = "";
do {
  const q = new URLSearchParams({ maxResults: "1000", ...(pageToken ? { nextPageToken: pageToken } : {}) });
  const res = await (await fetch(`${api}:batchGet?${q}`, { headers })).json();
  if (res.error) throw new Error(res.error.message);
  for (const u of res.users || []) ids.push(u.localId);
  pageToken = res.nextPageToken || "";
} while (pageToken);

console.log(`${project}: ${ids.length} auth accounts`);
if (!apply) {
  console.log("dry run: nothing deleted (add --apply to delete)");
  process.exit(0);
}
let deleted = 0;
for (let i = 0; i < ids.length; i += 1000) {
  const batch = ids.slice(i, i + 1000);
  const res = await (await fetch(`${api}:batchDelete`, {
    method: "POST",
    headers,
    body: JSON.stringify({ localIds: batch, force: true }),
  })).json();
  if (res.error) throw new Error(res.error.message);
  const failed = (res.errors || []).length;
  deleted += batch.length - failed;
  if (failed) console.log(`${failed} accounts could not be deleted`);
}
console.log(`deleted ${deleted} of ${ids.length} auth accounts`);
