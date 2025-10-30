# 🧪 Complete E2E Test Suite for UrGood Hackathon

## Quick Start

```bash
# Run all E2E tests
./test-e2e.sh

# Run backend tests only
cd backend && npm test -- voice-e2e.test.ts

# Run iOS manual tests
# Follow E2E_TEST_CHECKLIST.md
```

## Test Files Created

1. **`backend/tests/voice-e2e.test.ts`** - Backend E2E tests
2. **`test-e2e.sh`** - Automated test runner script
3. **`E2E_TEST_CHECKLIST.md`** - Manual iOS test checklist

## Test Coverage ✅

### ✅ Backend Tests (Automated)
- Voice authorization endpoint
- Premium subscription validation
- Session start/end tracking
- Soft cap detection (100 minutes)
- Usage counter increments
- End-to-end voice flow

### ✅ iOS Tests (Manual)
- Authentication → RevenueCat sync
- Free user voice access rejection
- Premium user voice flow
- Session tracking verification
- Soft cap UI messaging
- Purchase flow
- Restore purchases

## Running Tests

### 1. Backend Tests

```bash
cd backend

# Install dependencies (if needed)
npm install

# Run all tests
npm test

# Run voice E2E tests only
npm test -- voice-e2e.test.ts

# Run with coverage
npm run test:coverage
```

**Expected Output:**
```
PASS  tests/voice-e2e.test.ts
  Voice Chat E2E Tests
    Voice Authorization
      ✓ should authorize premium user for voice chat
      ✓ should reject free user from voice chat
      ✓ should require authentication
    Voice Session Tracking
      ✓ should track session start
      ✓ should track session end with duration
      ✓ should increment session counters correctly
    Soft Cap Detection
      ✓ should detect soft cap when 100 minutes reached
      ✓ should track soft cap status in session end
    Voice Status Endpoint
      ✓ should return service status
    End-to-End Voice Flow
      ✓ should complete full voice session lifecycle
```

### 2. Automated Test Script

```bash
# Make executable (already done)
chmod +x test-e2e.sh

# Run the script
./test-e2e.sh
```

**What it checks:**
- ✅ Backend availability
- ✅ Database connection
- ✅ Voice integration code
- ✅ RevenueCat configuration
- ✅ iOS build setup
- ✅ Manual endpoint tests

### 3. Manual iOS Tests

Follow **`E2E_TEST_CHECKLIST.md`** for step-by-step manual testing.

**Key test scenarios:**
1. Sign in → Verify RevenueCat sync
2. Free user → Try voice → Should show paywall
3. Premium user → Start voice → Should work
4. Check backend logs → Verify tracking
5. Purchase subscription → Verify access granted
6. Restore purchases → Verify restoration

## Test Results Interpretation

### ✅ All Tests Pass
- Backend endpoints working correctly
- Session tracking functional
- Soft cap detection working
- Ready for submission!

### ⚠️ Some Tests Fail
**Common Issues:**

1. **Backend not running**
   ```bash
   cd backend && npm run dev
   ```

2. **Database not accessible**
   ```bash
   # Check PostgreSQL is running
   pg_isready
   
   # Check connection string in .env
   ```

3. **Missing environment variables**
   - Check `backend/.env` has all required vars
   - Check `urgood/Secrets.xcconfig` has API keys

4. **RevenueCat not configured**
   - Add `REVENUECAT_API_KEY` to `Secrets.xcconfig`
   - Verify dashboard: `main_offering` is current

## Debugging Failed Tests

### Backend Tests Fail

```bash
# Check backend logs
cd backend && npm run dev

# Check database
cd backend && npx prisma studio

# Run single test with verbose output
npm test -- voice-e2e.test.ts --verbose
```

### iOS Tests Fail

1. **Check Xcode console logs**
   - Look for errors prefixed with `❌`
   - Check network request failures

2. **Verify backend connection**
   ```bash
   curl http://localhost:3001/api/v1/voice/status
   ```

3. **Check Firebase authentication**
   - Verify user is signed in
   - Check Firebase ID token is valid

4. **Verify RevenueCat**
   - Check console for RevenueCat logs
   - Verify API key is loaded
   - Check dashboard for test purchases

## Pre-Submission Checklist

Before submitting to hackathon:

- [ ] All backend tests pass (`npm test`)
- [ ] `./test-e2e.sh` shows all checks passing
- [ ] Manual iOS tests completed (see checklist)
- [ ] No console errors in iOS app
- [ ] Backend logs show correct tracking
- [ ] Database records created correctly
- [ ] RevenueCat sandbox purchase tested
- [ ] App builds successfully (`./build.sh --archive`)
- [ ] No crashes in 10+ test runs

## Success Criteria 🎯

**All these must pass:**

1. ✅ Backend voice endpoints respond correctly
2. ✅ Premium users can access voice chat
3. ✅ Free users see paywall
4. ✅ Sessions tracked in database
5. ✅ Soft cap detected and shown
6. ✅ RevenueCat syncs on auth
7. ✅ Purchase flow works
8. ✅ App builds without errors

## Files Created

```
urgood/
├── backend/
│   └── tests/
│       └── voice-e2e.test.ts     # Backend E2E tests
├── test-e2e.sh                    # Automated test runner
├── E2E_TEST_CHECKLIST.md          # Manual iOS checklist
└── HACKATHON_CRITICAL_PATH_COMPLETE.md  # Implementation summary
```

## Next Steps

1. **Run automated tests:**
   ```bash
   ./test-e2e.sh
   ```

2. **Run backend tests:**
   ```bash
   cd backend && npm test -- voice-e2e.test.ts
   ```

3. **Complete manual iOS tests:**
   - Follow `E2E_TEST_CHECKLIST.md`

4. **Fix any failures:**
   - See debugging section above

5. **Re-test until all pass:**
   - ✅ All tests green
   - ✅ Ready for submission!

## Support

If tests fail, check:
- Backend logs: `cd backend && npm run dev`
- iOS console: Xcode → Debug Area → Console
- Database: `cd backend && npx prisma studio`
- Network: Use Network tab in Xcode debugger

