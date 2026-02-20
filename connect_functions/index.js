// ============================================================
// 🔥 ConnectApp Firebase Functions (Stripe + Notifications)
// ============================================================

const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const { RtcTokenBuilder, RtcRole } = require("agora-access-token");
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

// --- Get User Tokens ---
async function getUserTokens(uid) {
  const snap = await db.collection("users").doc(uid).get();
  if (!snap.exists) return [];
  const data = snap.data() || {};
  const arr = Array.isArray(data.fcmTokens) ? data.fcmTokens : [];
  const single = data.fcmToken ? [data.fcmToken] : [];
  return Array.from(new Set([...arr, ...single].filter(Boolean)));
}

async function getUserVoipTokens(uid) {
  const snap = await db.collection("users").doc(uid).get();
  if (!snap.exists) return [];
  const data = snap.data() || {};
  const arr = Array.isArray(data.voipTokens) ? data.voipTokens : [];
  const single = data.voipToken ? [data.voipToken] : [];
  return Array.from(new Set([...arr, ...single].filter(Boolean)));
}

// --- Send Notification ---
async function sendToTokens(tokens, payload) {
  const deduped = Array.from(new Set(tokens.filter(Boolean)));
  if (!deduped.length) return;
  return fcm.sendEachForMulticast({ tokens: deduped, ...payload });
}

let _apnProvider = null;
function getApnProvider() {
  if (_apnProvider) return _apnProvider;
  const apn = require("apn");
  const keyId = (APNS_KEY_ID.value() || "").trim();
  const teamId = (APNS_TEAM_ID.value() || "").trim();
  const key = (APNS_VOIP_KEY_P8.value() || "").replace(/\\n/g, "\n").trim();
  if (!keyId || !teamId || !key) {
    throw new Error("APNS secrets missing");
  }
  _apnProvider = new apn.Provider({
    token: { key, keyId, teamId },
    production: true,
  });
  return _apnProvider;
}

async function sendVoipPushToTokens(tokens, data) {
  const deduped = Array.from(new Set(tokens.filter(Boolean)));
  if (!deduped.length) return { sent: 0, failed: 0, skipped: true };

  const bundleId = (APNS_BUNDLE_ID.value() || "").trim();
  if (!bundleId) {
    throw new Error("APNS_BUNDLE_ID missing");
  }

  const apn = require("apn");
  const provider = getApnProvider();
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

  const result = await provider.send(notification, deduped);
  if (result.failed?.length) {
    console.warn("APNS VoIP failed tokens:", result.failed.map((f) => f.device));
  }
  return {
    sent: result.sent?.length || 0,
    failed: result.failed?.length || 0,
    skipped: false,
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
    if (!toUid || !channel) return;
    const payloadData = {
      channel: `${channel}`,
      isVideo: `${Boolean(isVideo)}`,
      fromName: `${fromName || "Caller"}`,
      fromUid: `${d.fromUid || ""}`,
      toUid: `${toUid}`,
      callId: event.params.inviteId || `${channel}`,
    };

    // Primary path for iOS incoming-call reliability
    try {
      const voipTokens = await getUserVoipTokens(toUid);
      if (voipTokens.length) {
        const voipRes = await sendVoipPushToTokens(voipTokens, payloadData);
        console.log("APNS VoIP result:", voipRes);
      }
    } catch (e) {
      console.error("APNS VoIP send failed:", e);
    }

    // Fallback path for regular notifications (Android/iOS)
    const tokens = await getUserTokens(toUid);
    if (tokens.length) {
      await sendToTokens(tokens, {
        notification: {
          title: isVideo ? "Incoming Video Call" : "Incoming Audio Call",
          body: `From ${fromName || "Someone"}`,
        },
        data: {
          type: "call_invite",
          ...payloadData,
        },
      });
    }
  }
);

exports.onChatMessageCreated = onDocumentCreated(
  { document: "chats/{chatId}/messages/{messageId}", region: "us-central1" },
  async (event) => {
    const m = event.data?.data() || {};
    const chatId = event.params.chatId;
    const authorId = m.authorId;
    if (!chatId || !authorId) return;
    const chat = (await db.doc(`chats/${chatId}`).get()).data() || {};
    const users = chat.users || chat.participants || [];
    const recipients = users.filter((u) => u !== authorId);
    const sDoc = await db.collection("users").doc(authorId).get();
    const s = sDoc.data() || {};
    const fromName = s.fullName || s.name || "Someone";
    const body = m.text ? m.text.slice(0, 120) : "Sent you a message";

    for (const uid of recipients) {
      const tokens = await getUserTokens(uid);
      if (!tokens.length) continue;
      await sendToTokens(tokens, {
        notification: { title: fromName, body },
        data: {
          type: "chat_message",
          chatId,
          authorId: `${authorId}`,
          otherUserId: `${authorId}`,
        },
      });
    }
  }
);

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

    const channelName = (request.data?.channelName || "").toString().trim();
    if (!channelName || channelName.length > 64 || !/^[A-Za-z0-9_]+$/.test(channelName)) {
      throw new HttpsError("invalid-argument", "Invalid channelName");
    }

    const rawUid = request.data?.uid;
    const uid = Number.isInteger(rawUid) ? rawUid : Number.parseInt(`${rawUid ?? 0}`, 10);
    if (!Number.isInteger(uid) || uid < 0) {
      throw new HttpsError("invalid-argument", "Invalid uid");
    }

    const role = request.data?.role === "subscriber" ? RtcRole.SUBSCRIBER : RtcRole.PUBLISHER;
    const expireSeconds = Math.min(
      Math.max(Number.parseInt(`${request.data?.expireSeconds ?? 3600}`, 10), 60),
      24 * 60 * 60
    );

    const now = Math.floor(Date.now() / 1000);
    const privilegeExpireTs = now + expireSeconds;

    try {
      const token = RtcTokenBuilder.buildTokenWithUid(
        appId,
        appCertificate,
        channelName,
        uid,
        role,
        privilegeExpireTs
      );
      return { token, expireAt: privilegeExpireTs };
    } catch (e) {
      console.error("getAgoraRtcToken failed:", e);
      throw new HttpsError("internal", "Failed to build Agora token");
    }
  }
);
