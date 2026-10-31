"use strict";

/**
 * One-off: moves `email` out of world-readable users/{uid} docs into the
 * server-only users/{uid}/private/account doc.
 *
 * Dry run (default) only counts:
 *   cd connect_functions
 *   gcloud auth application-default login
 *   GOOGLE_CLOUD_PROJECT=connectapp-278b4 node scripts/migrate_public_emails.js
 * Apply:
 *   GOOGLE_CLOUD_PROJECT=connectapp-278b4 node scripts/migrate_public_emails.js --apply
 *
 * Prints counts only, never addresses.
 */

const admin = require("firebase-admin");

async function main() {
  const apply = process.argv.includes("--apply");
  admin.initializeApp();
  const db = admin.firestore();
  const users = await db.collection("users").get();
  let withEmail = 0;
  let moved = 0;
  for (const doc of users.docs) {
    const email = `${doc.get("email") || ""}`.trim();
    if (!email) continue;
    withEmail += 1;
    if (!apply) continue;
    const batch = db.batch();
    batch.set(doc.ref.collection("private").doc("account"), { email }, { merge: true });
    batch.update(doc.ref, { email: admin.firestore.FieldValue.delete() });
    await batch.commit();
    moved += 1;
  }
  console.log(
    JSON.stringify({ mode: apply ? "apply" : "dry-run", users: users.size, withEmail, moved }),
  );
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
