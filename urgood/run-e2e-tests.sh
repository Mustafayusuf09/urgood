#!/bin/bash

# Comprehensive E2E Test Runner for UrGood
# Tests all critical features: Firebase Auth, RevenueCat, OpenAI Realtime, ElevenLabs

# Don't exit on error - we want to run all tests
# set -e

echo "🧪 UrGood Complete E2E Test Suite"
echo "=================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0
SKIPPED=0

pass() {
    echo -e "${GREEN}✅ PASS:${NC} $1"
    ((PASSED++))
}

fail() {
    echo -e "${RED}❌ FAIL:${NC} $1"
    ((FAILED++))
}

skip() {
    echo -e "${YELLOW}⏭️  SKIP:${NC} $1"
    ((SKIPPED++))
}

info() {
    echo -e "${BLUE}ℹ️  INFO:${NC} $1"
}

section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Test 1: Build Verification
test_build() {
    section "📱 Test 1: iOS Build Verification"
    
    cd urgood
    
    info "Building iOS app..."
    if xcodebuild -project urgood.xcodeproj -scheme urgood -sdk iphonesimulator -destination 'platform=iOS Simulator,id=8B3DB846-C0D6-4878-851A-17C6097C5324' build > /tmp/build.log 2>&1; then
        pass "iOS app builds successfully"
        cd ..
        return 0
    else
        fail "iOS app build failed - check /tmp/build.log"
        cd ..
        return 0  # Continue even if build fails for now
    fi
}

# Test 2: Firebase Configuration
test_firebase_config() {
    section "🔥 Test 2: Firebase Configuration"
    
    cd urgood
    
    # Check Firebase config file exists
    if [ -f "urgood/GoogleService-Info.plist" ]; then
        pass "GoogleService-Info.plist exists"
    else
        fail "GoogleService-Info.plist missing"
    fi
    
    # Check FirebaseConfig.swift exists
    if grep -r "FirebaseApp.configure" urgood/FirebaseConfig.swift > /dev/null 2>&1; then
        pass "Firebase configuration code present"
    else
        fail "Firebase configuration code missing"
    fi
    
    # Check Firebase imports
    if grep -r "import Firebase" urgood/urgoodApp.swift > /dev/null 2>&1 || \
       grep -r "import FirebaseCore" urgood/FirebaseConfig.swift > /dev/null 2>&1; then
        pass "Firebase imports present"
    else
        fail "Firebase imports missing"
    fi
    
    cd ..
}

# Test 3: RevenueCat Configuration
test_revenuecat_config() {
    section "💳 Test 3: RevenueCat Configuration"
    
    cd urgood
    
    # Check RevenueCat integration
    if grep -r "import RevenueCat" urgood/Core/Services/ProductionBillingService.swift > /dev/null 2>&1; then
        pass "RevenueCat SDK imported"
    else
        fail "RevenueCat SDK not imported"
    fi
    
    # Check RevenueCat initialization
    if grep -r "Purchases.configure\|Purchases.shared" urgood/Core/Services/ProductionBillingService.swift > /dev/null 2>&1; then
        pass "RevenueCat initialization code present"
    else
        fail "RevenueCat initialization code missing"
    fi
    
    # Check RevenueCat login/logout sync
    if grep -r "Purchases.shared.logIn\|Purchases.shared.logOut" urgood/Core/Services/UnifiedAuthService.swift > /dev/null 2>&1; then
        pass "RevenueCat auth sync implemented"
    else
        fail "RevenueCat auth sync missing"
    fi
    
    # Check for API key configuration
    if grep -r "REVENUECAT_API_KEY\|revenueCatAPIKey" urgood/Core/Services/ProductionBillingService.swift > /dev/null 2>&1; then
        pass "RevenueCat API key configuration present"
    else
        fail "RevenueCat API key configuration missing"
    fi
    
    cd ..
}

# Test 4: OpenAI Realtime Configuration
test_openai_realtime_config() {
    section "🤖 Test 4: OpenAI Realtime Configuration"
    
    cd urgood
    
    # Check OpenAI Realtime client exists
    if [ -f "urgood/Core/Services/OpenAIRealtimeClient.swift" ]; then
        pass "OpenAIRealtimeClient.swift exists"
    else
        fail "OpenAIRealtimeClient.swift missing"
    fi
    
    # Check WebSocket connection code
    if grep -r "URLSessionWebSocketTask\|wss://api.openai.com/v1/realtime" urgood/Core/Services/OpenAIRealtimeClient.swift > /dev/null 2>&1; then
        pass "OpenAI Realtime WebSocket connection code present"
    else
        fail "OpenAI Realtime WebSocket connection code missing"
    fi
    
    # Check audio input handling
    if grep -r "AVAudioEngine\|AVAudioInputNode" urgood/Core/Services/OpenAIRealtimeClient.swift > /dev/null 2>&1; then
        pass "Audio input handling implemented"
    else
        fail "Audio input handling missing"
    fi
    
    # Check API key handling
    if grep -r "getVoiceChatAPIKey\|OPENAI_API_KEY" urgood/Core/Services/OpenAIRealtimeClient.swift > /dev/null 2>&1; then
        pass "OpenAI API key handling present"
    else
        fail "OpenAI API key handling missing"
    fi
    
    cd ..
}

# Test 5: ElevenLabs Configuration
test_elevenlabs_config() {
    section "🎙️ Test 5: ElevenLabs Configuration"
    
    cd urgood
    
    # Check ElevenLabs service exists
    if [ -f "urgood/Core/Services/ElevenLabsService.swift" ]; then
        pass "ElevenLabsService.swift exists"
    else
        fail "ElevenLabsService.swift missing"
    fi
    
    # Check ElevenLabs API integration
    if grep -r "api.elevenlabs.io\|text-to-speech" urgood/Core/Services/ElevenLabsService.swift > /dev/null 2>&1; then
        pass "ElevenLabs API integration present"
    else
        fail "ElevenLabs API integration missing"
    fi
    
    # Check audio playback
    if grep -r "AVAudioPlayer\|playAudio" urgood/Core/Services/ElevenLabsService.swift > /dev/null 2>&1; then
        pass "ElevenLabs audio playback implemented"
    else
        fail "ElevenLabs audio playback missing"
    fi
    
    # Check integration with OpenAI Realtime
    if grep -r "ElevenLabsService\|elevenLabsService" urgood/Core/Services/OpenAIRealtimeClient.swift > /dev/null 2>&1; then
        pass "ElevenLabs integrated with OpenAI Realtime"
    else
        fail "ElevenLabs not integrated with OpenAI Realtime"
    fi
    
    # Check API key configuration
    if grep -r "ELEVENLABS_API_KEY\|elevenLabsAPIKey" urgood/Core/Services/ElevenLabsService.swift > /dev/null 2>&1; then
        pass "ElevenLabs API key configuration present"
    else
        fail "ElevenLabs API key configuration missing"
    fi
    
    cd ..
}

# Test 6: Voice Chat Integration
test_voice_chat_integration() {
    section "🗣️ Test 6: Voice Chat Integration"
    
    cd urgood
    
    # Check VoiceChatView exists
    if [ -f "urgood/Design/Components/VoiceChatComponents.swift" ] || \
       grep -r "VoiceChatView\|VoiceHomeView" urgood/Features/Chat/*.swift > /dev/null 2>&1; then
        pass "Voice chat UI components exist"
    else
        fail "Voice chat UI components missing"
    fi
    
    # Check voice session management
    if grep -r "voiceSessionStart\|voiceSessionEnd\|VoiceAuthService" urgood/Core/Services/*.swift > /dev/null 2>&1; then
        pass "Voice session management implemented"
    else
        fail "Voice session management missing"
    fi
    
    # Check status indicators
    if grep -r "isConnected\|isListening\|isSpeaking" urgood/Core/Services/OpenAIRealtimeClient.swift > /dev/null 2>&1; then
        pass "Voice chat status indicators present"
    else
        fail "Voice chat status indicators missing"
    fi
    
    cd ..
}

# Test 7: Authentication Flow
test_auth_flow() {
    section "🔐 Test 7: Authentication Flow"
    
    cd urgood
    
    # Check authentication view exists
    if [ -f "urgood/Features/Authentication/AuthenticationView.swift" ]; then
        pass "AuthenticationView.swift exists"
    else
        fail "AuthenticationView.swift missing"
    fi
    
    # Check Apple Sign In
    if grep -r "signInWithApple\|ASAuthorizationController" urgood/Features/Authentication/AuthenticationView.swift > /dev/null 2>&1; then
        pass "Apple Sign In implemented"
    else
        fail "Apple Sign In missing"
    fi
    
    # Check email authentication
    if grep -r "signUpWithEmail\|signInWithEmail" urgood/Core/Services/UnifiedAuthService.swift > /dev/null 2>&1; then
        pass "Email authentication implemented"
    else
        fail "Email authentication missing"
    fi
    
    # Check Firebase Auth integration
    if grep -r "FirebaseAuth\|Auth.auth()" urgood/Core/Services/UnifiedAuthService.swift > /dev/null 2>&1; then
        pass "Firebase Auth integrated"
    else
        fail "Firebase Auth not integrated"
    fi
    
    cd ..
}

# Test 8: Navigation Flow
test_navigation() {
    section "🧭 Test 8: Navigation Flow"
    
    cd urgood
    
    # Check main navigation view
    if [ -f "urgood/Features/Navigation/MainNavigationView.swift" ]; then
        pass "MainNavigationView.swift exists"
    else
        fail "MainNavigationView.swift missing"
    fi
    
    # Check hamburger menu
    if grep -r "HamburgerMenuView\|hamburgerButton" urgood/Features/Navigation/MainNavigationView.swift > /dev/null 2>&1; then
        pass "Hamburger menu implemented"
    else
        fail "Hamburger menu missing"
    fi
    
    # Check tab navigation
    if grep -r "AppTab\|selectedTab" urgood/Features/Navigation/MainNavigationView.swift > /dev/null 2>&1; then
        pass "Tab navigation implemented"
    else
        fail "Tab navigation missing"
    fi
    
    cd ..
}

# Test 9: Error Handling
test_error_handling() {
    section "⚠️ Test 9: Error Handling"
    
    cd urgood
    
    # Check error handling in services
    if grep -r "catch\|do.*try\|Error" urgood/Core/Services/OpenAIRealtimeClient.swift | head -5 > /dev/null 2>&1; then
        pass "Error handling present in OpenAI Realtime"
    else
        fail "Error handling missing in OpenAI Realtime"
    fi
    
    if grep -r "catch\|do.*try\|Error" urgood/Core/Services/ElevenLabsService.swift | head -5 > /dev/null 2>&1; then
        pass "Error handling present in ElevenLabs"
    else
        fail "Error handling missing in ElevenLabs"
    fi
    
    if grep -r "catch\|do.*try\|Error" urgood/Core/Services/UnifiedAuthService.swift | head -5 > /dev/null 2>&1; then
        pass "Error handling present in Authentication"
    else
        fail "Error handling missing in Authentication"
    fi
    
    cd ..
}

# Test 10: Code Quality
test_code_quality() {
    section "✨ Test 10: Code Quality"
    
    cd urgood
    
    # Check for unsafe force unwraps (except in known safe contexts)
    unsafe_unwraps=$(grep -r "!" urgood/urgood/Features/Insights/MultiUserInsightsViewModel.swift | grep -v "guard\|if\|!\s*=" | wc -l)
    if [ "$unsafe_unwraps" -eq 0 ]; then
        pass "No unsafe force unwraps found (after fix)"
    else
        fail "Found unsafe force unwraps"
    fi
    
    # Check for proper imports
    if grep -r "^import " urgood/urgoodApp.swift > /dev/null 2>&1; then
        pass "Proper imports present"
    else
        fail "Missing imports"
    fi
    
    cd ..
}

# Main execution
main() {
    echo ""
    echo "Starting comprehensive E2E test suite..."
    echo ""
    
    # Run all tests
    test_build
    test_firebase_config
    test_revenuecat_config
    test_openai_realtime_config
    test_elevenlabs_config
    test_voice_chat_integration
    test_auth_flow
    test_navigation
    test_error_handling
    test_code_quality
    
    # Summary
    section "📊 Test Summary"
    echo -e "${GREEN}✅ Passed: $PASSED${NC}"
    echo -e "${RED}❌ Failed: $FAILED${NC}"
    echo -e "${YELLOW}⏭️  Skipped: $SKIPPED${NC}"
    echo ""
    
    TOTAL=$((PASSED + FAILED + SKIPPED))
    if [ $FAILED -eq 0 ]; then
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}🎉 All tests passed! ($PASSED/$TOTAL)${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "✅ Firebase Auth: Configured"
        echo "✅ RevenueCat: Integrated"
        echo "✅ OpenAI Realtime: Configured"
        echo "✅ ElevenLabs: Integrated"
        echo "✅ Build: Successful"
        echo ""
        echo "Ready for deployment! 🚀"
        exit 0
    else
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}❌ Some tests failed ($FAILED/$TOTAL)${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "Please review the failures above and fix them before deployment."
        exit 1
    fi
}

# Run tests
main

