// Paid-session end-to-end test against STAGING only (helperly-call-v2-dev),
// in Stripe TEST mode, with disposable @example.test accounts.
//   node tool/staging_paid_e2e.mjs setup    -> accounts + helper onboarding link
//   (complete Stripe's test onboarding at the printed link)
//   node tool/staging_paid_e2e.mjs run      -> bookings, cancels, refunds,
//                                              report, release, 3DS, decline
//   node tool/staging_paid_e2e.mjs cleanup  -> deletes the accounts
// Needs paid sessions on in staging (PAID_SESSIONS_ENABLED=true) and the
// Stripe test key in Secret Manager. Secrets are never printed.
import fs from "node:fs";
import { execFileSync } from "node:child_process";

const cfg = JSON.parse(fs.readFileSync("config/staging/firebase.env.json", "utf8"));
const P = cfg.STAGING_PROJECT_ID;
if (P !== "helperly-call-v2-dev") throw new Error(`refusing: project ${P}`);
const KEY = cfg.STAGING_ANDROID_API_KEY;
const FS = `https://firestore.googleapis.com/v1/projects/${P}/databases/(default)/documents`;
const FN = `https://us-central1-${P}.cloudfunctions.net`;
const STATE = process.env.E2E_STATE || "test_artifacts/paid_e2e_state.json";
const MODE = process.argv[2] || "run";

const sh = (cmd, args) => execFileSync(cmd, args, { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim();
const SK = sh("gcloud", ["secrets", "versions", "access", "latest", "--secret", "STRIPE_SECRET", "--project", P]);
if (!SK.startsWith("sk_test_")) throw new Error("refusing: STRIPE_SECRET is not a test key");
const ADMIN = () => sh("gcloud", ["auth", "print-access-token"]);

const results = [];
const check = (name, ok, detail = "") => {
  results.push({ name, ok });
  console.log(`${ok ? "PASS" : "FAIL"}  ${name}${detail ? `  (${detail})` : ""}`);
};
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function waitFor(fn, ms = 60000) {
  const end = Date.now() + ms;
  while (Date.now() < end) { const v = await fn(); if (v) return v; await sleep(2000); }
  return null;
}

async function stripe(method, path, form) {
  const r = await fetch(`https://api.stripe.com/v1/${path}`, {
    method,
    headers: {
      authorization: `Basic ${Buffer.from(`${SK}:`).toString("base64")}`,
      "content-type": "application/x-www-form-urlencoded",
    },
    body: form ? new URLSearchParams(form).toString() : undefined,
  });
  return r.json();
}

async function signUp(tag) {
  const run = Date.now().toString(36);
  const email = `stg-pay-${tag}-${run}@example.test`;
  const password = `T-${run}-${Math.random().toString(36).slice(2)}`;
  const r = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${KEY}`, {
    method: "POST", headers: { "content-type": "application/json" },
    body: JSON.stringify({ email, password, returnSecureToken: true }),
  });
  const j = await r.json();
  if (!j.idToken) throw new Error(`signUp ${tag}: ${JSON.stringify(j.error)}`);
  return { tag, email, password, uid: j.localId, token: j.idToken };
}
async function signIn(u) {
  const r = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${KEY}`, {
    method: "POST", headers: { "content-type": "application/json" },
    body: JSON.stringify({ email: u.email, password: u.password, returnSecureToken: true }),
  });
  const j = await r.json();
  if (!j.idToken) throw new Error(`signIn ${u.tag}: ${JSON.stringify(j.error)}`);
  return { ...u, token: j.idToken };
}

const val = (v) => typeof v === "string" ? { stringValue: v }
  : typeof v === "boolean" ? { booleanValue: v }
  : typeof v === "number" ? { integerValue: `${v}` }
  : Array.isArray(v) ? { arrayValue: { values: v.map(val) } }
  : v instanceof Date ? { timestampValue: v.toISOString() } : { nullValue: null };
const fields = (o) => Object.fromEntries(Object.entries(o).map(([k, v]) => [k, val(v)]));
const plain = (f) => Object.fromEntries(Object.entries(f || {}).map(([k, v]) => [k,
  v.stringValue ?? (v.integerValue !== undefined ? Number(v.integerValue) : undefined)
  ?? v.doubleValue ?? v.booleanValue ?? v.timestampValue ?? (v.nullValue === null ? null : v)]));

async function fsReq(token, method, path, body, mask) {
  const q = mask ? "?" + mask.map((m) => `updateMask.fieldPaths=${m}`).join("&") : "";
  const r = await fetch(`${FS}/${path}${q}`, {
    method, headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: body ? JSON.stringify({ fields: fields(body) }) : undefined,
  });
  return { status: r.status, json: await r.json().catch(() => ({})) };
}
const patchAs = (u, path, data) => fsReq(u.token, "PATCH", path, data, Object.keys(data));
async function adminGet(path) {
  const r = await fsReq(ADMIN(), "GET", path);
  return r.status === 200 ? plain(r.json.fields) : null;
}
const adminPatch = (path, data) => fsReq(ADMIN(), "PATCH", path, data, Object.keys(data));

async function callable(u, name, data = {}) {
  const r = await fetch(`${FN}/${name}`, {
    method: "POST", headers: { authorization: `Bearer ${u.token}`, "content-type": "application/json" },
    body: JSON.stringify({ data }),
  });
  const j = await r.json().catch(() => ({}));
  return { status: r.status, result: j.result, error: j.error };
}
const opId = () => `e2e_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 10)}`;

async function addCard(u, testPm) {
  await callable(u, "createStripeCustomer");
  const si = await callable(u, "createSetupIntent");
  const secret = si.result?.clientSecret || "";
  const id = secret.split("_secret_")[0];
  const conf = await stripe("POST", `setup_intents/${id}/confirm`, { payment_method: testPm });
  if (conf.status !== "succeeded") return { ok: false, detail: conf.error?.message || conf.status };
  const def = await callable(u, "setDefaultPaymentMethod", { paymentMethodId: conf.payment_method });
  return { ok: def.result?.ok === true, detail: conf.payment_method?.slice(0, 6) };
}

// Cards that ask for 3D Secure or decline at every use cannot pass a
// SetupIntent here; attach them straight to the customer instead.
async function attachCard(u, testPm) {
  await callable(u, "createStripeCustomer");
  const cust = (await adminGet(`users/${u.uid}`))?.stripeCustomerId;
  const pm = await stripe("POST", `payment_methods/${testPm}/attach`, { customer: cust });
  if (!pm.id) return { ok: false, detail: pm.error?.message };
  const def = await callable(u, "setDefaultPaymentMethod", { paymentMethodId: pm.id });
  return { ok: def.result?.ok === true, detail: pm.id.slice(0, 6) };
}

async function book(seeker, helper, hoursAhead, extra = {}) {
  const operationId = opId();
  const r = await callable(seeker, "bookPaidSession", {
    operationId, helperId: helper.uid, durationMinutes: 10, callType: "audio",
    scheduledAtMs: Date.now() + hoursAhead * 3600e3, ...extra,
  });
  return { operationId, ...r };
}

// ---------------------------------------------------------------- setup
if (MODE === "setup") {
  const H = await signUp("helper");
  const S = await signUp("seeker");
  await waitFor(async () => (await adminGet(`users/${H.uid}`)) && (await adminGet(`users/${S.uid}`)), 30000);
  await patchAs(H, `users/${H.uid}`, { ageDeclaration: "adult", fullName: "E2E Helper", displayName: "E2E Helper",
    role: "helper", expertiseTags: ["Housing search"], spokenLanguages: ["en"], onboardingComplete: true });
  await patchAs(S, `users/${S.uid}`, { ageDeclaration: "adult", fullName: "E2E Seeker", displayName: "E2E Seeker",
    role: "seeker", interestTags: ["Housing"], onboardingComplete: true });
  const link = await callable(H, "createExpressAccountLink", { email: H.email });
  check("helper gets a Stripe onboarding link", !!link.result?.url, JSON.stringify(link.error || ""));
  fs.writeFileSync(STATE, JSON.stringify({ H, S }), { mode: 0o600 });
  if (link.result?.url) console.log(`ONBOARDING_URL ${link.result.url}`);
  process.exit(results.every((r) => r.ok) ? 0 : 1);
}

const state = JSON.parse(fs.readFileSync(STATE, "utf8"));
const H = await signIn(state.H);
const S = await signIn(state.S);

// -------------------------------------------------------------- cleanup
if (MODE === "cleanup") {
  for (const u of [H, S, ...(state.S2 ? [await signIn(state.S2)] : [])]) {
    const r = await callable(u, "deleteAccount", {});
    check(`deleteAccount ${u.tag}`, r.result?.success === true, JSON.stringify(r.error || ""));
  }
  fs.rmSync(STATE, { force: true });
  process.exit(results.every((r) => r.ok) ? 0 : 1);
}

// ------------------------------------------------------------------ run
const payout = await callable(H, "getPayoutStatus");
check("helper payouts enabled after onboarding", payout.result?.payoutsEnabled === true, JSON.stringify(payout.result || payout.error));
const hUser = await adminGet(`users/${H.uid}`);
check("server stored payoutsEnabled on the helper", hUser?.payoutsEnabled === true);
const acct = hUser?.stripeAccountId;

let r;
if (!(await adminGet(`users/${S.uid}`))?.defaultPaymentMethodId) {
  r = await book(S, H, 48);
  check("booking without a card is refused", !r.result?.success, JSON.stringify(r.error?.message || r.result));
}

const card = await addCard(S, "pm_card_visa");
check("seeker saves a test card (4242)", card.ok, card.detail);

// 1. Booking 48 h ahead, then the seeker cancels: 100 % back.
r = await book(S, H, 48);
check("paid booking succeeds", r.result?.success === true && r.result?.consultationId === r.operationId,
  JSON.stringify(r.result || r.error));
let c = await adminGet(`consultations/${r.operationId}`);
check("consultation written by the server, held",
  c?.status === "paid" && c?.payoutState === "held" && c?.amountCents === 449 && c?.platformFeeCents === 90
  && c?.helperShareCents === 359, c && `${c.status}/${c.payoutState} ${c.amountCents}/${c.platformFeeCents}/${c.helperShareCents}`);
const pi1 = c?.paymentIntentId;
const pi1s = pi1 ? await stripe("GET", `payment_intents/${pi1}`) : {};
check("Stripe PaymentIntent succeeded, 4.49 CAD", pi1s.status === "succeeded" && pi1s.amount === 449 && pi1s.currency === "cad");
const op1 = await waitFor(async () => {
  const o = await adminGet(`paymentOperations/${r.operationId}`);
  return o?.stripeStatus === "succeeded" ? o : null;
}, 30000);
check("payment operation recorded succeeded", !!op1);
let again = await callable(S, "bookPaidSession", { operationId: r.operationId, helperId: H.uid, durationMinutes: 10,
  callType: "audio", scheduledAtMs: Date.now() + 48 * 3600e3 });
check("retry with the same operation does not charge twice", again.result?.replayed === true,
  JSON.stringify(again.result || again.error));
let x = await callable(S, "cancelConsultation", { consultationId: r.operationId });
check("seeker cancel 48 h ahead refunds 100 %", x.result?.refundPercent === 100 && x.result?.refundAmount === 4.49,
  JSON.stringify(x.result || x.error));
c = await adminGet(`consultations/${r.operationId}`);
check("cancelled, nothing left to release", c?.status === "cancelled" && c?.payoutState === "none");
const ref1 = c?.refundId ? await stripe("GET", `refunds/${c.refundId}`) : {};
check("Stripe refund 4.49 CAD", ref1.amount === 449 && ["succeeded", "pending"].includes(ref1.status), ref1.status);

// 2. Booking 2 h ahead, seeker cancels: 50 % back, the rest is the helper's.
r = await book(S, H, 2);
const op2 = r.operationId;
x = await callable(S, "cancelConsultation", { consultationId: op2 });
check("seeker cancel 2 h ahead refunds 50 %", x.result?.refundPercent === 50, JSON.stringify(x.result || x.error));
c = await adminGet(`consultations/${op2}`);
check("half refunded, rest held for the helper", c?.status === "cancelled" && c?.payoutState === "held"
  && c?.refundedCents === 225, c && `${c.refundedCents} ${c.payoutState}`);

// 3. Helper cancels: always 100 % back.
r = await book(S, H, 3);
x = await callable(H, "cancelConsultation", { consultationId: r.operationId });
check("helper cancel refunds 100 %", x.result?.refundPercent === 100, JSON.stringify(x.result || x.error));

// 4. Seeker reports a problem: held for review, never released.
r = await book(S, H, 0);
const op4 = r.operationId;
x = await callable(S, "reportSessionProblem", { consultationId: op4, reason: "Helper did not join" });
c = await adminGet(`consultations/${op4}`);
check("report a problem puts it under review", c?.status === "under_review" && c?.payoutState === "review",
  JSON.stringify(x.error || "") + (c ? ` ${c.status}/${c.payoutState}` : ""));
x = await callable(H, "reportSessionProblem", { consultationId: op4, reason: "x" });
check("helper cannot report", !x.result?.ok, x.error?.status || "");

// 5. A finished session is released to the helper by the hourly job.
r = await book(S, H, 0);
const op5 = r.operationId;
const past = new Date(Date.now() - 60e3);
for (const id of [op2, op4, op5]) await adminPatch(`consultations/${id}`, { releaseAfter: past });
sh("gcloud", ["scheduler", "jobs", "run", "firebase-schedule-releaseHeldPayouts-us-central1",
  "--location", "us-central1", "--project", P]);
const done5 = await waitFor(async () => {
  const d = await adminGet(`consultations/${op5}`);
  return d?.payoutState === "released" ? d : null;
}, 120000);
check("release job completes the session", done5?.status === "completed", done5 && done5.status);
const tr5 = done5?.transferId ? await stripe("GET", `transfers/${done5.transferId}`) : {};
check("helper receives 80 % (3.59 CAD) on their Stripe account",
  tr5.amount === 359 && tr5.destination === acct && !!tr5.source_transaction, `${tr5.amount} ${tr5.destination === acct}`);
const d2 = await adminGet(`consultations/${op2}`);
const tr2 = d2?.transferId ? await stripe("GET", `transfers/${d2.transferId}`) : {};
// Kept 4.49 - 2.25 = 2.24; fee 20 % = 0.45 (rounded); helper 1.79.
check("late cancel: helper receives 80 % of the kept half", d2?.payoutState === "released" && tr2.amount === 179,
  `${d2?.payoutState} ${tr2.amount}`);
const d4 = await adminGet(`consultations/${op4}`);
check("reported session is not released", d4?.payoutState === "review" && !d4?.transferId);

// 6. Review only after a completed paid session.
async function review(u, consultationId) {
  const r = await fetch(`${FS.replace(/\/documents$/, "/documents:commit")}`, {
    method: "POST", headers: { authorization: `Bearer ${u.token}`, "content-type": "application/json" },
    body: JSON.stringify({ writes: [{
      update: { name: `projects/${P}/databases/(default)/documents/reviews/${consultationId}`,
        fields: fields({ consultationId, reviewerUid: u.uid, helperUid: H.uid, stars: 5, text: "Great" }) },
      updateTransforms: [{ fieldPath: "createdAt", setToServerValue: "REQUEST_TIME" }],
      currentDocument: { exists: false },
    }] }),
  });
  return r.status;
}
check("seeker cannot review a cancelled session", (await review(S, op2)) === 403);
check("seeker can review the completed paid session", (await review(S, op5)) === 200);

// 7. Bank verification (3D Secure) and a declined card.
const S2 = state.S2 ? await signIn(state.S2) : await signUp("seeker3ds");
await waitFor(async () => adminGet(`users/${S2.uid}`), 30000);
await patchAs(S2, `users/${S2.uid}`, { ageDeclaration: "adult", fullName: "E2E Seeker 3DS",
  displayName: "E2E Seeker 3DS", role: "seeker", onboardingComplete: true });
state.S2 = S2; fs.writeFileSync(STATE, JSON.stringify(state), { mode: 0o600 });
const card3 = await attachCard(S2, "pm_card_threeDSecure2Required");
check("3DS test card saved", card3.ok, card3.detail);
r = await book(S2, H, 24);
check("3DS card: server asks the app for bank confirmation", r.result?.requiresAction === true && !!r.result?.clientSecret,
  JSON.stringify(r.result ? { requiresAction: r.result.requiresAction } : r.error));
c = await adminGet(`consultations/${r.operationId}`);
check("no booking before the bank confirms", !c);

const S3card = await attachCard(S, "pm_card_chargeCustomerFail");
check("declining test card saved", S3card.ok, S3card.detail);
r = await book(S, H, 24);
check("declined card: booking refused, no consultation", !r.result?.success, r.error?.message);

const failed = results.filter((x) => !x.ok).length;
console.log(`\n${results.length - failed}/${results.length} passed. Accounts kept for the app test; run "cleanup" after.`);
process.exit(failed ? 1 : 0);
