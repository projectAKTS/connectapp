// Server-side smoke test against STAGING only (helperly-call-v2-dev), with
// disposable @example.test accounts that are deleted at the end.
//   node tool/staging_smoke.mjs
import fs from "node:fs";

const cfg = JSON.parse(fs.readFileSync("config/staging/firebase.env.json", "utf8"));
const P = cfg.STAGING_PROJECT_ID;
if (P !== "helperly-call-v2-dev") throw new Error(`refusing: project ${P}`);
const KEY = cfg.STAGING_ANDROID_API_KEY;
const FS = `https://firestore.googleapis.com/v1/projects/${P}/databases/(default)/documents`;
const FN = `https://us-central1-${P}.cloudfunctions.net`;
const PROD_AGORA = "dac900a04a87460c87c3d18b63cac65d";
const run = Date.now().toString(36);
const results = [];
const check = (name, ok, detail = "") => {
  results.push({ name, ok });
  console.log(`${ok ? "PASS" : "FAIL"}  ${name}${detail ? `  (${detail})` : ""}`);
};

async function signUp(tag) {
  const email = `stg-${tag}-${run}@example.test`;
  const password = `T-${run}-${Math.random().toString(36).slice(2)}`;
  const r = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${KEY}`, {
    method: "POST", headers: { "content-type": "application/json" },
    body: JSON.stringify({ email, password, returnSecureToken: true }),
  });
  const j = await r.json();
  if (!j.idToken) throw new Error(`signUp ${tag}: ${JSON.stringify(j.error)}`);
  return { tag, email, password, uid: j.localId, token: j.idToken };
}
const val = (v) => typeof v === "string" ? { stringValue: v }
  : typeof v === "boolean" ? { booleanValue: v }
  : typeof v === "number" ? { integerValue: `${v}` }
  : Array.isArray(v) ? { arrayValue: { values: v.map(val) } }
  : v instanceof Date ? { timestampValue: v.toISOString() } : { nullValue: null };
const fields = (o) => Object.fromEntries(Object.entries(o).map(([k, v]) => [k, val(v)]));
async function fsReq(u, method, path, body, mask) {
  const q = mask ? "?" + mask.map((m) => `updateMask.fieldPaths=${m}`).join("&") : "";
  const r = await fetch(`${FS}/${path}${q}`, {
    method, headers: { authorization: `Bearer ${u.token}`, "content-type": "application/json" },
    body: body ? JSON.stringify({ fields: fields(body) }) : undefined,
  });
  return { status: r.status, json: await r.json().catch(() => ({})) };
}
const patch = (u, path, data) => fsReq(u, "PATCH", path, data, Object.keys(data));
const create = (u, coll, id, data) => fsReq(u, "PATCH", `${coll}/${id}`, data, Object.keys(data));
const get = (u, path) => fsReq(u, "GET", path);
async function callable(u, name, data = {}) {
  const r = await fetch(`${FN}/${name}`, {
    method: "POST", headers: { authorization: `Bearer ${u.token}`, "content-type": "application/json" },
    body: JSON.stringify({ data }),
  });
  return { status: r.status, json: await r.json().catch(() => ({})) };
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function waitFor(fn, ms = 30000) {
  const end = Date.now() + ms;
  while (Date.now() < end) { if (await fn()) return true; await sleep(1500); }
  return false;
}

const A = await signUp("a"); const B = await signUp("b"); const C = await signUp("c");
check("sign-up (3 disposable accounts)", !!(A.uid && B.uid && C.uid));
check("onAuthUserCreated created the profile doc",
  await waitFor(async () => (await get(A, `users/${A.uid}`)).status === 200));

let r = await create(A, "posts", `p_${A.uid}`, { userID: A.uid, content: "smoke", postType: "quick" });
check("18+: undeclared account cannot post", r.status === 403, `status ${r.status}`);

await patch(A, `users/${A.uid}`, { ageDeclaration: "adult", fullName: "Smoke Helper", displayName: "Smoke Helper",
  role: "helper", expertiseTags: ["Housing search"], spokenLanguages: ["fr", "en"], onboardingComplete: true });
await patch(B, `users/${B.uid}`, { ageDeclaration: "adult", fullName: "Smoke Seeker", displayName: "Smoke Seeker",
  role: "seeker", interestTags: ["Housing"], onboardingComplete: true });
r = await create(A, "posts", `p_${A.uid}`, { userID: A.uid, content: "smoke", postType: "quick" });
check("18+: declared adult can post", r.status === 200, `status ${r.status}`);

const chat = [A.uid, B.uid].sort().join("_");
r = await create(B, "chats", chat, { participants: [A.uid, B.uid] });
check("chat created", r.status === 200, `status ${r.status}`);
r = await create(B, `chats/${chat}/messages`, `m_${run}`, { authorId: B.uid, text: "hello from smoke", type: "text" });
check("message sent", r.status === 200, `status ${r.status}`);
check("onChatMessageCreated ran once (notifiedAt claimed)", await waitFor(async () =>
  !!(await get(B, `chats/${chat}/messages/m_${run}`)).json.fields?.notifiedAt));
const writers = async () => ((await get(B, `chats/${chat}`)).json.fields?.repliedBy?.arrayValue?.values || [])
  .map((v) => v.stringValue);
check("first contact: the server records who wrote", await waitFor(async () => (await writers()).includes(B.uid)));
r = await create(B, `chats/${chat}/messages`, `img_${run}`, { authorId: B.uid, type: "image", uri: "x" });
check("first contact: no photo before the other person writes", r.status === 403, `status ${r.status}`);
await create(A, `chats/${chat}/messages`, `r_${run}`, { authorId: A.uid, text: "happy to help", type: "text" });
await waitFor(async () => (await writers()).includes(A.uid));
r = await create(B, `chats/${chat}/messages`, `img2_${run}`, { authorId: B.uid, type: "image", uri: "x" });
check("first contact: photos allowed after a reply", r.status === 200, `status ${r.status}`);

r = await create(B, "callInvites", `inv_${run}`, { fromUid: B.uid, fromName: "Smoke Seeker", toUid: A.uid,
  toName: "Smoke Helper", channel: `ch_${run}`, isVideo: false, status: "ringing", type: "call_invite" });
check("call invite created (adults)", r.status === 200, `status ${r.status}`);

// Unanswered call: the caller hangs up while it rings, the callee gets a note.
const missedNotes = async () => ((await get(A, `chats/${chat}/messages?pageSize=50`)).json.documents || [])
  .filter((d) => d.fields?.type?.stringValue === "missed_call");
const unreadA = async () => Number((await get(A, `users/${A.uid}`)).json.fields?.unreadMessagesCount?.integerValue || 0);
await sleep(8000); // let the earlier messages finish counting
const unreadBefore = await unreadA();
await create(B, "callInvites", `inv_missed_${run}`, { fromUid: B.uid, fromName: "Smoke Seeker", toUid: A.uid,
  toName: "Smoke Helper", channel: `ch_missed_${run}`, isVideo: true, status: "ringing", type: "call_invite" });
await sleep(2000);
r = await patch(B, `callInvites/inv_missed_${run}`, { status: "cancelled", endReason: "caller_cancelled" });
check("caller cancels a ringing call", r.status === 200, `status ${r.status}`);
check("missed call: a note is added to the chat", await waitFor(async () => (await missedNotes()).length === 1));
const note = (await missedNotes())[0]?.fields || {};
check("missed call: note is from the caller, video, system",
  note.authorId?.stringValue === B.uid && note.isVideo?.booleanValue === true && note.system?.booleanValue === true);
const chatUnreadA = async () => Number((await get(A, `chats/${chat}`)).json.fields?.unreadBy?.mapValue?.fields?.[A.uid]?.integerValue || 0);
check("chat list: the per-chat unread count reaches the callee", await waitFor(async () => (await chatUnreadA()) >= 1), `unreadBy=${await chatUnreadA()}`);
check("missed call: the callee has it unread", await waitFor(async () => (await unreadA()) === unreadBefore + 1), `before ${unreadBefore}, after ${await unreadA()}`);
await create(B, "callInvites", `inv_declined_${run}`, { fromUid: B.uid, fromName: "Smoke Seeker", toUid: A.uid,
  toName: "Smoke Helper", channel: `ch_declined_${run}`, isVideo: false, status: "ringing", type: "call_invite" });
await sleep(2000);
await patch(A, `callInvites/inv_declined_${run}`, { status: "declined", declinedBy: A.uid });
const unreadBeforeDecline = await unreadA();
check("declined call: a silent note is added to the chat", await waitFor(async () =>
  (await missedNotes()).some((d) => d.fields?.silent?.booleanValue === true)));
await sleep(8000);
check("declined call: no unread for the callee", (await unreadA()) === unreadBeforeDecline,
  `before ${unreadBeforeDecline}, after ${await unreadA()}`);

r = await callable(B, "getAgoraRtcToken", { channelName: `ch_${run}`, uid: 1234, role: "publisher" });
const appId = r.json?.result?.appId;
check("Agora token from staging app (not production)", !!(r.json?.result?.token && appId && appId !== PROD_AGORA),
  `status ${r.status}, appId …${(appId || "").slice(-4)}`);

// A pair-call channel (c_<uidA 12>_<uidB 12>_<time>) gives a token only to its two people.
const pairChannel = (() => {
  const [x, y] = [A.uid, B.uid].map((u) => u.replace(/[^A-Za-z0-9_]/g, "").slice(0, 12)).sort();
  return `c_${x}_${y}_${run}`;
})();
r = await callable(A, "getAgoraRtcToken", { channelName: pairChannel, uid: 0, role: "publisher" });
const rB = await callable(B, "getAgoraRtcToken", { channelName: pairChannel, uid: 0, role: "publisher" });
check("call token: both people in the call get one", !!(r.json?.result?.token && rB.json?.result?.token),
  `status ${r.status}/${rB.status}`);
r = await callable(C, "getAgoraRtcToken", { channelName: pairChannel, uid: 0, role: "publisher" });
check("call token: a third person is refused", r.json?.error?.status === "PERMISSION_DENIED" && !r.json?.result,
  r.json?.error?.status || `status ${r.status}`);

r = await callable(B, "chargeStoredPaymentMethod", { operationId: `op_smoke_${run}_0001`, durationMinutes: 10, callType: "audio", helperId: A.uid });
check("payments refused on the server", r.json?.error?.status === "FAILED_PRECONDITION" &&
  /beta/.test(r.json?.error?.message || ""), r.json?.error?.message);
r = await callable(A, "createExpressAccountLink", {});
check("helper payout onboarding refused", r.json?.error?.status === "FAILED_PRECONDITION", r.json?.error?.message);
r = await callable(B, "createStripeCheckoutSession", { consultationId: "x", cost: 5 });
check("checkout (helper transfers) refused", r.json?.error?.status === "FAILED_PRECONDITION", r.json?.error?.message);

await patch(C, `users/${C.uid}`, { ageDeclaration: "minor" });
r = await patch(C, `users/${C.uid}`, { ageDeclaration: "adult" });
check("minor cannot self-lift the restriction", r.status === 403, `status ${r.status}`);
r = await create(A, "callInvites", `inv_minor_${run}`, { fromUid: A.uid, toUid: C.uid, channel: "x", status: "ringing" });
check("nobody can call a restricted minor", r.status === 403, `status ${r.status}`);

r = await create(B, "reports", `rep_${run}`, { type: "user", targetId: A.uid, targetUid: A.uid,
  reason: "Spam or scam", reporterUid: B.uid, status: "open", createdAt: new Date() });
check("report filed", r.status === 200, `status ${r.status}`);
r = await get(A, `reports/rep_${run}`);
check("reports are private (reported user cannot read)", r.status === 403, `status ${r.status}`);

r = await callable(B, "deleteAccount", {});
check("deleteAccount (B) complete", r.json?.result?.success === true && r.json?.result?.complete === true, JSON.stringify(r.json?.result || r.json?.error));
r = await get(A, `users/${B.uid}`);
check("B's profile is gone", r.status === 404, `status ${r.status}`);
r = await get(A, `callInvites/inv_${run}`);
const inv = r.json.fields || {};
check("B's name scrubbed from call record", (inv.fromName?.stringValue ?? "x") === "", `fromName="${inv.fromName?.stringValue}"`);
r = await get(A, `chats/${chat}/messages/m_${run}`);
check("B's message kept with A (documented)", r.status === 200, `status ${r.status}`);
const login = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${KEY}`, {
  method: "POST", headers: { "content-type": "application/json" },
  body: JSON.stringify({ email: B.email, password: B.password, returnSecureToken: true }) });
const loginErr = (await login.json()).error?.message;
// Projects with email-enumeration protection answer INVALID_LOGIN_CREDENTIALS.
check("B can no longer sign in", ["EMAIL_NOT_FOUND", "INVALID_LOGIN_CREDENTIALS"].includes(loginErr), loginErr);

for (const u of [A, C]) await callable(u, "deleteAccount", {});
const failed = results.filter((x) => !x.ok).length;
console.log(`\n${results.length - failed}/${results.length} passed; disposable accounts deleted.`);
process.exit(failed ? 1 : 0);
