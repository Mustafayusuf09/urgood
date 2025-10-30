import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { OpenAI } from 'openai';
import { z } from 'zod';
import { getConfig, getEnvironmentSettings } from './config';

// Get Firestore instance (initialized in index.ts)
const db = admin.firestore();

// Note: Voice Chat Authorization is now handled in index.ts to avoid duplication
// This file focuses on TTS functionality only

// MARK: - ElevenLabs Text-to-Speech

export const synthesizeSpeech = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const schema = z.object({
    text: z.string().min(1).max(5000), // Limit text length
    voiceId: z.string().optional(),
    modelId: z.string().optional(),
  });

  try {
    const config = getConfig();
    const envSettings = getEnvironmentSettings();
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
    const response = await fetch(
      `https://api.elevenlabs.io/v1/text-to-speech/${selectedVoiceId}`,
      {
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
      }
    );

    if (!response.ok) {
      console.error(`ElevenLabs API error: ${response.status} ${response.statusText}`);
      
      if (response.status === 401) {
        throw new functions.https.HttpsError('internal', 'TTS authentication failed');
      } else if (response.status === 429) {
        throw new functions.https.HttpsError('resource-exhausted', 'TTS quota exceeded');
      } else {
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

  } catch (error) {
    console.error('TTS Synthesis Error:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to synthesize speech');
  }
});

// Helper function for rate limiting
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
  
  // Log this action
  await db.collection('rate_limits').add({
    userId,
    action,
    timestamp: admin.firestore.FieldValue.serverTimestamp()
  });
}
