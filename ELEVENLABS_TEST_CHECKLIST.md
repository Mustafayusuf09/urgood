# ElevenLabs Integration Test Checklist

## Pre-Test Setup ✓

- [ ] Sign up for ElevenLabs account at [elevenlabs.io](https://elevenlabs.io)
- [ ] Get API key from ElevenLabs dashboard
- [ ] Add `ELEVENLABS_API_KEY` to Xcode scheme environment variables
- [ ] Restart Xcode after adding the variable

## Quick Test (5 minutes)

### 1. Launch Test
```
Expected Console Output:
✅ [ElevenLabs] Initialized with API key
✅ [Realtime] Using ElevenLabs for voice output
```

- [ ] Launch app in Xcode
- [ ] Check console for initialization messages
- [ ] No errors during startup

### 2. Connection Test
```
Expected Console Output:
🔌 [Realtime] Connecting to OpenAI Realtime API...
✅ [Realtime] Got API key from Firebase Functions
✅ [Realtime] Connected successfully
⚙️ [Realtime] Configuring session...
✅ [Realtime] Session configured (modalities: ["text"])
```

- [ ] Navigate to Pulse tab (voice chat)
- [ ] Tap mic button to start
- [ ] Verify connection messages appear
- [ ] Session configured with text-only modality

### 3. Voice Input Test
```
Expected Console Output:
🎤 [Realtime] User started speaking
🎤 [Realtime] User stopped speaking
📝 [Realtime] Transcript: [your words]
```

- [ ] Grant microphone permission
- [ ] Speak clearly: "Hey Nova, how are you today?"
- [ ] Wait for transcription to appear
- [ ] Transcript is accurate

### 4. ElevenLabs Synthesis Test
```
Expected Console Output:
📝 [Realtime] Full transcript: [Nova's response]
🎤 [Realtime] Sending to ElevenLabs: [response text]
🎙️ [ElevenLabs] Queuing text for synthesis
▶️ [ElevenLabs] Processing queue with 1 items
🎤 [ElevenLabs] Synthesizing with ElevenLabs API...
📡 [ElevenLabs] Response status: 200
✅ [ElevenLabs] Received audio data: [X bytes]
🔊 [ElevenLabs] Playing audio...
▶️ [ElevenLabs] Playback started, duration: [X]s
✅ [ElevenLabs] Playback complete
```

- [ ] Wait for Nova's response
- [ ] Hear Rachel's voice (ElevenLabs)
- [ ] Voice is clear and natural
- [ ] No audio cutting or distortion
- [ ] Playback completes successfully

### 5. Multi-Turn Test
```
Test multiple exchanges in sequence
```

- [ ] Have 3-4 exchanges with Nova
- [ ] Each response plays completely
- [ ] No audio overlap between responses
- [ ] Queue management works correctly

## Fallback Test (3 minutes)

### 1. Remove API Key
- [ ] Edit scheme and remove `ELEVENLABS_API_KEY`
- [ ] Restart app

### 2. Verify Fallback
```
Expected Console Output:
⚠️ [ElevenLabs] API key not found in environment, will use fallback
ℹ️ [Realtime] ElevenLabs not configured, will use fallback synthesis
```

- [ ] Console shows fallback messages
- [ ] Start voice chat
- [ ] Speak to Nova
- [ ] Hear AVSpeechSynthesizer voice (iOS default)
- [ ] Voice chat still works

### 3. Restore API Key
- [ ] Add `ELEVENLABS_API_KEY` back to scheme
- [ ] Restart app
- [ ] Verify ElevenLabs voice returns

## Edge Case Tests (5 minutes)

### 1. Network Interruption
- [ ] Start conversation
- [ ] Enable Airplane Mode mid-response
- [ ] Verify graceful error handling
- [ ] Re-enable network
- [ ] Verify recovery

### 2. Long Response Test
- [ ] Ask: "Can you explain the benefits of CBT therapy in detail?"
- [ ] Verify long response plays completely
- [ ] No timeout or truncation

### 3. Quick Succession Test
- [ ] Speak immediately after Nova starts responding
- [ ] Verify interruption handling
- [ ] No audio glitches

### 4. Background/Foreground Test
- [ ] Start voice chat
- [ ] Switch to another app mid-conversation
- [ ] Return to UrGood
- [ ] Verify audio continues or resumes gracefully

## Performance Test (2 minutes)

### Latency Check
- [ ] Measure time from "you stop speaking" to "audio starts"
- [ ] Target: < 2 seconds for synthesis
- [ ] Target: < 3 seconds total (including OpenAI processing)

### Audio Quality Check
- [ ] Test with headphones
- [ ] Test with device speaker
- [ ] Test with Bluetooth speaker
- [ ] Audio clear on all outputs

## Production Readiness (Before Launch)

### Security
- [ ] API key NOT in source code
- [ ] API key NOT in Info.plist
- [ ] API key only in environment/backend
- [ ] No keys committed to Git

### Monitoring
- [ ] Set up usage tracking
- [ ] Set up error alerts
- [ ] Monitor ElevenLabs quota
- [ ] Plan for quota exceeded scenario

### Documentation
- [ ] Team knows how to test locally
- [ ] Backend team has proxy endpoint spec
- [ ] Support team has troubleshooting guide

## Common Issues & Solutions

### Issue: "API key not found"
**Solution**: 
1. Edit Scheme → Run → Arguments → Environment Variables
2. Add `ELEVENLABS_API_KEY` with your key
3. Restart Xcode

### Issue: "Response status: 401"
**Solution**: 
1. Verify API key is correct
2. Check ElevenLabs account is active
3. Ensure you have credits

### Issue: No audio output
**Solution**:
1. Check device volume
2. Check mute switch
3. Try with headphones
4. Check Bluetooth connections
5. Review audio session errors in console

### Issue: Audio cuts off
**Solution**:
1. Check internet stability
2. Verify ElevenLabs response complete
3. Look for AVAudioPlayer errors
4. Test with shorter responses

## Test Results

Date: ___________
Tester: ___________

Quick Test: ⬜ Pass ⬜ Fail
Fallback Test: ⬜ Pass ⬜ Fail
Edge Cases: ⬜ Pass ⬜ Fail
Performance: ⬜ Pass ⬜ Fail

Notes:
_______________________________________
_______________________________________
_______________________________________

---

## Next Steps After Testing

1. [ ] Document any issues found
2. [ ] Test on physical device (not just simulator)
3. [ ] Test with different network speeds (WiFi, 5G, 4G)
4. [ ] Get feedback from test users on voice quality
5. [ ] Monitor ElevenLabs usage and costs
6. [ ] Plan production backend proxy implementation

