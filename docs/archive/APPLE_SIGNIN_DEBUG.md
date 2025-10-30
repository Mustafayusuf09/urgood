# 🍎 Apple Sign-In Debug Guide

## 🔍 Current Issue Analysis

Your Apple Sign-In spinner is stuck because the authentication flow is failing at the **backend authentication step**. Here's what's happening:

1. ✅ Apple Sign-In dialog appears
2. ✅ User authenticates with Apple
3. ✅ Firebase receives the Apple credential
4. ❌ **Backend API call fails/hangs** → Spinner never resolves

## 🚨 Root Cause

Your `ProductionAuthService` is calling:
```
https://api.urgood.app/v1/auth/apple
```

This backend call is either:
- **Timing out** (30+ seconds)
- **Returning an error** (500, 404, etc.)
- **Missing Apple Sign-In configuration**

## 🔧 Immediate Fix Options

### Option 1: Skip Backend Auth (Quick Fix)
Temporarily disable backend authentication to test Apple Sign-In:

```swift
// In ProductionAuthService.swift, comment out the backend call:
do {
    // try await authenticateWithBackend(...)
    print("🔧 Backend auth temporarily disabled")
} catch {
    log.error("🍎 Backend authentication failed: \(error.localizedDescription)")
}
```

### Option 2: Add Timeout & Better Error Handling

```swift
private func authenticateWithBackend(...) async throws {
    guard let url = URL(string: "https://api.urgood.app/v1/auth/apple") else {
        throw ProductionAuthError.networkError
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = 10.0 // Add 10 second timeout
    
    // ... rest of implementation
}
```

## 🔍 Debug Steps

### 1. Check Backend Status
Test your backend endpoint:
```bash
curl -X POST https://api.urgood.app/v1/auth/apple \
  -H "Content-Type: application/json" \
  -d '{"test": "true"}'
```

### 2. Enable Detailed Logging
Add this to your `ProductionAuthService`:

```swift
private func authenticateWithBackend(...) async throws {
    print("🍎 [DEBUG] Starting backend auth...")
    print("🍎 [DEBUG] URL: https://api.urgood.app/v1/auth/apple")
    
    // ... existing code ...
    
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        print("🍎 [DEBUG] Backend response received")
        print("🍎 [DEBUG] Status: \(httpResponse.statusCode)")
        print("🍎 [DEBUG] Response: \(String(data: data, encoding: .utf8) ?? "nil")")
    } catch {
        print("🍎 [DEBUG] Network error: \(error)")
        throw error
    }
}
```

### 3. Test on Real Device
Apple Sign-In often behaves differently on simulator vs. real device.

## 🛠️ Backend Configuration Checklist

Your backend needs:

### 1. Apple Sign-In Route
```typescript
// /v1/auth/apple endpoint should exist
app.post('/v1/auth/apple', async (req, res) => {
  // Handle Apple token verification
});
```

### 2. Apple Token Verification
Your backend must verify the Apple `identityToken`:
- Download Apple's public keys
- Verify JWT signature
- Check token expiration
- Validate audience (your app's bundle ID)

### 3. CORS Configuration
If testing from web/simulator:
```typescript
app.use(cors({
  origin: ['https://urgood-dc7f0.firebaseapp.com', 'http://localhost:*'],
  credentials: true
}));
```

## 🚀 Firebase Console Setup

### 1. Enable Apple Sign-In Provider
1. Go to [Firebase Console](https://console.firebase.google.com/project/urgood-dc7f0)
2. Authentication → Sign-in method
3. Enable **Apple** provider
4. Configure:
   - **Service ID**: `com.urgood.urgood.signin`
   - **Team ID**: `JK7B7MXHZU`
   - **Key ID**: (from Apple Developer)
   - **Private Key**: Upload your `.p8` file

### 2. Add Authorized Domains
In Firebase Console → Authentication → Settings → Authorized domains:
- `urgood-dc7f0.firebaseapp.com`
- `localhost` (for testing)

## 🍏 Apple Developer Console Setup

### 1. App ID Configuration
1. Go to [Apple Developer](https://developer.apple.com/account/resources/identifiers/list)
2. Select your App ID: `com.urgood.urgood`
3. Enable **Sign in with Apple**
4. Save changes

### 2. Service ID Setup
1. Create new Service ID: `com.urgood.urgood.signin`
2. Enable **Sign in with Apple**
3. Configure:
   - **Primary App ID**: `com.urgood.urgood`
   - **Return URLs**: `https://urgood-dc7f0.firebaseapp.com/__/auth/handler`

### 3. Generate Private Key
1. Go to Keys section
2. Create new key for **Sign in with Apple**
3. Download `.p8` file
4. Note the **Key ID**

## 🧪 Testing Strategy

### 1. Test Firebase Only
Temporarily comment out backend auth to test Firebase:
```swift
// Comment out this line:
// try await authenticateWithBackend(...)
```

### 2. Test Backend Separately
Use Postman/curl to test your backend endpoint independently.

### 3. Add Comprehensive Logging
Log every step of the authentication flow to identify where it fails.

## 📱 Quick Test Implementation

Add this temporary debug version to your `ProductionAuthService`:

```swift
func debugAppleSignIn() async {
    print("🍎 [DEBUG] Starting Apple Sign-In debug test...")
    
    // Test 1: Basic Apple Sign-In (no backend)
    do {
        let nonce = randomNonceString()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        print("🍎 [DEBUG] Apple request created successfully")
        // Continue with normal flow but skip backend auth
    } catch {
        print("🍎 [DEBUG] Apple Sign-In setup failed: \(error)")
    }
}
```

## 🎯 Most Likely Solutions

1. **Backend is down/misconfigured** → Fix backend endpoint
2. **Network timeout** → Add proper timeout handling
3. **Apple keys not configured** → Set up Apple private key in Firebase
4. **CORS issues** → Configure backend CORS properly
5. **Bundle ID mismatch** → Verify all IDs match exactly

Start with **Option 1** (skip backend auth) to isolate whether the issue is Firebase or backend-related.

