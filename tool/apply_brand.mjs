// Updates public brand copy in Flutter and hosted pages. Review the diff
// manually, then verify native builds and provider consoles separately.
//
//   node tool/apply_brand.mjs --name "NewName" --support "help@newname.com"
//   node tool/apply_brand.mjs --name "NewName" --dry-run
//
// Then run `flutter pub get` (regenerates the localizations) and the tests.
// It never touches code identifiers, the bundle id / application id, the
// Firebase projects or the Stripe account (rename those in their consoles).
import fs from "node:fs";
import path from "node:path";

const BRAND = "config/brand.json";
const args = process.argv.slice(2);
const arg = (k) => { const i = args.indexOf(k); return i >= 0 ? args[i + 1] : undefined; };
const dry = args.includes("--dry-run");
const current = JSON.parse(fs.readFileSync(BRAND, "utf8"));
const next = {
  appName: (arg("--name") ?? current.appName).trim(),
  supportEmail: (arg("--support") ?? current.supportEmail).trim(),
};
if (!next.appName || /["<>\\]/.test(next.appName)) throw new Error("invalid --name");
if (!/^[^@\s"<>]+@[^@\s"<>]+\.[a-z]{2,}$/i.test(next.supportEmail)) throw new Error("invalid --support");

const walk = (dir) => fs.readdirSync(dir, { withFileTypes: true }).flatMap((d) =>
  d.isDirectory() ? walk(path.join(dir, d.name)) : [path.join(dir, d.name)]);
const files = [
  "lib/l10n/app_en.arb",
  "lib/l10n/app_fr.arb",
  "lib/config/legal_texts.dart",
  "ios/Runner/Info.plist",
  "ios/Runner.xcodeproj/project.pbxproj",
  "android/app/src/main/AndroidManifest.xml",
  "android/app/src/main/res/xml/locales_config.xml",
  "lib/services/android_incoming_call.dart",
  ...walk("public").filter((f) => f.endsWith(".html")),
];

const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
// The e-mail first, so its domain is not caught by the name rule.
const oldSupportEmails = [...new Set([current.supportEmail, "support@helperly.app"])]
  .filter((email) => email !== next.supportEmail);
const oldNames = [...new Set([current.appName, "Helperly"])]
  .filter((name) => name !== next.appName);
const rules = [
  ...oldSupportEmails.map((email) => [new RegExp(esc(email), "g"), next.supportEmail]),
  // Whole word only: never part of an identifier such as HelperlyTestRuntime.
  ...oldNames.map((name) => [
    new RegExp(`(?<![A-Za-z0-9_@.])${esc(name)}(?![A-Za-z0-9_])`, "g"),
    next.appName,
  ]),
];

let total = 0;
for (const f of files) {
  const before = fs.readFileSync(f, "utf8");
  let after = before;
  let n = 0;
  for (const [re, to] of rules) after = after.replace(re, () => { n++; return to; });
  if (n) {
    total += n;
    console.log(`${dry ? "would change" : "changed"} ${n}\t${f}`);
    if (!dry) fs.writeFileSync(f, after);
  }
}
// CallKit uses a native display-name field. Avoid changing diagnostic log
// prefixes or the stable bundle ID while updating only these two values.
const appDelegate = "ios/Runner/AppDelegate.swift";
if (fs.existsSync(appDelegate)) {
  const before = fs.readFileSync(appDelegate, "utf8");
  let after = before;
  for (const oldName of oldNames) {
    after = after.replace(`callData.appName = "${oldName}"`, `callData.appName = "${next.appName}"`);
    after = after.replace(`CXProviderConfiguration(localizedName: "${oldName}")`, `CXProviderConfiguration(localizedName: "${next.appName}")`);
  }
  if (after !== before) {
    console.log(`${dry ? "would change" : "changed"}\t${appDelegate} (CallKit display names)`);
    if (!dry) fs.writeFileSync(appDelegate, after);
  }
}
if (!dry) fs.writeFileSync(BRAND, JSON.stringify(next, null, 2) + "\n");
console.log(`${total} replacements${dry ? " (dry run, nothing written)" : ""}.`);
if (!dry && total) console.log("Next: flutter gen-l10n, then review the native builds and provider settings.");
