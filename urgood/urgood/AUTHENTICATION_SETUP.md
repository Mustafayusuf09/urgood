# 🔐 Authentication Setup Guide

This guide explains how the authentication system is set up in urgood and how to configure the Firebase callback URL.

## 🚀 What's Implemented

### ✅ Complete Authentication Flow
- **Apple Sign In** with Firebase + backend token exchange
- **Email/Password** authentication
- **Firebase Authentication** backend
- **User data storage** in Firestore
- **Proper error handling** and loading states
- **Sign out functionality**

### ✅ Firebase Configuration
- **Project ID**: `urgood-dc7f0`
- **Bundle ID**: `com.urgood.urgood`
- **Authorization Callback URL**: `https://urgood-dc7f0.firebaseapp.com/__/auth/handler`

## 🔧 Configuration Files

### 1. Firebase Configuration
- `FirebaseConfig.swift` - Main Firebase configuration
- `GoogleService-Info.plist` - Firebase project settings
- `Info.plist` - URL scheme configuration

### 2. Authentication Service
- `AuthenticationService.swift` - Core authentication logic
- `AuthenticationView.swift` - UI for sign in/sign up

### 3. App Configuration
- `urgoodApp.swift` - App delegate with URL handling
- `urgood.entitlements` - Apple Sign In capability

## 🌐 Firebase Console Setup

### 1. Authentication Settings
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select project: `urgood-dc7f0`
3. Navigate to **Authentication** > **Settings** > **General**
4. Add your app's bundle ID: `com.urgood.urgood`

### 2. Apple Sign In Configuration
1. In Firebase Console, go to **Authentication** > **Sign-in method**
2. Enable **Apple** provider
3. Add your Apple Developer Team ID (`JK7B7MXHZU`)
4. Configure the callback URL: `https://urgood-dc7f0.firebaseapp.com/__/auth/handler`
5. Set the **Service ID** to `com.urgood.urgood.signin`
6. Add the return domain: `urgood-dc7f0.firebaseapp.com`

> 🔐 **Production Reminder:** Apple Sign In requires a private key generated from the Developer portal (Certificates, Identifiers & Profiles > Keys). Download the `.p8` key, note the Key ID, and store the key securely for server-side token validation.

### 3. Backend Environment Variables
Ensure the following environment variables are set in the production backend (`backend/.env`):

- `APPLE_TEAM_ID=JK7B7MXHZU`
- `APPLE_KEY_ID=<Your Key ID>`
- `APPLE_CLIENT_ID=com.urgood.urgood`
- `APPLE_SERVICE_ID=com.urgood.urgood.signin`
- `APPLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"`

Store the private key with literal `\n` characters or load it from a secure secret manager. Never commit the raw `.p8` file.

### 3. Firestore Rules
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
  }
}
```

## 📱 iOS App Configuration

### 1. URL Scheme
The app is configured with the URL scheme: `com.urgood.urgood`

### 2. Apple Sign In Capability
Added to `urgood.entitlements`:
```xml
<key>com.apple.developer.applesignin</key>
<array>
    <string>Default</string>
</array>
```

### 3. Info.plist Configuration
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.urgood.urgood</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.urgood.urgood</string>
        </array>
    </dict>
</array>
```

## 🔄 Authentication Flow

### 1. Apple Sign In (Production)
1. User taps "Sign in with Apple"
2. Apple presents authentication sheet
3. User authenticates with Face ID/Touch ID
4. App receives Apple ID credential
5. Firebase exchanges the credential using `OAuthProvider.appleCredential`
6. App posts `identityToken` + `authorizationCode` to `https://api.urgood.app/v1/auth/apple`
7. Backend verifies the token, issues refresh/access tokens, and persists the user
8. Access/refresh tokens are stored in the Keychain (handled in `EnhancedLocalStore`)
9. User state updates in-app and the main interface is shown

### 2. Email/Password
1. User enters email and password
2. Firebase validates credentials
3. User data retrieved from Firestore
4. App transitions to main interface

### 3. Sign Out
1. User taps "Sign Out" in settings
2. Firebase signs out user
3. App returns to authentication screen

## 🛡️ Security Features

### 1. Nonce Validation
- Apple Sign In uses cryptographic nonce for security
- Prevents replay attacks
- Validates token authenticity

### 2. Error Handling
- Network error detection
- Invalid credential handling
- User-friendly error messages

### 3. Data Privacy
- User data stored securely in Firestore
- Authentication state managed by Firebase
- Local data cleared on sign out

## 🧪 Testing

### 1. Test Apple Sign In
1. Run app on physical device (required for Apple Sign In)
2. Tap "Sign in with Apple"
3. Complete authentication flow
4. Verify user data in Firebase Console

### 2. Test Email Authentication
1. Create account with email/password
2. Sign out and sign back in
3. Verify data persistence

### 3. Test Error Scenarios
1. Try invalid credentials
2. Test network disconnection
3. Verify error messages

## 🚨 Troubleshooting

### Common Issues

#### "Apple Sign In not available"
- Ensure running on physical device
- Check Apple Developer account setup
- Verify bundle ID matches

#### "Firebase configuration error"
- Check `GoogleService-Info.plist` is included in project
- Verify project ID matches Firebase Console
- Ensure API key is correct

#### "URL scheme not working"
- Check `Info.plist` configuration
- Verify bundle identifier matches
- Test URL scheme in Safari

### Debug Steps
1. Check Firebase Console for authentication logs
2. Verify Firestore rules allow user access
3. Test with Firebase Auth emulator
4. Check Xcode console for error messages

## 📚 Additional Resources

- [Firebase Authentication Documentation](https://firebase.google.com/docs/auth)
- [Apple Sign In Documentation](https://developer.apple.com/sign-in-with-apple/)
- [Firebase iOS Setup Guide](https://firebase.google.com/docs/ios/setup)

---

**Note**: This authentication system is production-ready and follows Firebase best practices for security and user experience.
