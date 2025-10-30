# Xcode Cloud Setup Guide for UrGood

## Overview
This guide will help you set up Xcode Cloud for automated building, testing, and deployment of UrGood.

## Prerequisites
- ✅ GitHub repository connected (https://github.com/Mustafayusuf09/urgood)
- [ ] Active Apple Developer Program membership
- [ ] Xcode 14+ installed
- [ ] Admin access to your Apple Developer account

## Step 1: Enable Xcode Cloud in App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Click on your app (UrGood)
3. Navigate to **Xcode Cloud** tab
4. Click **Get Started**

## Step 2: Connect GitHub Repository in Xcode

1. Open `urgood.xcodeproj` in Xcode
2. Go to **Product → Xcode Cloud → Manage Workflows**
3. Click **Create Workflow**
4. Select your GitHub repository: `Mustafayusuf09/urgood`
5. Authorize Xcode Cloud to access your GitHub repository

### GitHub App Installation
Xcode Cloud will prompt you to install the GitHub App:
- Grant access to the `urgood` repository
- Allow Xcode Cloud to read code and commit statuses
- This enables automatic builds on push/PR

## Step 3: Configure Workflows

### Workflow 1: Continuous Integration (CI)
**Purpose:** Build and test on every push

```yaml
Name: CI - Build & Test
Trigger: 
  - Push to main branch
  - Pull requests
Actions:
  1. Build urgood scheme
  2. Run unit tests (UrGoodTests)
  3. Run UI tests (UrGoodUITests)
Environment:
  - Xcode: Latest Release
  - iOS Simulator: iPhone 15 Pro (iOS 17.0+)
```

### Workflow 2: TestFlight Distribution
**Purpose:** Distribute to TestFlight on tags

```yaml
Name: TestFlight Release
Trigger:
  - Tags matching: v*.*.*
Actions:
  1. Build urgood scheme
  2. Run tests
  3. Archive for distribution
  4. Upload to TestFlight
Environment:
  - Xcode: Latest Release
Post-Actions:
  - Notify team on Slack/Email
```

### Workflow 3: Nightly Builds
**Purpose:** Daily smoke tests

```yaml
Name: Nightly Build
Trigger:
  - Schedule: Every day at 2 AM UTC
Actions:
  1. Build urgood scheme
  2. Run integration tests
  3. Generate test report
```

## Step 4: Configure Environment Variables & Secrets

### In Xcode Cloud Settings:

1. Go to **Product → Xcode Cloud → Manage Workflows**
2. Select your workflow
3. Click **Environment** tab
4. Add the following secrets:

#### Required Secrets:
```
OPENAI_API_KEY=your_openai_key
ELEVENLABS_API_KEY=your_elevenlabs_key
FIREBASE_CONFIG=your_firebase_config
REVENUECAT_API_KEY=your_revenuecat_key
```

### Setting Secrets:
- Click **+ Environment Variable**
- Name: `OPENAI_API_KEY`
- Value: Your actual API key
- Check **Secret** ✓
- Repeat for all keys

## Step 5: Configure Code Signing

### Automatic Signing (Recommended):
1. In Xcode Cloud workflow settings
2. Go to **Archive** step
3. Select **Automatic** code signing
4. Choose your team and provisioning profile

### Manual Signing:
If you need specific certificates:
1. Upload certificates to App Store Connect
2. Create provisioning profiles
3. Select them in Xcode Cloud settings

## Step 6: Create ci_scripts (Custom Build Scripts)

Create a `ci_scripts` folder at the project root for custom Xcode Cloud scripts:

### File: `ci_scripts/ci_post_clone.sh`
```bash
#!/bin/sh

# Install dependencies
echo "Installing dependencies..."

# If you use CocoaPods
# pod install

# If you use Swift Package Manager (already handled by Xcode Cloud)

# Set up environment from secrets
echo "Setting up environment variables..."
echo "OPENAI_API_KEY=$OPENAI_API_KEY" >> urgood/urgood/.env
echo "ELEVENLABS_API_KEY=$ELEVENLABS_API_KEY" >> urgood/urgood/.env

# Create Secrets.xcconfig from environment
cat > urgood/Secrets.xcconfig << EOF
OPENAI_API_KEY = $OPENAI_API_KEY
ELEVENLABS_API_KEY = $ELEVENLABS_API_KEY
FIREBASE_CONFIG = $FIREBASE_CONFIG
REVENUECAT_API_KEY = $REVENUECAT_API_KEY
EOF

echo "✅ Setup complete!"
```

### File: `ci_scripts/ci_post_xcodebuild.sh`
```bash
#!/bin/sh

# Run after build
echo "Build completed successfully!"

# Optional: Send notifications, upload artifacts, etc.
```

## Step 7: Start Your First Build

### Via Git Push:
```bash
git add .
git commit -m "feat: Add Xcode Cloud configuration"
git push origin main
```

### Via Xcode:
1. **Product → Xcode Cloud → Start Build**
2. Select workflow
3. Choose branch/tag
4. Click **Start Build**

## Step 8: Monitor Builds

### In Xcode:
- **Product → Xcode Cloud → Show Workflow**
- View build logs, test results, and archives

### In App Store Connect:
- Navigate to Xcode Cloud tab
- View build history, analytics, and trends

## Workflow Configuration Tips

### Optimize Build Times:
```yaml
Cache:
  - Swift Package Manager dependencies
  - Derived Data (when possible)
```

### Branch Strategies:
- **main**: Runs CI on every push
- **develop**: Runs full test suite
- **feature/***: Runs quick tests only
- **release/***: Builds and deploys to TestFlight

### Notifications:
Configure in Xcode Cloud settings:
- Email on build failures
- Slack webhook for team updates
- GitHub commit status checks

## Troubleshooting

### Build Failing?
1. Check logs in Xcode Cloud
2. Verify all secrets are set correctly
3. Ensure signing certificates are valid
4. Check Xcode version compatibility

### Tests Failing?
1. Run tests locally first: `cmd + U`
2. Check simulator version matches
3. Verify test data and mocks

### Secrets Not Working?
1. Confirm secrets are marked as "Secret" in settings
2. Check environment variable names (case-sensitive)
3. Verify ci_scripts has execute permissions

## Commands to Set Execute Permissions

```bash
chmod +x ci_scripts/ci_post_clone.sh
chmod +x ci_scripts/ci_post_xcodebuild.sh
```

## Next Steps

1. ✅ Enable Xcode Cloud in App Store Connect
2. ✅ Connect GitHub repository
3. ✅ Create workflows
4. ✅ Add environment secrets
5. ✅ Configure code signing
6. ✅ Add ci_scripts
7. ✅ Push and trigger first build
8. 📊 Monitor and optimize

## Resources

- [Xcode Cloud Documentation](https://developer.apple.com/xcode-cloud/)
- [Workflow Configuration](https://developer.apple.com/documentation/xcode/xcode-cloud-workflow-reference)
- [CI/CD Best Practices](https://developer.apple.com/documentation/xcode/managing-builds)

---

**Pro Tip:** Start with just the CI workflow, get it working, then add TestFlight and nightly builds. One step at a time! 🚀

