// connect_app/connect_functions/index.js

// v2 HTTPS entrypoints + Scheduler
const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule }               = require("firebase-functions/v2/scheduler");

const admin = require("firebase-admin");
admin.initializeApp();

// Helper to get Stripe client inside handlers
function getStripeClient() {
  const secret = process.env.STRIPE_SECRET || require("firebase-functions").config().stripe.secret;
  if (!secret) {
    console.error("Stripe secret missing in environment or functions config");
    throw new Error("Stripe secret is not configured");
  }
  return require("stripe")(secret);
}

// ────────────────────────────────────────────
// 1) Add Default Fields to Users (HTTPS trigger)
// ────────────────────────────────────────────
exports.addDefaultFieldsToUsers = onRequest(
  { cpu: 1, memory: "256Mi" },
  async (req, res) => {
    const usersRef = admin.firestore().collection("users");
    try {
      const snapshot = await usersRef.get();
      const batch = admin.firestore().batch();

      snapshot.forEach(doc => {
        const data = doc.data();
        batch.update(doc.ref, {
          bio:            data.bio            || "No bio available yet.",
          name:           data.name           || "",
          lastName:       data.lastName       || "",
          profilePicture: data.profilePicture || "",
          userName:       data.userName       || "",
          postsCount:     data.postsCount     || 0,
          followers:      data.followers      || [],
          following:      data.following      || []
        });
      });

      await batch.commit();
      res.status(200).send("All users updated successfully with default fields.");
    } catch (error) {
      console.error("Error updating users:", error);
      res.status(500).send("Error updating users.");
    }
  }
);

// ────────────────────────────────────────────
// 2) Scheduled Consultation Reminder
// ────────────────────────────────────────────
exports.scheduledConsultationReminder = onSchedule(
  { cpu: 1, memory: "512Mi", schedule: "every 5 minutes" },
  async (ctx) => {
    const now   = admin.firestore.Timestamp.now();
    const later = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 5 * 60 * 1000)
    );

    const snap = await admin.firestore()
      .collection("consultations")
      .where("scheduledAt", ">=", now)
      .where("scheduledAt", "<=", later)
      .get();

    if (snap.empty) {
      console.log("No consultations starting within the next 5 minutes.");
      return null;
    }

    const sendPromises = [];
    snap.forEach(doc => {
      const { participants = [], scheduledAt } = doc.data();
      const startTime = scheduledAt.toDate().toLocaleTimeString();

      participants.forEach(async uid => {
        const userDoc = await admin.firestore().collection("users").doc(uid).get();
        if (!userDoc.exists) return;
        const token = userDoc.data().fcmToken;
        if (!token) return;

        sendPromises.push(
          admin.messaging().send({
            token,
            notification: {
              title: "Upcoming Consultation",
              body:  `Your consultation starts at ${startTime}.`
            },
            data: { consultationId: doc.id }
          })
        );
      });
    });

    return Promise.all(sendPromises);
  }
);

// ────────────────────────────────────────────
// 3) Create Stripe Checkout Session (onCall)
// ────────────────────────────────────────────
exports.createStripeCheckoutSession = onCall(
  { cpu: 1 },
  async (data, context) => {
    const stripe = getStripeClient();
    const { consultationId, cost, currency, successUrl, cancelUrl } = data;
    if (!consultationId || cost == null) {
      throw new HttpsError("invalid-argument", "Missing consultationId or cost");
    }
    try {
      const session = await stripe.checkout.sessions.create({
        payment_method_types: ["card"],
        line_items: [{
          price_data: {
            currency:     currency || "usd",
            product_data: { name: `Consultation Booking (${consultationId})` },
            unit_amount:  Math.round(cost * 100),
          },
          quantity: 1
        }],
        mode:        "payment",
        success_url: successUrl,
        cancel_url:  cancelUrl,
        metadata:    { consultationId }
      });
      return { sessionId: session.id, checkoutUrl: session.url };
    } catch (error) {
      console.error("Error creating Stripe session:", error);
      throw new HttpsError("internal", "Unable to create checkout session");
    }
  }
);

// ────────────────────────────────────────────
// 4) Create Stripe Customer (onCall)
// ────────────────────────────────────────────
exports.createStripeCustomer = onCall(
  { cpu: 1 },
  async (data, context) => {
    const stripe = getStripeClient();
    if (!context.auth) {
      throw new HttpsError("unauthenticated", "Not authenticated.");
    }
    const uid     = context.auth.uid;
    const userRef = admin.firestore().collection("users").doc(uid);
    const userDoc = await userRef.get();
    if (!userDoc.exists) {
      throw new HttpsError("not-found", "User not found.");
    }
    const userData = userDoc.data() || {};
    if (userData.stripeCustomerId) {
      return { stripeCustomerId: userData.stripeCustomerId };
    }
    try {
      const customer = await stripe.customers.create({
        email: userData.email,
        name:  userData.name
      });
      await userRef.update({ stripeCustomerId: customer.id });
      return { stripeCustomerId: customer.id };
    } catch (error) {
      console.error("Error creating Stripe customer:", error);
      throw new HttpsError("internal", "Unable to create Stripe customer");
    }
  }
);

// ────────────────────────────────────────────
// 5) Create SetupIntent (onCall)
// ────────────────────────────────────────────
exports.createSetupIntent = onCall(
  { cpu: 1 },
  async (data, context) => {
    const stripe = getStripeClient();
    if (!context.auth) {
      throw new HttpsError("unauthenticated", "Not authenticated.");
    }
    const uid     = context.auth.uid;
    const userRef = admin.firestore().collection("users").doc(uid);
    const userDoc = await userRef.get();
    if (!userDoc.exists) {
      throw new HttpsError("not-found", "User not found.");
    }
    const userData = userDoc.data() || {};
    if (!userData.stripeCustomerId) {
      throw new HttpsError("failed-precondition", "No Stripe customer.");
    }
    try {
      const si = await stripe.setupIntents.create({
        customer:             userData.stripeCustomerId,
        payment_method_types: ["card"]
      });
      return { clientSecret: si.client_secret };
    } catch (error) {
      console.error("Error creating setup intent:", error);
      throw new HttpsError("internal", "Unable to create setup intent");
    }
  }
);

// ────────────────────────────────────────────
// 6) Charge Stored Payment Method (onCall)
// ────────────────────────────────────────────
exports.chargeStoredPaymentMethod = onCall(
  { cpu: 1 },
  async (data, context) => {
    const stripe = getStripeClient();
    if (!context.auth) {
      throw new HttpsError("unauthenticated", "Not authenticated.");
    }
    const { userId, amount, currency } = data;
    if (!userId || amount == null) {
      throw new HttpsError("invalid-argument", "Missing userId or amount");
    }
    const userDoc = await admin.firestore().collection("users").doc(userId).get();
    if (!userDoc.exists) {
      throw new HttpsError("not-found", "User not found");
    }
    const { stripeCustomerId, defaultPaymentMethodId } = userDoc.data() || {};
    if (!stripeCustomerId || !defaultPaymentMethodId) {
      throw new HttpsError("failed-precondition", "No stored payment method");
    }
    try {
      const pi = await stripe.paymentIntents.create({
        amount:       Math.round(amount * 100),
        currency:     currency || "usd",
        customer:     stripeCustomerId,
        payment_method: defaultPaymentMethodId,
        off_session:  true,
        confirm:      true
      });
      return { success: true, paymentIntentId: pi.id };
    } catch (error) {
      console.error("Error charging payment method:", error);
      return { success: false, error: error.message };
    }
  }
);

// ────────────────────────────────────────────
// 7) Health Check (HTTPS trigger)
// ────────────────────────────────────────────
exports.healthCheck = onRequest(
  { cpu: 1 },
  (req, res) => {
    res.status(200).send("OK");
  }
);
