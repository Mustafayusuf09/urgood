# iOS E2E Test Checklist

## Pre-Test Setup ✅

### 1. Configuration
- [ ] `REVENUECAT_API_KEY` added to `Secrets.xcconfig`
- [ ] `OPENAI_API_KEY` configured
- [ ] Backend URL set correctly (`https://api.urgood.app` for production)
- [ ] Firebase project configured

### 2. RevenueCat Dashboard
- [ ] `main_offering` created and set as "current offering"
- [ ] Product `urgood_core_monthly` created ($24.99/month)
- [ ] Entitlement `premium` created
- [ ] Product attached to `premium` entitlement
- [ ] Offering includes the product

## Test Flow 🧪

### Test 1: Authentication → RevenueCat Sync
1. **Open app**
2. **Sign in with Apple** (or email)
   - ✅ Check console logs for: `✅ RevenueCat login successful`
   - ✅ Check console logs for entitlements status
3. **Sign out**
   - ✅ Check console logs for: `✅ RevenueCat logout successful`

**Expected Result:** RevenueCat logs in/out syncs with Firebase auth

---

### Test 2: Voice Chat - Free User (Should Fail)
1. **Sign in as free user** (default registration)
2. **Navigate to Voice Chat**
3. **Tap to start voice chat**
   - ✅ Should show paywall
   - ✅ Error message: "Voice chat requires premium subscription"
   - ✅ Console shows: `❌ [VoiceChat] Premium subscription required`

**Expected Result:** Free users cannot access voice chat

---

### Test 3: Voice Chat - Premium User (Full Flow)
1. **Sign in as premium user** (or purchase subscription)
2. **Navigate to Voice Chat**
3. **Tap to start voice chat**
   - ✅ Check console logs:
     - `🎙️ [VoiceAuth] Session started: <session-id>`
     - `✅ [VoiceChat] Backend session started`
     - `✅ [VoiceChat] API key authorized`
   - ✅ Status message shows: "Connected! Start talking..."
4. **Speak into microphone**
   - ✅ AI responds
   - ✅ Transcripts appear
   - ✅ Status shows: "Listening..." or "UrGood is speaking..."
5. **End session** (tap stop or close)
   - ✅ Check console logs:
     - `🎙️ [VoiceAuth] Session ended: <session-id>, duration: <X>s`
   - ✅ Status resets

**Expected Result:** Full voice session works end-to-end

---

### Test 4: Session Tracking Verification
1. **Start voice session** (as premium user)
2. **Wait 30 seconds**
3. **End session**
4. **Check backend logs** or database:
   - ✅ `VoiceUsage` record created/updated
   - ✅ `sessionsStarted` incremented
   - ✅ `sessionsCompleted` incremented
   - ✅ `secondsUsed` includes session duration

**Expected Result:** Session usage tracked in database

---

### Test 5: Soft Cap Detection
1. **Check current usage** (via backend or admin panel)
2. **If under 100 minutes:** Start multiple sessions until near limit
3. **If near limit:** Start one more session
4. **Check UI:**
   - ✅ Status message shows: "(soft cap reached)"
   - ✅ Soft cap warning appears
5. **Try to start another session:**
   - ✅ Still works (soft cap, not hard cap)
   - ✅ Status indicates soft cap reached

**Expected Result:** Soft cap detected and shown in UI

---

### Test 6: Purchase Flow (RevenueCat)
1. **Sign in as free user**
2. **Navigate to paywall** (via voice chat or settings)
3. **Tap "Start daily sessions"**
4. **Complete purchase** (sandbox account)
   - ✅ RevenueCat purchase flow appears
   - ✅ Product shown: "$24.99/month"
5. **Complete purchase**
   - ✅ Check console logs:
     - `✅ Purchase success handled - user upgraded to premium`
   - ✅ User profile shows premium status
   - ✅ Voice chat now accessible

**Expected Result:** Purchase flow works, entitlement grants access

---

### Test 7: Restore Purchases
1. **Sign out**
2. **Sign in with different account**
3. **Navigate to Settings**
4. **Tap "Restore Purchases"**
   - ✅ If purchases exist: User restored to premium
   - ✅ If no purchases: Shows "No purchases found"
   - ✅ Console logs restore attempt

**Expected Result:** Restore purchases works correctly

---

### Test 8: Text Chat (Verification)
1. **Sign in** (free or premium)
2. **Navigate to text chat**
3. **Send message**
   - ✅ AI responds
   - ✅ Message saved
4. **Check daily limit** (if free user)
   - ✅ After 10 messages: Should show limit reached

**Expected Result:** Text chat works with limits

---

## Automated Checks 🔍

### Run from Terminal:
```bash
# Test backend endpoints
curl http://localhost:3001/api/v1/voice/status

# Run E2E test script
./test-e2e.sh

# Run backend tests
cd backend && npm test -- voice-e2e.test.ts
```

---

## Common Issues & Fixes 🛠️

### Issue: "RevenueCat API key missing"
**Fix:** Add `REVENUECAT_API_KEY` to `Secrets.xcconfig`

### Issue: "Voice chat requires premium subscription" (premium user)
**Fix:** 
- Check RevenueCat dashboard: User has active entitlement
- Check backend: User `subscriptionStatus` is `PREMIUM_MONTHLY`
- Verify RevenueCat logIn called on auth

### Issue: "Failed to authorize voice chat"
**Fix:**
- Check backend is running
- Check Firebase ID token is valid
- Check backend logs for errors

### Issue: Session not tracking
**Fix:**
- Check backend logs for session/start and session/end calls
- Verify network requests in Xcode debugger
- Check database for VoiceUsage records

### Issue: Build fails
**Fix:**
- Run `./build.sh` (uses auto-detected devices)
- Check Xcode for specific errors
- Verify all dependencies installed

---

## Success Criteria ✅

All tests should pass:
- ✅ RevenueCat syncs on auth state changes
- ✅ Free users cannot access voice chat
- ✅ Premium users can start/end voice sessions
- ✅ Sessions tracked in backend database
- ✅ Soft cap detected and shown in UI
- ✅ Purchase flow works end-to-end
- ✅ Restore purchases works
- ✅ Text chat works with limits

---

## Debug Commands 🔧

```bash
# Check backend logs
cd backend && npm run dev

# Check database
cd backend && npx prisma studio

# Check iOS logs
# In Xcode: View → Debug Area → Activate Console

# Test voice endpoints manually
curl -X POST http://localhost:3001/api/v1/voice/authorize \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"sessionId": "test-123"}'
```

---

## Final Verification ✅

Before submission:
- [ ] All tests pass
- [ ] No console errors
- [ ] Backend logs show correct tracking
- [ ] Database records created correctly
- [ ] RevenueCat dashboard shows test purchases
- [ ] App builds successfully (`./build.sh --archive`)
- [ ] No crashes in 10+ test runs

