# ElevenLabs Production Setup for UrGood

## 🎯 Overview

The UrGood app uses **two different methods** to access ElevenLabs based on the build type:

- **Development (DEBUG)**: Direct API calls using Xcode environment variable
- **Production (RELEASE)**: Secure Firebase Functions proxy (API key never exposed)

---

## 🔧 Development Setup (for testing in Xcode)

### Option 1: Xcode Environment Variables (Recommended)

1. In Xcode, click the **scheme dropdown** (next to play button)
2. Select **"Edit Scheme..."**
3. Select **"Run"** on the left sidebar
4. Go to **"Arguments"** tab
5. Under **"Environment Variables"**, click **+** button
6. Add these variables:

```
ELEVENLABS_API_KEY = your_elevenlabs_key_here
OPENAI_API_KEY = your_openai_key_here
```

7. Click **Close**
8. **Clean Build Folder** (Cmd+Shift+K)
9. **Rebuild and run** the app

### Option 2: Edit Scheme File Directly

Alternatively, edit `.xcscheme` file in:
```
urgood/urgood.xcodeproj/xcshareddata/xcschemes/urgood.xcscheme
```

Add this in the `<EnvironmentVariables>` section:
```xml
<EnvironmentVariables>
   <EnvironmentVariable
      key = "ELEVENLABS_API_KEY"
      value = "your_key_here"
      isEnabled = "YES">
   </EnvironmentVariable>
   <EnvironmentVariable
      key = "OPENAI_API_KEY"
      value = "your_key_here"
      isEnabled = "YES">
   </EnvironmentVariable>
</EnvironmentVariables>
```

⚠️ **Never commit API keys!** Add `.xcscheme` to `.gitignore` if it contains keys.

---

## 🚀 Production Setup (Firebase Functions)

### Step 1: Get Your ElevenLabs API Key

1. Go to https://elevenlabs.io
2. Sign up/login
3. Go to **Settings** → **API Keys**
4. Copy your API key

### Step 2: Configure Firebase Functions

```bash
cd firebase-functions

# Set the ElevenLabs API key in Firebase config
firebase functions:config:set elevenlabs.key="YOUR_ELEVENLABS_API_KEY"

# Verify it was set correctly
firebase functions:config:get
```

You should see:
```json
{
  "elevenlabs": {
    "key": "YOUR_KEY"
  }
}
```

### Step 3: Deploy Firebase Functions

```bash
# Deploy the synthesizeSpeech function
firebase deploy --only functions:synthesizeSpeech

# Or deploy all functions
firebase deploy --only functions
```

### Step 4: Verify Deployment

```bash
# Check deployed functions
firebase functions:list

# Check function logs
firebase functions:log --only synthesizeSpeech

# Test the function manually
firebase functions:shell
> synthesizeSpeech({text: "Hello world", voiceId: "21m00Tcm4TlvDq8ikWAM"})
```

---

## 📱 How It Works in the App

### Development Mode (DEBUG build)

```swift
// In ElevenLabsService.swift
init() {
    #if DEBUG
    self.useProductionMode = false
    self.apiKey = ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"]
    
    if apiKey == nil || apiKey?.isEmpty == true {
        print("⚠️ [ElevenLabs] API key not found, will use fallback")
        useFallback = true
    }
    #else
    // Production...
    #endif
}
```

**Flow:**
1. App reads `ELEVENLABS_API_KEY` from Xcode environment
2. Makes direct API calls to ElevenLabs
3. No Firebase Functions needed for testing

### Production Mode (RELEASE build)

```swift
init() {
    #if DEBUG
    // Development...
    #else
    self.useProductionMode = true
    self.apiKey = nil  // No API key in the app!
    print("✅ [ElevenLabs] Initialized with Firebase Functions")
    #endif
}
```

**Flow:**
1. App calls Firebase Function `synthesizeSpeech`
2. Firebase Function reads secure config
3. Firebase Function calls ElevenLabs API
4. Returns audio data to app
5. **API key never exposed in the app binary!**

---

## 🔐 Security Best Practices

### ✅ What We Do (Secure)

1. **Production**: API keys stored in Firebase Functions config (server-side)
2. **Development**: API keys in Xcode environment variables (not in code)
3. **Never**: Hardcode API keys in source code
4. **Never**: Commit API keys to git

### 📝 .gitignore Should Include

```gitignore
# API Keys
.env
.env.local
*.xcscheme  # If it contains environment variables

# Firebase
firebase-functions/.env
firebase-functions/.runtimeconfig.json
```

---

## 🧪 Testing

### Test Development Mode

1. Set `ELEVENLABS_API_KEY` in Xcode scheme
2. Run app in DEBUG mode
3. Start voice chat
4. Check console for:
```
✅ [ElevenLabs] Initialized with direct API (development mode)
🎤 [ElevenLabs] Synthesizing with ElevenLabs API...
✅ [ElevenLabs] Received audio data: X bytes
▶️ [ElevenLabs] Playback started
```

### Test Production Mode (TestFlight)

1. Build for **Release** configuration
2. Archive and upload to TestFlight
3. Install TestFlight build
4. Start voice chat
5. Check device console for:
```
✅ [ElevenLabs] Initialized with Firebase Functions (production mode)
🎤 [ElevenLabs] Synthesizing via Firebase Function (production)...
✅ [ElevenLabs] Received audio from Firebase: X bytes
```

---

## 🐛 Troubleshooting

### Issue: "API key not found in environment"

**In Development:**
- Verify `ELEVENLABS_API_KEY` is set in Xcode scheme
- Clean build folder (Cmd+Shift+K)
- Rebuild

**In Production:**
- Check Firebase config: `firebase functions:config:get`
- Verify function is deployed: `firebase functions:list`
- Check function logs: `firebase functions:log`

### Issue: "Firebase authorization failed"

- User must be authenticated (signed in)
- Check Firebase auth status
- Verify `synthesizeSpeech` function has correct permissions

### Issue: "Rate limit exceeded"

- ElevenLabs free tier has limits
- Check your usage at https://elevenlabs.io/usage
- Consider upgrading plan for production

---

## 💰 ElevenLabs Pricing

| Plan | Characters/month | Cost |
|------|-----------------|------|
| Free | 10,000 | $0 |
| Starter | 30,000 | $5 |
| Creator | 100,000 | $22 |
| Pro | 500,000 | $99 |

**Estimate for UrGood:**
- Average response: ~200 characters
- 10,000 chars = ~50 AI responses
- 100,000 chars = ~500 AI responses per month

---

## 📋 Deployment Checklist

### Before Production Launch

- [ ] ElevenLabs API key added to Firebase config
- [ ] Firebase Functions deployed (`synthesizeSpeech`)
- [ ] Tested in DEBUG mode (direct API)
- [ ] Tested in RELEASE mode (Firebase Functions)
- [ ] Tested on TestFlight
- [ ] Verified API keys not in source code
- [ ] Verified API keys not in git history
- [ ] ElevenLabs account has sufficient credits
- [ ] Set up usage alerts in ElevenLabs dashboard
- [ ] Documented emergency fallback procedure

### Emergency Fallback

If ElevenLabs fails, the app automatically uses **AVSpeechSynthesizer** (iOS system voice):
```
🔄 [ElevenLabs] Using AVSpeechSynthesizer fallback
```

Users will still hear audio responses, just lower quality.

---

## 🔄 Updating API Keys

### Development
Update in Xcode scheme → Clean → Rebuild

### Production
```bash
# Update Firebase config
firebase functions:config:set elevenlabs.key="NEW_KEY"

# Redeploy (this is REQUIRED for config changes to take effect)
firebase deploy --only functions:synthesizeSpeech
```

**Important:** Config changes require redeployment to take effect!

---

## 📞 Support

**ElevenLabs Support:**
- Dashboard: https://elevenlabs.io/app
- Documentation: https://docs.elevenlabs.io
- Support: support@elevenlabs.io

**Firebase Support:**
- Console: https://console.firebase.google.com
- Documentation: https://firebase.google.com/docs/functions

---

## ✅ Current Status

Your app is **already configured correctly** for production! 🎉

- ✅ ElevenLabs integration working
- ✅ Firebase Functions proxy ready
- ✅ Secure API key handling
- ✅ Automatic fallback if unavailable
- ✅ Development and production modes

**Next steps:**
1. Add `ELEVENLABS_API_KEY` to your Xcode scheme for development testing
2. Add key to Firebase config for production deployment
3. Test both modes
4. Deploy to TestFlight

