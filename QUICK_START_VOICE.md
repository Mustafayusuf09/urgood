# Quick Start: Get Voice Working in 2 Minutes

## For Development (Testing in Xcode)

### 1. Get Your ElevenLabs API Key
- Go to https://elevenlabs.io/app/settings
- Copy your API key

### 2. Add to Xcode
1. Click **urgood** scheme dropdown (next to play button)
2. Select **"Edit Scheme..."**
3. Click **"Run"** → **"Arguments"** tab
4. Under **"Environment Variables"**, click **+**
5. Add:
   ```
   Name: ELEVENLABS_API_KEY
   Value: [paste your key here]
   ```
6. Click **Close**

### 3. Rebuild & Test
1. Press **Cmd+Shift+K** (Clean Build Folder)
2. Press **Cmd+R** (Run)
3. Start voice chat
4. **You should hear the AI speaking!**

---

## For Production (TestFlight/App Store)

### 1. Configure Firebase Functions

```bash
cd firebase-functions
firebase functions:config:set elevenlabs.key="YOUR_API_KEY"
firebase deploy --only functions:synthesizeSpeech
```

### 2. Build for Release
- The app automatically uses Firebase Functions in production
- No API key needed in the app binary
- Secure and production-ready!

---

## Verify It's Working

**Console should show:**
```
✅ [ElevenLabs] Initialized with direct API (development mode)
🎤 [ElevenLabs] Synthesizing with ElevenLabs API...
✅ [ElevenLabs] Received audio data: 50000 bytes
▶️ [ElevenLabs] Playback started, duration: 3.5s
✅ [ElevenLabs] Playback complete
```

**If you see:**
```
⚠️ [ElevenLabs] API key not found in environment
```
→ Go back to step 2 and add the key to Xcode scheme

---

## Done! 🎉

Your AI should now speak with high-quality ElevenLabs voices!

