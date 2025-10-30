# Voice Output Fix Guide

## Issue: AI Not Speaking (No Audio Output)

The AI text responses are generated but you can't hear the voice output.

---

## How the System Works

### Voice Flow
```
User speaks → Whisper transcribes → GPT-4o responds → ElevenLabs synthesizes → Audio plays
```

### Key Components

1. **OpenAIRealtimeClient** - Manages WebSocket connection to OpenAI
2. **ElevenLabsService** - Converts text responses to speech
3. **APIConfig** - Configuration for both services

---

## Quick Fixes to Try

### Fix 1: Check ElevenLabs Configuration

The system is configured to use ElevenLabs for voice output. Check if it's working:

1. Look for these log messages when you start voice chat:
   ```
   ✅ [Realtime] Using ElevenLabs for voice output
   🎤 [Realtime] Sending to ElevenLabs: [text]...
   ✅ [ElevenLabs] Received audio data: X bytes
   ▶️ [ElevenLabs] Playback started
   ```

2. If you see **fallback mode**:
   ```
   🔄 [ElevenLabs] Using AVSpeechSynthesizer fallback
   ```
   This means ElevenLabs isn't configured, but you should still hear audio using the iOS system voice.

### Fix 2: Add ElevenLabs API Key (Development Only)

If you're testing in development mode (DEBUG build):

**In Xcode:**
1. Go to **Product → Scheme → Edit Scheme**
2. Select **Run** → **Arguments** tab
3. In **Environment Variables**, add:
   - Name: `ELEVENLABS_API_KEY`
   - Value: Your ElevenLabs API key from https://elevenlabs.io

**Or add to your `.env` file** (if using):
```bash
ELEVENLABS_API_KEY=your_key_here
```

### Fix 3: Production Mode (Uses Firebase Functions)

In production (Release build), the app automatically uses Firebase Functions to securely call ElevenLabs.

**Verify Firebase Functions setup:**
1. Check that `synthesizeSpeech` function is deployed
2. Run: `firebase functions:list` to see deployed functions
3. Check function logs: `firebase functions:log --only synthesizeSpeech`

---

## Debugging Steps

### 1. Enable Debug Logging

The code already has extensive logging. Check the Xcode console for:

**Connection logs:**
```
🔌 [Realtime] Connecting to OpenAI Realtime API...
✅ [Realtime] Connected successfully
```

**Transcription logs:**
```
📝 [Realtime] Full transcript: [user's speech]
```

**Voice synthesis logs:**
```
🎤 [Realtime] Sending to ElevenLabs: [AI response]...
✅ [ElevenLabs] Received audio data: X bytes
▶️ [ElevenLabs] Playback started, duration: Xs
```

### 2. Check Audio Permissions

The app should already request microphone permission. Verify:
1. Go to **Settings → Privacy → Microphone**
2. Ensure **UrGood** is enabled

### 3. Check Audio Session

The ElevenLabsService configures audio session for playback:
```swift
.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetoothA2DP])
```

**Test:**
- Try with headphones
- Try with speaker phone
- Check device volume

### 4. Test Voice Synthesis Directly

You can test if ElevenLabs is working by checking the console logs when AI responds.

**Look for:**
- ✅ Success indicators
- ❌ Error messages
- 🔄 Fallback usage

---

## Common Issues & Solutions

### Issue: "ElevenLabs API key not configured"

**Solution:** Add the API key as described in Fix #2 above, or use production mode with Firebase Functions.

### Issue: "Playback failed"

**Possible causes:**
1. Audio format incompatibility
2. Audio session not configured
3. Device volume muted

**Solution:**
- Check device volume
- Try restarting the app
- Check console for specific error messages

### Issue: "Firebase authorization failed"

**Solution:**
1. Ensure user is logged in
2. Check Firebase Functions are deployed
3. Verify `authorizeVoiceChat` function works

### Issue: Audio cuts off or doesn't play

**Possible causes:**
1. Audio queue processing issue
2. Player lifecycle issue

**Solution:**
- The system uses an audio queue for sequential playback
- Check if `isPlayingQueue` is stuck in true state
- Try stopping and restarting voice chat

---

## System Architecture

### Current Configuration

```swift
// In APIConfig.swift
static var useElevenLabs: Bool {
    #if DEBUG
    return elevenLabsAPIKey != nil && !elevenLabsAPIKey!.isEmpty
    #else
    return true // Production always uses ElevenLabs via Firebase
    #endif
}
```

### Voice Synthesis Flow

```
OpenAI generates text response
         ↓
OpenAIRealtimeClient receives transcript
         ↓
Checks: useElevenLabs == true ?
         ↓
    YES: Send to ElevenLabsService
         ↓
ElevenLabsService checks mode:
  - Production: Call Firebase Function
  - Development: Call ElevenLabs API directly
  - Fallback: Use AVSpeechSynthesizer
         ↓
Audio data returned
         ↓
AVAudioPlayer plays audio
         ↓
User hears response
```

---

## Testing Checklist

- [ ] **Console shows AI response text** (proves OpenAI is working)
- [ ] **Console shows "Sending to ElevenLabs"** (proves text is being sent)
- [ ] **Console shows "Received audio data"** (proves synthesis worked)
- [ ] **Console shows "Playback started"** (proves audio player started)
- [ ] **Can hear audio** (proves everything works end-to-end)

**If all checks pass except the last one:**
- Check device volume
- Check audio output (speaker/headphones)
- Check if other apps can play audio
- Restart device

---

## Quick Test Script

To quickly test if voice output works, look for this exact sequence in the console:

```
1. 📝 [Realtime] Full transcript: [AI's text response]
2. 🎤 [Realtime] Sending to ElevenLabs: [first 50 chars]...
3. ✅ [ElevenLabs] Received audio data: [number] bytes
4. 🔊 [ElevenLabs] Playing audio...
5. ▶️ [ElevenLabs] Playback started, duration: [X]s
6. ✅ [ElevenLabs] Playback complete
```

**If you see all 6 steps**, the system is working correctly and the issue is likely:
- Device volume
- Audio routing (check if audio is going to wrong output)
- Hardware issue

**If you don't see step 2**, the issue is in OpenAIRealtimeClient configuration.

**If you don't see step 3**, the issue is ElevenLabs API or Firebase Functions.

**If you don't see steps 4-6**, the issue is audio playback.

---

## Manual Fix: Force Fallback Voice

If ElevenLabs isn't working and you need voice output immediately:

The system automatically falls back to AVSpeechSynthesizer if ElevenLabs fails. You should hear a robotic but functional voice.

**To test fallback mode:**
1. Don't set `ELEVENLABS_API_KEY` in development
2. The system will automatically use fallback
3. Look for: `🔄 [ElevenLabs] Using AVSpeechSynthesizer fallback`

---

## Production Deployment

For production (TestFlight/App Store):

1. **Firebase Functions must be deployed:**
   ```bash
   cd firebase-functions
   firebase deploy --only functions:synthesizeSpeech
   ```

2. **Set ElevenLabs API key in Firebase:**
   ```bash
   firebase functions:config:set elevenlabs.key="YOUR_KEY"
   ```

3. **Verify deployment:**
   ```bash
   firebase functions:config:get
   ```

---

## Additional Notes

### Why ElevenLabs?
- Higher quality than OpenAI TTS
- More natural-sounding voices
- Better for Gen Z audience
- Emotional and expressive

### Fallback Strategy
- System automatically falls back to iOS system voice if ElevenLabs fails
- Users will still get audio output, just lower quality
- No manual intervention needed

### Future Improvements
- Add voice quality indicator in UI
- Show when using fallback mode
- Add manual voice quality selection
- Cache frequently used phrases

---

## Support

If you're still experiencing issues:

1. **Check the console logs** - They tell you exactly what's happening
2. **Test with fallback** - Proves audio playback works
3. **Test ElevenLabs separately** - Use their web interface to verify API key
4. **Check Firebase Functions** - Run the function manually to test

The system is designed to always provide audio output, even if the primary method (ElevenLabs) fails.

