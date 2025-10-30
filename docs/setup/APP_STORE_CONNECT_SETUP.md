# 🚀 App Store Connect Setup Guide

**Status**: Apple Developer Program Active ✅  
**Bundle ID**: `com.urgood.urgood`  
**Team ID**: `JK7B7MXHZU`

---

## Step 1: Create App Listing

### 1.1 Access App Store Connect
1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Sign in with your Apple ID
3. Click **"My Apps"** in the top navigation

### 1.2 Create New App
1. Click the **"+"** button (top left)
2. Select **"New App"**
3. Fill in the form:
   - **Platform**: iOS
   - **Name**: UrGood
   - **Primary Language**: English (US)
   - **Bundle ID**: `com.urgood.urgood` (select from dropdown)
   - **SKU**: `urgood-ios-001` (unique identifier)
   - **User Access**: Full Access

### 1.3 App Information
1. **Category**: Health & Fitness
2. **Content Rights**: No
3. **Age Rating**: 12+ (due to mental health content)

---

## Step 2: Configure In-App Purchases

### 2.1 Create Subscription Group
1. In your app → **Subscriptions** tab
2. Click **"Create Subscription Group"**
3. **Reference Name**: "Premium"
4. **Localized Reference Name**: "Premium"

### 2.2 Create Monthly Subscription
1. Click **"Create Subscription"**
2. Fill in:
   - **Product ID**: `urgood_premium_monthly`
   - **Reference Name**: "UrGood Premium Monthly"
   - **Type**: Auto-Renewable Subscription
   - **Subscription Duration**: 1 Month
   - **Price**: $12.99/month (Tier 25)
   - **Subscription Group**: Premium

### 2.3 Create Yearly Subscription
1. Click **"Create Subscription"** again
2. Fill in:
   - **Product ID**: `urgood_premium_yearly`
   - **Reference Name**: "UrGood Premium Yearly"
   - **Type**: Auto-Renewable Subscription
   - **Subscription Duration**: 1 Year
   - **Price**: $79.99/year (Tier 50)
   - **Subscription Group**: Premium

### 2.4 Add Localized Information
For both subscriptions, add:
- **Display Name**: "UrGood Premium"
- **Description**: "Unlimited access to AI mental health coaching, advanced insights, and premium features"

---

## Step 3: App Store Information

### 3.1 App Information Tab
1. **App Name**: UrGood
2. **Subtitle**: "Your AI mental health companion"
3. **Category**: Health & Fitness
4. **Content Rights**: No
5. **Age Rating**: Complete the questionnaire (likely 12+)

### 3.2 Pricing and Availability
1. **Price**: Free (with in-app purchases)
2. **Availability**: All countries/regions
3. **Release**: Manual release (recommended for first launch)

### 3.3 App Privacy
1. **Data Collection**: Yes
2. **Data Types**:
   - **Health & Fitness**: Yes (mood tracking)
   - **Usage Data**: Yes (analytics)
   - **Diagnostics**: Yes (crash reports)
3. **Data Usage**: App functionality, analytics, advertising
4. **Data Sharing**: No (privacy-focused)

---

## Step 4: App Store Description

### 4.1 App Description (4000 characters max)
```
UrGood is your personal AI mental health companion, designed to provide 24/7 emotional support and wellness guidance.

✨ WHAT MAKES URGOD SPECIAL:
• AI-powered conversations that understand your emotions
• Voice chat for natural, therapeutic conversations
• Daily mood tracking with personalized insights
• Crisis detection with immediate support resources
• Privacy-first: Your data stays on your device

🎯 PERFECT FOR:
• Daily emotional check-ins
• Stress and anxiety management
• Building healthy mental habits
• Getting support when you need it most
• Tracking your mental wellness journey

🔒 PRIVACY & SECURITY:
• End-to-end encryption
• No data sharing with third parties
• Works completely offline
• Your conversations stay private

💬 HOW IT WORKS:
1. Start with a quick personality assessment
2. Chat with your AI companion anytime
3. Track your mood and get insights
4. Build healthy habits with daily check-ins

🌟 PREMIUM FEATURES:
• Unlimited conversations
• Advanced AI insights
• Weekly wellness recaps
• Priority support
• Voice chat capabilities

UrGood is not a replacement for professional therapy or medical treatment. If you're experiencing a mental health crisis, please contact your local emergency services or crisis hotline.

Start your mental wellness journey today with UrGood.
```

### 4.2 Promotional Text (170 characters max)
```
Your AI mental health companion. Chat anytime, track your mood, get personalized insights. Privacy-first design keeps your data secure.
```

### 4.3 Keywords (100 characters max)
```
mental health,AI,wellness,mood tracking,anxiety,depression,therapy,self-care,meditation,mindfulness
```

---

## Step 5: App Review Information

### 5.1 Contact Information
- **First Name**: [Your first name]
- **Last Name**: [Your last name]
- **Phone Number**: [Your phone number]
- **Email**: [Your email]

### 5.2 Demo Account (if needed)
- **Username**: [Create test account]
- **Password**: [Create test password]
- **Notes**: "Test account for App Store review"

### 5.3 Review Notes
```
This is a mental health app that provides AI-powered emotional support. Key features to test:

1. Onboarding flow with personality assessment
2. Chat functionality with AI companion
3. Mood tracking and insights
4. Premium subscription flow
5. Crisis detection and resources

The app is designed for adults 18+ and includes appropriate disclaimers about not being a replacement for professional therapy.
```

---

## Step 6: Screenshots

### 6.1 Required Sizes
You need screenshots for these display sizes:
- **6.7" display** (iPhone 14 Pro Max, 15 Pro Max)
- **6.5" display** (iPhone 11 Pro Max, XS Max)
- **5.5" display** (iPhone 8 Plus)

### 6.2 Screenshot Content
Create screenshots showing:
1. **Onboarding**: Welcome screen with personality quiz
2. **Chat**: AI conversation interface
3. **Insights**: Mood tracking and analytics
4. **Streaks**: Daily check-in progress
5. **Settings**: App configuration
6. **Paywall**: Premium upgrade screen

### 6.3 Screenshot Tips
- Use captions to explain features
- Keep UI clean and showcase personality
- Use consistent styling across all screenshots
- Highlight key features with callouts

---

## Step 7: App Icon

### 7.1 Upload App Icon
1. **App Icon**: 1024x1024 pixels
2. **Format**: PNG or JPEG
3. **No transparency**: Solid background required
4. **No rounded corners**: Apple adds them automatically

---

## Step 8: Build Upload

### 8.1 Archive and Upload
1. In Xcode: **Product** → **Archive**
2. Wait for archive to complete
3. Click **"Distribute App"**
4. Select **"App Store Connect"**
5. Select **"Upload"**
6. Follow the upload process

### 8.2 Select Build
1. In App Store Connect → **TestFlight** tab
2. Wait for build to process (5-10 minutes)
3. Go to **App Store** tab
4. Select the build you just uploaded

---

## Step 9: Submit for Review

### 9.1 Final Checks
- [ ] All required fields filled
- [ ] Screenshots uploaded
- [ ] App icon uploaded
- [ ] Build selected
- [ ] In-app purchases configured
- [ ] Privacy policy URL added

### 9.2 Submit
1. Click **"Submit for Review"**
2. Select **"Manual Release"** (recommended)
3. Add any additional notes for reviewer
4. Click **"Submit"**

---

## Step 10: Monitor Review

### 10.1 Review Process
- **Typical timeline**: 1-2 weeks
- **Status updates**: Check daily
- **Possible outcomes**:
  - ✅ Approved
  - ❌ Rejected (with feedback)
  - ⏸️ On Hold (waiting for response)

### 10.2 If Rejected
1. Read rejection reasons carefully
2. Fix issues in Xcode
3. Upload new build
4. Resubmit for review

---

## Next Steps After Approval

1. **Release**: Manually release when ready
2. **Monitor**: Track downloads and reviews
3. **Support**: Respond to user feedback
4. **Updates**: Plan version 1.0.1 with bug fixes

---

**Ready to start? Let's begin with Step 1!**
