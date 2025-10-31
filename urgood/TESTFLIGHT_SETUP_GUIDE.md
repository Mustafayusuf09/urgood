# 🧪 TestFlight Beta Testing Setup Guide

Complete guide for setting up TestFlight beta testing for UrGood.

## 📋 Prerequisites

### Required Accounts & Memberships
- ✅ **Apple Developer Program** membership ($99/year)
- ✅ **App Store Connect** access
- ✅ **Xcode** with valid signing certificates
- ✅ **RevenueCat** account configured
- ✅ **Firebase** project set up

### App Readiness Checklist
- ✅ App builds successfully for iOS 16.6+
- ✅ All core features functional
- ✅ Subscription system integrated (RevenueCat)
- ✅ Privacy manifest and Info.plist configured
- ✅ App icons and assets in place

## 🚀 Step 1: App Store Connect Setup

### 1.1 Create App Record
1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click **"My Apps"** → **"+"** → **"New App"**
3. Fill in app details:
   - **Platform**: iOS
   - **Name**: UrGood
   - **Primary Language**: English (U.S.)
   - **Bundle ID**: com.urgood.urgood
   - **SKU**: urgood-ios-app

### 1.2 Configure App Information
1. Navigate to **App Information** tab
2. Set **Category**: Health & Fitness
3. Set **Age Rating**: 12+ (Medical/Treatment Information)
4. Add **Privacy Policy URL**: https://urgood.app/privacy
5. Add **Terms of Service URL**: https://urgood.app/terms

### 1.3 Set Up In-App Purchases
1. Go to **Features** → **In-App Purchases**
2. Create **Auto-Renewable Subscription Group**: "Premium Subscriptions"
3. Add subscriptions:

#### Monthly Subscription
- **Product ID**: `urgood_premium_monthly`
- **Reference Name**: UrGood Premium Monthly
- **Subscription Duration**: 1 Month
- **Price**: $12.99 (Tier 13)
- **Display Name**: UrGood Premium
- **Description**: Unlimited AI conversations, advanced insights, and priority support

#### Yearly Subscription
- **Product ID**: `urgood_premium_yearly`
- **Reference Name**: UrGood Premium Yearly
- **Subscription Duration**: 1 Year
- **Price**: $79.99 (Tier 55)
- **Display Name**: UrGood Premium
- **Description**: Unlimited AI conversations, advanced insights, and priority support - Save 48%!

## 🔨 Step 2: Build Preparation

### 2.1 Archive Build for Distribution
```bash
# Navigate to project directory
cd /Users/mustafayusuf/urgood/urgood

# Clean build folder
xcodebuild clean -scheme urgood

# Archive for distribution
xcodebuild archive \
  -scheme urgood \
  -destination "generic/platform=iOS" \
  -archivePath "./build/UrGood.xcarchive"
```

### 2.2 Export for App Store Distribution
1. Open **Xcode** → **Window** → **Organizer**
2. Select the archived build
3. Click **"Distribute App"**
4. Choose **"App Store Connect"**
5. Select **"Upload"**
6. Choose **"Automatically manage signing"**
7. Review and upload

## 📱 Step 3: TestFlight Configuration

### 3.1 Configure TestFlight Settings
1. In App Store Connect, go to **TestFlight** tab
2. Select your uploaded build
3. Configure **Test Information**:
   - **What to Test**: Focus on AI conversations, mood tracking, and subscription flow
   - **Test Details**: Provide testing instructions (see below)
   - **Feedback Email**: testflight@urgood.app
   - **Marketing URL**: https://urgood.app
   - **Privacy Policy URL**: https://urgood.app/privacy

### 3.2 Beta App Review Information
```
BETA TESTING FOCUS AREAS:

1. AI CONVERSATION QUALITY
   - Test various mood states and conversation topics
   - Verify AI responses are appropriate and helpful
   - Check voice chat functionality

2. MOOD TRACKING ACCURACY
   - Complete daily check-ins
   - Verify data persistence and insights
   - Test progress visualization

3. SUBSCRIPTION FLOW
   - Test premium upgrade process
   - Verify feature unlocking
   - Test restore purchases

4. PRIVACY & SECURITY
   - Verify data encryption
   - Test offline functionality
   - Check privacy settings

KNOWN LIMITATIONS:
- AI responses are simulated in beta environment
- Some premium features may have limited functionality
- Voice synthesis may have slight delays

TESTING CREDENTIALS:
- Demo account: beta@urgood.app / BetaTest2025!
- All premium features unlocked for testing
```

### 3.3 Export Compliance
- **Does your app use encryption?**: No
- **ITSAppUsesNonExemptEncryption**: false (already in Info.plist)

## 👥 Step 4: Beta Tester Management

### 4.1 Internal Testing (Apple Developer Team)
1. Go to **TestFlight** → **Internal Testing**
2. Create test group: "UrGood Core Team"
3. Add team members by email:
   - Development team
   - Product managers
   - QA testers

### 4.2 External Testing (Public Beta)
1. Go to **TestFlight** → **External Testing**
2. Create test group: "UrGood Beta Users"
3. Set **Public Link**: Enable for easy distribution
4. Configure **Beta Tester Criteria**:
   - Age: 16+ (matches app requirements)
   - Regions: United States, Canada, UK, Australia
   - Max testers: 1000

### 4.3 Beta Tester Instructions
```
Welcome to UrGood Beta! 🎉

Thank you for helping us test UrGood, your AI mental health coach.

GETTING STARTED:
1. Download TestFlight from the App Store
2. Open the beta invitation link
3. Install UrGood Beta
4. Create your account or use demo login

WHAT TO TEST:
✅ AI Conversations - Chat with your AI coach
✅ Voice Chat - Try voice conversations
✅ Mood Tracking - Complete daily check-ins
✅ Premium Features - Test subscription flow
✅ Settings & Privacy - Review privacy controls

IMPORTANT NOTES:
⚠️ This is beta software - expect some bugs
⚠️ Your data may be reset between beta versions
⚠️ UrGood is NOT therapy - for emergencies call 988

HOW TO PROVIDE FEEDBACK:
• Use TestFlight's built-in feedback feature
• Email us at testflight@urgood.app
• Report crashes through TestFlight
• Join our beta Discord: [link]

DEMO CREDENTIALS (optional):
Email: beta@urgood.app
Password: BetaTest2025!

Thank you for helping make UrGood better! 💚
```

## 📊 Step 5: Beta Analytics & Monitoring

### 5.1 TestFlight Analytics
Monitor these key metrics:
- **Install Rate**: % of invitees who install
- **Session Duration**: How long users engage
- **Crash Rate**: Technical stability
- **Feedback Volume**: User engagement level

### 5.2 Firebase Analytics (Beta)
Track beta-specific events:
```swift
// Log beta testing events
FirebaseConfig.logEvent("beta_feature_tested", parameters: [
    "feature": "ai_chat",
    "beta_version": "1.0.0-beta.1",
    "user_type": "external_tester"
])
```

### 5.3 RevenueCat Sandbox Testing
- Configure sandbox environment
- Test subscription purchases with sandbox accounts
- Verify subscription restoration
- Monitor subscription analytics

## 🔄 Step 6: Beta Iteration Process

### 6.1 Weekly Beta Releases
1. **Monday**: Collect feedback from previous week
2. **Tuesday-Thursday**: Implement fixes and improvements
3. **Friday**: Build and upload new beta version
4. **Weekend**: Internal testing and validation

### 6.2 Feedback Management
- **Critical Bugs**: Fix within 24 hours
- **Feature Requests**: Evaluate and prioritize
- **UI/UX Issues**: Address in next beta release
- **Performance Issues**: Monitor and optimize

### 6.3 Beta Version Naming
- **Format**: 1.0.0-beta.X
- **Example**: 1.0.0-beta.1, 1.0.0-beta.2, etc.
- **Release Notes**: Clear changelog for each version

## 🎯 Step 7: Pre-Production Checklist

### 7.1 Beta Testing Completion Criteria
- [ ] **50+ active beta testers**
- [ ] **Crash rate < 1%**
- [ ] **Average session > 5 minutes**
- [ ] **Positive feedback > 80%**
- [ ] **All critical bugs resolved**
- [ ] **Subscription flow tested successfully**

### 7.2 Final Beta Validation
- [ ] Test on multiple device types (iPhone 12, 13, 14, 15)
- [ ] Verify iOS 16.6+ compatibility
- [ ] Test with various network conditions
- [ ] Validate accessibility features
- [ ] Confirm privacy compliance

### 7.3 Production Readiness
- [ ] Remove beta-specific code and analytics
- [ ] Update API endpoints to production
- [ ] Configure production RevenueCat environment
- [ ] Update Firebase to production project
- [ ] Final security audit completed

## 🚀 Step 8: Launch Preparation

### 8.1 App Store Submission
1. Create production build (version 1.0.0)
2. Upload to App Store Connect
3. Complete all metadata and screenshots
4. Submit for App Store review
5. Monitor review status

### 8.2 Launch Day Checklist
- [ ] Monitor app performance
- [ ] Respond to user reviews
- [ ] Track subscription conversions
- [ ] Monitor crash reports
- [ ] Prepare customer support

## 📞 Support & Resources

### Beta Testing Support
- **Email**: testflight@urgood.app
- **Response Time**: Within 24 hours
- **Discord**: Beta tester community
- **Documentation**: https://urgood.app/beta-docs

### Technical Resources
- **TestFlight Documentation**: https://developer.apple.com/testflight/
- **App Store Connect Guide**: https://developer.apple.com/app-store-connect/
- **RevenueCat Testing**: https://docs.revenuecat.com/docs/sandbox

---

## 🎉 Success Metrics

### Beta Testing Goals
- **Primary**: Validate core AI conversation quality
- **Secondary**: Test subscription conversion flow
- **Tertiary**: Gather feedback for UI/UX improvements

### Launch Readiness Indicators
- ✅ **Technical Stability**: <1% crash rate
- ✅ **User Engagement**: >5min average session
- ✅ **Feature Completeness**: All core features tested
- ✅ **Business Model**: Subscription flow validated
- ✅ **Compliance**: Privacy and legal requirements met

**With this comprehensive TestFlight setup, UrGood will be thoroughly tested and ready for a successful App Store launch!** 🚀









