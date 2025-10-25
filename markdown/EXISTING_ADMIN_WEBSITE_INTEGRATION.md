# Using Your Existing Admin Website for PayMongo Integration

This guide shows how to integrate the Flutter app with your **existing** admin website at [https://b-go-capstone-admin-chi.vercel.app/](https://b-go-capstone-admin-chi.vercel.app/) without creating new JSX files.

## How It Works

The Flutter app will:

1. **Call your existing API** to create a PayMongo checkout session
2. **Launch the PayMongo checkout URL** directly in the browser
3. **Poll your existing API** to check payment status
4. **Handle webhook updates** through your existing webhook endpoint

## Required API Endpoints

You only need to ensure these endpoints exist in your admin website:

### 1. Create PayMongo Checkout Session

**File:** `api/payment/booking/create-paymongo-checkout.js`
**URL:** `/api/payment/booking/create-paymongo-checkout`
**Method:** POST

**Request Body:**

```json
{
  "amount": 1500,
  "currency": "PHP",
  "metadata": {
    "bookingId": "abc123",
    "userId": "user456",
    "route": "Batangas",
    "fromPlace": "SM Lipa",
    "toPlace": "Batangas City",
    "quantity": 2,
    "fareTypes": "Regular,Student",
    "source": "flutter_app"
  }
}
```

**Response:**

```json
{
  "checkoutUrl": "https://checkout.paymongo.com/...",
  "checkoutId": "checkout_abc123"
}
```

### 2. Check Payment Status

**File:** `api/payment/booking/[bookingId].js`
**URL:** `/api/payment/booking/[bookingId]?userId=user456`
**Method:** GET

**Response:**

```json
{
  "status": "paid",
  "paymongoPaymentId": "payment_xyz789",
  "amount": 15.0,
  "paidAt": "2024-01-15T10:30:00Z",
  "error": null
}
```

### 3. PayMongo Webhook Handler

**File:** `api/webhooks/paymongo.js`
**URL:** `/api/webhooks/paymongo`
**Method:** POST

This should already exist in your admin website to handle PayMongo webhook notifications.

## Flutter App Integration

The Flutter app is already configured to work with your existing admin website:

### Payment Flow

1. **User clicks "Pay Now"** in Flutter app
2. **App calls your API** to create PayMongo checkout session
3. **App launches PayMongo checkout** in browser
4. **User completes payment** on PayMongo
5. **PayMongo sends webhook** to your admin website
6. **App polls your API** to check payment status
7. **App shows success** when payment is confirmed

### Code Example

```dart
// This is already implemented in PaymentService
final success = await PaymentService.launchPaymentPage(
  bookingId: 'abc123',
  amount: 15.00,
  route: 'Batangas',
  fromPlace: 'SM Lipa',
  toPlace: 'Batangas City',
  quantity: 2,
  fareTypes: ['Regular', 'Student'],
  userId: 'user456',
);
```

## What You Need to Do

### 1. Ensure API Endpoints Exist

Check if these files exist in your admin website:

- `api/payment/booking/create-paymongo-checkout.js`
- `api/payment/booking/[bookingId].js`
- `api/webhooks/paymongo.js`

### 2. Update API Endpoints (if needed)

If the endpoints don't exist or need updates, use the code from the `ADMIN_WEBSITE_INTEGRATION_GUIDE.md` file.

### 3. Configure PayMongo Webhooks

In your PayMongo dashboard:

- **Webhook URL:** `https://b-go-capstone-admin-chi.vercel.app/api/webhooks/paymongo`
- **Events:** `payment.paid`, `payment.failed`

### 4. Test the Integration

1. Create a pre-booking in Flutter app
2. Click "Pay Now"
3. Complete payment on PayMongo
4. Verify payment status updates in app

## Benefits of This Approach

✅ **No new JSX files needed** - Uses your existing admin website
✅ **Direct PayMongo integration** - Launches PayMongo checkout directly
✅ **Existing webhook handling** - Uses your current webhook setup
✅ **Minimal changes required** - Only API endpoints need to exist
✅ **Secure payment flow** - PayMongo handles all payment processing

## API Endpoint Requirements

### create-paymongo-checkout.js

```javascript
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

### [bookingId].js

```javascript
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

## Testing

1. **Test API Endpoints**

   ```bash
   # Test checkout creation
   curl -X POST https://b-go-capstone-admin-chi.vercel.app/api/payment/booking/create-paymongo-checkout \
     -H "Content-Type: application/json" \
     -d '{"amount": 1500, "currency": "PHP", "metadata": {"bookingId": "test123", "userId": "user456"}}'

   # Test status check
   curl https://b-go-capstone-admin-chi.vercel.app/api/payment/booking/test123?userId=user456
   ```

2. **Test Flutter Integration**
   - Create pre-booking in app
   - Click "Pay Now"
   - Verify PayMongo checkout opens
   - Complete test payment
   - Check payment status updates

## Summary

The Flutter app is now configured to work directly with your existing admin website API endpoints. No new JSX files are needed - the app will:

1. Call your existing API to create PayMongo checkout sessions
2. Launch PayMongo checkout URLs directly
3. Poll your existing API for payment status updates
4. Handle webhook notifications through your existing webhook endpoint

This approach leverages your existing infrastructure while providing a seamless payment experience for users.
