#!/bin/bash

# Build script for UrGood iOS app
# Handles device selection automatically

set -e

echo "🔨 Building UrGood iOS app..."

# Find available iPhone simulator
DEVICE_ID=$(xcrun simctl list devices available | grep "iPhone" | grep -v "iPad" | head -1 | sed 's/.*(\([^)]*\)).*/\1/')

if [ -z "$DEVICE_ID" ]; then
    echo "❌ No iPhone simulator found. Please create one in Xcode."
    exit 1
fi

DEVICE_NAME=$(xcrun simctl list devices available | grep "iPhone" | grep -v "iPad" | head -1 | sed 's/\(.*\) (.*/\1/' | xargs)
echo "📱 Using device: $DEVICE_NAME ($DEVICE_ID)"

# Build for simulator
echo "🔨 Building for simulator..."
xcodebuild clean build \
    -project urgood.xcodeproj \
    -scheme urgood \
    -sdk iphonesimulator \
    -destination "id=$DEVICE_ID" \
    CODE_SIGNING_ALLOWED=NO \
    | xcpretty || exit 1

echo "✅ Build completed successfully!"

# Optional: Archive for submission
if [ "$1" == "--archive" ]; then
    echo "📦 Creating archive..."
    xcodebuild archive \
        -project urgood.xcodeproj \
        -scheme urgood \
        -archivePath "./build/urgood.xcarchive" \
        -destination "generic/platform=iOS" \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        | xcpretty || exit 1
    
    echo "✅ Archive created at ./build/urgood.xcarchive"
fi

