# ElevenLabs Production Deployment Guide

## Overview

This guide covers deploying ElevenLabs TTS to production using Firebase Functions as a secure proxy. Your API key will be stored securely on the backend, never exposed in the iOS app.

## Architecture

### Development Mode
```
iOS App → Direct ElevenLabs API (with env var key)
```

### Production Mode
```
iOS App → Firebase Function → ElevenLabs API (with stored key)
```

## Deployment Steps

### 1. Install Firebase CLI (if not already installed)

```bash
npm install -g firebase-tools
```

### 2. Navigate to Firebase Functions Directory

```bash
cd /Users/mustafayusuf/urgood/firebase-functions
```

### 3. Set ElevenLabs API Key in Firebase

```bash
firebase functions:config:set elevenlabs.key="YOUR_ELEVENLABS_API_KEY"
```

Replace `YOUR_ELEVENLABS_API_KEY` with your actual key from [elevenlabs.io](https://elevenlabs.io).

### 4. Verify Configuration

```bash
firebase functions:config:get
```

You should see:
```json
{
  "elevenlabs": {
    "key": "YOUR_KEY_HERE"
  },
  "openai": {
    "key": "YOUR_OPENAI_KEY_HERE"
  }
}
```

### 5. Deploy Firebase Function

```bash
# Deploy only the new function
firebase deploy --only functions:synthesizeSpeech

# Or deploy all functions
firebase deploy --only functions
```

Expected output:
```
✔  functions[synthesizeSpeech(us-central1)] Successful update operation.

Functions deployed:
  ✔ synthesizeSpeech(us-central1)
```

### 6. Test the Function

You can test using Firebase Console or curl:

```bash
# Get your Firebase project ID
PROJECT_ID="urgood-dc7f0"

# Test endpoint
curl -X POST \
  https://us-central1-${PROJECT_ID}.cloudfunctions.net/synthesizeSpeech \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(firebase auth:print-identity-token)" \
  -d '{
    "data": {
      "text": "Hello, this is a test of the ElevenLabs integration."
    }
  }'
```

### 7. Update iOS App (Already Done)

The iOS app automatically uses Firebase Functions in production mode:

```swift
#if DEBUG
// Development: Direct API with environment variable
#else
// Production: Firebase Function
#endif
```

### 8. Build Production iOS App

1. In Xcode, select **Product** → **Archive**
2. The production build will automatically use Firebase Functions
3. No API key needed in the app!

## Firebase Function Details

### Function: `synthesizeSpeech`

**Endpoint**: `https://us-central1-urgood-dc7f0.cloudfunctions.net/synthesizeSpeech`

**Request**:
```javascript
{
  text: string,        // Required: Text to synthesize (max 5000 chars)
  voiceId?: string,    // Optional: Voice ID (default: Rachel)
  modelId?: string     // Optional: Model ID (default: eleven_multilingual_v2)
}
```

**Response**:
```javascript
{
  success: true,
  audioData: string,   // Base64-encoded MP3 audio
  format: "mp3",
  size: number         // Audio size in bytes
}
```

**Features**:
- ✅ Authentication required (Firebase Auth)
- ✅ Rate limiting (30 requests/minute per user)
- ✅ Analytics tracking
- ✅ Error handling with fallback
- ✅ Secure API key management

### Rate Limits

Default rate limits (can be adjusted in `voice-only.ts`):
- **TTS Synthesis**: 30 requests/minute per user
- **Voice Chat Auth**: 10 sessions/hour per user

To adjust:
```typescript
await checkRateLimit(userId, 'tts_synthesis', 30, 1); // 30 per 1 minute
```

### Cost Tracking

Analytics events are logged to Firestore:
```javascript
{
  userId: string,
  eventName: 'tts_synthesis',
  parameters: {
    textLength: number,
    audioSize: number,
    voiceId: string,
    modelId: string
  },
  timestamp: serverTimestamp
}
```

Query usage in Firebase Console:
```javascript
db.collection('analytics_events')
  .where('eventName', '==', 'tts_synthesis')
  .where('timestamp', '>', startDate)
  .get()
```

## Security Best Practices

### ✅ What We Did Right

1. **API Key Never in App**: Key stored only in Firebase Functions
2. **Authentication Required**: Users must be signed in
3. **Rate Limiting**: Prevents abuse and runaway costs
4. **Input Validation**: Text limited to 5000 characters
5. **Error Handling**: Graceful degradation with fallback

### ⚠️ Additional Recommendations

1. **Monitor Usage**:
   ```bash
   # Set up budget alerts in Firebase
   # Firebase Console → Functions → Usage tab
   ```

2. **Premium-Only Access** (Optional):
   ```typescript
   // In synthesizeSpeech function
   const userDoc = await db.collection('users').doc(userId).get();
   const isPremium = userDoc.data()?.subscriptionStatus === 'PREMIUM';
   
   if (!isPremium) {
     throw new functions.https.HttpsError('permission-denied', 'Premium required');
   }
   ```

3. **Quotas & Alerts**:
   - Set ElevenLabs quota alerts at 80% usage
   - Monitor Firebase Functions execution time
   - Set up error rate alerts

## Testing Production Deployment

### 1. Local Testing with Production Mode

You can test the Firebase Function locally before deploying:

```bash
cd firebase-functions

# Set environment variables for local testing
export ELEVENLABS_API_KEY="your_key_here"

# Run Firebase emulator
firebase emulators:start --only functions
```

Then in iOS app, temporarily point to emulator:
```swift
// In ElevenLabsService.swift init
#if DEBUG
functions.useFunctionsEmulator(origin: "http://localhost:5001")
#endif
```

### 2. Production Testing Checklist

After deployment:

- [ ] TestFlight build connects successfully
- [ ] Voice synthesis works end-to-end
- [ ] Rate limiting triggers correctly (test with 31 requests in 1 min)
- [ ] Fallback to AVSpeechSynthesizer works if function fails
- [ ] Analytics events logged correctly
- [ ] No API keys exposed in app binary
- [ ] Audio quality matches development mode

### 3. Monitor Logs

```bash
# Stream Firebase Function logs
firebase functions:log --only synthesizeSpeech

# Look for:
# ✅ Successfully synthesized X bytes of audio
# ❌ ElevenLabs API error: 401/429/500
```

## Troubleshooting

### Function Returns "TTS service unavailable"

**Problem**: API key not configured
**Solution**:
```bash
firebase functions:config:set elevenlabs.key="YOUR_KEY"
firebase deploy --only functions:synthesizeSpeech
```

### Function Returns "Unauthenticated"

**Problem**: User not signed in or token expired
**Solution**: Check Firebase Auth is working in iOS app

### Function Returns "Rate limit exceeded"

**Expected**: User made >30 requests in 1 minute
**Solution**: 
- Wait 1 minute or adjust rate limit
- App automatically falls back to AVSpeechSynthesizer

### Function Times Out

**Problem**: ElevenLabs API slow or network issues
**Solution**:
- Check ElevenLabs status page
- Increase function timeout in firebase.json:
  ```json
  {
    "functions": {
      "timeoutSeconds": 60
    }
  }
  ```

### High Costs

**Problem**: Unexpected ElevenLabs usage
**Solution**:
- Query analytics_events to find heavy users
- Implement stricter rate limits
- Consider caching common responses
- Make voice chat premium-only

## Cost Estimates

### ElevenLabs Pricing
- **Free**: 10,000 characters/month
- **Starter**: $5/month for 30,000 characters
- **Creator**: $22/month for 100,000 characters

### Firebase Functions Pricing
- **Free Tier**: 2M invocations/month
- **Paid**: $0.40 per million invocations

### Typical Usage
Average therapy response: ~150 characters

| Plan | Monthly Chars | Responses | Cost |
|------|---------------|-----------|------|
| Free | 10,000 | ~66 | $0 |
| Starter | 30,000 | ~200 | $5 |
| Creator | 100,000 | ~666 | $22 |

**Firebase Cost**: Negligible (well within free tier)

## Rollback Plan

If something goes wrong:

### 1. Disable ElevenLabs, Use Fallback Only

```swift
// In ElevenLabsService.swift init
self.useFallback = true // Force fallback for all users
```

### 2. Revert to Previous Function Version

```bash
firebase functions:delete synthesizeSpeech
# Then deploy older version
```

### 3. Switch Back to Direct API (Not Recommended)

Only as last resort - exposes API key:
```swift
#if DEBUG
self.useProductionMode = false
#else
self.useProductionMode = false // Temporarily disable
#endif
```

## Monitoring & Alerts

### Set Up Alerts

1. **ElevenLabs Dashboard**:
   - Set quota alert at 80%
   - Enable email notifications

2. **Firebase Console**:
   - Functions → Metrics
   - Set alert for error rate > 5%
   - Set alert for execution time > 10s

3. **Custom Monitoring** (Optional):
   - Track success/failure rates in Firestore
   - Create dashboard for TTS usage
   - Alert on fallback usage spike

## Next Steps

After successful deployment:

1. [ ] Monitor first week of production usage
2. [ ] Adjust rate limits based on actual usage
3. [ ] Gather user feedback on voice quality
4. [ ] Consider voice customization options
5. [ ] Optimize for lower latency if needed
6. [ ] Plan for scaling (caching, CDN, etc.)

## Support

- **Firebase Functions**: [Firebase Support](https://firebase.google.com/support)
- **ElevenLabs**: support@elevenlabs.io
- **Your Backend Team**: [Contact info]

---

## Deployment Checklist

Pre-deployment:
- [ ] ElevenLabs API key obtained
- [ ] Firebase CLI installed
- [ ] Firebase Functions config set
- [ ] Function tested locally
- [ ] iOS app updated (already done)

Deployment:
- [ ] Run `firebase deploy --only functions:synthesizeSpeech`
- [ ] Verify function deployed successfully
- [ ] Test with curl or Firebase Console
- [ ] Build production iOS app

Post-deployment:
- [ ] Test end-to-end on TestFlight
- [ ] Monitor logs for first 24 hours
- [ ] Check ElevenLabs usage dashboard
- [ ] Verify analytics events logging
- [ ] Document any issues

**Status**: Ready to deploy! 🚀

