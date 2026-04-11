// ============================================================
// 🔥 ConnectApp Firebase Functions (Stripe + Notifications)
// ============================================================

const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const functionsV1 = require("firebase-functions/v1");
const { defineSecret } = require("firebase-functions/params");
const { RtcTokenBuilder, RtcRole } = require("agora-token");
const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();
const fcm = admin.messaging();
const STRIPE_SECRET = defineSecret("STRIPE_SECRET");
const AGORA_APP_ID = defineSecret("AGORA_APP_ID");
const AGORA_APP_CERTIFICATE = defineSecret("AGORA_APP_CERTIFICATE");
const APNS_KEY_ID = defineSecret("APNS_KEY_ID");
const APNS_TEAM_ID = defineSecret("APNS_TEAM_ID");
const APNS_BUNDLE_ID = defineSecret("APNS_BUNDLE_ID");
const APNS_VOIP_KEY_P8 = defineSecret("APNS_VOIP_KEY_P8");

// --- Stripe Client Helper ---
function getStripeClient() {
  const secret = STRIPE_SECRET.value();
  if (!secret) throw new Error("Stripe secret missing");
  return require("stripe")(secret);
}

function getStripeMode() {
  const secret = STRIPE_SECRET.value() || "";
  return secret.startsWith("sk_live_") ? "live" : "test";
}

function fallbackNameFromEmail(email) {
  const e = `${email || ""}`.trim();
  if (!e.includes("@")) return "";
  const raw = e.split("@")[0];
  const cleaned = raw.replace(/[^A-Za-z0-9]+/g, " ").trim();
  if (!cleaned) return "";
  return cleaned
    .split(" ")
    .filter(Boolean)
    .map((p) => p.charAt(0).toUpperCase() + p.slice(1))
    .join(" ")
    .trim();
}

function inferOtherUidFromChatId(chatId, currentUid) {
  const id = `${chatId || ""}`.trim();
  const me = `${currentUid || ""}`.trim();
  if (!id || !me) return "";

  const prefix = `${me}_`;
  if (id.startsWith(prefix) && id.length > prefix.length) {
    return id.substring(prefix.length);
  }
  const suffix = `_${me}`;
  if (id.endsWith(suffix) && id.length > suffix.length) {
    return id.substring(0, id.length - suffix.length);
  }

  const parts = id.split("_").filter(Boolean);
  if (parts.length === 2) {
    return parts[0] === me ? parts[1] : parts[0];
  }
  return "";
}

function deriveRtcUidFromAuthUid(authUid) {
  const source = `${authUid || ""}`;
  if (!source) return 1;
  // FNV-1a 32-bit hash for stable, deterministic non-zero Agora uid.
  let hash = 0x811c9dc5;
  for (let i = 0; i < source.length; i++) {
    hash ^= source.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193);
  }
  const unsigned = hash >>> 0;
  return (unsigned % 2147483646) + 1;
}

// --- Get User Tokens ---
function normalizeTokenList(arr, single) {
  const list = Array.isArray(arr) ? arr : [];
  const one = single ? [single] : [];
  return Array.from(new Set([...list, ...one].filter(Boolean)));
}

function tokenSuffixes(tokens) {
  return (Array.isArray(tokens) ? tokens : [])
    .filter(Boolean)
    .map((token) => `${token}`.slice(-12));
}

async function getUserPushTokenSets(uid) {
  const snap = await db.collection("users").doc(uid).get();
  if (!snap.exists) {
    return {
      fcmAll: [],
      fcmForFallback: [],
      apns: [],
      voip: [],
    };
  }
  const data = snap.data() || {};
  // Prefer the latest scalar token fields over historical arrays. Reinstalls
  // were growing these arrays and causing duplicate notifications.
  const fcmAll = data.fcmToken
    ? normalizeTokenList([], data.fcmToken)
    : normalizeTokenList(data.fcmTokens, data.fcmToken);
  const fcmIos = data.fcmTokenIos
    ? normalizeTokenList([], data.fcmTokenIos)
    : normalizeTokenList(data.fcmTokensIos, data.fcmTokenIos);
  const fcmAndroid = data.fcmTokenAndroid
    ? normalizeTokenList([], data.fcmTokenAndroid)
    : normalizeTokenList(data.fcmTokensAndroid, data.fcmTokenAndroid);
  const apns = data.apnsToken
    ? normalizeTokenList([], data.apnsToken)
    : normalizeTokenList(data.apnsTokens, data.apnsToken);
  const voip = data.voipToken
    ? normalizeTokenList([], data.voipToken)
    : normalizeTokenList(data.voipTokens, data.voipToken);

  // Prefer explicit Android tokens for FCM fallback.
  // If only iOS tokens exist, skip FCM and rely on APNS direct paths.
  let fcmForFallback = fcmAndroid;
  if (!fcmForFallback.length) {
    if (fcmIos.length) {
      const iosSet = new Set(fcmIos);
      fcmForFallback = fcmAll.filter((token) => !iosSet.has(token));
    } else {
      fcmForFallback = fcmAll;
    }
  }

  return {
    fcmAll,
    fcmForFallback: Array.from(new Set(fcmForFallback)),
    apns,
    voip,
  };
}

async function getUserTokens(uid) {
  const tokenSets = await getUserPushTokenSets(uid);
  return tokenSets.fcmAll;
}

async function getUserVoipTokens(uid) {
  const tokenSets = await getUserPushTokenSets(uid);
  return tokenSets.voip;
}

async function getUserApnsTokens(uid) {
  const tokenSets = await getUserPushTokenSets(uid);
  return tokenSets.apns;
}

// --- Send Notification ---
async function sendToTokens(tokens, payload) {
  const deduped = Array.from(new Set(tokens.filter(Boolean)));
  if (!deduped.length) return;
  const result = await fcm.sendEachForMulticast({ tokens: deduped, ...payload });
  const failed = [];
  result.responses.forEach((r, i) => {
    if (!r.success) {
      failed.push({
        token: deduped[i],
        code: r.error?.code || "unknown",
        message: r.error?.message || "",
      });
    }
  });
  if (failed.length) {
    console.warn("FCM send failures:", failed);
  }
  return result;
}

const _apnProviders = new Map();
function looksLikeBase64KeyBody(s) {
  return /^[A-Za-z0-9+/=\s]+$/.test(s) && s.replace(/\s+/g, "").length > 120;
}

function normalizeApnsKey(rawValue) {
  const raw = (rawValue || "").replace(/\\n/g, "\n").trim();
  if (!raw) return null;

  // If a filesystem path was intentionally provided.
  if ((raw.endsWith(".p8") || raw.startsWith("/")) && !raw.includes("BEGIN")) {
    return raw;
  }

  // Full PEM key.
  if (raw.includes("BEGIN PRIVATE KEY")) {
    return Buffer.from(raw, "utf8");
  }

  // Base64-only key body from secret manager; wrap as PEM.
  if (looksLikeBase64KeyBody(raw)) {
    const compact = raw.replace(/\s+/g, "");
    const lines = compact.match(/.{1,64}/g) || [compact];
    const pem = [
      "-----BEGIN PRIVATE KEY-----",
      ...lines,
      "-----END PRIVATE KEY-----",
      "",
    ].join("\n");
    return Buffer.from(pem, "utf8");
  }

  // Best effort: use raw bytes.
  return Buffer.from(raw, "utf8");
}

function getApnProvider({ production }) {
  const cacheKey = production ? "production" : "development";
  if (_apnProviders.has(cacheKey)) return _apnProviders.get(cacheKey);
  const apn = require("apn");
  const keyId = (APNS_KEY_ID.value() || "").trim();
  const teamId = (APNS_TEAM_ID.value() || "").trim();
  const key = normalizeApnsKey(APNS_VOIP_KEY_P8.value());
  if (!keyId || !teamId || !key) {
    throw new Error("APNS secrets missing");
  }
  const provider = new apn.Provider({
    token: { key, keyId, teamId },
    production,
  });
  _apnProviders.set(cacheKey, provider);
  return provider;
}

function apnsFailureReason(failure) {
  return (
    failure?.response?.reason ||
    failure?.error?.reason ||
    failure?.error?.message ||
    "unknown"
  );
}

function shouldRetryApnsInDevelopment(result) {
  const failed = Array.isArray(result?.failed) ? result.failed : [];
  const sent = Array.isArray(result?.sent) ? result.sent : [];
  if (!failed.length || sent.length > 0) return false;
  const retryReasons = new Set([
    "BadDeviceToken",
    "DeviceTokenNotForTopic",
    "Unregistered",
    "MissingTopic",
    "TopicDisallowed",
  ]);
  return failed.some((f) => retryReasons.has(apnsFailureReason(f)));
}

function logApnsFailures(label, result, environment) {
  const failed = Array.isArray(result?.failed) ? result.failed : [];
  if (!failed.length) return;
  const details = failed.map((f) => ({
    device: f?.device,
    reason: apnsFailureReason(f),
    status: f?.status ?? null,
  }));
  console.warn(`${label} failed tokens (${environment}):`, details);
}

async function sendApnsWithFallback(notification, tokens) {
  let environment = "production";
  let result = await getApnProvider({ production: true }).send(notification, tokens);
  if (shouldRetryApnsInDevelopment(result)) {
    environment = "development";
    result = await getApnProvider({ production: false }).send(notification, tokens);
  }
  return { result, environment };
}

async function sendVoipPushToTokens(tokens, data) {
  const deduped = Array.from(new Set(tokens.filter(Boolean)));
  if (!deduped.length) return { sent: 0, failed: 0, skipped: true };

  const bundleId = (APNS_BUNDLE_ID.value() || "").trim();
  if (!bundleId) {
    throw new Error("APNS_BUNDLE_ID missing");
  }

  const apn = require("apn");
  const notification = new apn.Notification();
  notification.topic = `${bundleId}.voip`;
  notification.pushType = "voip";
  notification.priority = 10;
  notification.expiry = Math.floor(Date.now() / 1000) + 45;
  notification.contentAvailable = 1;
  notification.payload = {
    type: "call_invite",
    ...data,
  };

  const { result, environment } = await sendApnsWithFallback(
    notification,
    deduped
  );
  logApnsFailures("APNS VoIP", result, environment);
  return {
    sent: result.sent?.length || 0,
    failed: result.failed?.length || 0,
    skipped: false,
    environment,
  };
}

async function sendApnsAlertToTokens(tokens, { title, body, data }) {
  const deduped = Array.from(new Set(tokens.filter(Boolean)));
  if (!deduped.length) return { sent: 0, failed: 0, skipped: true };

  const bundleId = (APNS_BUNDLE_ID.value() || "").trim();
  if (!bundleId) {
    throw new Error("APNS_BUNDLE_ID missing");
  }

  const apn = require("apn");
  const notification = new apn.Notification();
  notification.topic = bundleId;
  notification.pushType = "alert";
  notification.priority = 10;
  notification.expiry = Math.floor(Date.now() / 1000) + 60;
  notification.alert = {
    title: `${title || "Notification"}`,
    body: `${body || ""}`,
  };
  notification.sound = "default";
  notification.payload = {
    ...(data || {}),
  };

  const { result, environment } = await sendApnsWithFallback(
    notification,
    deduped
  );
  logApnsFailures("APNS alert", result, environment);
  return {
    sent: result.sent?.length || 0,
    failed: result.failed?.length || 0,
    skipped: false,
    environment,
  };
}

// --- Ensure Stripe Customer ---
async function getOrCreateCustomer(uid) {
  const ref = db.collection("users").doc(uid);
  const doc = await ref.get();
  if (!doc.exists) throw new HttpsError("not-found", "User not found");
  const data = doc.data() || {};
  const stripe = getStripeClient();
  const mode = getStripeMode();
  if (data.stripeCustomerId) {
    try {
      await stripe.customers.retrieve(data.stripeCustomerId);
      return data.stripeCustomerId;
    } catch (e) {
      if (e && e.code === "resource_missing") {
        // Customer exists in other mode; create a new one for this mode.
      } else {
        throw e;
      }
    }
  }

  const customer = await stripe.customers.create({
    email: data.email || undefined,
    name: data.fullName || data.name || undefined,
    metadata: { firebaseUID: uid },
  });

  await ref.update({ stripeCustomerId: customer.id, stripeCustomerMode: mode });
  return customer.id;
}

/* ============================================================
   🔔 REMINDERS & UTILITIES
   ============================================================ */

exports.scheduledConsultationReminder = onSchedule(
  { schedule: "every 5 minutes", region: "us-central1" },
  async () => {
    const now = admin.firestore.Timestamp.now();
    const later = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 5 * 60 * 1000)
    );

    const snap = await db
      .collection("consultations")
      .where("scheduledAt", ">=", now)
      .where("scheduledAt", "<=", later)
      .get();

    if (snap.empty) return console.log("No consultations soon.");

    const sends = [];
    for (const doc of snap.docs) {
      const data = doc.data();
      const participants = Array.isArray(data.participants)
        ? data.participants
        : [];
      const time = data.scheduledAt?.toDate?.()?.toLocaleTimeString?.() || "";
      for (const uid of participants) {
        const tokens = await getUserTokens(uid);
        if (!tokens.length) continue;
        sends.push(
          sendToTokens(tokens, {
            notification: {
              title: "Upcoming Consultation",
              body: `Starts at ${time}`,
            },
            data: { type: "consultation_reminder", id: doc.id },
          })
        );
      }
    }
    return Promise.all(sends);
  }
);

/* ============================================================
   💳 STRIPE CALLABLE FUNCTIONS
   ============================================================ */

// 1️⃣ Create Stripe Customer
exports.createStripeCustomer = onCall(
  { region: "us-central1", invoker: "public", secrets: [STRIPE_SECRET] },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated");
    const id = await getOrCreateCustomer(request.auth.uid);
    return { stripeCustomerId: id };
  }
);

// 2️⃣ Create Setup Intent
exports.createSetupIntent = onCall(
  { region: "us-central1", invoker: "public", secrets: [STRIPE_SECRET] },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated");
    const stripe = getStripeClient();
    const uid = request.auth.uid;
    const customerId = await getOrCreateCustomer(uid);
    const ephKey = await stripe.ephemeralKeys.create(
      { customer: customerId },
      { apiVersion: "2023-10-16" }
    );
    const si = await stripe.setupIntents.create({
      customer: customerId,
      payment_method_types: ["card"],
    });
    return {
      clientSecret: si.client_secret,
      customerId,
      ephemeralKeySecret: ephKey.secret,
    };
  }
);

// 3️⃣ List saved payment methods
exports.listPaymentMethods = onCall(
  { region: "us-central1", invoker: "public", secrets: [STRIPE_SECRET] },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated");
    const uid = request.auth.uid;

    const userDoc = await db.collection("users").doc(uid).get();
    const userData = userDoc.data() || {};
    const defaultPaymentMethodId = userData.defaultPaymentMethodId || null;

    const stripe = getStripeClient();
    const customerId = await getOrCreateCustomer(uid);
    const methods = await stripe.paymentMethods.list({
      customer: customerId,
      type: "card",
    });

    return {
      defaultPaymentMethodId,
      paymentMethods: methods.data.map((pm) => ({
        id: pm.id,
        brand: pm.card?.brand || null,
        last4: pm.card?.last4 || null,
        expMonth: pm.card?.exp_month || null,
        expYear: pm.card?.exp_year || null,
        funding: pm.card?.funding || null,
      })),
    };
  }
);

// 3️⃣ Set default payment method
exports.setDefaultPaymentMethod = onCall(
  { region: "us-central1", invoker: "public", secrets: [STRIPE_SECRET] },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated");
    const { paymentMethodId } = request.data || {};
    if (!paymentMethodId)
      throw new HttpsError("invalid-argument", "paymentMethodId required");

    const uid = request.auth.uid;
    const stripe = getStripeClient();
    const customerId = await getOrCreateCustomer(uid);

    await stripe.customers.update(customerId, {
      invoice_settings: { default_payment_method: paymentMethodId },
    });

    await db
      .collection("users")
      .doc(uid)
      .set({ defaultPaymentMethodId: paymentMethodId }, { merge: true });

    return { ok: true };
  }
);

// 4️⃣ Remove payment method
exports.removePaymentMethod = onCall(
  { region: "us-central1", invoker: "public", secrets: [STRIPE_SECRET] },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated");
    const { paymentMethodId } = request.data || {};
    if (!paymentMethodId)
      throw new HttpsError("invalid-argument", "paymentMethodId required");

    const uid = request.auth.uid;
    const stripe = getStripeClient();
    const customerId = await getOrCreateCustomer(uid);

    await stripe.paymentMethods.detach(paymentMethodId);

    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();
    const userData = userDoc.data() || {};
    if (userData.defaultPaymentMethodId === paymentMethodId) {
      await stripe.customers.update(customerId, {
        invoice_settings: { default_payment_method: null },
      });
      await userRef.set({ defaultPaymentMethodId: null }, { merge: true });
    }

    return { ok: true };
  }
);

// 5️⃣ Cancel consultation + refund
exports.cancelConsultation = onCall(
  { region: "us-central1", invoker: "public", secrets: [STRIPE_SECRET] },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated");
    const { consultationId } = request.data || {};
    if (!consultationId)
      throw new HttpsError("invalid-argument", "consultationId required");

    const uid = request.auth.uid;
    const ref = db.collection("consultations").doc(consultationId);
    const doc = await ref.get();
    if (!doc.exists) throw new HttpsError("not-found", "Consultation not found");

    const data = doc.data() || {};
    if (data.userId !== uid) throw new HttpsError("permission-denied");
    if (data.status === "cancelled") {
      return {
        ok: true,
        refundAmount: data.refundAmount || 0,
        refundPercent: data.refundPercent || 0,
      };
    }

    const scheduledAt = data.scheduledAt?.toDate?.() || null;
    const now = new Date();
    let refundPercent = 0;
    if (scheduledAt) {
      const diffMs = scheduledAt.getTime() - now.getTime();
      if (diffMs >= 24 * 60 * 60 * 1000) refundPercent = 100;
      else if (diffMs >= 60 * 60 * 1000) refundPercent = 50;
    }

    const cost = Number(data.cost || 0);
    const amountCents = Math.round(cost * 100);
    const refundCents = Math.round((amountCents * refundPercent) / 100);
    let refundId = null;

    const stripe = getStripeClient();
    if (refundCents > 0 && data.paymentIntentId) {
      const refund = await stripe.refunds.create({
        payment_intent: data.paymentIntentId,
        amount: refundCents,
      });
      refundId = refund.id;
    }

    await ref.set(
      {
        status: "cancelled",
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        refundAmount: refundCents / 100,
        refundPercent,
        refundId,
      },
      { merge: true }
    );

    return {
      ok: true,
      refundAmount: refundCents / 100,
      refundPercent,
      refundId,
    };
  }
);

// 6️⃣ Charge Stored Payment Method
exports.chargeStoredPaymentMethod = onCall(
  { region: "us-central1", invoker: "public", secrets: [STRIPE_SECRET] },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated");
    const stripe = getStripeClient();
    const uid = request.auth.uid;
    const { amount, currency = "cad" } = request.data || {};

    if (!amount || amount <= 0)
      throw new HttpsError("invalid-argument", "Invalid amount");

    const doc = await db.collection("users").doc(uid).get();
    const u = doc.data() || {};
    if (!u.stripeCustomerId || !u.defaultPaymentMethodId)
      throw new HttpsError("failed-precondition", "No stored payment method");

    try {
      const pi = await stripe.paymentIntents.create({
        amount: Math.round(amount * 100),
        currency,
        customer: u.stripeCustomerId,
        payment_method: u.defaultPaymentMethodId,
        off_session: true,
        confirm: true,
      });
      return { success: true, id: pi.id };
    } catch (e) {
      console.error("Charge error:", e);
      throw new HttpsError("internal", e.message);
    }
  }
);

// 4️⃣ Create Express Account for Helpers
exports.createExpressAccountLink = onCall(
  { region: "us-central1", invoker: "public", secrets: [STRIPE_SECRET] },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated");
    const stripe = getStripeClient();
    const uid = request.auth.uid;
    const ref = db.collection("users").doc(uid);
    const data = (await ref.get()).data() || {};

    let accountId = data.stripeAccountId;
    if (!accountId) {
      const acct = await stripe.accounts.create({
        type: "express",
        country: "CA",
        email: data.email,
        capabilities: { transfers: { requested: true } },
      });
      accountId = acct.id;
      await ref.update({ stripeAccountId: acct.id });
    }

    const link = await stripe.accountLinks.create({
      account: accountId,
      refresh_url: "https://yourapp.page.link/onboarding_refresh",
      return_url: "https://yourapp.page.link/onboarding_success",
      type: "account_onboarding",
    });
    return { url: link.url, stripeAccountId: accountId };
  }
);

// 5️⃣ Create Stripe Checkout Session
exports.createStripeCheckoutSession = onCall(
  { region: "us-central1", invoker: "public", secrets: [STRIPE_SECRET] },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated");
    const stripe = getStripeClient();
    const uid = request.auth.uid;
    const {
      consultationId,
      cost,
      helperStripeAccountId,
      currency = "cad",
      successUrl,
      cancelUrl,
    } = request.data || {};

    if (!consultationId || !cost || !helperStripeAccountId)
      throw new HttpsError("invalid-argument", "Missing required fields");

    const platformFee = Math.round(cost * 100 * 0.15);
    const customerId = await getOrCreateCustomer(uid);

    const session = await stripe.checkout.sessions.create({
      customer: customerId,
      payment_method_types: ["card"],
      line_items: [
        {
          price_data: {
            currency,
            product_data: { name: `Consultation (${consultationId})` },
            unit_amount: Math.round(cost * 100),
          },
          quantity: 1,
        },
      ],
      mode: "payment",
      success_url: successUrl || "https://yourapp.page.link/success",
      cancel_url: cancelUrl || "https://yourapp.page.link/cancel",
      payment_intent_data: {
        application_fee_amount: platformFee,
        transfer_data: { destination: helperStripeAccountId },
        metadata: { consultationId, uid },
      },
    });

    return { sessionId: session.id, checkoutUrl: session.url };
  }
);

// 6️⃣ Stripe Webhook
exports.handleStripeWebhook = onRequest(
  { region: "us-central1", secrets: [STRIPE_SECRET] },
  async (req, res) => {
    const stripe = getStripeClient();
    const sig = req.headers["stripe-signature"];
    const endpointSecret = process.env.STRIPE_WEBHOOK_SECRET;
    let event;
    try {
      event = stripe.webhooks.constructEvent(req.rawBody, sig, endpointSecret);
    } catch (e) {
      console.error("Webhook signature failed:", e.message);
      return res.status(400).send(`Webhook Error: ${e.message}`);
    }

    if (event.type === "payment_intent.succeeded") {
      const pi = event.data.object;
      const consultationId = pi.metadata?.consultationId;
      if (consultationId) {
        await db.collection("consultations").doc(consultationId).update({
          status: "paid",
          paidAt: admin.firestore.FieldValue.serverTimestamp(),
          paymentIntentId: pi.id,
        });
      }
    }
    res.json({ received: true });
  }
);

/* ============================================================
   🔔 FIRESTORE TRIGGERS
   ============================================================ */

exports.onCallInviteCreated = onDocumentCreated(
  {
    document: "callInvites/{inviteId}",
    region: "us-central1",
    secrets: [APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID, APNS_VOIP_KEY_P8],
  },
  async (event) => {
    const d = event.data?.data() || {};
    const { fromName, toUid, channel, isVideo } = d;
    const inviteId = event.params.inviteId || "";
    if (!toUid || !channel) return;
    let voipDelivered = false;
    let apnsAlertDelivered = false;
    const payloadData = {
      channel: `${channel}`,
      isVideo: `${Boolean(isVideo)}`,
      fromName: `${fromName || "Caller"}`,
      fromUid: `${d.fromUid || ""}`,
      toUid: `${toUid}`,
      callId: event.params.inviteId || `${channel}`,
    };
    const tokenSets = await getUserPushTokenSets(toUid);

    // Primary path for iOS incoming-call reliability
    try {
      const voipTokens = tokenSets.voip;
      if (voipTokens.length) {
        const voipRes = await sendVoipPushToTokens(voipTokens, payloadData);
        voipDelivered = (voipRes.sent || 0) > 0;
        console.log("APNS VoIP result:", {
          inviteId,
          toUid,
          channel,
          tokenSuffixes: tokenSuffixes(voipTokens),
          ...voipRes,
        });
      } else {
        console.log("APNS VoIP skipped: no tokens", { inviteId, toUid, channel });
      }
    } catch (e) {
      console.error("APNS VoIP send failed:", e);
    }

    // Only use regular APNs alert as a fallback when VoIP delivery is unavailable.
    // Sending both on iOS creates duplicate incoming-call notifications.
    try {
      const apnsTokens = tokenSets.apns;
      if (voipDelivered) {
        console.log("APNS alert skipped: voip already delivered", {
          inviteId,
          toUid,
          channel,
          tokenSuffixes: tokenSuffixes(tokenSets.apns),
        });
      } else if (apnsTokens.length) {
        const apnsRes = await sendApnsAlertToTokens(apnsTokens, {
          title: isVideo ? "Incoming Video Call" : "Incoming Audio Call",
          body: `From ${fromName || "Someone"}`,
          data: {
            type: "call_invite",
            ...payloadData,
          },
        });
        apnsAlertDelivered = (apnsRes.sent || 0) > 0;
        console.log("APNS alert result:", {
          inviteId,
          toUid,
          channel,
          tokenSuffixes: tokenSuffixes(apnsTokens),
          ...apnsRes,
        });
      } else {
        console.log("APNS alert skipped: no tokens", { inviteId, toUid, channel });
      }
    } catch (e) {
      console.error("APNS alert send failed:", e);
    }

    // Use FCM for Android by default, and as a full fallback when direct APNS fails.
    const tokens = (voipDelivered || apnsAlertDelivered)
      ? tokenSets.fcmForFallback
      : tokenSets.fcmAll;
    if (tokens.length) {
      await sendToTokens(tokens, {
        notification: {
          title: isVideo ? "Incoming Video Call" : "Incoming Audio Call",
          body: `From ${fromName || "Someone"}`,
        },
        android: {
          priority: "high",
          notification: {
            channelId: "high_importance_channel",
            sound: "default",
          },
        },
        apns: {
          headers: {
            "apns-priority": "10",
          },
          payload: {
            aps: {
              sound: "default",
              contentAvailable: true,
            },
          },
        },
        data: {
          type: "call_invite",
          ...payloadData,
        },
      });
    } else {
      console.log("FCM skipped: no tokens", { inviteId, toUid, channel });
    }
  }
);

exports.onChatMessageCreated = onDocumentCreated(
  {
    document: "chats/{chatId}/messages/{messageId}",
    region: "us-central1",
    secrets: [APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID, APNS_VOIP_KEY_P8],
  },
  async (event) => {
    const m = event.data?.data() || {};
    const chatId = event.params.chatId;
    const authorId = m.authorId;
    if (!chatId || !authorId) return;
    const chat = (await db.doc(`chats/${chatId}`).get()).data() || {};
    let users = [];
    if (Array.isArray(chat.users) && chat.users.length) users = chat.users;
    else if (Array.isArray(chat.participants) && chat.participants.length) users = chat.participants;
    else {
      const inferredOther = inferOtherUidFromChatId(chatId, authorId);
      if (inferredOther) {
        users = [authorId, inferredOther];
      } else if (chatId.includes("_")) {
        const parts = chatId.split("_").filter(Boolean);
        if (parts.length === 2) users = parts;
      }
    }
    users = Array.from(new Set((users || []).map((u) => `${u}`))).filter(Boolean);
    if (users.length < 2) {
      console.warn("onChatMessageCreated skip: could not infer participants", {
        chatId,
        authorId,
        usersCount: users.length,
      });
      return;
    }

    const recipients = users.filter((u) => u !== authorId);
    const parseMillis = (value) => {
      if (!value) return 0;
      if (typeof value === "number" && Number.isFinite(value)) return value;
      if (typeof value === "string") {
        const parsed = Date.parse(value);
        return Number.isFinite(parsed) ? parsed : 0;
      }
      if (value instanceof Date) return value.getTime();
      if (typeof value.toMillis === "function") {
        const ms = value.toMillis();
        return Number.isFinite(ms) ? ms : 0;
      }
      return 0;
    };
    // Prefer server-side event commit time to avoid client clock skew.
    const messageCreatedAtMs =
      parseMillis(event.time) ||
      parseMillis(event.data?.createTime) ||
      parseMillis(m.createdAt) ||
      Date.now();
    const sDoc = await db.collection("users").doc(authorId).get();
    const s = sDoc.data() || {};
    const fromName = s.displayName || s.fullName || s.name || "Someone";
    const body = m.text ? m.text.slice(0, 120) : "Sent you a message";
    const lastMessageType = `${m.type || (m.text ? "text" : "attachment")}`;
    let lastMessageText = "";
    if (typeof m.text === "string" && m.text.trim()) {
      lastMessageText = m.text.trim().slice(0, 120);
    } else if (lastMessageType === "image") {
      lastMessageText = "Photo";
    } else if (lastMessageType === "video") {
      lastMessageText = "Video";
    } else if (lastMessageType === "file") {
      lastMessageText = "File";
    } else if (lastMessageType === "missed_call") {
      lastMessageText = "Missed call";
    } else {
      lastMessageText = "Sent you a message";
    }

    // Keep sender unread at zero. Recipient unread is incremented per-message below.
    const chatRef = db.collection("chats").doc(chatId);
    await db.collection("chats").doc(chatId).set(
      {
        // Self-heal legacy chat docs and keep list metadata always fresh.
        users,
        participants: users,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
        lastMessageAuthorId: `${authorId}`,
        lastMessageType,
        lastMessageText,
        [`unreadBy.${authorId}`]: 0,
      },
      { merge: true }
    );

    // Keep a fast user-level unread counter for reliable badges in clients.
    await Promise.all(
      recipients.map(async (uid) => {
        try {
          const userRef = db.collection("users").doc(uid);
          const userSnap = await userRef.get();
          const userData = userSnap.data() || {};
          const lastSeen = userData.lastMessagesSeenAt;
          const lastSeenMs =
            lastSeen && typeof lastSeen.toMillis === "function"
              ? lastSeen.toMillis()
              : 0;
          // Skip stale increments if user has already opened messages
          // after this message was created.
          if (lastSeenMs > 0 && lastSeenMs - messageCreatedAtMs >= 1000) {
            console.log("onChatMessageCreated skip unread increment (already seen)", {
              chatId,
              uid,
              lastSeenMs,
              messageCreatedAtMs,
            });
            return;
          }
          await Promise.all([
            userRef.set(
              {
                unreadMessagesCount: admin.firestore.FieldValue.increment(1),
                lastIncomingMessageAt: admin.firestore.FieldValue.serverTimestamp(),
              },
              { merge: true }
            ),
            chatRef.set(
              {
                [`unreadBy.${uid}`]: admin.firestore.FieldValue.increment(1),
              },
              { merge: true }
            ),
          ]);
        } catch (e) {
          console.warn("onChatMessageCreated unread counter update failed", {
            chatId,
            uid,
            error: `${e}`,
          });
        }
      })
    );

    for (const uid of recipients) {
      const tokenSets = await getUserPushTokenSets(uid);
      const tokens = tokenSets.fcmAll;
      if (tokens.length) {
        await sendToTokens(tokens, {
          notification: { title: fromName, body },
          android: {
            priority: "high",
            notification: {
              channelId: "high_importance_channel",
              sound: "default",
            },
          },
          apns: {
            headers: {
              "apns-priority": "10",
            },
            payload: {
              aps: {
                sound: "default",
                contentAvailable: true,
              },
            },
          },
          data: {
            type: "chat_message",
            chatId,
            authorId: `${authorId}`,
            otherUserId: `${authorId}`,
          },
        });
        continue;
      }

      // Last-resort fallback if an iOS device somehow has APNS but no FCM token.
      try {
        const apnsTokens = tokenSets.apns;
        if (apnsTokens.length) {
          await sendApnsAlertToTokens(apnsTokens, {
            title: fromName,
            body,
            data: {
              type: "chat_message",
              chatId,
              authorId: `${authorId}`,
              otherUserId: `${authorId}`,
            },
          });
        }
      } catch (e) {
        console.error("APNS alert (chat) send failed:", e);
      }
    }
  }
);

exports.onAuthUserCreated = functionsV1.auth.user().onCreate(async (user) => {
  if (!user || !user.uid) return;

  const uid = `${user.uid}`;
  const email = `${user.email || ""}`.trim();
  const displayNameRaw = `${user.displayName || ""}`.trim();
  const resolvedName = displayNameRaw || fallbackNameFromEmail(email) || "User";

  await db.collection("users").doc(uid).set(
    {
      fullName: resolvedName,
      fullNameLower: resolvedName.toLowerCase(),
      displayName: resolvedName,
      displayName_lc: resolvedName.toLowerCase(),
      email,
      bio: "No bio available yet.",
      followers: [],
      following: [],
      postsCount: 0,
      profilePicture: "",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      xpPoints: 0,
      badges: [],
      postCount: 0,
      commentCount: 0,
      helpfulMarks: 0,
      dailyLoginStreak: 0,
      postingStreak: 0,
      lastLoginDate: null,
      lastPostDate: null,
      referralCount: 0,
      categoryPosts: {
        Career: 0,
        Travel: 0,
        Finance: 0,
        Technology: 0,
        Health: 0,
      },
      activePerks: {
        priorityPostBoost: null,
        profileHighlight: null,
        commentBoost: null,
      },
      premiumStatus: "none",
      trialUsed: false,
    },
    { merge: true }
  );
});

exports.healthCheck = onRequest(
  { region: "us-central1" },
  (_req, res) => res.status(200).send("OK")
);

/* ============================================================
   📞 AGORA CALL TOKEN
   ============================================================ */

exports.getAgoraRtcToken = onCall(
  {
    region: "us-central1",
    invoker: "public",
    secrets: [AGORA_APP_ID, AGORA_APP_CERTIFICATE],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }

    const appId = (AGORA_APP_ID.value() || "").trim();
    const appCertificate = (AGORA_APP_CERTIFICATE.value() || "").trim();
    if (!appId || !appCertificate) {
      throw new HttpsError("failed-precondition", "Agora secrets are missing");
    }
    if (!/^[0-9a-fA-F]{32}$/.test(appCertificate)) {
      throw new HttpsError(
        "failed-precondition",
        "AGORA_APP_CERTIFICATE is invalid. Expected 32-char hex certificate."
      );
    }

    const channelName = (request.data?.channelName || "").toString().trim();
    if (!channelName || channelName.length > 64 || !/^[A-Za-z0-9_]+$/.test(channelName)) {
      throw new HttpsError("invalid-argument", "Invalid channelName");
    }

    const rawUid = request.data?.uid;
    let uid = Number.isInteger(rawUid) ? rawUid : Number.parseInt(`${rawUid ?? 0}`, 10);
    if (!Number.isInteger(uid) || uid < 0 || uid > 0xffffffff) {
      throw new HttpsError("invalid-argument", "Invalid uid");
    }
    const requestedUid = uid;
    const allowUidZeroRequested = request.data?.allowUidZero === true;
    const allowUidZero = allowUidZeroRequested;
    if (uid === 0 && !allowUidZero) {
      uid = deriveRtcUidFromAuthUid(request.auth.uid);
    }

    const roleInput = `${request.data?.role || ""}`.toLowerCase();
    const role = roleInput === "subscriber"
      ? (RtcRole.SUBSCRIBER ?? RtcRole.Subscriber ?? 2)
      : (RtcRole.PUBLISHER ?? RtcRole.Publisher ?? 1);
    const expireSeconds = Math.min(
      Math.max(Number.parseInt(`${request.data?.expireSeconds ?? 3600}`, 10), 60),
      24 * 60 * 60
    );

    const now = Math.floor(Date.now() / 1000);
    const expireAt = now + expireSeconds;

    try {
      const token = RtcTokenBuilder.buildTokenWithUid(
        appId,
        appCertificate,
        channelName,
        uid,
        role,
        expireSeconds,
        expireSeconds
      );
      const tokenVersion = token.slice(0, 3);
      console.log("getAgoraRtcToken ok", {
        channelName,
        requestedUid,
        uid,
        allowUidZeroRequested,
        allowUidZero,
        expireAt,
        expireSeconds,
        tokenVersion,
        appIdSuffix: appId.slice(-6),
      });
      return {
        token,
        expireAt,
        appId,
        uid,
        requestedUid,
        allowUidZeroRequested,
        allowUidZero,
        tokenVersion,
      };
    } catch (e) {
      console.error("getAgoraRtcToken failed:", e);
      throw new HttpsError("internal", "Failed to build Agora token");
    }
  }
);
