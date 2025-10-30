"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.authorizeVoiceChat = exports.synthesizeSpeech = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const config_1 = require("./config");
// Initialize Firebase Admin
admin.initializeApp();
const db = admin.firestore();
// Validate configuration on startup
(0, config_1.validateConfig)();
// Export functions from voice-only module
var voice_only_1 = require("./voice-only");
Object.defineProperty(exports, "synthesizeSpeech", { enumerable: true, get: function () { return voice_only_1.synthesizeSpeech; } });
// Voice Chat Authorization Function with Enhanced Security
exports.authorizeVoiceChat = functions.https.onCall(async (data, context) => {
    var _a, _b, _c, _d;
    // Verify authentication
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    try {
        const config = (0, config_1.getConfig)();
        const envSettings = (0, config_1.getEnvironmentSettings)();
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
        const subscriptionStatus = (userData === null || userData === void 0 ? void 0 : userData.subscriptionStatus) || 'free';
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
            ipAddress: ((_a = context.rawRequest) === null || _a === void 0 ? void 0 : _a.ip) || 'unknown',
            userAgent: ((_b = context.rawRequest) === null || _b === void 0 ? void 0 : _b.get('user-agent')) || 'unknown',
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
    }
    catch (error) {
        console.error('❌ Voice Chat Authorization Error:', error);
        // Log security events
        if ((_c = context.auth) === null || _c === void 0 ? void 0 : _c.uid) {
            await db.collection('security_logs').add({
                userId: context.auth.uid,
                event: 'voice_chat_auth_failed',
                error: error instanceof Error ? error.message : 'Unknown error',
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                ipAddress: ((_d = context.rawRequest) === null || _d === void 0 ? void 0 : _d.ip) || 'unknown'
            }).catch(logError => console.error('Failed to log security event:', logError));
        }
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', 'Failed to authorize voice chat');
    }
});
//# sourceMappingURL=index.js.map