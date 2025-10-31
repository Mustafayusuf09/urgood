# 🚀 RevenueCat Integration Setup Guide

This guide walks you through setting up RevenueCat for UrGood's subscription system.

## 📋 Prerequisites

### Required Accounts
- **Apple Developer Account** - For App Store Connect access
- **RevenueCat Account** - For subscription management
- **App Store Connect** - For product configuration

### Required Information
- Bundle ID: `com.urgood.app` (or your actual bundle ID)
- Product IDs: `urgood_premium_monthly`, `urgood_premium_yearly`
- RevenueCat API Key (from RevenueCat dashboard)

## 🔧 Step 1: App Store Connect Setup

### 1. Create In-App Purchase Products
1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Select your app → Features → In-App Purchases
3. Click "+" to create new products

#### Monthly Subscription
- **Product ID**: `urgood_premium_monthly`
- **Reference Name**: UrGood Premium Monthly
- **Type**: Auto-Renewable Subscription
- **Subscription Group**: Premium Subscriptions
- **Price**: $12.99/month
- **Subscription Duration**: 1 Month

#### Yearly Subscription  
- **Product ID**: `urgood_premium_yearly`
- **Reference Name**: UrGood Premium Yearly
- **Type**: Auto-Renewable Subscription
- **Subscription Group**: Premium Subscriptions
- **Price**: $79.99/year
- **Subscription Duration**: 1 Year

### 2. Configure Subscription Group
1. Create subscription group: "Premium Subscriptions"
2. Set subscription level hierarchy:
   - Level 1: Monthly ($12.99)
   - Level 2: Yearly ($79.99) - Higher level for better value

### 3. Add Subscription Metadata
For each subscription, add:
- **Display Name**: "UrGood Premium"
- **Description**: "Unlock unlimited chats, voice replies, advanced insights, and priority support"
- **Screenshots**: Add promotional images
- **Review Information**: Add test account details

## 🎯 Step 2: RevenueCat Dashboard Setup

### 1. Create RevenueCat Project
1. Go to [RevenueCat Dashboard](https://app.revenuecat.com)
2. Create new project: "UrGood"
3. Add iOS app with your Bundle ID

### 2. Configure Products
1. Go to Products tab
2. Add products:
   - `urgood_premium_monthly` → Monthly Premium
   - `urgood_premium_yearly` → Yearly Premium

### 3. Create Entitlements
1. Go to Entitlements tab
2. Create entitlement: `premium`
3. Attach both products to this entitlement

### 4. Set Up Offerings
1. Go to Offerings tab
2. Create offering: `main_offering`
3. Add packages:
   - Monthly package → `urgood_premium_monthly`
   - Yearly package → `urgood_premium_yearly`
4. Set as current offering

### 5. Get API Keys
1. Go to Project Settings → API Keys
2. Copy the **Public API Key** (starts with `appl_`)
3. Save this for app configuration

## ⚙️ Step 3: App Configuration

### 1. Update Secrets.xcconfig
```bash
# RevenueCat Configuration
REVENUECAT_API_KEY = appl_your_actual_api_key_here
```

### 2. Verify Product IDs
The app is already configured with these product IDs:
- `urgood_premium_monthly`
- `urgood_premium_yearly`

Make sure these match exactly in App Store Connect.

### 3. Test Configuration
The app includes validation that will check:
- ✅ RevenueCat API key is configured
- ✅ Products are available in offerings
- ✅ Entitlements are properly set up

## 🧪 Step 4: Testing

### 1. Sandbox Testing
1. Create sandbox test user in App Store Connect
2. Sign out of App Store on test device
3. Build and run app in debug mode
4. Test purchase flow with sandbox account

### 2. Test Scenarios
- **Purchase Monthly**: Verify subscription activates
- **Purchase Yearly**: Verify subscription activates
- **Restore Purchases**: Verify existing purchases restore
- **Subscription Expiry**: Test with expired sandbox subscription
- **Cancellation**: Test subscription cancellation flow

### 3. RevenueCat Dashboard Verification
1. Check Customer tab for test purchases
2. Verify Revenue tab shows test transactions
3. Confirm Charts show subscription metrics

## 🔍 Step 5: Production Validation

### 1. Pre-Launch Checklist
- [ ] App Store Connect products approved
- [ ] RevenueCat offerings configured
- [ ] API keys properly set in production
- [ ] Subscription group hierarchy correct
- [ ] Privacy policy includes subscription terms
- [ ] App metadata mentions subscription features

### 2. Production Testing
1. Submit app for review with subscription features
2. Test with real Apple ID (small amount)
3. Verify RevenueCat webhook integration
4. Check analytics and revenue tracking

## 🚨 Troubleshooting

### Common Issues

#### "No products available"
- **Cause**: Products not approved in App Store Connect
- **Solution**: Wait for Apple approval (24-48 hours)
- **Check**: Verify product IDs match exactly

#### "Invalid API key"
- **Cause**: Wrong API key or not configured
- **Solution**: Check RevenueCat dashboard for correct key
- **Check**: Ensure using Public API Key, not Secret Key

#### "Entitlement not active"
- **Cause**: Product not attached to entitlement
- **Solution**: Check RevenueCat entitlements configuration
- **Check**: Verify offering includes correct packages

#### "Purchase failed"
- **Cause**: Various reasons (network, Apple ID, etc.)
- **Solution**: Check error message in app logs
- **Check**: Verify sandbox account setup

### Debug Commands

```swift
// Check RevenueCat configuration
print("RevenueCat User ID: \(Purchases.shared.appUserID)")

// Validate products
Task {
    let isValid = await RevenueCatConfiguration.validateProductConfiguration()
    print("Product validation: \(isValid)")
}

// Check customer info
Task {
    let customerInfo = try await Purchases.shared.customerInfo()
    print("Active entitlements: \(customerInfo.entitlements.active)")
}
```

## 📊 Step 6: Analytics & Monitoring

### 1. RevenueCat Analytics
- **Revenue**: Track MRR, ARR, churn
- **Customers**: Monitor subscription lifecycle
- **Products**: Compare monthly vs yearly performance

### 2. Firebase Integration
The app automatically logs these events:
- `subscription_purchased`
- `subscription_restored`
- `subscription_expired`
- `revenuecat_purchase_failed`
- `revenuecat_restore_failed`

### 3. Key Metrics to Monitor
- **Conversion Rate**: Free to premium conversion
- **Churn Rate**: Monthly subscription cancellations
- **LTV**: Customer lifetime value
- **ARPU**: Average revenue per user

## 🔒 Security Best Practices

### 1. API Key Management
- ✅ Store API keys in `Secrets.xcconfig` (not committed)
- ✅ Use environment variables for production
- ✅ Never hardcode keys in source code
- ✅ Rotate keys periodically

### 2. Subscription Validation
- ✅ Server-side receipt validation (RevenueCat handles this)
- ✅ Webhook verification for subscription changes
- ✅ Graceful handling of subscription edge cases
- ✅ Proper error messaging for users

### 3. User Privacy
- ✅ Clear subscription terms in app
- ✅ Easy cancellation process
- ✅ Privacy policy covers subscription data
- ✅ GDPR compliance for EU users

## 🎉 Success Checklist

When everything is working correctly, you should see:

### In App
- [ ] Paywall displays correct prices
- [ ] Purchase flow completes successfully
- [ ] Premium features unlock immediately
- [ ] Restore purchases works
- [ ] Subscription status updates in real-time

### In RevenueCat Dashboard
- [ ] Customers appear after purchase
- [ ] Revenue tracking works
- [ ] Subscription events logged
- [ ] Webhooks firing correctly

### In App Store Connect
- [ ] Subscription reports show data
- [ ] Customer reviews mention premium features
- [ ] Revenue appears in financial reports

---

## 📞 Support Resources

- **RevenueCat Docs**: https://docs.revenuecat.com
- **Apple Subscription Guide**: https://developer.apple.com/app-store/subscriptions/
- **App Store Review Guidelines**: https://developer.apple.com/app-store/review/guidelines/

**Your UrGood app now has enterprise-grade subscription management!** 🚀💰









