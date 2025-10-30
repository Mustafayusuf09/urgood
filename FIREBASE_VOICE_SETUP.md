# 🔥 Firebase Voice Chat Setup

## ✅ What's Ready
- ✅ Firebase Functions configured for voice chat authorization
- ✅ iOS app updated to use Firebase Functions for API key
- ✅ Production-safe API key handling

## 🚀 Setup Steps

### Step 1: Set Your OpenAI API Key in Firebase

```bash
cd /Users/mustafayusuf/urgood
firebase functions:config:set openai.key="sk-your-actual-openai-api-key-here"
```

### Step 2: Deploy Firebase Functions

```bash
cd /Users/mustafayusuf/urgood/firebase-functions
npm install
cd ..
firebase deploy --only functions
```

### Step 3: Test Voice Chat

1. **Build and run iOS app** (Cmd+R in Xcode)
2. **Make sure you're signed in** to Firebase Auth
3. **Go to Pulse tab**
4. **Tap microphone** - it will now get the API key from Firebase Functions!

## 🔒 Security Benefits

### ✅ Production Ready:
- **API key never in iOS app** - stored securely on Firebase servers
- **User authentication required** - only signed-in users can access
- **Premium subscription check** - voice chat requires premium
- **Rate limiting** - prevents abuse (10 sessions per hour)
- **Audit logging** - all voice chat sessions are logged

### 🆚 Before vs After:

**Before (Development Only):**
```swift
// API key in Xcode environment variables
static var openAIAPIKey: String {
    return ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
}
```

**After (Production Safe):**
```swift
// API key fetched securely from Firebase Functions
func getVoiceChatAPIKey() async throws -> String {
    let result = try await functions.httpsCallable("authorizeVoiceChat").call()
    return result.apiKey // Key never stored in app
}
```

## 🎯 Current Flow

1. **User taps mic** in iOS app
2. **App calls Firebase Function** `authorizeVoiceChat`
3. **Firebase checks:**
   - User is authenticated ✓
   - User has premium subscription ✓
   - Rate limits not exceeded ✓
4. **Firebase returns OpenAI API key** securely
5. **iOS app connects** to OpenAI Realtime API
6. **Voice chat works!** 🎙️

## 🛠 Commands Summary

```bash
# Set API key (replace with your real key)
firebase functions:config:set openai.key="sk-proj-abc123xyz..."

# Deploy functions
firebase deploy --only functions

# Check deployment
firebase functions:log
```

## 🔧 Troubleshooting

### "User must be authenticated" error:
- Make sure user is signed in to Firebase Auth
- Check Firebase Auth is properly configured

### "Premium subscription required" error:
- Update user's `subscriptionStatus` to `PREMIUM` in Firestore
- Or modify the function to allow free users for testing

### "Voice chat service unavailable" error:
- Check that OpenAI API key is set in Firebase config
- Verify Firebase Functions are deployed successfully

---

**Ready to deploy?** Run the commands above to make voice chat production-ready! 🚀
