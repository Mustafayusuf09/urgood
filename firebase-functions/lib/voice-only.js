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
exports.synthesizeSpeech = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const zod_1 = require("zod");
const config_1 = require("./config");
// Get Firestore instance (initialized in index.ts)
const db = admin.firestore();
// Note: Voice Chat Authorization is now handled in index.ts to avoid duplication
// This file focuses on TTS functionality only
// MARK: - ElevenLabs Text-to-Speech
exports.synthesizeSpeech = functions.https.onCall(async (data, context) => {
    // Verify authentication
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const schema = zod_1.z.object({
        text: zod_1.z.string().min(1).max(5000), // Limit text length
        voiceId: zod_1.z.string().optional(),
        modelId: zod_1.z.string().optional(),
    });
    try {
        const config = (0, config_1.getConfig)();
        const envSettings = (0, config_1.getEnvironmentSettings)();
        const { text, voiceId, modelId } = schema.parse(data);
        const userId = context.auth.uid;
        console.log(`🎙️ TTS request from user ${userId} (${envSettings.isProduction ? 'PROD' : 'DEV'}), text length: ${text.length}`);
        // Enhanced rate limiting based on environment
        const rateLimit = envSettings.rateLimits.tts;
        await checkRateLimit(userId, 'tts_synthesis', rateLimit, 1); // Per minute
        // Default to Rachel voice and multilingual v2 model
        const selectedVoiceId = voiceId || '21m00Tcm4TlvDq8ikWAM'; // Rachel
        const selectedModelId = modelId || 'eleven_multilingual_v2';
        // Call ElevenLabs API with secure configuration
        const response = await fetch(`https://api.elevenlabs.io/v1/text-to-speech/${selectedVoiceId}`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${config.elevenlabs.key}`,
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                text: text,
                model_id: selectedModelId,
                voice_settings: {
                    stability: 0.35,
                    similarity_boost: 0.85,
                },
            }),
        });
        if (!response.ok) {
            console.error(`ElevenLabs API error: ${response.status} ${response.statusText}`);
            if (response.status === 401) {
                throw new functions.https.HttpsError('internal', 'TTS authentication failed');
            }
            else if (response.status === 429) {
                throw new functions.https.HttpsError('resource-exhausted', 'TTS quota exceeded');
            }
            else {
                throw new functions.https.HttpsError('internal', 'TTS synthesis failed');
            }
        }
        // Get audio data as buffer
        const audioBuffer = await response.arrayBuffer();
        const audioBase64 = Buffer.from(audioBuffer).toString('base64');
        console.log(`✅ Successfully synthesized ${audioBuffer.byteLength} bytes of audio`);
        // Log analytics
        await db.collection('analytics_events').add({
            userId,
            eventName: 'tts_synthesis',
            parameters: {
                textLength: text.length,
                audioSize: audioBuffer.byteLength,
                voiceId: selectedVoiceId,
                modelId: selectedModelId,
            },
            timestamp: admin.firestore.FieldValue.serverTimestamp()
        });
        return {
            success: true,
            audioData: audioBase64,
            format: 'mp3',
            size: audioBuffer.byteLength,
        };
    }
    catch (error) {
        console.error('TTS Synthesis Error:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', 'Failed to synthesize speech');
    }
});
// Helper function for rate limiting
async function checkRateLimit(userId, action, limit, windowMinutes) {
    const windowStart = new Date(Date.now() - windowMinutes * 60 * 1000);
    const recentActions = await db.collection('rate_limits')
        .where('userId', '==', userId)
        .where('action', '==', action)
        .where('timestamp', '>', admin.firestore.Timestamp.fromDate(windowStart))
        .get();
    if (recentActions.size >= limit) {
        throw new functions.https.HttpsError('resource-exhausted', 'Rate limit exceeded');
    }
    // Log this action
    await db.collection('rate_limits').add({
        userId,
        action,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
}
//# sourceMappingURL=voice-only.js.map