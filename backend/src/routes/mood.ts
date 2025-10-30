import { Router } from 'express';
import { body, query, param } from 'express-validator';
import { prisma } from '../utils/database';
import { validateRequest, validationRules } from '../middleware/validation';
import { asyncHandler } from '../middleware/errorHandler';
import { logger } from '../utils/logger';
import { cacheService } from '../utils/redis';
import { analytics } from '../utils/analytics';

const router = Router();

/**
 * @swagger
 * /mood/entries:
 *   post:
 *     summary: Create a mood entry
 *     tags: [Mood]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - mood
 *             properties:
 *               mood:
 *                 type: integer
 *                 minimum: 1
 *                 maximum: 5
 *               tags:
 *                 type: array
 *                 items:
 *                   type: string
 *               notes:
 *                 type: string
 *     responses:
 *       201:
 *         description: Mood entry created successfully
 */
router.post('/entries',
  validationRules.moodEntry,
  validateRequest,
  asyncHandler(async (req, res) => {
    const userId = req.user!.id;
    const { mood, tags = [], notes } = req.body;
    
    // Create mood entry
    const moodEntry = await prisma.moodEntry.create({
      data: {
        userId,
        mood,
        tags,
        notes
      },
      select: {
        id: true,
        mood: true,
        tags: true,
        notes: true,
        createdAt: true
      }
    });
    
    // Update user stats
    await prisma.user.update({
      where: { id: userId },
      data: {
        totalCheckins: { increment: 1 },
        lastActiveAt: new Date()
      }
    });
    
    // Track analytics event
    await analytics.trackMoodEntry(userId, mood, notes);
    
    // Clear cache
    await cacheService.delete(`user_profile:${userId}`);
    
    logger.info('Mood entry created', {
      userId,
      moodEntryId: moodEntry.id,
      mood
    });
    
    res.status(201).json({
      success: true,
      message: 'Mood entry created successfully',
      data: { moodEntry }
    });
  })
);

/**
 * @swagger
 * /mood/entries:
 *   get:
 *     summary: Get mood entries
 *     tags: [Mood]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: startDate
 *         schema:
 *           type: string
 *           format: date
 *       - in: query
 *         name: endDate
 *         schema:
 *           type: string
 *           format: date
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           minimum: 1
 *           maximum: 100
 *           default: 30
 *     responses:
 *       200:
 *         description: Mood entries retrieved successfully
 */
router.get('/entries',
  [
    query('startDate').optional().isISO8601().toDate(),
    query('endDate').optional().isISO8601().toDate(),
    query('limit').optional().isInt({ min: 1, max: 100 }).toInt()
  ],
  validateRequest,
  asyncHandler(async (req, res) => {
    const userId = req.user!.id;
    const startDate = req.query.startDate as Date;
    const endDate = req.query.endDate as Date;
    const limit = parseInt(req.query.limit as string) || 30;
    
    // Build date filter
    const dateFilter: any = {};
    if (startDate) dateFilter.gte = startDate;
    if (endDate) dateFilter.lte = endDate;
    
    const entries = await prisma.moodEntry.findMany({
      where: {
        userId,
        ...(Object.keys(dateFilter).length > 0 && { createdAt: dateFilter })
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
      select: {
        id: true,
        mood: true,
        tags: true,
        notes: true,
        createdAt: true
      }
    });
    
    res.json({
      success: true,
      data: { entries }
    });
  })
);

/**
 * @swagger
 * /mood/trends:
 *   get:
 *     summary: Get mood trends and analytics
 *     tags: [Mood]
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
 *         description: Mood trends retrieved successfully
 */
router.get('/trends',
  query('period').optional().isIn(['7d', '30d', '90d']),
  validateRequest,
  asyncHandler(async (req, res) => {
    const userId = req.user!.id;
    const period = req.query.period as string || '30d';
    
    // Calculate date range
    const days = period === '7d' ? 7 : period === '30d' ? 30 : 90;
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);
    
    // Get mood entries for the period
    const entries = await prisma.moodEntry.findMany({
      where: {
        userId,
        createdAt: { gte: startDate }
      },
      orderBy: { createdAt: 'asc' },
      select: {
        mood: true,
        tags: true,
        createdAt: true
      }
    });
    
    if (entries.length === 0) {
      return res.json({
        success: true,
        data: {
          trends: {
            averageMood: 0,
            moodDistribution: {},
            dailyAverages: [],
            commonTags: [],
            totalEntries: 0
          }
        }
      });
    }
    
    // Calculate statistics
    const totalMood = entries.reduce((sum, entry) => sum + entry.mood, 0);
    const averageMood = totalMood / entries.length;
    
    // Mood distribution
    const moodDistribution = entries.reduce((dist: any, entry) => {
      dist[entry.mood] = (dist[entry.mood] || 0) + 1;
      return dist;
    }, {});
    
    // Daily averages
    const dailyGroups = entries.reduce((groups: any, entry) => {
      const date = entry.createdAt.toISOString().split('T')[0];
      if (!groups[date]) groups[date] = [];
      groups[date].push(entry.mood);
      return groups;
    }, {});
    
    const dailyAverages = Object.entries(dailyGroups).map(([date, moods]: [string, any]) => ({
      date,
      averageMood: moods.reduce((sum: number, mood: number) => sum + mood, 0) / moods.length,
      entryCount: moods.length
    }));
    
    // Common tags
    const allTags = entries.flatMap(entry => entry.tags);
    const tagCounts = allTags.reduce((counts: any, tag) => {
      counts[tag] = (counts[tag] || 0) + 1;
      return counts;
    }, {});
    
    const commonTags = Object.entries(tagCounts)
      .sort(([, a]: [string, any], [, b]: [string, any]) => b - a)
      .slice(0, 10)
      .map(([tag, count]) => ({ tag, count }));
    
    const trends = {
      averageMood: Math.round(averageMood * 100) / 100,
      moodDistribution,
      dailyAverages,
      commonTags,
      totalEntries: entries.length,
      period,
      dateRange: {
        start: startDate.toISOString(),
        end: new Date().toISOString()
      }
    };
    
    res.json({
      success: true,
      data: { trends }
    });
  })
);

export default router;
