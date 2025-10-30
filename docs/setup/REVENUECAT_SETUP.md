# 💳 RevenueCat Production Setup Guide

**Status**: Apple Developer Program Active ✅  
**Bundle ID**: `com.urgood.urgood`  
**Team ID**: `JK7B7MXHZU`

---

## Step 1: Create RevenueCat Account

### 1.1 Sign Up
1. Go to [RevenueCat Dashboard](https://app.revenuecat.com)
2. Click **"Sign Up"**
3. Sign up with your Apple ID (recommended)
4. Verify your email address

### 1.2 Create Project
1. Click **"Create Project"**
2. **Project Name**: UrGood
3. **Description**: "AI mental health companion app"
4. Click **"Create Project"**

---

## Step 2: Add iOS App

### 2.1 Add App
1. In your project dashboard, click **"Add App"**
2. Select **"iOS"**
3. Fill in:
   - **App Name**: UrGood
   - **Bundle ID**: `com.urgood.urgood`
4. Click **"Add App"**

### 2.2 Get API Key
1. In your app settings, find **"API Keys"**
2. Copy your **Public API Key** (format: `appl_xxxxx...`)
3. Save this key securely - you'll need it for the app

---

## Step 3: Configure App Store Connect Integration

### 3.1 Get App Store Connect Credentials
You'll need these from Apple Developer Portal:

1. **Issuer ID**:
   - Go to [Apple Developer Portal](https://developer.apple.com)
   - **Certificates, Identifiers & Profiles**
   - **Keys** → **App Store Connect API**
   - Copy **Issuer ID**

2. **Key ID**:
   - In the same section, copy **Key ID**

3. **Private Key**:
   - Download the **.p8 file**
   - Keep it secure - you can only download it once

### 3.2 Add Credentials to RevenueCat
1. In RevenueCat → **Apps** → **UrGood** → **Settings**
2. **App Store Connect** section
3. Add:
   - **Issuer ID**: [Your issuer ID]
   - **Key ID**: [Your key ID]
   - **Private Key**: [Upload .p8 file]
4. Click **"Save"**

---

## Step 4: Configure Products

### 4.1 Create Entitlement
1. In RevenueCat → **Entitlements**
2. Click **"Create Entitlement"**
3. **Identifier**: `premium`
4. **Display Name**: "Premium"
5. Click **"Create"**

### 4.2 Add Products
1. In **Products** section
2. Click **"Add Product"**
3. **Product ID**: `urgood_premium_monthly`
4. **Type**: Auto-Renewable Subscription
5. **Entitlement**: premium
6. Click **"Add"**

4. Repeat for yearly subscription:
   - **Product ID**: `urgood_premium_yearly`
   - **Type**: Auto-Renewable Subscription
   - **Entitlement**: premium

### 4.3 Create Offering
1. In **Offerings** section
2. Click **"Create Offering"**
3. **Identifier**: `default`
4. **Display Name**: "Default"
5. Add both products to the offering
6. Click **"Create"**

---

## Step 5: Update App Code

### 5.1 Add RevenueCat Package
1. In Xcode: **File** → **Add Package Dependencies**
2. URL: `https://github.com/RevenueCat/purchases-ios`
3. Select **RevenueCat** package
4. Add to target: **urgood**

### 5.2 Update ProductionConfig.swift
Replace the placeholder API key:

```swift
// In ProductionConfig.swift
static let revenueCatAPIKey = "appl_YOUR_ACTUAL_API_KEY_HERE"
```

### 5.3 Update BillingService.swift
Replace the current BillingService with the ProductionBillingService we created:

```swift
// In DIContainer.swift, replace:
self.billingService = BillingService(localStore: localStore)

// With:
self.billingService = ProductionBillingService(localStore: localStore)
```

---

## Step 6: Test Configuration

### 6.1 Sandbox Testing
1. Create sandbox test accounts in App Store Connect
2. Test subscription flow in sandbox
3. Verify RevenueCat dashboard shows test purchases

### 6.2 Test Scenarios
- [ ] Monthly subscription purchase
- [ ] Yearly subscription purchase
- [ ] Restore purchases
- [ ] Subscription cancellation
- [ ] Subscription renewal

---

## Step 7: Production Configuration

### 7.1 Update App Store Connect
1. Ensure all subscription products are **"Ready for Sale"**
2. Verify pricing is correct
3. Check localized descriptions

### 7.2 RevenueCat Dashboard
1. Verify all products are linked
2. Check entitlement configuration
3. Test webhook endpoints (if using)

---

## Step 8: Monitoring Setup

### 8.1 RevenueCat Analytics
1. Set up conversion tracking
2. Monitor subscription metrics
3. Track churn rates

### 8.2 Key Metrics to Monitor
- **Conversion Rate**: Free to Premium
- **Churn Rate**: Monthly cancellation rate
- **ARPU**: Average revenue per user
- **LTV**: Lifetime value

---

## Step 9: Webhook Configuration (Optional)

### 9.1 Set Up Webhooks
1. In RevenueCat → **Webhooks**
2. Add webhook URL (your backend)
3. Select events to track:
   - `INITIAL_PURCHASE`
   - `RENEWAL`
   - `CANCELLATION`
   - `EXPIRATION`

### 9.2 Backend Integration
Update your backend to handle RevenueCat webhooks for:
- Subscription status updates
- User entitlement changes
- Payment failures

---

## Step 10: Launch Checklist

### 10.1 Pre-Launch
- [ ] RevenueCat account created
- [ ] API key configured
- [ ] Products added to RevenueCat
- [ ] App Store Connect products ready
- [ ] Sandbox testing complete
- [ ] Production build tested

### 10.2 Post-Launch
- [ ] Monitor subscription metrics
- [ ] Track conversion rates
- [ ] Respond to payment issues
- [ ] Update pricing if needed

---

## Troubleshooting

### Common Issues

1. **"Product not found"**
   - Check product IDs match exactly
   - Ensure products are "Ready for Sale" in App Store Connect

2. **"Invalid API key"**
   - Verify API key is correct
   - Check bundle ID matches

3. **"Purchase failed"**
   - Test with sandbox accounts
   - Check App Store Connect configuration

### Support Resources
- [RevenueCat Documentation](https://docs.revenuecat.com)
- [RevenueCat Support](https://support.revenuecat.com)
- [Apple In-App Purchase Guide](https://developer.apple.com/in-app-purchase/)

---

**Ready to configure RevenueCat? Let's start with Step 1!**
