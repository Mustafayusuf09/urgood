import { Router } from 'express';
import { body } from 'express-validator';
import { authMiddleware } from '../middleware/auth';
import { validateRequest } from '../middleware/validation';
import { prisma } from '../utils/database';
import type { VoiceUsage } from '@prisma/client';
import OpenAI from 'openai';
import { config } from '../config/config';

const router = Router();

const VOICE_SOFT_CAP_MINUTES = 100;
const VOICE_SOFT_CAP_SECONDS = VOICE_SOFT_CAP_MINUTES * 60;

const getUsageWindow = (reference: Date = new Date()) => {
    const start = new Date(Date.UTC(reference.getUTCFullYear(), reference.getUTCMonth(), 1));
    const end = new Date(Date.UTC(reference.getUTCFullYear(), reference.getUTCMonth() + 1, 1));
    return { start, end };
};

const formatDailySessionStatus = (record: VoiceUsage, softCapReached: boolean) => {
    return {
        status: softCapReached ? 'soft_cap_reached' : 'available',
        softCapReached,
        sessionsStartedThisMonth: record.sessionsStarted,
        sessionsCompletedThisMonth: record.sessionsCompleted
    };
};

const ensureVoiceUsageRecord = async (userId: string): Promise<VoiceUsage> => {
    const { start, end } = getUsageWindow();

    let record = await prisma.voiceUsage.findFirst({
        where: {
            userId,
            periodStart: start,
            periodEnd: end
        }
    });

    if (!record) {
        record = await prisma.voiceUsage.create({
            data: {
                userId,
                periodStart: start,
                periodEnd: end
            }
        });
    }

    return record;
};

const getVoiceUsageSummary = async (userId: string) => {
    const record = await ensureVoiceUsageRecord(userId);
    const softCapReached = record.secondsUsed >= VOICE_SOFT_CAP_SECONDS;
    return { record, softCapReached };
};

const incrementVoiceSessionsStarted = async (userId: string) => {
    const record = await ensureVoiceUsageRecord(userId);
    const updated = await prisma.voiceUsage.update({
        where: { id: record.id },
        data: {
            sessionsStarted: { increment: 1 },
            lastSessionAt: new Date()
        }
    });

    return { record: updated, softCapReached: updated.secondsUsed >= VOICE_SOFT_CAP_SECONDS };
};

const incrementVoiceSessionsCompleted = async (userId: string, durationSeconds: number) => {
    const record = await ensureVoiceUsageRecord(userId);
    const safeDuration = Math.max(0, Math.floor(durationSeconds));
    const previouslyAtSoftCap = record.secondsUsed >= VOICE_SOFT_CAP_SECONDS;

    const updated = await prisma.voiceUsage.update({
        where: { id: record.id },
        data: {
            sessionsCompleted: { increment: 1 },
            secondsUsed: { increment: safeDuration },
            lastSessionAt: new Date()
        }
    });

    const softCapReached = updated.secondsUsed >= VOICE_SOFT_CAP_SECONDS;

    if (!previouslyAtSoftCap && softCapReached) {
        console.log(`⚠️ [Voice] User ${userId} reached the 100-minute voice soft cap (soft cap applies to daily sessions).`);
    }

    return { record: updated, softCapReached };
};

// Initialize OpenAI client
const openai = new OpenAI({
    apiKey: config.openai.apiKey,
});

/**
 * POST /api/voice/authorize
 * Authorize user for OpenAI Realtime API access
 * 
 * This endpoint:
 * 1. Verifies user authentication
 * 2. Checks user's subscription status for rate limiting
 * 3. Logs voice chat session start
 * 4. Returns authorization for direct OpenAI connection
 */
router.post('/authorize', 
    authMiddleware,
    [
        body('sessionId').optional().isString(),
        body('userId').optional().isString()
    ],
    validateRequest,
    async (req, res) => {
        try {
            const userId = req.user?.id || 'anonymous';
            const subscriptionStatus = req.user?.subscriptionStatus || 'FREE';
            const { sessionId } = req.body;

            // Log voice chat session start
            console.log(`🎙️ [Voice] User ${userId} starting voice chat session`);

            // Check if user has voice chat access
            const hasVoiceAccess = subscriptionStatus === 'PREMIUM_MONTHLY' || subscriptionStatus === 'TRIAL';
            
            if (!hasVoiceAccess) {
                return res.status(403).json({
                    error: 'Voice chat requires premium subscription',
                    code: 'PREMIUM_REQUIRED'
                });
            }

            // Check OpenAI API key is configured
            if (!config.openai.apiKey || config.openai.apiKey === 'sk-your-openai-api-key-here') {
                console.error('❌ [Voice] OpenAI API key not configured');
                return res.status(500).json({
                    error: 'Voice chat service unavailable',
                    code: 'SERVICE_UNAVAILABLE'
                });
            }

            const usageSummary = await getVoiceUsageSummary(userId);
            const dailySessions = formatDailySessionStatus(usageSummary.record, usageSummary.softCapReached);

            // Return authorization
            res.json({
                authorized: true,
                userId,
                sessionId,
                rateLimits: {
                    requestsPerMinute: subscriptionStatus === 'PREMIUM_MONTHLY' ? 60 : 10,
                    dailyLimit: subscriptionStatus === 'PREMIUM_MONTHLY' ? 1000 : 50
                },
                dailySessions,
                message: usageSummary.softCapReached
                    ? 'Daily sessions are currently in soft-cap mode. We will still do our best to keep them going.'
                    : 'Daily sessions are ready to go.'
            });

        } catch (error) {
            console.error('❌ [Voice] Authorization error:', error);
            res.status(500).json({ 
                error: 'Failed to authorize voice chat',
                code: 'AUTHORIZATION_FAILED'
            });
        }
    }
);

/**
 * POST /api/voice/session/start
 * Start a voice chat session and log analytics
 */
router.post('/session/start',
    authMiddleware,
    async (req, res) => {
        try {
            const userId = req.user?.id || 'anonymous';
            const sessionId = `voice_${Date.now()}_${userId}`;

            // Log session start for analytics
            console.log(`🎙️ [Voice] Session started: ${sessionId} for user ${userId}`);

            const usageSummary = await incrementVoiceSessionsStarted(userId);
            const dailySessions = formatDailySessionStatus(usageSummary.record, usageSummary.softCapReached);

            // Track analytics event
            const { analytics } = await import('../utils/analytics');
            await analytics.trackVoiceSession(userId, sessionId, 'started', {
                platform: req.headers['x-platform'] || 'web',
                subscriptionStatus: req.user?.subscriptionStatus,
                deviceId: req.headers['x-device-id'],
                version: req.headers['x-app-version'],
                dailySessionStatus: dailySessions.status
            });

            res.json({
                sessionId,
                startedAt: new Date().toISOString(),
                status: 'active',
                dailySessions
            });

        } catch (error) {
            console.error('❌ [Voice] Session start error:', error);
            res.status(500).json({ 
                error: 'Failed to start voice session',
                code: 'SESSION_START_FAILED'
            });
        }
    }
);

/**
 * POST /api/voice/session/end
 * End a voice chat session and log analytics
 */
router.post('/session/end',
    authMiddleware,
    async (req, res) => {
        try {
            const userId = req.user?.id || 'anonymous';
            const { sessionId, duration, messageCount } = req.body;
            const numericDuration = typeof duration === 'number' ? duration : Number(duration);
            const safeDuration = Number.isFinite(numericDuration) ? Math.max(0, Math.floor(numericDuration)) : 0;
            const usageSummary = await incrementVoiceSessionsCompleted(userId, safeDuration);
            const dailySessions = formatDailySessionStatus(usageSummary.record, usageSummary.softCapReached);

            // Log session end for analytics
            console.log(`🎙️ [Voice] Session ended: ${sessionId} - Duration: ${safeDuration}s, Messages: ${messageCount}`);

            // Track analytics event
            const { analytics } = await import('../utils/analytics');
            await analytics.trackVoiceSession(userId, sessionId, 'ended', {
                duration: safeDuration,
                messageCount: messageCount || 0,
                platform: req.headers['x-platform'] || 'web',
                subscriptionStatus: req.user?.subscriptionStatus,
                deviceId: req.headers['x-device-id'],
                version: req.headers['x-app-version'],
                dailySessionStatus: dailySessions.status
            });

            res.json({
                sessionId,
                endedAt: new Date().toISOString(),
                status: 'completed',
                dailySessions
            });

        } catch (error) {
            console.error('❌ [Voice] Session end error:', error);
            res.status(500).json({ 
                error: 'Failed to end voice session',
                code: 'SESSION_END_FAILED'
            });
        }
    }
);

/**
 * GET /api/voice/status
 * Check voice chat service status
 */
router.get('/status', async (req, res) => {
    try {
        // Check if OpenAI API is accessible
        const isOpenAIConfigured = config.openai.apiKey && 
                                  config.openai.apiKey !== 'sk-your-openai-api-key-here';

        res.json({
            status: 'online',
            openaiConfigured: isOpenAIConfigured,
            model: config.openai.model || 'gpt-4o',
            timestamp: new Date().toISOString()
        });

    } catch (error) {
        console.error('❌ [Voice] Status check error:', error);
        res.status(500).json({ 
            status: 'error',
            error: 'Service status check failed'
        });
    }
});

export default router;
