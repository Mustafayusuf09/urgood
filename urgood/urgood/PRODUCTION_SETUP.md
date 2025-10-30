# 🚀 Production Setup Guide

This guide will help you complete the Firebase and RevenueCat setup to make your app production-ready.

## 🔥 Firebase Setup

### 1. Enable Firebase Services

#### Analytics
- ✅ Already enabled in `GoogleService-Info.plist`
- ✅ Analytics tracking added throughout the app
- ✅ User properties and events configured

#### Crashlytics
1. **Add FirebaseCrashlytics dependency** in Xcode:
   - File → Add Package Dependencies
   - Search: `https://github.com/firebase/firebase-ios-sdk`
   - Select "FirebaseCrashlytics"

2. **Add Build Script**:
   - Select your target → Build Phases
   - Add "Run Script Phase"
   - Script: `"${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"`
   - Input Files:
     ```
     ${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${TARGET_NAME}
     $(SRCROOT)/$(BUILT_PRODUCTS_DIR)/$(INFOPLIST_PATH)
     ```

3. **Enable in Firebase Console**:
   - Go to [Firebase Console](https://console.firebase.google.com)
   - Select project: `urgood-dc7f0`
   - Navigate to Crashlytics
   - Click "Get started"

#### Firestore Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Quiz answers are private to each user
    match /users/{userId}/quizzes/{quizId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Chat messages are private to each user
    match /users/{userId}/messages/{messageId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### 2. Firebase Analytics Events

The app now tracks these events:
- `user_sign_in` - User authentication
- `user_sign_up` - User registration  
- `chat_message_sent` - Chat interactions
- `mood_checkin` - Mood tracking
- `purchase_completed` - Subscription purchases
- `subscription_status_changed` - Subscription changes

## 💳 RevenueCat Setup

### 1. Create RevenueCat Account
1. Go to [RevenueCat Dashboard](https://app.revenuecat.com)
2. Create a new project: "urgood"
3. Add your iOS app with bundle ID: `com.urgood.urgood`

### 2. Configure App Store Connect
1. **Create In-App Purchases** in App Store Connect:
   - Product ID: `urgood_premium_monthly`
   - Type: Auto-Renewable Subscription
   - Price: $12.99/month
   - Reference Name: "Urgood Premium Monthly"

2. **Add to RevenueCat**:
   - Go to Products → Add Product
   - Enter Product ID: `urgood_premium_monthly`
   - Select "Auto-Renewable Subscription"

### 3. Create Entitlements
1. In RevenueCat Dashboard:
   - Go to Entitlements
   - Create: "premium"
   - Attach Products: `urgood_premium_monthly`

### 4. Update API Key
1. Get your RevenueCat API Key from the dashboard
2. Update `RevenueCatService.swift`:
   ```swift
   private let apiKey = "appl_your_actual_revenuecat_api_key_here"
   ```

### 5. Test Purchases
1. **Sandbox Testing**:
   - Create sandbox users in App Store Connect
   - Test purchases in sandbox environment
   - Verify RevenueCat dashboard shows test purchases

2. **Production Testing**:
   - Use TestFlight for production testing
   - Verify real purchases work correctly

## 🔧 Final Configuration

### 1. Update Development Config
The app is now set to production mode:
- ✅ Authentication required
- ✅ Paywall restrictions active
- ✅ Onboarding flows enabled

### 2. Environment Variables
Create a `Config.swift` file for sensitive data:
```swift
struct Config {
    static let openAIAPIKey = "your-openai-api-key"
    static let revenueCatAPIKey = "your-revenuecat-api-key"
}
```

### 3. App Store Connect
1. **App Information**:
   - Bundle ID: `com.urgood.urgood`
   - Version: 1.0.0
   - Build: 1

2. **App Review Information**:
   - Test account credentials
   - Demo video showing key features
   - Notes about mental health app guidelines

3. **Pricing and Availability**:
   - Set price: Free
   - Enable in-app purchases
   - Select countries/regions

## 🧪 Testing Checklist

### Firebase Testing
- [ ] User authentication works (Apple Sign In + Email)
- [ ] User data saves to Firestore
- [ ] Analytics events appear in Firebase Console
- [ ] Crashlytics reports crashes (test with intentional crash)

### RevenueCat Testing
- [ ] Paywall displays correctly
- [ ] Purchase flow works in sandbox
- [ ] Subscription status updates correctly
- [ ] Restore purchases works
- [ ] Premium features unlock after purchase

### App Features Testing
- [ ] Chat with AI coach
- [ ] Mood check-ins and streaks
- [ ] Advanced AI insights
- [ ] Crisis detection and resources
- [ ] Onboarding flow
- [ ] Settings and user management

## 🚀 Deployment

### 1. Build for Production
1. Set build configuration to "Release"
2. Archive the app
3. Upload to App Store Connect

### 2. App Store Review
1. Submit for review
2. Provide test account if needed
3. Respond to any review feedback

### 3. Launch
1. Release to App Store
2. Monitor Firebase Analytics
3. Monitor RevenueCat dashboard
4. Respond to user feedback

## 📊 Monitoring

### Firebase Console
- Monitor user authentication
- Track analytics events
- Review crash reports
- Check Firestore usage

### RevenueCat Dashboard
- Monitor subscription metrics
- Track revenue and churn
- Analyze user cohorts
- Review customer support

## 🆘 Troubleshooting

### Common Issues

#### "RevenueCat not working"
- Check API key is correct
- Verify product IDs match App Store Connect
- Ensure entitlements are configured

#### "Firebase authentication failing"
- Check bundle ID matches Firebase Console
- Verify Apple Sign In is enabled
- Check URL scheme configuration

#### "Analytics not showing"
- Wait 24-48 hours for data to appear
- Check if Analytics is enabled in Firebase Console
- Verify events are being sent (check console logs)

## 📞 Support

If you encounter issues:
1. Check Firebase Console for errors
2. Review RevenueCat dashboard
3. Check Xcode console for detailed logs
4. Test in sandbox environment first

---

**🎉 Congratulations!** Your app is now production-ready with full Firebase and RevenueCat integration!
