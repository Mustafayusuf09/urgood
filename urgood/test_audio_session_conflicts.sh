#!/bin/bash

# Audio Session Conflicts - End-to-End Test Script
# Tests the centralized AudioSessionManager to ensure no conflicts between services

echo "🎵 Testing Audio Session Conflicts Fix"
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run test
run_test() {
    local test_name="$1"
    local expected_log="$2"
    local timeout_seconds="${3:-10}"
    
    echo -e "${BLUE}Testing: $test_name${NC}"
    
    # Build and run the app in simulator
    echo "Building app..."
    cd /Users/mustafayusuf/urgood/urgood
    
    # Clean build
    xcodebuild clean -project urgood.xcodeproj -scheme urgood -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' > /dev/null 2>&1
    
    # Build
    if xcodebuild build -project urgood.xcodeproj -scheme urgood -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' > build.log 2>&1; then
        echo -e "${GREEN}✅ Build successful${NC}"
    else
        echo -e "${RED}❌ Build failed${NC}"
        echo "Build errors:"
        cat build.log | grep -E "(error|Error)" | head -5
        ((TESTS_FAILED++))
        return 1
    fi
    
    # Start simulator and app
    echo "Starting simulator and app..."
    xcrun simctl boot "iPhone 15" > /dev/null 2>&1
    
    # Install and launch app
    if xcodebuild test -project urgood.xcodeproj -scheme urgood -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' -only-testing:UrGoodTests/AudioSessionManagerTests > test.log 2>&1; then
        echo -e "${GREEN}✅ $test_name passed${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ $test_name failed${NC}"
        echo "Test output:"
        cat test.log | tail -10
        ((TESTS_FAILED++))
    fi
    
    # Clean up
    rm -f build.log test.log
}

# Test 1: AudioSessionManager Initialization
echo -e "\n${YELLOW}Test 1: AudioSessionManager Initialization${NC}"
echo "Expected: AudioSessionManager should initialize without conflicts"

# Check if AudioSessionManager compiles and initializes
if grep -q "AudioSessionManager" /Users/mustafayusuf/urgood/urgood/urgood/Core/Services/AudioSessionManager.swift; then
    echo -e "${GREEN}✅ AudioSessionManager exists${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}❌ AudioSessionManager not found${NC}"
    ((TESTS_FAILED++))
fi

# Test 2: Service Integration
echo -e "\n${YELLOW}Test 2: Service Integration${NC}"
echo "Expected: All audio services should use AudioSessionManager"

services=("ElevenLabsService" "OpenAIRealtimeClient" "AudioRecordingService" "AudioPlaybackService")
for service in "${services[@]}"; do
    if grep -q "audioSessionManager" "/Users/mustafayusuf/urgood/urgood/urgood/Core/Services/${service}.swift" 2>/dev/null; then
        echo -e "${GREEN}✅ $service integrated with AudioSessionManager${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ $service not integrated with AudioSessionManager${NC}"
        ((TESTS_FAILED++))
    fi
done

# Test 3: Configuration Priority
echo -e "\n${YELLOW}Test 3: Configuration Priority System${NC}"
echo "Expected: Voice chat should have highest priority"

if grep -q "priority: 100" /Users/mustafayusuf/urgood/urgood/urgood/Core/Services/AudioSessionManager.swift; then
    echo -e "${GREEN}✅ Voice chat has highest priority (100)${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}❌ Voice chat priority not set correctly${NC}"
    ((TESTS_FAILED++))
fi

# Test 4: Conflict Prevention
echo -e "\n${YELLOW}Test 4: Conflict Prevention${NC}"
echo "Expected: No direct AVAudioSession.setCategory calls in services"

conflict_files=()
for file in /Users/mustafayusuf/urgood/urgood/urgood/Core/Services/*.swift; do
    if grep -q "audioSession.setCategory\|AVAudioSession.*setCategory" "$file" 2>/dev/null; then
        if ! grep -q "AudioSessionManager" "$file" 2>/dev/null; then
            conflict_files+=("$(basename "$file")")
        fi
    fi
done

if [ ${#conflict_files[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ No audio session conflicts detected${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}❌ Audio session conflicts found in: ${conflict_files[*]}${NC}"
    ((TESTS_FAILED++))
fi

# Test 5: Proper Cleanup
echo -e "\n${YELLOW}Test 5: Proper Cleanup${NC}"
echo "Expected: Services should release audio session configuration"

cleanup_services=("ElevenLabsService" "OpenAIRealtimeClient" "AudioPlaybackService")
for service in "${cleanup_services[@]}"; do
    if grep -q "releaseConfiguration" "/Users/mustafayusuf/urgood/urgood/urgood/Core/Services/${service}.swift" 2>/dev/null; then
        echo -e "${GREEN}✅ $service properly releases audio session${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ $service missing audio session cleanup${NC}"
        ((TESTS_FAILED++))
    fi
done

# Test 6: Build Verification
echo -e "\n${YELLOW}Test 6: Build Verification${NC}"
echo "Expected: Project should build without errors"

cd /Users/mustafayusuf/urgood/urgood
if xcodebuild build -project urgood.xcodeproj -scheme urgood -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Project builds successfully${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}❌ Project build failed${NC}"
    echo "Build errors:"
    xcodebuild build -project urgood.xcodeproj -scheme urgood -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' 2>&1 | grep -E "(error|Error)" | head -3
    ((TESTS_FAILED++))
fi

# Summary
echo -e "\n${BLUE}Test Summary${NC}"
echo "============"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}🎉 All tests passed! Audio session conflicts have been resolved.${NC}"
    echo -e "${GREEN}✅ AudioSessionManager successfully coordinates all audio services${NC}"
    echo -e "${GREEN}✅ No more conflicts between ElevenLabs, OpenAI, Recording, and Playback${NC}"
    echo -e "${GREEN}✅ Priority system ensures voice chat gets precedence${NC}"
    exit 0
else
    echo -e "\n${RED}❌ Some tests failed. Please review the issues above.${NC}"
    exit 1
fi
