// functions/index.js

// V2 entrypoints
const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");

const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();
const fcm = admin.messaging();

/** Helpers */

// Stripe client
function getStripeClient() {
  const secret =
    process.env.STRIPE_SECRET ||
    (require("firebase-functions").config().stripe &&
      require("firebase-functions").config().stripe.secret);
  if (!secret) {
    console.error("Stripe secret missing in env or functions config");
    throw new Error("Stripe secret is not configured");
  }
  return require("stripe")(secret);
}

// Read tokens from users doc: supports fcmTokens[] and legacy fcmToken
async function getUserTokens(uid) {
  const snap = await db.collection("users").doc(uid).get();
  if (!snap.exists) return [];
  const data = snap.data() || {};
  const arr = Array.isArray(data.fcmTokens) ? data.fcmTokens : [];
  const single = data.fcmToken ? [data.fcmToken] : [];
  return Array.from(new Set([...arr, ...single].filter(Boolean)));
}

async function sendToTokens(tokens, payload) {
  const deduped = Array.from(new Set((tokens || []).filter(Boolean)));
  if (deduped.length === 0) return;
  await fcm.sendEachForMulticast({ tokens: deduped, ...payload });
}

/** 1) Add default fields to users (HTTP) */
exports.addDefaultFieldsToUsers = onRequest(
  { cpu: 1, memory: "256Mi" },
  async (_req, res) => {
    try {
      const snapshot = await db.collection("users").get();
      const batch = db.batch();
      snapshot.forEach((doc) => {
        const data = doc.data() || {};
        batch.set(
          doc.ref,
          {
            bio: data.bio || "No bio available yet.",
            name: data.name || "",
            lastName: data.lastName || "",
            profilePicture: data.profilePicture || "",
            userName: data.userName || "",
            postsCount: data.postsCount || 0,
            followers: data.followers || [],
            following: data.following || [],
          },
          { merge: true }
        );
      });
      await batch.commit();
      res.status(200).send("All users updated successfully with default fields.");
    } catch (err) {
      console.error("Error updating users:", err);
      res.status(500).send("Error updating users.");
    }
  }
);

/** 2) Scheduled consultation reminder (every 5 minutes) */
exports.scheduledConsultationReminder = onSchedule(
  { cpu: 1, memory: "512Mi", schedule: "every 5 minutes" },
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

    if (snap.empty) {
      console.log("No consultations within next 5 minutes.");
      return null;
    }

    const sends = [];
    for (const doc of snap.docs) {
      const data = doc.data() || {};
      const participants = Array.isArray(data.participants) ? data.participants : [];
      const startTime = data.scheduledAt?.toDate?.().toLocaleTimeString?.() || "";

      for (const uid of participants) {
        const tokens = await getUserTokens(uid);
        if (tokens.length === 0) continue;

        sends.push(
          sendToTokens(tokens, {
            notification: {
              title: "Upcoming Consultation",
              body: `Your consultation starts at ${startTime}.`,
            },
            data: { type: "consultation_reminder", consultationId: doc.id },
            android: { priority: "high" },
            apns: {
              headers: { "apns-priority": "10" },
              payload: { aps: { sound: "default" } },
            },
          })
        );
      }
    }
    return Promise.all(sends);
  }
);

/** 3) Stripe: create checkout session (onCall) */
exports.createStripeCheckoutSession = onCall(
  { cpu: 1, invoker: ["public"] },
  async (data, _context) => {
    const stripe = getStripeClient();
    const { consultationId, cost, currency, successUrl, cancelUrl } = data;
    if (!consultationId || cost == null) {
      throw new HttpsError("invalid-argument", "Missing consultationId or cost");
    }
    try {
      const session = await stripe.checkout.sessions.create({
        payment_method_types: ["card"],
        line_items: [
          {
            price_data: {
              currency: currency || "usd",
              product_data: { name: `Consultation Booking (${consultationId})` },
              unit_amount: Math.round(cost * 100),
            },
            quantity: 1,
          },
        ],
        mode: "payment",
        success_url: successUrl,
        cancel_url: cancelUrl,
        metadata: { consultationId },
      });
      return { sessionId: session.id, checkoutUrl: session.url };
    } catch (err) {
      console.error("Error creating Stripe session:", err);
      throw new HttpsError("internal", "Unable to create checkout session");
    }
  }
);

/** 4) Stripe: create customer (onCall) */
exports.createStripeCustomer = onCall(
  { cpu: 1, invoker: ["public"] },
  async (_data, context) => {
    if (!context.auth) throw new HttpsError("unauthenticated", "Not authenticated.");
    const stripe = getStripeClient();
    const uid = context.auth.uid;

    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();
    if (!userDoc.exists) throw new HttpsError("not-found", "User not found.");
    const userData = userDoc.data() || {};

    if (userData.stripeCustomerId) {
      return { stripeCustomerId: userData.stripeCustomerId };
    }

    try {
      const customer = await stripe.customers.create({
        email: userData.email,
        name: userData.name,
      });
      await userRef.update({ stripeCustomerId: customer.id });
      return { stripeCustomerId: customer.id };
    } catch (err) {
      console.error("Error creating Stripe customer:", err);
      throw new HttpsError("internal", "Unable to create Stripe customer");
    }
  }
);

/** 5) Stripe: setup intent (onCall) */
exports.createSetupIntent = onCall(
  { cpu: 1, invoker: ["public"] },
  async (_data, context) => {
    if (!context.auth) throw new HttpsError("unauthenticated", "Not authenticated.");
    const stripe = getStripeClient();
    const uid = context.auth.uid;

    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();
    if (!userDoc.exists) throw new HttpsError("not-found", "User not found.");
    const userData = userDoc.data() || {};
    if (!userData.stripeCustomerId) {
      throw new HttpsError("failed-precondition", "No Stripe customer.");
    }

    try {
      const si = await stripe.setupIntents.create({
        customer: userData.stripeCustomerId,
        payment_method_types: ["card"],
      });
      return { clientSecret: si.client_secret };
    } catch (err) {
      console.error("Error creating setup intent:", err);
      throw new HttpsError("internal", "Unable to create setup intent");
    }
  }
);

/** 6) Stripe: charge stored payment method (onCall) */
exports.chargeStoredPaymentMethod = onCall(
  { cpu: 1, invoker: ["public"] },
  async (data, context) => {
    if (!context.auth) throw new HttpsError("unauthenticated", "Not authenticated.");
    const stripe = getStripeClient();
    const { userId, amount, currency } = data;
    if (!userId || amount == null) {
      throw new HttpsError("invalid-argument", "Missing userId or amount");
    }

    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) throw new HttpsError("not-found", "User not found");
    const { stripeCustomerId, defaultPaymentMethodId } = userDoc.data() || {};
    if (!stripeCustomerId || !defaultPaymentMethodId) {
      throw new HttpsError("failed-precondition", "No stored payment method");
    }

    try {
      const pi = await stripe.paymentIntents.create({
        amount: Math.round(amount * 100),
        currency: currency || "usd",
        customer: stripeCustomerId,
        payment_method: defaultPaymentMethodId,
        off_session: true,
        confirm: true,
      });
      return { success: true, paymentIntentId: pi.id };
    } catch (err) {
      console.error("Error charging payment method:", err);
      return { success: false, error: err.message };
    }
  }
);

/** 7) Health check (HTTP) */
exports.healthCheck = onRequest({ cpu: 1, memory: "128Mi" }, (_req, res) => {
  res.status(200).send("OK");
});

/** 8) PUSH: when a new call invite is created -> notify callee
 *  Collection: callInvites
 */
exports.onCallInviteCreated = onDocumentCreated("callInvites/{inviteId}", async (event) => {
  const invite = event.data?.data() || {};
  const { fromUid, fromName, toUid, channel, isVideo } = invite;

  if (!toUid || !channel) return;

  const tokens = await getUserTokens(toUid);
  if (tokens.length === 0) return;

  const payload = {
    notification: {
      title: isVideo ? "Incoming Video Call" : "Incoming Audio Call",
      body: `From ${fromName || "Someone"}`,
    },
    data: {
      action: "incoming_call",     // <-- matches app handler
      channel: String(channel),
      isVideo: String(!!isVideo),
      fromName: String(fromName || "Caller"),
    },
    android: { priority: "high", notification: { sound: "default" } },
    apns: {
      headers: { "apns-priority": "10" },
      payload: { aps: { sound: "default", contentAvailable: 1 } },
    },
  };

  await sendToTokens(tokens, payload);
});

/** 9) PUSH: chat message -> notify other participant(s) */
exports.onChatMessageCreated = onDocumentCreated("chats/{chatId}/messages/{messageId}", async (event) => {
  const message = event.data?.data() || {};
  const chatId = event.params.chatId;
  const { authorId, text } = message;

  const chatDoc = await db.collection("chats").doc(chatId).get();
  const participants = chatDoc.get("participants") || [];
  const targets = participants.filter((uid) => uid !== authorId);

  let allTokens = [];
  for (const uid of targets) {
    const tokens = await getUserTokens(uid);
    allTokens = allTokens.concat(tokens);
  }
  allTokens = Array.from(new Set(allTokens.filter(Boolean)));
  if (allTokens.length === 0) return;

  const payload = {
    notification: {
      title: "New Message",
      body: text ? String(text).slice(0, 140) : "You have a new message",
    },
    data: {
      type: "chat_message",
      chatId: String(chatId || ""),
    },
    android: { priority: "high", notification: { sound: "default" } },
    apns: {
      headers: { "apns-priority": "10" },
      payload: { aps: { sound: "default" } },
    },
  };

  await sendToTokens(allTokens, payload);
});
