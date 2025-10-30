# ElevenLabs TTS - Quick Reference Card

## 🎯 Quick Deploy (Production)

```bash
cd firebase-functions

# Set API key
firebase functions:config:set elevenlabs.key="YOUR_KEY"

# Deploy
firebase deploy --only functions:synthesizeSpeech

# Verify
firebase functions:log --only synthesizeSpeech
```

Done! Your iOS production build now uses secure Firebase proxy.

---

## 🛠️ Development Setup

**Xcode**: Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables

Add:
- **Name**: `ELEVENLABS_API_KEY`
- **Value**: Your key from elevenlabs.io

---

## 📊 Architecture

```
Development: iOS → Direct ElevenLabs API
Production:  iOS → Firebase Function → ElevenLabs API
```

---

## 🔍 Logs to Watch

### iOS Console (Development)
```
✅ [ElevenLabs] Initialized with direct API (development mode)
🎤 [ElevenLabs] Synthesizing with ElevenLabs API...
✅ [ElevenLabs] Received audio data: X bytes
```

### iOS Console (Production)
```
✅ [ElevenLabs] Initialized with Firebase Functions (production mode)
🎤 [ElevenLabs] Synthesizing via Firebase Function (production)...
✅ [ElevenLabs] Received audio from Firebase: X bytes
```

### Firebase Function Logs
```bash
firebase functions:log --only synthesizeSpeech
```

Expected:
```
🎙️ Synthesizing speech for user abc123, text length: 150
✅ Successfully synthesized 45678 bytes of audio
```

---

## 🚨 Common Issues

| Issue | Solution |
|-------|----------|
| "TTS service unavailable" | Run: `firebase functions:config:set elevenlabs.key="KEY"` |
| "Rate limit exceeded" | Expected after 30/min, app uses fallback |
| "Unauthenticated" | User not signed in to Firebase |
| No audio | Check device volume, Bluetooth, logs |

---

## 💰 Costs

**ElevenLabs**:
- Free: 10k chars/month (~66 responses)
- Starter: $5/month for 30k chars (~200 responses)
- Creator: $22/month for 100k chars (~666 responses)

**Firebase**: Free tier covers most usage (2M invocations/month)

---

## 📁 Key Files

| File | Purpose |
|------|---------|
| `ElevenLabsService.swift` | TTS service with queue management |
| `OpenAIRealtimeClient.swift` | Routes text to ElevenLabs |
| `APIConfig.swift` | Configuration & voice settings |
| `voice-only.ts` | Firebase Function (production proxy) |
| `deploy-elevenlabs.sh` | Deployment helper script |

---

## 🧪 Test Commands

```bash
# Test Firebase Function locally
cd firebase-functions
firebase emulators:start --only functions

# Deploy to production
firebase deploy --only functions:synthesizeSpeech

# Check config
firebase functions:config:get

# View logs
firebase functions:log --only synthesizeSpeech

# List all functions
firebase functions:list
```

---

## 🔐 Security Checklist

✅ API key stored in Firebase (not in app)
✅ Authentication required
✅ Rate limiting enabled (30/min)
✅ Input validation (max 5000 chars)
✅ Analytics tracking
✅ Graceful fallback

---

## 📞 Support Links

- **ElevenLabs**: https://elevenlabs.io/app/settings
- **ElevenLabs Docs**: https://docs.elevenlabs.io
- **Firebase Functions**: https://firebase.google.com/docs/functions
- **Voice Library**: https://elevenlabs.io/voice-library

---

## 🎙️ Voice Options

Current: **Rachel** (`21m00Tcm4TlvDq8ikWAM`)

To change, edit `APIConfig.swift`:
```swift
static let elevenLabsVoiceId = "VOICE_ID_HERE"
```

Popular voices:
- Bella: `EXAVITQu4vr4xnSDxMaL` (soft, calm)
- Elli: `MF3mGyEYCl7XYWbV9V6O` (energetic, Gen Z)
- Josh: `TxGEqnHWrfWFTfGW9XjX` (warm, mature)

---

## 📖 Full Documentation

- `ELEVENLABS_VOICE_SETUP.md` - Complete setup
- `ELEVENLABS_PRODUCTION_DEPLOYMENT.md` - Detailed deployment
- `ELEVENLABS_TEST_CHECKLIST.md` - Testing guide
- `PRODUCTION_DEPLOYMENT_SUMMARY.md` - Quick summary
- `ELEVENLABS_IMPLEMENTATION_SUMMARY.md` - Technical details

---

**Questions?** Check the full guides above or contact your team! 🚀

