import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { getConfig, validateConfig, getEnvironmentSettings } from './config';

// Initialize Firebase Admin
admin.initializeApp();
const db = admin.firestore();

// Validate configuration on startup
validateConfig();

// Export functions from voice-only module
export { synthesizeSpeech } from './voice-only';

// Voice Chat Authorization Function with Enhanced Security
export const authorizeVoiceChat = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  try {
    const config = getConfig();
    const envSettings = getEnvironmentSettings();
    const userId = context.auth.uid;
    const sessionId = data.sessionId || `session_${Date.now()}`;

    console.log(`🔐 Voice chat authorization request from user: ${userId} (${envSettings.isProduction ? 'PROD' : 'DEV'})`);

    // Enhanced rate limiting based on environment
    const hourAgo = new Date(Date.now() - 60 * 60 * 1000);
    const recentSessions = await db.collection('voice_sessions')
      .where('userId', '==', userId)
      .where('timestamp', '>', admin.firestore.Timestamp.fromDate(hourAgo))
      .get();

    const rateLimit = envSettings.rateLimits.voiceChat;
    if (recentSessions.size >= rateLimit) {
      console.warn(`🚫 Rate limit exceeded for user ${userId}: ${recentSessions.size}/${rateLimit}`);
      throw new functions.https.HttpsError('resource-exhausted', `Voice chat rate limit exceeded (${rateLimit}/hour). Please try again later.`);
    }

    // Get user data to check subscription and account status
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      console.error(`❌ User profile not found: ${userId}`);
      throw new functions.https.HttpsError('not-found', 'User profile not found');
    }

    const userData = userDoc.data();
    const subscriptionStatus = userData?.subscriptionStatus || 'free';
    
    // Environment-based subscription check
    if (envSettings.subscriptionRequired.voiceChat && subscriptionStatus !== 'premium') {
      console.warn(`🚫 Premium required for user ${userId} (status: ${subscriptionStatus})`);
      throw new functions.https.HttpsError('permission-denied', 'Voice chat requires premium subscription');
    }
    
    // Log the voice chat session with enhanced security data
    await db.collection('voice_sessions').add({
      userId,
      sessionId,
      subscriptionStatus,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      status: 'authorized',
      environment: envSettings.isProduction ? 'production' : 'development',
      ipAddress: context.rawRequest?.ip || 'unknown',
      userAgent: context.rawRequest?.get('user-agent') || 'unknown',
      rateLimit: {
        current: recentSessions.size,
        max: rateLimit
      }
    });

    console.log(`✅ Voice chat authorized for user: ${userId} (${subscriptionStatus})`);

    return {
      authorized: true,
      apiKey: config.openai.key,
      userId,
      sessionId,
      subscriptionStatus,
      environment: envSettings.isProduction ? 'production' : 'development'
    };

  } catch (error) {
    console.error('❌ Voice Chat Authorization Error:', error);
    
    // Log security events
    if (context.auth?.uid) {
      await db.collection('security_logs').add({
        userId: context.auth.uid,
        event: 'voice_chat_auth_failed',
        error: error instanceof Error ? error.message : 'Unknown error',
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        ipAddress: context.rawRequest?.ip || 'unknown'
      }).catch(logError => console.error('Failed to log security event:', logError));
    }
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to authorize voice chat');
  }
});