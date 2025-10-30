#!/bin/sh

set -e

echo "🎉 UrGood CI Post-Build Script"
echo "=============================="

# Check build result
if [ "$CI_XCODEBUILD_EXIT_CODE" = "0" ]; then
    echo "✅ Build succeeded!"
else
    echo "❌ Build failed with exit code: $CI_XCODEBUILD_EXIT_CODE"
    exit $CI_XCODEBUILD_EXIT_CODE
fi

# Print build information
echo ""
echo "📊 Build Information:"
echo "   Action: $CI_XCODEBUILD_ACTION"
echo "   Scheme: $CI_XCODE_SCHEME"
echo "   Configuration: $CI_XCODE_CONFIGURATION"
echo "   Workspace: $CI_WORKSPACE"
echo "   Branch: $CI_BRANCH"
echo "   Tag: $CI_TAG"
echo "   Commit: $CI_COMMIT"

# If this was a test action, report test results
if [ "$CI_XCODEBUILD_ACTION" = "test" ]; then
    echo ""
    echo "🧪 Test Results:"
    
    # Test result bundle location
    if [ -d "$CI_RESULT_BUNDLE_PATH" ]; then
        echo "   Result bundle: $CI_RESULT_BUNDLE_PATH"
        
        # You could parse test results here if needed
        # xcrun xcresulttool get --path "$CI_RESULT_BUNDLE_PATH"
    fi
fi

# If this was an archive action, report archive information
if [ "$CI_XCODEBUILD_ACTION" = "archive" ]; then
    echo ""
    echo "📦 Archive Information:"
    
    if [ -d "$CI_ARCHIVE_PATH" ]; then
        echo "   Archive path: $CI_ARCHIVE_PATH"
        echo "   App size:"
        du -sh "$CI_ARCHIVE_PATH"
    fi
    
    echo ""
    echo "🚀 Ready for TestFlight distribution!"
fi

# Optional: Send notifications (you can add Slack webhooks, etc.)
echo ""
echo "📢 Notifications:"
echo "   Build completed at: $(date)"

# Clean up temporary files if needed
echo ""
echo "🧹 Cleanup..."
# Add any cleanup tasks here

echo ""
echo "✅ Post-build script complete!"
echo "=============================="

