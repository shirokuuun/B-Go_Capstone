# PayMongo Integration for B-Go Pre-Booking System

This document outlines the complete PayMongo integration implementation for the B-Go pre-booking payment system.

## Overview

The integration allows users to:
1. Create pre-bookings in the Flutter app
2. Be redirected to the admin website for PayMongo payment processing
3. Have their payment status automatically updated in the app via webhooks
4. Receive real-time payment confirmations

## Architecture

```
Flutter App → Admin Website → PayMongo → Webhook → Admin Website → Flutter App
```

## Implementation Details

### 1. Flutter App Changes

#### Dependencies Added
- `url_launcher: ^6.3.1` - For opening external URLs
- `http: ^1.2.2` - For API communication

#### New Services Created

##### PaymentService (`lib/services/payment_service.dart`)
- `launchPaymentPage()` - Opens admin website with booking data
- `checkPaymentStatus()` - Polls payment status from admin website
- `updateBookingStatus()` - Updates Firestore with payment status
- `createPayMongoPaymentIntent()` - Creates payment intent via admin website
- `handlePayMongoWebhook()` - Processes webhook notifications
- `getBookingDetails()` - Retrieves booking information
- `cancelBooking()` - Cancels a booking

##### WebhookService (`lib/services/webhook_service.dart`)
- `registerWebhook()` - Registers webhook endpoint with PayMongo
- `handlePayMongoWebhook()` - Processes PayMongo webhook notifications
- `verifyWebhookSignature()` - Verifies webhook authenticity
- `processWebhookPayload()` - Extracts data from webhook payload
- `sendPaymentNotification()` - Sends user notifications
- `getWebhookLogs()` - Retrieves webhook logs for debugging
- `logWebhookEvent()` - Logs webhook events

#### Updated Files

##### `lib/pages/passenger/services/pre_book.dart`
- Added `bookingId` parameter to `PreBookSummaryPage`
- Updated `savePreBooking()` to return booking ID
- Modified `_launchAdminWebsite()` to use `PaymentService`
- Added periodic payment status checking
- Updated cancellation flow to use `PaymentService`

### 2. Admin Website Requirements

The admin website (React.js) needs to implement the following endpoints:

#### API Endpoints

##### `GET /payment`
- Receives booking data as query parameters
- Displays payment form with PayMongo integration
- Shows booking details and total amount

**Query Parameters:**
```
bookingId: string
amount: string (in PHP)
route: string
from: string
to: string
quantity: string
fareTypes: string (comma-separated)
userId: string
source: 'flutter_app'
```

##### `GET /api/payment-status/:bookingId`
- Returns current payment status for a booking
- Used by Flutter app to poll payment status

**Response:**
```json
{
  "status": "pending_payment" | "paid" | "failed" | "cancelled",
  "paymongoPaymentId": "string",
  "amount": number,
  "paidAt": "ISO string" | null,
  "error": "string" | null
}
```

##### `POST /api/create-payment-intent`
- Creates PayMongo payment intent
- Called by Flutter app or directly from payment page

**Request Body:**
```json
{
  "amount": number (in centavos),
  "currency": "PHP",
  "metadata": {
    "bookingId": "string",
    "route": "string",
    "fromPlace": "string",
    "toPlace": "string",
    "quantity": number,
    "source": "flutter_app"
  }
}
```

**Response:**
```json
{
  "clientKey": "string",
  "paymentIntentId": "string",
  "checkoutUrl": "string"
}
```

##### `POST /api/register-webhook`
- Registers webhook endpoint with PayMongo
- Called when booking is created

**Request Body:**
```json
{
  "bookingId": "string",
  "userId": "string",
  "webhookUrl": "string"
}
```

##### `POST /api/payment-webhook`
- Receives PayMongo webhook notifications
- Updates Firestore with payment status
- Sends notifications to user

**Request Body:** (PayMongo webhook payload)
```json
{
  "type": "payment.paid" | "payment.failed",
  "data": {
    "id": "string",
    "attributes": {
      "id": "string",
      "amount": number,
      "currency": "string",
      "status": "string",
      "payment_method": {
        "type": "string"
      },
      "metadata": {
        "bookingId": "string"
      }
    }
  }
}
```

### 3. PayMongo Configuration

#### Environment Variables (Admin Website)
```env
PAYMONGO_SECRET_KEY=pk_test_...
PAYMONGO_PUBLIC_KEY=pk_test_...
PAYMONGO_WEBHOOK_SECRET=whsec_...
```

#### Webhook Configuration
- **Endpoint URL:** `https://your-admin-website.vercel.app/api/payment-webhook`
- **Events:** `payment.paid`, `payment.failed`
- **Secret:** Use PayMongo webhook secret for verification

### 4. Payment Flow

#### Step 1: Pre-Booking Creation
1. User creates pre-booking in Flutter app
2. Booking saved to Firestore with `status: 'pending_payment'`
3. Booking ID returned to app

#### Step 2: Payment Initiation
1. User clicks "Pay Now" button
2. App calls `PaymentService.launchPaymentPage()`
3. Admin website opens with booking data in URL parameters
4. Payment page displays booking details and PayMongo checkout

#### Step 3: Payment Processing
1. User completes payment on PayMongo checkout
2. PayMongo sends webhook to admin website
3. Admin website updates Firestore with payment status
4. Admin website sends notification to user

#### Step 4: Status Update
1. Flutter app polls payment status every 10 seconds
2. When payment is confirmed, app navigates to confirmation page
3. User receives booking confirmation

### 5. Error Handling

#### Payment Failures
- Failed payments are marked as `status: 'payment_failed'`
- User can retry payment or cancel booking
- Error messages are displayed to user

#### Timeout Handling
- 10-minute payment timeout
- Automatic cancellation if payment not completed
- User notification of timeout

#### Network Issues
- Retry mechanisms for API calls
- Offline handling with local state
- User feedback for connection issues

### 6. Security Considerations

#### Webhook Verification
- Verify PayMongo webhook signatures
- Validate webhook payload structure
- Log all webhook events for debugging

#### Data Validation
- Validate all incoming data
- Sanitize user inputs
- Check user permissions

#### API Security
- Use HTTPS for all communications
- Implement rate limiting
- Validate API keys and secrets

### 7. Testing

#### Test Scenarios
1. **Successful Payment**
   - Create booking → Pay → Verify status update
2. **Failed Payment**
   - Create booking → Fail payment → Verify failure handling
3. **Timeout**
   - Create booking → Wait 10 minutes → Verify cancellation
4. **Network Issues**
   - Test offline scenarios
   - Test API failures

#### Test Data
- Use PayMongo test keys
- Test with small amounts
- Verify webhook delivery

### 8. Deployment Checklist

#### Flutter App
- [ ] Add new dependencies
- [ ] Update payment flow
- [ ] Test URL launching
- [ ] Verify status polling

#### Admin Website
- [ ] Implement PayMongo SDK
- [ ] Create API endpoints
- [ ] Set up webhook handling
- [ ] Configure environment variables
- [ ] Test payment flow

#### PayMongo
- [ ] Configure webhook endpoint
- [ ] Set webhook secret
- [ ] Test webhook delivery
- [ ] Verify payment processing

### 9. Monitoring and Logging

#### Logging
- Log all payment events
- Track webhook deliveries
- Monitor API response times
- Log error conditions

#### Monitoring
- Payment success rates
- Webhook delivery success
- API response times
- Error rates

### 10. Future Enhancements

#### Features
- Payment retry mechanism
- Partial payment support
- Refund handling
- Payment analytics

#### Improvements
- Real-time status updates via WebSocket
- Push notifications for payment status
- Enhanced error handling
- Payment method preferences

## Support

For issues or questions regarding the PayMongo integration:
1. Check webhook logs in Firestore
2. Verify PayMongo dashboard for payment status
3. Review admin website logs
4. Test with PayMongo test environment

## References

- [PayMongo Documentation](https://developers.paymongo.com/)
- [PayMongo Webhooks](https://developers.paymongo.com/docs/webhooks)
- [PayMongo Checkout](https://developers.paymongo.com/docs/checkout)
- [Flutter URL Launcher](https://pub.dev/packages/url_launcher)
