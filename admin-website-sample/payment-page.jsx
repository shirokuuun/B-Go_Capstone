import React, { useState, useEffect } from "react";
import { useSearchParams, useNavigate } from "react-router-dom";
import { loadStripe } from "@stripe/stripe-js";
import {
  Elements,
  CardElement,
  useStripe,
  useElements,
} from "@stripe/react-stripe-js";

// PayMongo configuration
const PAYMONGO_PUBLIC_KEY = process.env.REACT_APP_PAYMONGO_PUBLIC_KEY;
const stripePromise = loadStripe(PAYMONGO_PUBLIC_KEY);

const PaymentPage = () => {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const [bookingData, setBookingData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    // Extract booking data from URL parameters
    const bookingId = searchParams.get("bookingId");
    const amount = parseFloat(searchParams.get("amount"));
    const route = searchParams.get("route");
    const fromPlace = searchParams.get("from");
    const toPlace = searchParams.get("to");
    const quantity = parseInt(searchParams.get("quantity"));
    const fareTypes = searchParams.get("fareTypes")?.split(",") || [];
    const userId = searchParams.get("userId");

    if (!bookingId || !amount || !route) {
      setError("Invalid booking data. Please try again from the app.");
      setLoading(false);
      return;
    }

    setBookingData({
      bookingId,
      amount,
      route,
      fromPlace,
      toPlace,
      quantity,
      fareTypes,
      userId,
    });
    setLoading(false);
  }, [searchParams]);

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

      <Elements stripe={stripePromise}>
        <PaymentForm bookingData={bookingData} />
      </Elements>
    </div>
  );
};

const PaymentForm = ({ bookingData }) => {
  const stripe = useStripe();
  const elements = useElements();
  const [processing, setProcessing] = useState(false);
  const [error, setError] = useState(null);

  const handleSubmit = async (event) => {
    event.preventDefault();

    if (!stripe || !elements) {
      return;
    }

    setProcessing(true);
    setError(null);

    try {
      // Create payment intent
      const response = await fetch("/api/create-payment-intent", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          amount: Math.round(bookingData.amount * 100), // Convert to centavos
          currency: "PHP",
          metadata: {
            bookingId: bookingData.bookingId,
            route: bookingData.route,
            fromPlace: bookingData.fromPlace,
            toPlace: bookingData.toPlace,
            quantity: bookingData.quantity,
            source: "flutter_app",
          },
        }),
      });

      const { clientKey, paymentIntentId } = await response.json();

      if (!response.ok) {
        throw new Error("Failed to create payment intent");
      }

      // Confirm payment with PayMongo
      const { error: stripeError, paymentIntent } = await stripe.confirmPayment(
        {
          elements,
          confirmParams: {
            return_url: `${window.location.origin}/payment-success?bookingId=${bookingData.bookingId}`,
          },
          redirect: "if_required",
        }
      );

      if (stripeError) {
        setError(stripeError.message);
      } else if (paymentIntent.status === "succeeded") {
        // Payment successful
        await handlePaymentSuccess(paymentIntent.id);
      } else {
        setError("Payment was not completed. Please try again.");
      }
    } catch (err) {
      setError(
        err.message || "An error occurred during payment. Please try again."
      );
    } finally {
      setProcessing(false);
    }
  };

  const handlePaymentSuccess = async (paymentIntentId) => {
    try {
      // Update booking status
      await fetch("/api/update-payment-status", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          bookingId: bookingData.bookingId,
          status: "paid",
          paymongoPaymentId: paymentIntentId,
        }),
      });

      // Redirect to success page
      window.location.href = `/payment-success?bookingId=${bookingData.bookingId}`;
    } catch (err) {
      console.error("Error updating payment status:", err);
      setError(
        "Payment successful but failed to update status. Please contact support."
      );
    }
  };

  return (
    <form onSubmit={handleSubmit} className="payment-form">
      <div className="card-element-container">
        <label>Card Details</label>
        <CardElement
          options={{
            style: {
              base: {
                fontSize: "16px",
                color: "#424770",
                "::placeholder": {
                  color: "#aab7c4",
                },
              },
            },
          }}
        />
      </div>

      {error && <div className="error-message">{error}</div>}

      <button
        type="submit"
        disabled={!stripe || processing}
        className="pay-button"
      >
        {processing ? "Processing..." : `Pay ₱${bookingData.amount.toFixed(2)}`}
      </button>

      <div className="payment-info">
        <p>Secure payment powered by PayMongo</p>
        <p>Your payment information is encrypted and secure</p>
      </div>
    </form>
  );
};

export default PaymentPage;
