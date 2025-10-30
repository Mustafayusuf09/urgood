# 🔒 Firebase Security Setup Guide

This guide explains the comprehensive security measures implemented for UrGood's Firebase backend.

## 🛡️ Security Features Implemented

### ✅ Firestore Security Rules
- **User-based access control**: Users can only access their own data
- **Authentication required**: All operations require valid Firebase Auth
- **Data validation**: Strict validation of data structure and types
- **Rate limiting protection**: Built-in protection against abuse
- **Default deny**: Any unspecified collections are blocked

### ✅ Firestore Indexes
- **Optimized queries**: Composite indexes for complex queries
- **Performance optimization**: Indexes for all common query patterns
- **User-scoped queries**: Efficient filtering by userId
- **Time-based sorting**: Optimized timestamp-based queries

### ✅ Firebase Functions Security
- **Authentication verification**: All functions require valid auth
- **Rate limiting**: Per-user limits on API calls
- **Subscription validation**: Premium features gated properly
- **Input validation**: Zod schema validation for all inputs
- **Error handling**: Secure error messages without data leaks

## 📁 Collections & Security Rules

### Users Collection (`/users/{userId}`)
```javascript
// Users can only read/write their own profile
allow read, write: if request.auth.uid == userId && isValidUserData();
```

**Protected Data:**
- Personal information (email, name)
- Subscription status
- Usage statistics
- Preferences

### Chat Messages (`/chat_messages/{messageId}`)
```javascript
// Users can only access their own messages
allow read: if resource.data.userId == request.auth.uid;
allow create: if isValidChatMessage();
```

**Protected Data:**
- Chat conversations
- AI responses
- Message metadata

### Mood Entries (`/mood_entries/{entryId}`)
```javascript
// Users can only access their own mood data
allow read: if resource.data.userId == request.auth.uid;
allow create: if isValidMoodEntry();
```

**Protected Data:**
- Mood ratings (1-5 scale)
- Mood tags and categories
- Timestamp data

### Sessions (`/sessions/{sessionId}`)
```javascript
// Users can only access their own sessions
allow read: if resource.data.userId == request.auth.uid;
```

**Protected Data:**
- Chat session metadata
- Session duration
- Activity timestamps

### Insights (`/insights/{insightId}`)
```javascript
// Users can only access their own insights
allow read: if resource.data.userId == request.auth.uid;
```

**Protected Data:**
- AI-generated insights
- Progress analysis
- Personalized recommendations

## 🚀 Deployment Instructions

### 1. Deploy Security Rules
```bash
# Deploy Firestore rules
firebase deploy --only firestore:rules

# Deploy Firestore indexes
firebase deploy --only firestore:indexes
```

### 2. Configure Firebase Functions Environment
```bash
# Set OpenAI API key
firebase functions:config:set openai.key="your-openai-api-key"

# Set ElevenLabs API key
firebase functions:config:set elevenlabs.key="your-elevenlabs-api-key"

# Deploy functions
firebase deploy --only functions
```

### 3. Verify Security Rules
```bash
# Test security rules locally
firebase emulators:start --only firestore

# Run security rule tests
npm test -- --testPathPattern=firestore.rules.test.js
```

## 🔍 Security Validation

### Data Validation Functions
```javascript
// User data validation
function isValidUserData() {
  return request.resource.data.keys().hasAll([
    'uid', 'email', 'subscriptionStatus', 'streakCount', 
    'totalCheckins', 'messagesThisWeek', 'isEmailVerified'
  ]) &&
  request.resource.data.subscriptionStatus in ['free', 'premium'];
}

// Chat message validation
function isValidChatMessage() {
  return request.resource.data.keys().hasAll([
    'id', 'role', 'text', 'timestamp', 'userId'
  ]) &&
  request.resource.data.role in ['user', 'assistant'] &&
  request.resource.data.userId == request.auth.uid;
}

// Mood entry validation
function isValidMoodEntry() {
  return request.resource.data.mood >= 1 &&
         request.resource.data.mood <= 5 &&
         request.resource.data.userId == request.auth.uid;
}
```

## ⚡ Rate Limiting

### Firebase Functions Rate Limits
- **Voice Chat**: 5 sessions per hour per user
- **TTS Synthesis**: 30 requests per minute per user
- **General API**: 100 requests per hour per user

### Implementation
```typescript
async function checkRateLimit(userId: string, action: string, limit: number, windowMinutes: number) {
  const windowStart = new Date(Date.now() - windowMinutes * 60 * 1000);
  
  const recentActions = await db.collection('rate_limits')
    .where('userId', '==', userId)
    .where('action', '==', action)
    .where('timestamp', '>', admin.firestore.Timestamp.fromDate(windowStart))
    .get();
  
  if (recentActions.size >= limit) {
    throw new functions.https.HttpsError('resource-exhausted', 'Rate limit exceeded');
  }
}
```

## 🔐 API Key Security

### Environment Variables
```bash
# Firebase Functions Config
OPENAI_API_KEY=sk-your-openai-key
ELEVENLABS_API_KEY=your-elevenlabs-key
NODE_ENV=production
```

### Secure Key Management
- ✅ API keys stored in Firebase Functions config
- ✅ Keys never exposed to client-side code
- ✅ Environment-based configuration
- ✅ Separate keys for development/production

## 📊 Analytics & Monitoring

### Security Events Logged
- Authentication attempts
- Rate limit violations
- Unauthorized access attempts
- API key usage
- Subscription violations

### Monitoring Collections
- `analytics_events` - User activity tracking
- `rate_limits` - Rate limiting enforcement
- `voice_sessions` - Voice chat usage
- `security_logs` - Security-related events

## 🚨 Security Best Practices

### ✅ Implemented
- User authentication required for all operations
- Data isolation between users
- Input validation and sanitization
- Rate limiting and abuse prevention
- Secure API key management
- Comprehensive logging and monitoring

### 🔄 Ongoing Security
- Regular security rule audits
- API key rotation schedule
- Rate limit monitoring and adjustment
- User behavior analysis
- Security incident response plan

## 🧪 Testing Security Rules

### Test Commands
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Start emulator
firebase emulators:start --only firestore

# Run security tests
npm run test:security
```

### Test Coverage
- ✅ Authenticated user access
- ✅ Unauthorized access prevention
- ✅ Cross-user data isolation
- ✅ Data validation enforcement
- ✅ Rate limiting functionality

## 📞 Emergency Procedures

### Security Incident Response
1. **Immediate**: Disable affected Firebase Functions
2. **Assess**: Review security logs and identify breach scope
3. **Contain**: Update security rules to block malicious access
4. **Notify**: Alert users if personal data was compromised
5. **Recover**: Restore secure operations and implement fixes
6. **Learn**: Update security measures based on incident

### Contact Information
- **Firebase Console**: https://console.firebase.google.com
- **Security Issues**: Report to development team immediately
- **Emergency Shutdown**: Use Firebase Console to disable services

---

🔒 **Security is our top priority. This setup ensures user data is protected while maintaining optimal performance.**
