// ============================================================
// 🔥 ConnectApp Firebase Functions (Stripe + Notifications)
// ============================================================

const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const functions = require("firebase-functions"); // legacy compat
const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();
const fcm = admin.messaging();

// --- Stripe Client Helper ---
function getStripeClient() {
  const secret =
    process.env.STRIPE_SECRET ||
    (functions.config().stripe && functions.config().stripe.secret);
  if (!secret) throw new Error("Stripe secret missing");
  return require("stripe")(secret);
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

// --- Send Notification ---
async function sendToTokens(tokens, payload) {
  const deduped = Array.from(new Set(tokens.filter(Boolean)));
  if (!deduped.length) return;
  return fcm.sendEachForMulticast({ tokens: deduped, ...payload });
}

// --- Ensure Stripe Customer ---
async function getOrCreateCustomer(uid) {
  const ref = db.collection("users").doc(uid);
  const doc = await ref.get();
  if (!doc.exists) throw new HttpsError("not-found", "User not found");
  const data = doc.data() || {};
  if (data.stripeCustomerId) return data.stripeCustomerId;

  const stripe = getStripeClient();
  const customer = await stripe.customers.create({
    email: data.email || undefined,
    name: data.fullName || data.name || undefined,
    metadata: { firebaseUID: uid },
  });

  await ref.update({ stripeCustomerId: customer.id });
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
  { region: "us-central1" },
  async (_data, context) => {
    if (!context.auth) throw new HttpsError("unauthenticated");
    const id = await getOrCreateCustomer(context.auth.uid);
    return { stripeCustomerId: id };
  }
);

// 2️⃣ Create Setup Intent
exports.createSetupIntent = onCall(
  { region: "us-central1" },
  async (_data, context) => {
    if (!context.auth) throw new HttpsError("unauthenticated");
    const stripe = getStripeClient();
    const uid = context.auth.uid;
    const customerId = await getOrCreateCustomer(uid);
    const si = await stripe.setupIntents.create({
      customer: customerId,
      payment_method_types: ["card"],
    });
    return { clientSecret: si.client_secret };
  }
);

// 3️⃣ Charge Stored Payment Method
exports.chargeStoredPaymentMethod = onCall(
  { region: "us-central1" },
  async (data, context) => {
    if (!context.auth) throw new HttpsError("unauthenticated");
    const stripe = getStripeClient();
    const uid = context.auth.uid;
    const { amount, currency = "cad" } = data;

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
  { region: "us-central1" },
  async (_data, context) => {
    if (!context.auth) throw new HttpsError("unauthenticated");
    const stripe = getStripeClient();
    const uid = context.auth.uid;
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
  { region: "us-central1" },
  async (data, context) => {
    if (!context.auth) throw new HttpsError("unauthenticated");
    const stripe = getStripeClient();
    const uid = context.auth.uid;
    const {
      consultationId,
      cost,
      helperStripeAccountId,
      currency = "cad",
      successUrl,
      cancelUrl,
    } = data;

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
  { region: "us-central1" },
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
  { document: "callInvites/{inviteId}", region: "us-central1" },
  async (event) => {
    const d = event.data?.data() || {};
    const { fromName, toUid, channel, isVideo } = d;
    if (!toUid || !channel) return;
    const tokens = await getUserTokens(toUid);
    if (!tokens.length) return;
    await sendToTokens(tokens, {
      notification: {
        title: isVideo ? "Incoming Video Call" : "Incoming Audio Call",
        body: `From ${fromName || "Someone"}`,
      },
      data: { type: "call_invite", channel },
    });
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
        data: { type: "chat_message", chatId },
      });
    }
  }
);

exports.healthCheck = onRequest(
  { region: "us-central1" },
  (_req, res) => res.status(200).send("OK")
);
