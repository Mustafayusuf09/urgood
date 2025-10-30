import { Router } from 'express';
import { query, param } from 'express-validator';
import { prisma, getDatabaseStats } from '../utils/database';
import { validateRequest } from '../middleware/validation';
import { asyncHandler } from '../middleware/errorHandler';
import { requireRole } from '../middleware/auth';
import { logger } from '../utils/logger';

const router = Router();

// All admin routes require admin role
router.use(requireRole('admin'));

/**
 * @swagger
 * /admin/stats:
 *   get:
 *     summary: Get system statistics
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: System statistics retrieved successfully
 */
router.get('/stats',
  asyncHandler(async (req, res) => {
    // Get database statistics
    const dbStats = await getDatabaseStats();
    
    // Get additional statistics
    const [
      activeUsers,
      premiumUsers,
      recentCrisisEvents,
      systemHealth
    ] = await Promise.all([
      prisma.user.count({
        where: {
          lastActiveAt: {
            gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) // Last 7 days
          },
          deletedAt: null
        }
      }),
      prisma.user.count({
        where: {
          subscriptionStatus: {
            in: ['PREMIUM_MONTHLY']
          },
          deletedAt: null
        }
      }),
      prisma.crisisEvent.count({
        where: {
          createdAt: {
            gte: new Date(Date.now() - 24 * 60 * 60 * 1000) // Last 24 hours
          }
        }
      }),
      prisma.systemHealth.findMany({
        orderBy: { createdAt: 'desc' },
        take: 1
      })
    ]);
    
    const stats = {
      database: dbStats,
      users: {
        total: dbStats.users,
        active: activeUsers,
        premium: premiumUsers,
        freeUsers: dbStats.users - premiumUsers
      },
      activity: {
        totalMessages: dbStats.chatMessages,
        totalMoodEntries: dbStats.moodEntries,
        totalPayments: dbStats.payments
      },
      alerts: {
        recentCrisisEvents,
        systemHealth: systemHealth[0] || null
      }
    };
    
    res.json({
      success: true,
      data: { stats }
    });
  })
);

/**
 * @swagger
 * /admin/users:
 *   get:
 *     summary: Get users list with pagination
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           minimum: 1
 *           default: 1
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           minimum: 1
 *           maximum: 100
 *           default: 20
 *       - in: query
 *         name: search
 *         schema:
 *           type: string
 *       - in: query
 *         name: subscription
 *         schema:
 *           type: string
 *           enum: [FREE, PREMIUM_MONTHLY, TRIAL, CANCELLED]
 *     responses:
 *       200:
 *         description: Users list retrieved successfully
 */
router.get('/users',
  [
    query('page').optional().isInt({ min: 1 }).toInt(),
    query('limit').optional().isInt({ min: 1, max: 100 }).toInt(),
    query('search').optional().isString(),
    query('subscription').optional().isIn(['FREE', 'PREMIUM_MONTHLY', 'TRIAL', 'CANCELLED'])
  ],
  validateRequest,
  asyncHandler(async (req, res) => {
    const page = parseInt(req.query.page as string) || 1;
    const limit = parseInt(req.query.limit as string) || 20;
    const search = req.query.search as string;
    const subscription = req.query.subscription as string;
    const offset = (page - 1) * limit;
    
    // Build where clause
    const where: any = { deletedAt: null };
    
    if (search) {
      where.OR = [
        { email: { contains: search, mode: 'insensitive' } },
        { name: { contains: search, mode: 'insensitive' } }
      ];
    }
    
    if (subscription) {
      where.subscriptionStatus = subscription;
    }
    
    // Get users with pagination
    const [users, totalCount] = await Promise.all([
      prisma.user.findMany({
        where,
        skip: offset,
        take: limit,
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          email: true,
          name: true,
          subscriptionStatus: true,
          streakCount: true,
          totalCheckins: true,
          messagesThisWeek: true,
          lastActiveAt: true,
          createdAt: true,
          emailVerified: true
        }
      }),
      prisma.user.count({ where })
    ]);
    
    const totalPages = Math.ceil(totalCount / limit);
    
    res.json({
      success: true,
      data: {
        users,
        pagination: {
          page,
          limit,
          totalCount,
          totalPages,
          hasNext: page < totalPages,
          hasPrev: page > 1
        }
      }
    });
  })
);

/**
 * @swagger
 * /admin/users/{userId}:
 *   get:
 *     summary: Get detailed user information
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: userId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: User details retrieved successfully
 */
router.get('/users/:userId',
  param('userId').isUUID().withMessage('Invalid user ID'),
  validateRequest,
  asyncHandler(async (req, res) => {
    const { userId } = req.params;
    
    // Get user with related data
    const user = await prisma.user.findUnique({
      where: { id: userId },
      include: {
        sessions: {
          select: {
            id: true,
            deviceId: true,
            platform: true,
            ipAddress: true,
            createdAt: true,
            updatedAt: true
          }
        },
        payments: {
          select: {
            id: true,
            amount: true,
            currency: true,
            status: true,
            productId: true,
            createdAt: true
          },
          orderBy: { createdAt: 'desc' },
          take: 10
        },
        crisisEvents: {
          select: {
            id: true,
            level: true,
            resolved: true,
            createdAt: true
          },
          orderBy: { createdAt: 'desc' },
          take: 5
        }
      }
    });
    
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }
    
    // Get additional statistics
    const [messageCount, moodEntryCount] = await Promise.all([
      prisma.chatMessage.count({ where: { userId } }),
      prisma.moodEntry.count({ where: { userId } })
    ]);
    
    const userDetails = {
      ...user,
      statistics: {
        totalMessages: messageCount,
        totalMoodEntries: moodEntryCount
      }
    };
    
    res.json({
      success: true,
      data: { user: userDetails }
    });
  })
);

/**
 * @swagger
 * /admin/crisis-events:
 *   get:
 *     summary: Get crisis events for monitoring
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: level
 *         schema:
 *           type: string
 *           enum: [LOW, MEDIUM, HIGH, CRITICAL]
 *       - in: query
 *         name: resolved
 *         schema:
 *           type: boolean
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           minimum: 1
 *           maximum: 100
 *           default: 50
 *     responses:
 *       200:
 *         description: Crisis events retrieved successfully
 */
router.get('/crisis-events',
  [
    query('level').optional().isIn(['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']),
    query('resolved').optional().isBoolean().toBoolean(),
    query('limit').optional().isInt({ min: 1, max: 100 }).toInt()
  ],
  validateRequest,
  asyncHandler(async (req, res) => {
    const level = req.query.level as string;
    const resolved = req.query.resolved as boolean;
    const limit = parseInt(req.query.limit as string) || 50;
    
    const where: any = {};
    if (level) where.level = level;
    if (typeof resolved === 'boolean') where.resolved = resolved;
    
    const events = await prisma.crisisEvent.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: limit,
      select: {
        id: true,
        userId: true,
        level: true,
        message: true,
        actionTaken: true,
        resolved: true,
        createdAt: true,
        user: {
          select: {
            email: true,
            name: true
          }
        }
      }
    });
    
    res.json({
      success: true,
      data: { events }
    });
  })
);

/**
 * @swagger
 * /admin/analytics:
 *   get:
 *     summary: Get system analytics
 *     tags: [Admin]
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
 *         description: System analytics retrieved successfully
 */
router.get('/analytics',
  query('period').optional().isIn(['7d', '30d', '90d']),
  validateRequest,
  asyncHandler(async (req, res) => {
    const period = req.query.period as string || '30d';
    const days = period === '7d' ? 7 : period === '30d' ? 30 : 90;
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);
    
    // Get analytics data
    const [
      newUsers,
      activeUsers,
      totalMessages,
      totalMoodEntries,
      subscriptionConversions,
      crisisEvents
    ] = await Promise.all([
      prisma.user.count({
        where: {
          createdAt: { gte: startDate },
          deletedAt: null
        }
      }),
      prisma.user.count({
        where: {
          lastActiveAt: { gte: startDate },
          deletedAt: null
        }
      }),
      prisma.chatMessage.count({
        where: { createdAt: { gte: startDate } }
      }),
      prisma.moodEntry.count({
        where: { createdAt: { gte: startDate } }
      }),
      prisma.payment.count({
        where: {
          createdAt: { gte: startDate },
          status: 'SUCCEEDED'
        }
      }),
      prisma.crisisEvent.groupBy({
        by: ['level'],
        where: { createdAt: { gte: startDate } },
        _count: { id: true }
      })
    ]);
    
    // Daily activity trends
    const dailyStats = await prisma.$queryRaw`
      SELECT 
        DATE(created_at) as date,
        COUNT(DISTINCT user_id) as active_users,
        COUNT(*) as total_messages
      FROM chat_messages 
      WHERE created_at >= ${startDate}
      GROUP BY DATE(created_at)
      ORDER BY date ASC
    `;
    
    const analytics = {
      overview: {
        period,
        newUsers,
        activeUsers,
        totalMessages,
        totalMoodEntries,
        subscriptionConversions
      },
      crisisEvents: crisisEvents.reduce((acc: any, event) => {
        acc[event.level] = event._count.id;
        return acc;
      }, {}),
      trends: {
        dailyActivity: dailyStats
      }
    };
    
    res.json({
      success: true,
      data: { analytics }
    });
  })
);

export default router;
