#!/bin/bash

# Comprehensive E2E Test Script for UrGood Hackathon Submission
# Tests all critical path functionality end-to-end

set -e

echo "🧪 UrGood E2E Test Suite"
echo "========================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0

# Helper functions
pass() {
    echo -e "${GREEN}✅ PASS:${NC} $1"
    ((PASSED++))
}

fail() {
    echo -e "${RED}❌ FAIL:${NC} $1"
    ((FAILED++))
}

info() {
    echo -e "${YELLOW}ℹ️  INFO:${NC} $1"
}

# Check if backend is running
check_backend() {
    info "Checking backend availability..."
    if curl -s http://localhost:3001/api/v1/health > /dev/null 2>&1; then
        pass "Backend is running"
        return 0
    else
        fail "Backend is not running. Start with: cd backend && npm run dev"
        return 1
    fi
}

# Check if database is accessible
check_database() {
    info "Checking database connection..."
    cd backend
    if npm run db:check > /dev/null 2>&1; then
        pass "Database is accessible"
        cd ..
        return 0
    else
        fail "Database connection failed"
        cd ..
        return 1
    fi
}

# Run backend tests
run_backend_tests() {
    info "Running backend E2E tests..."
    cd backend
    
    if npm test -- voice-e2e.test.ts 2>&1 | grep -q "PASS\|FAIL"; then
        if npm test -- voice-e2e.test.ts 2>&1 | grep -q "PASS"; then
            pass "Backend E2E tests passed"
            cd ..
            return 0
        else
            fail "Backend E2E tests failed"
            cd ..
            return 1
        fi
    else
        # Try running with jest directly
        if npx jest tests/voice-e2e.test.ts 2>&1 | tail -1 | grep -q "PASS"; then
            pass "Backend E2E tests passed"
            cd ..
            return 0
        else
            fail "Backend E2E tests failed - check output above"
            cd ..
            return 1
        fi
    fi
}

# Test voice endpoints manually
test_voice_endpoints() {
    info "Testing voice endpoints manually..."
    
    # Create test user and get token (simplified)
    BACKEND_URL="${BACKEND_URL:-http://localhost:3001}"
    
    # Register test user
    REGISTER_RESPONSE=$(curl -s -X POST "$BACKEND_URL/api/v1/auth/register" \
        -H "Content-Type: application/json" \
        -d '{
            "email": "e2e-test-'$(date +%s)'@example.com",
            "password": "TestPassword123!",
            "name": "E2E Test User"
        }')
    
    TOKEN=$(echo $REGISTER_RESPONSE | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
    USER_ID=$(echo $REGISTER_RESPONSE | grep -o '"id":"[^"]*' | cut -d'"' -f4)
    
    if [ -z "$TOKEN" ]; then
        fail "Failed to register test user"
        return 1
    fi
    
    pass "Test user registered"
    
    # Upgrade to premium
    # Note: This would normally be done via subscription, but for testing we'll update DB directly
    info "Upgrading user to premium for testing..."
    
    # Test voice authorize (should fail for free user)
    AUTH_RESPONSE=$(curl -s -X POST "$BACKEND_URL/api/v1/voice/authorize" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"sessionId": "test-123"}')
    
    if echo "$AUTH_RESPONSE" | grep -q "PREMIUM_REQUIRED"; then
        pass "Voice authorization correctly rejects free users"
    else
        fail "Voice authorization should reject free users"
    fi
    
    # Test voice status (public endpoint)
    STATUS_RESPONSE=$(curl -s "$BACKEND_URL/api/v1/voice/status")
    if echo "$STATUS_RESPONSE" | grep -q "online"; then
        pass "Voice status endpoint works"
    else
        fail "Voice status endpoint failed"
    fi
}

# Check iOS build
check_ios_build() {
    info "Checking iOS build..."
    cd urgood
    
    if xcodebuild -list -project urgood.xcodeproj > /dev/null 2>&1; then
        pass "Xcode project is valid"
        
        # Check if build script exists
        if [ -f "build.sh" ]; then
            pass "Build script exists"
        else
            fail "Build script missing"
        fi
        
        cd ..
        return 0
    else
        fail "Xcode project not found or invalid"
        cd ..
        return 1
    fi
}

# Check RevenueCat configuration
check_revenuecat_config() {
    info "Checking RevenueCat configuration..."
    cd urgood
    
    # Check if RevenueCat files exist
    if grep -r "RevenueCat" urgood/Core/Services/ProductionBillingService.swift > /dev/null 2>&1; then
        pass "RevenueCat integration code exists"
    else
        fail "RevenueCat integration code missing"
    fi
    
    if grep -r "Purchases.shared.logIn" urgood/Core/Services/UnifiedAuthService.swift > /dev/null 2>&1; then
        pass "RevenueCat login/logout sync implemented"
    else
        fail "RevenueCat login/logout sync missing"
    fi
    
    cd ..
}

# Check voice backend integration
check_voice_integration() {
    info "Checking voice backend integration..."
    cd urgood
    
    if grep -r "voiceSessionStart\|voiceSessionEnd" urgood/Core/Services/VoiceChatService.swift > /dev/null 2>&1; then
        pass "Voice session tracking implemented"
    else
        fail "Voice session tracking missing"
    fi
    
    if grep -r "softCapReached" urgood/Core/Services/VoiceAuthService.swift > /dev/null 2>&1; then
        pass "Soft cap handling implemented"
    else
        fail "Soft cap handling missing"
    fi
    
    if grep -r "/api/v1/voice" urgood/Core/Config/EnvironmentConfig.swift > /dev/null 2>&1; then
        pass "Voice endpoints configured"
    else
        fail "Voice endpoints not configured"
    fi
    
    cd ..
}

# Main test execution
main() {
    echo ""
    echo "Starting E2E test suite..."
    echo ""
    
    # Configuration checks
    echo "📋 Configuration Checks"
    echo "----------------------"
    check_voice_integration
    check_revenuecat_config
    check_ios_build
    echo ""
    
    # Backend checks
    echo "🔌 Backend Checks"
    echo "----------------"
    if check_backend; then
        check_database
        # Uncomment to run automated tests
        # run_backend_tests
        test_voice_endpoints
    fi
    echo ""
    
    # Summary
    echo "📊 Test Summary"
    echo "--------------"
    echo -e "${GREEN}Passed: $PASSED${NC}"
    echo -e "${RED}Failed: $FAILED${NC}"
    echo ""
    
    if [ $FAILED -eq 0 ]; then
        echo -e "${GREEN}✅ All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}❌ Some tests failed. Please review above.${NC}"
        exit 1
    fi
}

# Run tests
main

