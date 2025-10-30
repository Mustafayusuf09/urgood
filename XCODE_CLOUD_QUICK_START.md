# Xcode Cloud Quick Start 🚀

Hey! Here's the TL;DR for getting Xcode Cloud up and running with UrGood.

## What You Need
- Apple Developer account (paid membership)
- GitHub repo already connected ✅
- Xcode 14+ installed ✅

## 5-Minute Setup

### 1. Open Xcode
```bash
cd /Users/mustafayusuf/urgood/urgood
open urgood.xcodeproj
```

### 2. Navigate to Xcode Cloud
In Xcode menu:
```
Product → Xcode Cloud → Create Workflow
```

### 3. Connect to GitHub
- Select repository: `Mustafayusuf09/urgood`
- Click **Authorize**
- Install the Xcode Cloud GitHub App when prompted

### 4. Create Your First Workflow

#### Option A: Use the Default Workflow (Easiest)
1. Xcode will suggest a default workflow
2. Click **Create Workflow**
3. Done! 🎉

#### Option B: Custom Workflow (Recommended)
1. Click **Create Workflow**
2. Set these options:
   - **Name:** "CI - Build & Test"
   - **Trigger:** Branch Changes → `main`
   - **Actions:** 
     - ✅ Build
     - ✅ Test
   - **Environment:** Latest Xcode, iPhone 15 Pro simulator

### 5. Add Your API Keys

In Xcode Cloud workflow settings:
1. Click **Environment** tab
2. Add these as **Secret** variables:

```
OPENAI_API_KEY=sk-...
ELEVENLABS_API_KEY=...
FIREBASE_CONFIG=...
REVENUECAT_API_KEY=...
```

**Important:** Check the "Secret" checkbox for each! 🔐

### 6. Configure Signing

1. In workflow, go to **Archive** section
2. Select **Automatic** signing
3. Choose your team
4. Save

### 7. Trigger First Build

Push to GitHub:
```bash
git add .
git commit -m "chore: Add Xcode Cloud configuration"
git push origin main
```

Or manually in Xcode:
```
Product → Xcode Cloud → Start Build
```

## What Gets Built Automatically

✅ **On every push to `main`:**
- Builds the app
- Runs unit tests
- Runs UI tests
- Shows results in Xcode

✅ **On pull requests:**
- Builds and tests
- Shows status check on GitHub

✅ **On tags (v*.*.*):**
- Builds for release
- Archives the app
- Uploads to TestFlight (when configured)

## Monitoring Builds

### In Xcode:
```
Product → Xcode Cloud → Show Workflow
```

### In App Store Connect:
Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → Your App → Xcode Cloud

## Troubleshooting

### "Repository not found"
- Make sure you authorized the GitHub App
- Check repo permissions in GitHub Settings → Applications → Xcode Cloud

### "Build failed: Signing error"
- Add your Apple ID in Xcode preferences
- Verify your team in project settings
- Use Automatic signing

### "Missing API keys"
- Double-check environment variables in workflow settings
- Make sure they're marked as "Secret"
- Restart the build

### "Tests failing"
- Run tests locally first: `Cmd + U`
- Check simulator version matches
- Verify test data is available

## CI Scripts Explained

The `ci_scripts` folder contains scripts that run during Xcode Cloud builds:

- **ci_post_clone.sh**: Runs after code is cloned
  - Sets up environment
  - Creates Secrets.xcconfig
  - Verifies project structure

- **ci_post_xcodebuild.sh**: Runs after build completes
  - Reports build results
  - Handles test results
  - Manages archives

These run automatically—you don't need to do anything! ✨

## Next Steps

1. ✅ Get first build passing
2. Add TestFlight workflow for releases
3. Set up notifications (Slack/Email)
4. Configure branch protection rules on GitHub

## Resources

- [Full Setup Guide](./urgood/XCODE_CLOUD_SETUP.md)
- [Xcode Cloud Docs](https://developer.apple.com/xcode-cloud/)
- [CI/CD Best Practices](https://developer.apple.com/documentation/xcode/managing-builds)

---

**Need help?** Check the full guide at `urgood/XCODE_CLOUD_SETUP.md` for detailed instructions.

Let's ship it! 🚢

