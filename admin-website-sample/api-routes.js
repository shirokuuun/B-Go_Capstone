// API Routes for PayMongo Integration
// This file contains the backend API routes for the admin website

const express = require("express");
const router = express.Router();
const admin = require("firebase-admin");
const { initializeApp } = require("firebase/app");
const { getFirestore } = require("firebase/firestore");

// Initialize Firebase Admin (for server-side operations)
const serviceAccount = require("./path/to/serviceAccountKey.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// PayMongo configuration
const PAYMONGO_SECRET_KEY = process.env.PAYMONGO_SECRET_KEY;
const PAYMONGO_WEBHOOK_SECRET = process.env.PAYMONGO_WEBHOOK_SECRET;

// GET /api/payment-status/:bookingId
router.get("/payment-status/:bookingId", async (req, res) => {
  try {
    const { bookingId } = req.params;

    // Get booking from Firestore
    const bookingRef = db
      .collection("users")
      .doc(req.query.userId)
      .collection("preBookings")
      .doc(bookingId);
    const bookingDoc = await bookingRef.get();

    if (!bookingDoc.exists) {
      return res.status(404).json({ error: "Booking not found" });
    }

    const bookingData = bookingDoc.data();

    res.json({
      status: bookingData.status || "pending_payment",
      paymongoPaymentId: bookingData.paymongoPaymentId || null,
      amount: bookingData.amount || 0,
      paidAt: bookingData.paidAt || null,
      error: bookingData.paymentError || null,
    });
  } catch (error) {
    console.error("Error getting payment status:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

// POST /api/create-payment-intent
router.post("/create-payment-intent", async (req, res) => {
  try {
    const { amount, currency, metadata } = req.body;

    // Create payment intent with PayMongo
    const paymentIntentResponse = await fetch(
      "https://api.paymongo.com/v1/payment_intents",
      {
        method: "POST",
        headers: {
          Authorization: `Basic ${Buffer.from(
            PAYMONGO_SECRET_KEY + ":"
          ).toString("base64")}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          data: {
            attributes: {
              amount: amount,
              currency: currency,
              metadata: metadata,
            },
          },
        }),
      }
    );

    const paymentIntentData = await paymentIntentResponse.json();

    if (!paymentIntentResponse.ok) {
      throw new Error(
        paymentIntentData.errors?.[0]?.detail ||
          "Failed to create payment intent"
      );
    }

    const paymentIntent = paymentIntentData.data;

    // Update booking with payment intent ID
    if (metadata.bookingId) {
      const bookingRef = db
        .collection("users")
        .doc(metadata.userId)
        .collection("preBookings")
        .doc(metadata.bookingId);
      await bookingRef.update({
        paymongoPaymentIntentId: paymentIntent.id,
        paymongoClientKey: paymentIntent.attributes.client_key,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    res.json({
      clientKey: paymentIntent.attributes.client_key,
      paymentIntentId: paymentIntent.id,
      checkoutUrl: paymentIntent.attributes.next_action?.redirect?.url,
    });
  } catch (error) {
    console.error("Error creating payment intent:", error);
    res
      .status(500)
      .json({ error: error.message || "Failed to create payment intent" });
  }
});

// POST /api/update-payment-status
router.post("/update-payment-status", async (req, res) => {
  try {
    const { bookingId, status, paymongoPaymentId, userId } = req.body;

    const updateData = {
      status: status,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (paymongoPaymentId) {
      updateData.paymongoPaymentId = paymongoPaymentId;
    }

    if (status === "paid") {
      updateData.paidAt = admin.firestore.FieldValue.serverTimestamp();
      updateData.boardingStatus = "pending";
    }

    // Update booking in Firestore
    const bookingRef = db
      .collection("users")
      .doc(userId)
      .collection("preBookings")
      .doc(bookingId);
    await bookingRef.update(updateData);

    // Send notification to user
    await db
      .collection("users")
      .doc(userId)
      .collection("notifications")
      .add({
        type: "payment_update",
        bookingId: bookingId,
        status: status,
        message:
          status === "paid"
            ? "Payment successful! Your booking is confirmed."
            : "Payment failed. Please try again.",
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    res.json({ success: true });
  } catch (error) {
    console.error("Error updating payment status:", error);
    res.status(500).json({ error: "Failed to update payment status" });
  }
});

// POST /api/register-webhook
router.post("/register-webhook", async (req, res) => {
  try {
    const { bookingId, userId, webhookUrl } = req.body;

    // Register webhook with PayMongo (if needed)
    // This is typically done once during setup, not per booking

    res.json({ success: true, message: "Webhook registered successfully" });
  } catch (error) {
    console.error("Error registering webhook:", error);
    res.status(500).json({ error: "Failed to register webhook" });
  }
});

// POST /api/payment-webhook (PayMongo webhook endpoint)
router.post("/payment-webhook", async (req, res) => {
  try {
    const signature = req.headers["paymongo-signature"];
    const payload = JSON.stringify(req.body);

    // Verify webhook signature
    if (!verifyWebhookSignature(payload, signature, PAYMONGO_WEBHOOK_SECRET)) {
      console.error("Invalid webhook signature");
      return res.status(400).json({ error: "Invalid signature" });
    }

    const event = req.body;
    console.log("Received webhook event:", event.type);

    // Handle different event types
    switch (event.type) {
      case "payment.paid":
        await handlePaymentPaid(event.data);
        break;
      case "payment.failed":
        await handlePaymentFailed(event.data);
        break;
      default:
        console.log("Unhandled event type:", event.type);
    }

    res.json({ received: true });
  } catch (error) {
    console.error("Error processing webhook:", error);
    res.status(500).json({ error: "Webhook processing failed" });
  }
});

// Helper function to verify webhook signature
function verifyWebhookSignature(payload, signature, secret) {
  const crypto = require("crypto");
  const expectedSignature = crypto
    .createHmac("sha256", secret)
    .update(payload)
    .digest("hex");

  return signature === expectedSignature;
}

// Handle successful payment
async function handlePaymentPaid(paymentData) {
  try {
    const payment = paymentData.attributes;
    const metadata = payment.metadata || {};
    const bookingId = metadata.bookingId;
    const userId = metadata.userId;

    if (!bookingId || !userId) {
      console.error("Missing booking ID or user ID in payment metadata");
      return;
    }

    // Update booking status
    const bookingRef = db
      .collection("users")
      .doc(userId)
      .collection("preBookings")
      .doc(bookingId);
    await bookingRef.update({
      status: "paid",
      paymongoPaymentId: payment.id,
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
      boardingStatus: "pending",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Send notification
    await db.collection("users").doc(userId).collection("notifications").add({
      type: "payment_update",
      bookingId: bookingId,
      status: "paid",
      message: "Payment successful! Your booking is confirmed.",
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log("Payment processed successfully for booking:", bookingId);
  } catch (error) {
    console.error("Error handling payment success:", error);
  }
}

// Handle failed payment
async function handlePaymentFailed(paymentData) {
  try {
    const payment = paymentData.attributes;
    const metadata = payment.metadata || {};
    const bookingId = metadata.bookingId;
    const userId = metadata.userId;

    if (!bookingId || !userId) {
      console.error("Missing booking ID or user ID in payment metadata");
      return;
    }

    // Update booking status
    const bookingRef = db
      .collection("users")
      .doc(userId)
      .collection("preBookings")
      .doc(bookingId);
    await bookingRef.update({
      status: "payment_failed",
      paymongoPaymentId: payment.id,
      paymentError: payment.failure_reason || "Payment failed",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Send notification
    await db.collection("users").doc(userId).collection("notifications").add({
      type: "payment_update",
      bookingId: bookingId,
      status: "payment_failed",
      message: "Payment failed. Please try again.",
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log("Payment failed for booking:", bookingId);
  } catch (error) {
    console.error("Error handling payment failure:", error);
  }
}

module.exports = router;
