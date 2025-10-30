# ElevenLabs Voice Integration for UrGood Pulse

## Overview

UrGood now uses **ElevenLabs Text-to-Speech** for voice output in the Pulse tab, while keeping OpenAI Realtime for transcription and reasoning. This hybrid approach gives you:

- ✅ **High-quality voice**: ElevenLabs "Rachel" voice with natural intonation
- ✅ **Full OpenAI intelligence**: Keep all transcription and reasoning capabilities
- ✅ **Sequential playback**: Queue management prevents audio overlap
- ✅ **Fallback support**: Automatic fallback to AVSpeechSynthesizer if ElevenLabs fails
- ✅ **Non-blocking**: All audio operations run on background threads

## Architecture

```
User speaks → OpenAI Realtime (STT + Reasoning) → Text Response
                                                        ↓
                                                   ElevenLabs TTS
                                                        ↓
                                                   Audio Playback
```

### Key Components

1. **ElevenLabsService.swift** - Handles TTS API calls, queue management, and fallback
2. **OpenAIRealtimeClient.swift** - Captures text responses and routes to ElevenLabs
3. **APIConfig.swift** - Configuration for ElevenLabs (voice, model, settings)

## Setup Instructions

### Choose Your Deployment Mode

**Development Mode**: Use direct ElevenLabs API with local API key
**Production Mode**: Use Firebase Functions proxy (secure, no key in app)

---

### Development Setup (Local Testing)

1. **Get ElevenLabs API Key**
   - Sign up at [elevenlabs.io](https://elevenlabs.io)
   - Navigate to your profile → API Keys
   - Create a new API key
   - Copy the key

2. **Configure Xcode Environment Variable**
   - In Xcode, select your scheme: **urgood** at the top
   - Click **Product** → **Scheme** → **Edit Scheme...**
   - Select **Run** in the left sidebar
   - Go to **Arguments** tab
   - Under **Environment Variables**, click **+**
   - Add:
     - **Name**: `ELEVENLABS_API_KEY`
     - **Value**: `your_api_key_here`
   - Click **Close**

---

### Production Setup (Firebase Functions)

For production deployment, follow the comprehensive guide:
**See: `ELEVENLABS_PRODUCTION_DEPLOYMENT.md`**

Quick steps:
1. Get ElevenLabs API key from [elevenlabs.io](https://elevenlabs.io)
2. Set in Firebase:
   ```bash
   firebase functions:config:set elevenlabs.key="YOUR_KEY"
   ```
3. Deploy function:
   ```bash
   firebase deploy --only functions:synthesizeSpeech
   ```
4. Build production iOS app - it automatically uses Firebase Functions!

**Benefits**:
- ✅ API key never exposed in app
- ✅ Authentication & rate limiting built-in
- ✅ Usage tracking & analytics
- ✅ Easy key rotation

### 3. Verify Configuration

The app will automatically detect the ElevenLabs API key on launch:

```swift
// In APIConfig.swift
static var elevenLabsAPIKey: String? {
    return ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"]
}

static var useElevenLabs: Bool {
    return elevenLabsAPIKey != nil && !elevenLabsAPIKey!.isEmpty
}
```

## How It Works

### 1. Voice Chat Initialization

When user starts voice chat:

```swift
// VoiceChatService.swift
func startVoiceChat() async {
    // 1. Request microphone permission
    // 2. Fetch OpenAI API key from Firebase Functions
    // 3. Create OpenAIRealtimeClient (which includes ElevenLabsService)
    // 4. Connect to OpenAI Realtime API
    // 5. Start listening
}
```

### 2. Real-time Conversation Flow

```
User speaks
    ↓
OpenAI Realtime captures audio → Transcribes → Reasons
    ↓
Sends text response back
    ↓
OpenAIRealtimeClient receives transcript
    ↓
Routes to ElevenLabsService.synthesizeAndQueue()
    ↓
ElevenLabs API converts text to audio
    ↓
Audio plays through AVAudioPlayer
```

### 3. Queue Management

The `ElevenLabsService` includes built-in queue management:

- Multiple text chunks are queued automatically
- Audio plays sequentially without overlap
- Queue is cleared on disconnect

### 4. Fallback Behavior

If ElevenLabs fails or key is missing:

```swift
// Automatic fallback to AVSpeechSynthesizer
if useFallback || apiKey == nil {
    await synthesizeWithFallback(text: item.text)
}
```

## API Configuration

### Current Settings

In `APIConfig.swift`:

```swift
// Voice ID for Rachel
static let elevenLabsVoiceId = "21m00Tcm4TlvDq8ikWAM"

// Model
static let elevenLabsModel = "eleven_multilingual_v2"

// Voice settings
static let elevenLabsStability = 0.35
static let elevenLabsSimilarityBoost = 0.85
```

### Available Voices

To change the voice, update `elevenLabsVoiceId` in `APIConfig.swift`:

- **Rachel** (default): `21m00Tcm4TlvDq8ikWAM` - Young, clear, professional
- **Bella**: `EXAVITQu4vr4xnSDxMaL` - Soft, calm, therapeutic
- **Domi**: `AZnzlk1XvdvUeBnXmlld` - Strong, confident, supportive
- **Elli**: `MF3mGyEYCl7XYWbV9V6O` - Energetic, friendly, Gen Z
- **Josh**: `TxGEqnHWrfWFTfGW9XjX` - Warm, mature, reassuring

## Testing

### End-to-End Test

1. **Launch the app** in Xcode with the environment variable set
2. **Check console** for initialization message:
   ```
   ✅ [Realtime] Using ElevenLabs for voice output
   ```
3. **Navigate to Pulse tab** (voice chat)
4. **Start voice chat** by tapping the mic button
5. **Speak to Nova**: "Hey, how are you?"
6. **Verify sequence**:
   ```
   🎤 [Realtime] User started speaking
   🎤 [Realtime] User stopped speaking
   📝 [Realtime] Transcript: [your text]
   🎤 [Realtime] Sending to ElevenLabs: [response text]
   🎙️ [ElevenLabs] Queuing text for synthesis
   ▶️ [ElevenLabs] Processing queue with 1 items
   🎤 [ElevenLabs] Synthesizing with ElevenLabs API...
   📡 [ElevenLabs] Response status: 200
   ✅ [ElevenLabs] Received audio data: [bytes]
   🔊 [ElevenLabs] Playing audio...
   ▶️ [ElevenLabs] Playback started, duration: [X]s
   ✅ [ElevenLabs] Playback complete
   ```

### Test Fallback

1. **Remove or invalidate** the `ELEVENLABS_API_KEY` environment variable
2. **Launch the app**
3. **Check console** for fallback message:
   ```
   ⚠️ [ElevenLabs] API key not found in environment, will use fallback
   ℹ️ [Realtime] ElevenLabs not configured, will use fallback synthesis
   ```
4. **Start voice chat** - should still work with AVSpeechSynthesizer

### Test Queue Management

1. Have a conversation that generates multiple responses quickly
2. Verify audio plays sequentially without overlap
3. Test disconnecting mid-playback - queue should clear

## Troubleshooting

### "API key not found" Warning

**Problem**: Console shows `⚠️ [ElevenLabs] API key not found in environment`

**Solution**: 
- Check that you added the environment variable in Edit Scheme
- Restart Xcode after adding the variable
- Verify the variable name is exactly `ELEVENLABS_API_KEY`

### "Unauthorized" Error (401)

**Problem**: `❌ [ElevenLabs] Response status: 401`

**Solution**:
- Verify your API key is correct
- Check your ElevenLabs account is active
- Ensure you have credits/quota remaining

### "Rate Limit Exceeded" (429)

**Problem**: `❌ [ElevenLabs] Response status: 429`

**Solution**:
- You've exceeded your ElevenLabs quota
- Wait for quota to reset
- Upgrade your ElevenLabs plan
- The app will automatically fall back to AVSpeechSynthesizer

### No Audio Output

**Problem**: Text appears but no audio plays

**Solution**:
- Check device volume and mute switch
- Verify Bluetooth devices aren't interfering
- Check console for audio session errors
- Test with headphones to isolate speaker issues

### Audio Cuts Off Early

**Problem**: Audio starts but stops prematurely

**Solution**:
- Check internet connection stability
- Verify ElevenLabs API response is complete
- Look for AVAudioPlayer errors in console

## Logging

Key log prefixes to watch:

- `🎙️ [ElevenLabs]` - ElevenLabs service events
- `🎤 [Realtime]` - OpenAI Realtime events
- `🔊 [ElevenLabs]` - Audio playback events
- `✅` - Success events
- `❌` - Error events
- `⚠️` - Warning events

## Cost Considerations

### ElevenLabs Pricing

- **Free Tier**: 10,000 characters/month
- **Starter**: $5/month for 30,000 characters
- **Creator**: $22/month for 100,000 characters

### Estimated Usage

Average therapy response: ~100-200 characters

- Free tier: ~50-100 responses/month
- Starter: ~150-300 responses/month
- Creator: ~500-1000 responses/month

### Fallback Strategy

The app automatically falls back to free AVSpeechSynthesizer:
- When ElevenLabs quota is exceeded
- When API key is missing
- On any ElevenLabs error

## Production Deployment

### Environment Variables in Production

**For Production Builds**:

1. Store the ElevenLabs API key in your backend
2. Create a secure endpoint to proxy ElevenLabs requests
3. Update `ElevenLabsService.swift` to call your backend instead of direct API

**Example backend endpoint**:

```swift
// Instead of direct ElevenLabs call
let url = URL(string: "\(APIConfig.backendURL)/api/voice/synthesize")

// Your backend calls ElevenLabs with stored key
// Returns audio data to app
```

### Security Best Practices

1. ⚠️ **Never** commit API keys to Git
2. ⚠️ **Never** hardcode keys in source files
3. ✅ Use environment variables for development
4. ✅ Use secure backend proxy for production
5. ✅ Implement rate limiting on your backend
6. ✅ Monitor usage and costs

## Next Steps

1. ✅ Test the integration locally
2. ✅ Verify fallback behavior works
3. ✅ Monitor console logs during testing
4. ⏭️ Create backend proxy for production (when ready)
5. ⏭️ Set up usage monitoring and alerts
6. ⏭️ Test on physical device with various network conditions

## Support

- ElevenLabs Docs: https://docs.elevenlabs.io/api-reference/text-to-speech
- ElevenLabs Support: support@elevenlabs.io
- Voice Library: https://elevenlabs.io/voice-library

---

**Implementation Complete! 🎉**

The voice chat now uses ElevenLabs for natural, high-quality audio while keeping OpenAI's powerful reasoning and transcription capabilities. Start testing and enjoy the improved voice experience!

