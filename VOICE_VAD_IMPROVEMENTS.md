# Voice Activity Detection (VAD) Improvements

## Problem
The voice chat was responding too quickly and triggering false replies, making conversations feel rushed and unnatural.

## Solution Implemented

### 1. **Higher VAD Threshold (0.5 → 0.8)**
- Located in: `OpenAIRealtimeClient.swift` line 202
- Increased from `0.5` to `0.8` to make speech detection more conservative
- Reduces false positives from background noise

### 2. **Longer Silence Duration (1200ms)**
- Located in: `OpenAIRealtimeClient.swift` line 204
- Set to `1200ms` (1.2 seconds) before AI assumes you're done speaking
- Gives you breathing room to pause and think without interruption

### 3. **-40 dB Noise Gate**
- Located in: `OpenAIRealtimeClient.swift` lines 54, 508-511
- Only sends audio above -40 dB threshold to the API
- Filters out background noise and quiet room ambience
- Prevents false speech detection from environmental sounds

### 4. **Explicit Audio Buffer Commit**
- Located in: `OpenAIRealtimeClient.swift` lines 289-298
- When server VAD detects speech stop, we explicitly commit the buffer
- Tells OpenAI "user is definitely done now, process this"
- Improves turn-taking accuracy

### 5. **VAD State Tracking**
- Located in: `OpenAIRealtimeClient.swift` lines 52-53, 283, 287
- Tracks `isSpeechActive` state based on server VAD events
- Syncs local state with OpenAI's speech detection
- Enables future enhancements (e.g., UI indicators)

### 6. **RMS Level Logging**
- Located in: `OpenAIRealtimeClient.swift` lines 499-505, 555-569
- Calculates RMS (Root Mean Square) audio levels in real-time
- Logs mic levels periodically: `🎤 [Realtime] Mic RMS: -35.2 dB`
- Helps diagnose audio issues and validate noise gate behavior

## Configuration Summary

```swift
turn_detection: {
    type: "server_vad",
    threshold: 0.8,              // Higher = less sensitive
    prefix_padding_ms: 300,      // Include 300ms before speech
    silence_duration_ms: 1200    // Wait 1.2s of silence before responding
}

noiseGateThreshold: -40.0 dB     // Only process audio above this level
```

## Expected Behavior

### Before
- AI responded after 0.5s of silence
- Threshold 0.5 picked up too much background noise
- No local noise filtering
- No explicit buffer commits

### After
- AI waits 1.2s of silence before responding
- Threshold 0.8 requires clearer speech to detect
- -40 dB noise gate filters ambient sound
- Explicit commit when speech ends
- Console logs show RMS levels for debugging

## Console Output Examples

```
🎤 [Realtime] Recording started
🎤 [Realtime] Mic RMS: -42.3 dB
🎤 [Realtime] User started speaking
🎤 [Realtime] Mic RMS: -28.5 dB
🎤 [Realtime] User stopped speaking
✅ [Realtime] Audio buffer committed
📝 [Realtime] Transcript: Hey Nova, I need some help with anxiety
```

## Testing Tips

1. **Check RMS Levels**: Look for `Mic RMS:` logs in console
   - Normal speech: -30 to -10 dB
   - Quiet room: -60 to -50 dB
   - If too low, adjust mic gain or move closer

2. **Watch VAD Events**: Monitor these logs:
   - `User started speaking`
   - `User stopped speaking`
   - `Audio buffer committed`

3. **Adjust if Needed**:
   - If still too sensitive → increase threshold to 0.9
   - If missing speech → decrease threshold to 0.7
   - If interrupting too much → increase silence_duration_ms to 1500
   - If responding too slow → decrease silence_duration_ms to 1000

## Files Modified

- `urgood/urgood/Core/Services/OpenAIRealtimeClient.swift`
  - Added VAD state tracking (lines 52-54)
  - Updated threshold to 0.8 (line 202)
  - Added speech event handlers with buffer commit (lines 281-298)
  - Added noise gate and RMS calculation (lines 495-569)
  - Reset speech state on disconnect/stop (lines 145, 164)

## Related Documentation

- [OpenAI Realtime API - Turn Detection](https://platform.openai.com/docs/guides/realtime)
- [AVAudioEngine Audio Processing](https://developer.apple.com/documentation/avfaudio/avaudioengine)

