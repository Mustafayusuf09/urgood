# 🚀 Production Services Setup Guide

**Status**: Apple Developer Program Active ✅  
**Bundle ID**: `com.urgood.urgood`  
**Team ID**: `JK7B7MXHZU`

---

## 1. App Store Connect Setup

### Step 1: Create App Listing
1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click **"My Apps"** → **"+"** → **"New App"**
3. Fill in:
   - **Platform**: iOS
   - **Name**: UrGood
   - **Primary Language**: English (US)
   - **Bundle ID**: `com.urgood.urgood` (select from dropdown)
   - **SKU**: `urgood-ios-001` (unique identifier)
   - **User Access**: Full Access

### Step 2: App Information
- **Category**: Health & Fitness
- **Content Rights**: No
- **Age Rating**: 12+ (due to mental health content)

---

## 2. RevenueCat Production Setup

### Step 1: Create RevenueCat Account
1. Go to [RevenueCat Dashboard](https://app.revenuecat.com)
2. Sign up with your Apple ID
3. Create new project: **"UrGood"**

### Step 2: Add iOS App
1. Click **"Add App"**
2. Select **"iOS"**
3. Enter:
   - **App Name**: UrGood
   - **Bundle ID**: `com.urgood.urgood`
4. Get your **API Key** (format: `appl_xxxxx...`)

### Step 3: Configure App Store Connect Integration
1. In RevenueCat → **Apps** → **UrGood** → **Settings**
2. Add **App Store Connect** credentials:
   - **Issuer ID**: (from Apple Developer Portal)
   - **Key ID**: (from Apple Developer Portal)
   - **Private Key**: (.p8 file from Apple Developer Portal)

---

## 3. In-App Purchase Configuration

### Step 1: Create Subscription Group
1. In App Store Connect → **UrGood** → **Subscriptions**
2. Click **"Create Subscription Group"**
3. **Reference Name**: "Premium"
4. **Localized Reference Name**: "Premium"

### Step 2: Create Monthly Subscription
- **Product ID**: `urgood_premium_monthly`
- **Reference Name**: "UrGood Premium Monthly"
- **Type**: Auto-Renewable Subscription
- **Subscription Duration**: 1 Month
- **Price**: $12.99/month (Tier 25)
- **Subscription Group**: Premium

### Step 3: Create Yearly Subscription
- **Product ID**: `urgood_premium_yearly`
- **Reference Name**: "UrGood Premium Yearly"
- **Type**: Auto-Renewable Subscription
- **Subscription Duration**: 1 Year
- **Price**: $79.99/year (Tier 50)
- **Subscription Group**: Premium

### Step 4: Add Localized Information
- **Display Name**: "UrGood Premium"
- **Description**: "Unlimited access to AI mental health coaching, advanced insights, and premium features"

---

## 4. Apple Sign In Production Setup

### Step 1: Configure Services ID
1. Go to [Apple Developer Portal](https://developer.apple.com)
2. **Certificates, Identifiers & Profiles** → **Identifiers**
3. Click **"+"** → **"Services IDs"**
4. **Description**: "UrGood Sign In"
5. **Identifier**: `com.urgood.urgood.signin`
6. **Enable**: "Sign In with Apple"
7. **Primary App ID**: `com.urgood.urgood`
8. **Domains**: `urgood-dc7f0.firebaseapp.com`

### Step 2: Update Firebase Configuration
1. Go to [Firebase Console](https://console.firebase.google.com)
2. **Authentication** → **Sign-in method** → **Apple**
3. **Services ID**: `com.urgood.urgood.signin`
4. **Team ID**: `JK7B7MXHZU`
5. **Key ID**: (from Apple Developer Portal)
6. **Private Key**: (.p8 file)

---

## 5. Push Notifications Setup

### Step 1: Create APNs Key
1. Apple Developer Portal → **Keys**
2. Click **"+"** → **"Apple Push Notifications service (APNs)"**
3. **Key Name**: "UrGood Push Notifications"
4. **Key ID**: (save this)
5. **Team ID**: `JK7B7MXHZU`
6. Download **.p8 file** (save securely)

### Step 2: Upload to Firebase
1. Firebase Console → **Project Settings** → **Cloud Messaging**
2. **Apple app configuration** → **Upload APNs Authentication Key**
3. Upload your **.p8 file**
4. Enter **Key ID** and **Team ID**

---

## 6. Update Xcode Project

### Step 1: Enable Capabilities
1. Open **urgood.xcodeproj** in Xcode
2. Select **urgood** target
3. **Signing & Capabilities** tab
4. Add capabilities:
   - ✅ **Push Notifications**
   - ✅ **Sign In with Apple**

### Step 2: Update Code Signing
1. **Team**: Select your team
2. **Bundle Identifier**: `com.urgood.urgood`
3. **Provisioning Profile**: Automatic

---

## 7. Update App Code

### Step 1: Replace Mock Services
We need to update the app to use real services instead of mock implementations.

### Step 2: Add RevenueCat SDK
1. **File** → **Add Package Dependencies**
2. URL: `https://github.com/RevenueCat/purchases-ios`
3. Add to target: **urgood**

### Step 3: Update Configuration
Replace mock API keys with real production keys.

---

## Next Steps

1. **Complete App Store Connect setup**
2. **Configure RevenueCat with real API key**
3. **Update Firebase with production settings**
4. **Test on real device**
5. **Upload to TestFlight**

---

**Ready to proceed with each step?**
