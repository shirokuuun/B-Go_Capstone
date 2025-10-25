# Google Maps API Setup for Road-Based ETA

## Overview

The app now uses Google Maps Directions API to calculate realistic ETA based on actual roads instead of straight-line distance.

## Setup Instructions

### 1. Get Google Maps API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable the following APIs:
   - **Directions API**
   - **Maps JavaScript API** (if not already enabled)
4. Create credentials (API Key)
5. Restrict the API key to only the APIs you need

### 2. Configure the API Key

**Option A: Using Environment Variables (Recommended)**

1. Create a `.env` file in the root directory of your project
2. Add your API key:

```env
GOOGLE_MAPS_API_DIRECTIONS_KEY=YOUR_ACTUAL_API_KEY_HERE
```

**Option B: Hardcode the API Key**

In `lib/config/api_keys.dart`, replace the fallback value:

```dart
static String get googleMapsApiDirectionsKey =>
  dotenv.env['GOOGLE_MAPS_API_DIRECTIONS_KEY'] ?? 'YOUR_ACTUAL_API_KEY_HERE';
```

**Current Status**: The app will use fallback ETA calculation if no API key is configured.

### 3. Add API Key to Android (Optional but Recommended)

In `android/app/src/main/AndroidManifest.xml`, add:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY" />
```

## Features

### Road-Based ETA Calculation

- Uses actual road network instead of straight-line distance
- Considers traffic conditions
- Accounts for road curves and turns
- More accurate than straight-line calculation

### Fallback System

- If API key is not configured, uses improved fallback calculation
- Applies 1.3x factor to straight-line distance for road curves
- Uses realistic bus speed (25 km/h) for city traffic

### Caching

- Routes are cached to avoid repeated API calls
- Improves performance and reduces API usage
- Cache key based on bus and user coordinates

## API Usage

- **Free Tier**: 2,500 requests per day
- **Cost**: $5 per 1,000 requests after free tier
- **Caching**: Reduces API calls significantly

## Testing

1. Set up API key
2. Run the app
3. Click on a bus marker
4. Check console logs for route calculation
5. Verify ETA shows realistic road-based time

## Troubleshooting

- Check console logs for API errors
- Verify API key is correct
- Ensure Directions API is enabled
- Check API quotas in Google Cloud Console
