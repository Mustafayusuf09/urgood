# Device Testing Checklist

**For Solana Cypherpunk Hackathon Submission**

This checklist ensures your app works flawlessly on physical devices before demo.

---

## 📱 iPhone Testing (iOS 17.0+)

### ✅ Authentication Flow

- [ ] **Apple Sign In**
  - [ ] Sign in button appears correctly
  - [ ] Apple Sign In modal appears
  - [ ] Authentication completes successfully
  - [ ] User is redirected to main app
  - [ ] Error handling works (user cancellation, network errors)

- [ ] **Email Sign Up**
  - [ ] Sign up form displays correctly
  - [ ] Validation works (email format, password strength)
  - [ ] Account creation succeeds
  - [ ] Email verification prompt appears
  - [ ] Error messages display correctly

- [ ] **Email Sign In**
  - [ ] Sign in form displays correctly
  - [ ] Login succeeds with valid credentials
  - [ ] Error handling for invalid credentials
  - [ ] Password reset flow works

---

### ✅ Voice Chat End-to-End

- [ ] **Microphone Permissions**
  - [ ] Permission prompt appears on first use
  - [ ] App handles permission denial gracefully
  - [ ] Settings shows microphone permission status

- [ ] **Connection Flow**
  - [ ] Tap microphone button
  - [ ] "Connecting..." status appears
  - [ ] Connection succeeds within 10 seconds
  - [ ] Status updates to "Connected! Start talking..."

- [ ] **Voice Input**
  - [ ] Speak into microphone
  - [ ] Audio is captured correctly
  - [ ] Visual feedback shows listening state
  - [ ] Voice activity detection works (auto-stop when silent)

- [ ] **OpenAI Realtime Integration**
  - [ ] Audio sent to OpenAI successfully
  - [ ] Transcription appears in real-time
  - [ ] User transcript displays correctly

- [ ] **ElevenLabs Voice Output**
  - [ ] AI response text received
  - [ ] ElevenLabs synthesis triggers
  - [ ] Audio playback works clearly
  - [ ] No audio glitches or delays
  - [ ] Fallback to system TTS works if ElevenLabs fails

- [ ] **Full Conversation Loop**
  - [ ] Complete back-and-forth conversation works
  - [ ] Multiple exchanges maintain context
  - [ ] Conversation feels natural and responsive
  - [ ] Latency is acceptable (< 2 seconds per turn)

- [ ] **Error Handling**
  - [ ] Network errors handled gracefully
  - [ ] Connection timeout handled
  - [ ] API errors display user-friendly messages
  - [ ] App recovers from errors without crashing

---

### ✅ Nova Assistant Emotional Intelligence

- [ ] **Response Quality**
  - [ ] Responses show emotional intelligence
  - [ ] Uses validation → reflection → challenge → empower pattern
  - [ ] Gen Z tone is authentic (not cringe)
  - [ ] Responses are personalized based on conversation

- [ ] **Crisis Detection**
  - [ ] Detects crisis keywords/phrases
  - [ ] Shows crisis resources appropriately
  - [ ] Displays emergency contact information
  - [ ] Escalates appropriately for critical cases

- [ ] **Context Awareness**
  - [ ] Remembers previous messages in conversation
  - [ ] Personalizes responses based on user history
  - [ ] Maintains conversational flow

---

### ✅ Payment Flow

- [ ] **Paywall Display**
  - [ ] Paywall appears when message limit reached
  - [ ] Subscription plan displays correctly ($24.99/month)
  - [ ] Features list shows correctly
  - [ ] UI is polished and professional

- [ ] **Subscription Flow** (if Stripe test mode enabled)
  - [ ] Subscription button works
  - [ ] Stripe test payment form appears
  - [ ] Test payment completes successfully
  - [ ] User gains premium access
  - [ ] Subscription status updates correctly

- [ ] **Mock Payment** (if test mode not enabled)
  - [ ] Payment UI displays correctly
  - [ ] Can demonstrate payment flow (even if mocked)
  - [ ] UI looks production-ready

---

### ✅ Performance & UX

- [ ] **App Launch**
  - [ ] App launches in < 3 seconds
  - [ ] Loading states display correctly
  - [ ] No white screen or hanging

- [ ] **Voice Chat Performance**
  - [ ] Voice chat latency is acceptable (< 2s per turn)
  - [ ] Audio playback is smooth
  - [ ] No audio glitches or stuttering
  - [ ] Memory usage is reasonable

- [ ] **UI Smoothness**
  - [ ] 60fps scrolling/animations
  - [ ] No jank or lag
  - [ ] Transitions are smooth
  - [ ] No layout glitches

- [ ] **Battery Usage**
  - [ ] Reasonable battery drain during voice chat
  - [ ] App doesn't overheat device
  - [ ] Background activity is minimal

---

### ✅ Edge Cases & Error Handling

- [ ] **Network Issues**
  - [ ] App handles offline mode gracefully
  - [ ] Reconnection works after network loss
  - [ ] Error messages are user-friendly

- [ ] **Audio Issues**
  - [ ] Handles audio session interruptions (calls, music)
  - [ ] Recovers from audio errors
  - [ ] Fallback mechanisms work

- [ ] **Memory Management**
  - [ ] No memory leaks during extended use
  - [ ] App handles memory warnings
  - [ ] Background app state handled correctly

---

## 🎯 Demo-Ready Checklist

Before submitting/demoing:

- [ ] **All above tests pass** ✅
- [ ] **Demo account created** (if needed)
- [ ] **Test data pre-loaded** (sample conversations, moods)
- [ ] **Demo script prepared** (see DEMO_VIDEO_SCRIPT.md)
- [ ] **Backup plan** (if voice chat fails, show text chat)
- [ ] **Device charged** (or charger ready)
- [ ] **WiFi stable** (or hotspot ready)

---

## 📝 Testing Notes

**Device Used:** _________________________  
**iOS Version:** _________________________  
**Date Tested:** _________________________  
**Tester:** _________________________  

**Issues Found:**
- 

**Notes:**
- 

---

## ⚠️ Known Issues

List any known issues that won't block demo:

1. 

---

**Last Updated:** October 2025  
**For:** Solana Cypherpunk Hackathon Submission

