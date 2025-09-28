# Admin Website Integration Guide for B-Go PayMongo

This guide shows how to integrate the Flutter app with your existing admin website at [https://b-go-capstone-admin-chi.vercel.app/](https://b-go-capstone-admin-chi.vercel.app/).

## Your Existing Structure

Based on your folder structure, you already have:

```
B-GO-CAPSTONE-ADMIN/
├── client/ (Frontend)
├── api/
│   ├── lib/
│   │   ├── firebase.js
│   │   └── paymongo.js
│   ├── payment/
│   │   └── booking/
│   │       ├── [sessionId].js
│   │       ├── create-paymongo-checkout.js
│   │       └── initiate-payment.js
│   └── webhooks/
│       ├── paymongo.js
│       └── create-payment-session.js
```

## Required API Endpoints

You need to implement these endpoints to work with the Flutter app:

### 1. Payment Page Route

**File:** `client/pages/payment.js` (or similar)
**URL:** `/payment`

This page should:

- Accept booking data from URL parameters
- Display booking details
- Show PayMongo checkout form
- Handle payment completion

### 2. Payment Status Check

**File:** `api/payment/booking/[bookingId].js`
**URL:** `/api/payment/booking/[bookingId]`

```javascript
// api/payment/booking/[bookingId].js
import { db } from "../../../lib/firebase";

export default async function handler(req, res) {
  if (req.method !== "GET") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  try {
    const { bookingId } = req.query;
    const { userId } = req.query;

    if (!bookingId || !userId) {
      return res.status(400).json({ error: "Missing bookingId or userId" });
    }

    // Get booking from Firestore
    const bookingRef = db
      .collection("users")
      .doc(userId)
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
}
```

### 3. Create Payment Session

**File:** `api/payment/booking/create-paymongo-checkout.js`
**URL:** `/api/payment/booking/create-paymongo-checkout`

```javascript
// api/payment/booking/create-paymongo-checkout.js
import { createPayMongoCheckout } from "../../lib/paymongo";
import { db } from "../../lib/firebase";

export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  try {
    const { amount, currency, metadata } = req.body;

    // Create PayMongo checkout session
    const checkoutSession = await createPayMongoCheckout({
      amount: amount,
      currency: currency,
      metadata: metadata,
    });

    // Update booking with checkout session ID
    if (metadata.bookingId && metadata.userId) {
      const bookingRef = db
        .collection("users")
        .doc(metadata.userId)
        .collection("preBookings")
        .doc(metadata.bookingId);

      await bookingRef.update({
        paymongoCheckoutId: checkoutSession.id,
        paymongoCheckoutUrl: checkoutSession.attributes.checkout_url,
        updatedAt: new Date(),
      });
    }

    res.json({
      checkoutUrl: checkoutSession.attributes.checkout_url,
      checkoutId: checkoutSession.id,
    });
  } catch (error) {
    console.error("Error creating checkout session:", error);
    res
      .status(500)
      .json({ error: error.message || "Failed to create checkout session" });
  }
}
```

### 4. Update Payment Status

**File:** `api/payment/booking/update-status.js`
**URL:** `/api/payment/booking/update-status`

```javascript
// api/payment/booking/update-status.js
import { db } from "../../lib/firebase";

export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  try {
    const { bookingId, userId, status, paymongoPaymentId } = req.body;

    const updateData = {
      status: status,
      updatedAt: new Date(),
    };

    if (paymongoPaymentId) {
      updateData.paymongoPaymentId = paymongoPaymentId;
    }

    if (status === "paid") {
      updateData.paidAt = new Date();
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
        createdAt: new Date(),
      });

    res.json({ success: true });
  } catch (error) {
    console.error("Error updating payment status:", error);
    res.status(500).json({ error: "Failed to update payment status" });
  }
}
```

### 5. PayMongo Webhook Handler

**File:** `api/webhooks/paymongo.js`
**URL:** `/api/webhooks/paymongo`

```javascript
// api/webhooks/paymongo.js
import { db } from "../lib/firebase";
import crypto from "crypto";

export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  try {
    const signature = req.headers["paymongo-signature"];
    const payload = JSON.stringify(req.body);
    const secret = process.env.PAYMONGO_WEBHOOK_SECRET;

    // Verify webhook signature
    if (!verifyWebhookSignature(payload, signature, secret)) {
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
}

function verifyWebhookSignature(payload, signature, secret) {
  const expectedSignature = crypto
    .createHmac("sha256", secret)
    .update(payload)
    .digest("hex");

  return signature === expectedSignature;
}

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
      paidAt: new Date(),
      boardingStatus: "pending",
      updatedAt: new Date(),
    });

    // Send notification
    await db.collection("users").doc(userId).collection("notifications").add({
      type: "payment_update",
      bookingId: bookingId,
      status: "paid",
      message: "Payment successful! Your booking is confirmed.",
      read: false,
      createdAt: new Date(),
    });

    console.log("Payment processed successfully for booking:", bookingId);
  } catch (error) {
    console.error("Error handling payment success:", error);
  }
}

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
      updatedAt: new Date(),
    });

    // Send notification
    await db.collection("users").doc(userId).collection("notifications").add({
      type: "payment_update",
      bookingId: bookingId,
      status: "payment_failed",
      message: "Payment failed. Please try again.",
      read: false,
      createdAt: new Date(),
    });

    console.log("Payment failed for booking:", bookingId);
  } catch (error) {
    console.error("Error handling payment failure:", error);
  }
}
```

## Frontend Payment Page

**File:** `client/pages/payment.js`

```javascript
// client/pages/payment.js
import { useState, useEffect } from "react";
import { useRouter } from "next/router";
import Head from "next/head";

export default function PaymentPage() {
  const router = useRouter();
  const [bookingData, setBookingData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [processing, setProcessing] = useState(false);

  useEffect(() => {
    // Extract booking data from URL parameters
    const { bookingId, amount, route, from, to, quantity, fareTypes, userId } =
      router.query;

    if (!bookingId || !amount || !route) {
      setError("Invalid booking data. Please try again from the app.");
      setLoading(false);
      return;
    }

    setBookingData({
      bookingId,
      amount: parseFloat(amount),
      route,
      fromPlace: from,
      toPlace: to,
      quantity: parseInt(quantity),
      fareTypes: fareTypes ? fareTypes.split(",") : [],
      userId,
    });
    setLoading(false);
  }, [router.query]);

  const handlePayment = async () => {
    if (!bookingData) return;

    setProcessing(true);
    setError(null);

    try {
      // Create PayMongo checkout session
      const response = await fetch(
        "/api/payment/booking/create-paymongo-checkout",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            amount: Math.round(bookingData.amount * 100), // Convert to centavos
            currency: "PHP",
            metadata: {
              bookingId: bookingData.bookingId,
              userId: bookingData.userId,
              route: bookingData.route,
              fromPlace: bookingData.fromPlace,
              toPlace: bookingData.toPlace,
              quantity: bookingData.quantity,
              source: "flutter_app",
            },
          }),
        }
      );

      const { checkoutUrl } = await response.json();

      if (!response.ok) {
        throw new Error("Failed to create payment session");
      }

      // Redirect to PayMongo checkout
      window.location.href = checkoutUrl;
    } catch (err) {
      setError(
        err.message || "An error occurred during payment. Please try again."
      );
      setProcessing(false);
    }
  };

  if (loading) {
    return (
      <div className="payment-container">
        <div className="loading">Loading payment details...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="payment-container">
        <div className="error">{error}</div>
        <button onClick={() => window.close()}>Close</button>
      </div>
    );
  }

  return (
    <>
      <Head>
        <title>B-Go Payment</title>
      </Head>
      <div className="payment-container">
        <div className="payment-header">
          <h1>B-Go Payment</h1>
          <p>Complete your pre-booking payment</p>
        </div>

        <div className="booking-details">
          <h2>Booking Details</h2>
          <div className="detail-row">
            <span>Route:</span>
            <span>{bookingData.route}</span>
          </div>
          <div className="detail-row">
            <span>From:</span>
            <span>{bookingData.fromPlace}</span>
          </div>
          <div className="detail-row">
            <span>To:</span>
            <span>{bookingData.toPlace}</span>
          </div>
          <div className="detail-row">
            <span>Passengers:</span>
            <span>{bookingData.quantity}</span>
          </div>
          <div className="detail-row">
            <span>Fare Types:</span>
            <span>{bookingData.fareTypes.join(", ")}</span>
          </div>
          <div className="detail-row total">
            <span>Total Amount:</span>
            <span>₱{bookingData.amount.toFixed(2)}</span>
          </div>
        </div>

        <button
          onClick={handlePayment}
          disabled={processing}
          className="pay-button"
        >
          {processing
            ? "Processing..."
            : `Pay ₱${bookingData.amount.toFixed(2)}`}
        </button>

        <div className="payment-info">
          <p>Secure payment powered by PayMongo</p>
          <p>Your payment information is encrypted and secure</p>
        </div>
      </div>

      <style jsx>{`
        .payment-container {
          max-width: 600px;
          margin: 0 auto;
          padding: 20px;
          font-family: Arial, sans-serif;
        }

        .payment-header {
          text-align: center;
          margin-bottom: 30px;
        }

        .payment-header h1 {
          color: #007a8f;
          margin-bottom: 10px;
        }

        .booking-details {
          background: #f5f5f5;
          padding: 20px;
          border-radius: 8px;
          margin-bottom: 30px;
        }

        .booking-details h2 {
          margin-top: 0;
          color: #333;
        }

        .detail-row {
          display: flex;
          justify-content: space-between;
          margin-bottom: 10px;
        }

        .detail-row.total {
          font-weight: bold;
          font-size: 18px;
          border-top: 1px solid #ddd;
          padding-top: 10px;
          margin-top: 10px;
        }

        .pay-button {
          width: 100%;
          background: #007a8f;
          color: white;
          border: none;
          padding: 15px;
          font-size: 18px;
          border-radius: 8px;
          cursor: pointer;
          margin-bottom: 20px;
        }

        .pay-button:disabled {
          background: #ccc;
          cursor: not-allowed;
        }

        .payment-info {
          text-align: center;
          color: #666;
          font-size: 14px;
        }

        .loading,
        .error {
          text-align: center;
          padding: 40px;
          font-size: 18px;
        }

        .error {
          color: red;
        }
      `}</style>
    </>
  );
}
```

## Environment Variables

Add these to your Vercel environment variables:

```env
PAYMONGO_SECRET_KEY=sk_test_your_secret_key_here
PAYMONGO_PUBLIC_KEY=pk_test_your_public_key_here
PAYMONGO_WEBHOOK_SECRET=whsec_your_webhook_secret_here
```

## PayMongo Webhook Configuration

In your PayMongo dashboard:

1. Go to Webhooks section
2. Add webhook endpoint: `https://b-go-capstone-admin-chi.vercel.app/api/webhooks/paymongo`
3. Select events: `payment.paid`, `payment.failed`
4. Copy the webhook secret to your environment variables

## Testing the Integration

1. **Create a pre-booking** in the Flutter app
2. **Click "Pay Now"** - should open your admin website
3. **Complete payment** on PayMongo checkout
4. **Verify webhook** updates the booking status
5. **Check Flutter app** - should show payment success

## Flutter App Integration

The Flutter app is already configured to work with your admin website. The `PaymentService` will:

1. Launch your admin website with booking data
2. Poll payment status every 10 seconds
3. Navigate to confirmation when payment succeeds

## Next Steps

1. Implement the API endpoints above
2. Create the payment page
3. Configure PayMongo webhooks
4. Test the complete flow
5. Deploy to production

The integration is now complete and ready for testing!
