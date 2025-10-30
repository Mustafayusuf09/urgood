import { Router } from 'express';
import { body, query } from 'express-validator';
import { prisma } from '../utils/database';
import { validateRequest } from '../middleware/validation';
import { asyncHandler } from '../middleware/errorHandler';
import { logger } from '../utils/logger';

const router = Router();

/**
 * @swagger
 * /analytics/events:
 *   post:
 *     summary: Track an analytics event
 *     tags: [Analytics]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - eventName
 *             properties:
 *               eventName:
 *                 type: string
 *               properties:
 *                 type: object
 *               sessionId:
 *                 type: string
 *     responses:
 *       201:
 *         description: Event tracked successfully
 */
router.post('/events',
  [
    body('eventName').isLength({ min: 1, max: 100 }).withMessage('Event name must be between 1 and 100 characters'),
    body('properties').optional().isObject().withMessage('Properties must be an object'),
    body('sessionId').optional().isUUID().withMessage('Session ID must be a valid UUID')
  ],
  validateRequest,
  asyncHandler(async (req, res) => {
    const userId = req.user!.id;
    const { eventName, properties, sessionId } = req.body;
    
    // Create analytics event
    const analyticsEvent = await prisma.analyticsEvent.create({
      data: {
        userId,
        eventName,
        properties,
        sessionId,
        deviceId: req.headers['x-device-id'] as string,
        platform: req.headers['x-platform'] as string,
        version: req.headers['x-app-version'] as string,
        ipAddress: req.ip,
        userAgent: req.get('User-Agent')
      },
      select: {
        id: true,
        eventName: true,
        properties: true,
        createdAt: true
      }
    });
    
    logger.info('Analytics event tracked', {
      userId,
      eventName,
      eventId: analyticsEvent.id
    });
    
    res.status(201).json({
      success: true,
      message: 'Event tracked successfully',
      data: { event: analyticsEvent }
    });
  })
);

/**
 * @swagger
 * /analytics/dashboard:
 *   get:
 *     summary: Get user analytics dashboard
 *     tags: [Analytics]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: period
 *         schema:
 *           type: string
 *           enum: [7d, 30d, 90d]
 *           default: 30d
 *     responses:
 *       200:
 *         description: Analytics dashboard data retrieved successfully
 */
router.get('/dashboard',
  query('period').optional().isIn(['7d', '30d', '90d']),
  validateRequest,
  asyncHandler(async (req, res) => {
    const userId = req.user!.id;
    const period = req.query.period as string || '30d';
    
    // Calculate date range
    const days = period === '7d' ? 7 : period === '30d' ? 30 : 90;
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);
    
    // Get user stats
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        streakCount: true,
        totalCheckins: true,
        messagesThisWeek: true,
        createdAt: true,
        lastActiveAt: true
      }
    });
    
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }
    
    // Get analytics for the period
    const [
      totalMessages,
      totalMoodEntries,
      recentEvents,
      dailyActivity,
      moodTrends
    ] = await Promise.all([
      // Total messages in period
      prisma.chatMessage.count({
        where: {
          userId,
          createdAt: { gte: startDate }
        }
      }),
      
      // Total mood entries in period
      prisma.moodEntry.count({
        where: {
          userId,
          createdAt: { gte: startDate }
        }
      }),
      
      // Recent analytics events
      prisma.analyticsEvent.findMany({
        where: {
          userId,
          createdAt: { gte: startDate }
        },
        orderBy: { createdAt: 'desc' },
        take: 10,
        select: {
          eventName: true,
          properties: true,
          createdAt: true
        }
      }),
      
      // Daily activity (messages and mood entries by day)
      prisma.$queryRaw`
        SELECT 
          DATE(created_at) as date,
          COUNT(*) as message_count
        FROM chat_messages 
        WHERE user_id = ${userId} 
          AND created_at >= ${startDate}
        GROUP BY DATE(created_at)
        ORDER BY date ASC
      `,
      
      // Mood trends
      prisma.moodEntry.findMany({
        where: {
          userId,
          createdAt: { gte: startDate }
        },
        select: {
          mood: true,
          createdAt: true
        },
        orderBy: { createdAt: 'asc' }
      })
    ]);
    
    // Calculate engagement metrics
    const daysSinceJoined = Math.floor(
      (Date.now() - user.createdAt.getTime()) / (1000 * 60 * 60 * 24)
    );
    
    const daysSinceLastActive = user.lastActiveAt 
      ? Math.floor((Date.now() - user.lastActiveAt.getTime()) / (1000 * 60 * 60 * 24))
      : daysSinceJoined;
    
    // Process mood trends
    const moodAverage = moodTrends.length > 0 
      ? moodTrends.reduce((sum, entry) => sum + entry.mood, 0) / moodTrends.length
      : 0;
    
    // Group mood entries by week
    const weeklyMoodTrends = moodTrends.reduce((weeks: any, entry) => {
      const weekStart = new Date(entry.createdAt);
      weekStart.setDate(weekStart.getDate() - weekStart.getDay());
      const weekKey = weekStart.toISOString().split('T')[0];
      
      if (!weeks[weekKey]) {
        weeks[weekKey] = [];
      }
      weeks[weekKey].push(entry.mood);
      return weeks;
    }, {});
    
    const weeklyAverages = Object.entries(weeklyMoodTrends).map(([week, moods]: [string, any]) => ({
      week,
      averageMood: moods.reduce((sum: number, mood: number) => sum + mood, 0) / moods.length,
      entryCount: moods.length
    }));
    
    const dashboard = {
      overview: {
        streakCount: user.streakCount,
        totalCheckins: user.totalCheckins,
        messagesThisWeek: user.messagesThisWeek,
        daysSinceJoined,
        daysSinceLastActive
      },
      periodStats: {
        period,
        totalMessages,
        totalMoodEntries,
        averageMood: Math.round(moodAverage * 100) / 100,
        activeDays: new Set(moodTrends.map(entry => 
          entry.createdAt.toISOString().split('T')[0]
        )).size
      },
      trends: {
        dailyActivity,
        weeklyMoodTrends: weeklyAverages,
        recentEvents: recentEvents.slice(0, 5)
      },
      insights: generateInsights(user, totalMessages, totalMoodEntries, moodAverage, days)
    };
    
    res.json({
      success: true,
      data: { dashboard }
    });
  })
);

// Helper function to generate insights
function generateInsights(
  user: any, 
  totalMessages: number, 
  totalMoodEntries: number, 
  averageMood: number, 
  days: number
) {
  const insights = [];
  
  // Streak insights
  if (user.streakCount >= 7) {
    insights.push({
      type: 'achievement',
      title: 'Great Consistency!',
      message: `You've maintained a ${user.streakCount}-day streak. Keep it up!`,
      icon: '🔥'
    });
  }
  
  // Activity insights
  const avgMessagesPerDay = totalMessages / days;
  if (avgMessagesPerDay > 2) {
    insights.push({
      type: 'engagement',
      title: 'Highly Engaged',
      message: `You're averaging ${Math.round(avgMessagesPerDay * 10) / 10} messages per day.`,
      icon: '💬'
    });
  }
  
  // Mood insights
  if (averageMood > 0) {
    if (averageMood >= 4) {
      insights.push({
        type: 'mood',
        title: 'Positive Trend',
        message: `Your average mood is ${Math.round(averageMood * 10) / 10}/5. You're doing great!`,
        icon: '😊'
      });
    } else if (averageMood < 2.5) {
      insights.push({
        type: 'mood',
        title: 'Need Support?',
        message: `Your average mood is ${Math.round(averageMood * 10) / 10}/5. Consider reaching out for support.`,
        icon: '🤗'
      });
    }
  }
  
  // Check-in insights
  const avgCheckinsPerWeek = (totalMoodEntries / days) * 7;
  if (avgCheckinsPerWeek >= 5) {
    insights.push({
      type: 'habit',
      title: 'Excellent Tracking',
      message: `You're checking in ${Math.round(avgCheckinsPerWeek * 10) / 10} times per week on average.`,
      icon: '📊'
    });
  }
  
  return insights;
}

export default router;
