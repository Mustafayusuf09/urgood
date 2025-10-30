import { Router } from 'express';
import { body, param } from 'express-validator';
import { prisma } from '../utils/database';
import { validateRequest, validationRules, schemas, validateSchema } from '../middleware/validation';
import { asyncHandler } from '../middleware/errorHandler';
import { auditEvents } from '../middleware/auditLogger';
import { hashPassword, verifyPassword } from '../middleware/auth';
import { logger } from '../utils/logger';
import { cacheService } from '../utils/redis';

const router = Router();

/**
 * @swagger
 * /users/profile:
 *   get:
 *     summary: Get current user profile
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: User profile retrieved successfully
 *       401:
 *         description: Unauthorized
 */
router.get('/profile',
  asyncHandler(async (req, res) => {
    const userId = req.user!.id;
    
    // Try to get from cache first
    const cacheKey = `user_profile:${userId}`;
    let user = await cacheService.get(cacheKey);
    
    if (!user) {
      user = await prisma.user.findUnique({
        where: { 
          id: userId,
          deletedAt: null
        },
        select: {
          id: true,
          email: true,
          name: true,
          subscriptionStatus: true,
          streakCount: true,
          totalCheckins: true,
          messagesThisWeek: true,
          lastActiveAt: true,
          timezone: true,
          language: true,
          preferences: true,
          emailVerified: true,
          createdAt: true,
          updatedAt: true
        }
      });
      
      if (user) {
        // Cache for 5 minutes
        await cacheService.set(cacheKey, user, 300);
      }
    }
    
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }
    
    res.json({
      success: true,
      data: { user }
    });
  })
);

/**
 * @swagger
 * /users/profile:
 *   put:
 *     summary: Update user profile
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name:
 *                 type: string
 *               timezone:
 *                 type: string
 *               language:
 *                 type: string
 *               preferences:
 *                 type: object
 *     responses:
 *       200:
 *         description: Profile updated successfully
 */
router.put('/profile',
  validateSchema(schemas.userUpdate),
  asyncHandler(async (req, res) => {
    const userId = req.user!.id;
    const { name, timezone, language, preferences } = req.body;
    
    // Update user
    const user = await prisma.user.update({
      where: { id: userId },
      data: {
        name,
        timezone,
        language,
        preferences,
        updatedAt: new Date()
      },
      select: {
        id: true,
        email: true,
        name: true,
        subscriptionStatus: true,
        timezone: true,
        language: true,
        preferences: true,
        updatedAt: true
      }
    });
    
    // Clear cache
    await cacheService.delete(`user_profile:${userId}`);
    await cacheService.delete(`user:${userId}`);
    
    // Log update
    auditEvents.userUpdate(userId, req);
    
    logger.info('User profile updated', {
      userId,
      updatedFields: Object.keys(req.body)
    });
    
    res.json({
      success: true,
      message: 'Profile updated successfully',
      data: { user }
    });
  })
);

/**
 * @swagger
 * /users/change-password:
 *   post:
 *     summary: Change user password
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - currentPassword
 *               - newPassword
 *             properties:
 *               currentPassword:
 *                 type: string
 *               newPassword:
 *                 type: string
 *                 minLength: 8
 *     responses:
 *       200:
 *         description: Password changed successfully
 *       400:
 *         description: Invalid current password
 */
router.post('/change-password',
  [
    body('currentPassword').notEmpty().withMessage('Current password is required'),
    body('newPassword')
      .isLength({ min: 8, max: 128 })
      .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/)
      .withMessage('New password must contain at least one lowercase letter, one uppercase letter, one number, and one special character')
  ],
  validateRequest,
  asyncHandler(async (req, res) => {
    const userId = req.user!.id;
    const { currentPassword, newPassword } = req.body;
    
    // Get user with password hash
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        passwordHash: true
      }
    });
    
    if (!user || !user.passwordHash) {
      return res.status(400).json({
        success: false,
        message: 'User not found or no password set'
      });
    }
    
    // Verify current password
    const isValidPassword = await verifyPassword(currentPassword, user.passwordHash);
    
    if (!isValidPassword) {
      return res.status(400).json({
        success: false,
        message: 'Current password is incorrect'
      });
    }
    
    // Hash new password
    const newPasswordHash = await hashPassword(newPassword);
    
    // Update password
    await prisma.user.update({
      where: { id: userId },
      data: {
        passwordHash: newPasswordHash,
        updatedAt: new Date()
      }
    });
    
    // Invalidate all sessions except current one
    const currentSession = await prisma.session.findFirst({
      where: { 
        userId,
        token: req.headers.authorization?.substring(7)
      }
    });
    
    await prisma.session.deleteMany({
      where: {
        userId,
        id: { not: currentSession?.id }
      }
    });
    
    // Clear cache
    await cacheService.delete(`user:${userId}`);
    
    // Log password change
    auditEvents.passwordChange(userId, req);
    
    logger.info('Password changed successfully', { userId });
    
    res.json({
      success: true,
      message: 'Password changed successfully'
    });
  })
);

/**
 * @swagger
 * /users/stats:
 *   get:
 *     summary: Get user statistics
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: User statistics retrieved successfully
 */
router.get('/stats',
  asyncHandler(async (req, res) => {
    const userId = req.user!.id;
    
    // Get user stats
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        streakCount: true,
        totalCheckins: true,
        messagesThisWeek: true,
        createdAt: true
      }
    });
    
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }
    
    // Get additional stats
    const [totalMessages, totalMoodEntries, recentActivity] = await Promise.all([
      prisma.chatMessage.count({
        where: { userId }
      }),
      prisma.moodEntry.count({
        where: { userId }
      }),
      prisma.chatMessage.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        take: 5,
        select: {
          id: true,
          role: true,
          createdAt: true
        }
      })
    ]);
    
    const daysSinceJoined = Math.floor(
      (Date.now() - user.createdAt.getTime()) / (1000 * 60 * 60 * 24)
    );
    
    const stats = {
      streakCount: user.streakCount,
      totalCheckins: user.totalCheckins,
      messagesThisWeek: user.messagesThisWeek,
      totalMessages,
      totalMoodEntries,
      daysSinceJoined,
      recentActivity
    };
    
    res.json({
      success: true,
      data: { stats }
    });
  })
);

/**
 * @swagger
 * /users/export-data:
 *   get:
 *     summary: Export user data (GDPR compliance)
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: User data exported successfully
 */
router.get('/export-data',
  asyncHandler(async (req, res) => {
    const userId = req.user!.id;
    
    // Get all user data
    const [user, chatMessages, moodEntries, crisisEvents, sessions] = await Promise.all([
      prisma.user.findUnique({
        where: { id: userId },
        select: {
          id: true,
          email: true,
          name: true,
          subscriptionStatus: true,
          streakCount: true,
          totalCheckins: true,
          messagesThisWeek: true,
          timezone: true,
          language: true,
          preferences: true,
          emailVerified: true,
          createdAt: true,
          updatedAt: true,
          lastActiveAt: true
        }
      }),
      prisma.chatMessage.findMany({
        where: { userId },
        select: {
          id: true,
          role: true,
          content: true,
          createdAt: true,
          metadata: true
        }
      }),
      prisma.moodEntry.findMany({
        where: { userId },
        select: {
          id: true,
          mood: true,
          tags: true,
          notes: true,
          createdAt: true
        }
      }),
      prisma.crisisEvent.findMany({
        where: { userId },
        select: {
          id: true,
          level: true,
          message: true,
          actionTaken: true,
          resolved: true,
          createdAt: true
        }
      }),
      prisma.session.findMany({
        where: { userId },
        select: {
          id: true,
          deviceId: true,
          platform: true,
          ipAddress: true,
          createdAt: true,
          updatedAt: true
        }
      })
    ]);
    
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }
    
    const exportData = {
      user,
      chatMessages,
      moodEntries,
      crisisEvents,
      sessions,
      exportedAt: new Date().toISOString()
    };
    
    // Log data export
    auditEvents.dataExport(userId, 'full_export', req);
    
    logger.info('User data exported', { userId });
    
    res.json({
      success: true,
      message: 'Data exported successfully',
      data: exportData
    });
  })
);

/**
 * @swagger
 * /users/delete-account:
 *   delete:
 *     summary: Delete user account
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - password
 *               - confirmation
 *             properties:
 *               password:
 *                 type: string
 *               confirmation:
 *                 type: string
 *                 enum: ['DELETE_MY_ACCOUNT']
 *     responses:
 *       200:
 *         description: Account deleted successfully
 *       400:
 *         description: Invalid password or confirmation
 */
router.delete('/delete-account',
  [
    body('password').notEmpty().withMessage('Password is required'),
    body('confirmation')
      .equals('DELETE_MY_ACCOUNT')
      .withMessage('Confirmation must be "DELETE_MY_ACCOUNT"')
  ],
  validateRequest,
  asyncHandler(async (req, res) => {
    const userId = req.user!.id;
    const { password } = req.body;
    
    // Get user with password hash
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        passwordHash: true
      }
    });
    
    if (!user || !user.passwordHash) {
      return res.status(400).json({
        success: false,
        message: 'User not found or no password set'
      });
    }
    
    // Verify password
    const isValidPassword = await verifyPassword(password, user.passwordHash);
    
    if (!isValidPassword) {
      return res.status(400).json({
        success: false,
        message: 'Invalid password'
      });
    }
    
    // Soft delete user (set deletedAt timestamp)
    await prisma.user.update({
      where: { id: userId },
      data: {
        deletedAt: new Date(),
        email: `deleted_${Date.now()}_${user.email}`, // Anonymize email
        name: null,
        passwordHash: null,
        emailVerificationToken: null,
        passwordResetToken: null,
        passwordResetExpires: null
      }
    });
    
    // Delete all sessions
    await prisma.session.deleteMany({
      where: { userId }
    });
    
    // Clear all cache
    await cacheService.delete(`user:${userId}`);
    await cacheService.delete(`user_profile:${userId}`);
    
    // Log account deletion
    auditEvents.userDelete(userId, req);
    
    logger.info('User account deleted', {
      userId,
      email: user.email
    });
    
    res.json({
      success: true,
      message: 'Account deleted successfully'
    });
  })
);

/**
 * @swagger
 * /users/sessions:
 *   get:
 *     summary: Get user sessions
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Sessions retrieved successfully
 */
router.get('/sessions',
  asyncHandler(async (req, res) => {
    const userId = req.user!.id;
    
    const sessions = await prisma.session.findMany({
      where: { 
        userId,
        expiresAt: { gt: new Date() }
      },
      select: {
        id: true,
        deviceId: true,
        platform: true,
        ipAddress: true,
        userAgent: true,
        createdAt: true,
        updatedAt: true
      },
      orderBy: { updatedAt: 'desc' }
    });
    
    res.json({
      success: true,
      data: { sessions }
    });
  })
);

/**
 * @swagger
 * /users/sessions/{sessionId}:
 *   delete:
 *     summary: Revoke a session
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: sessionId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Session revoked successfully
 */
router.delete('/sessions/:sessionId',
  param('sessionId').isUUID().withMessage('Invalid session ID'),
  validateRequest,
  asyncHandler(async (req, res) => {
    const userId = req.user!.id;
    const { sessionId } = req.params;
    
    // Delete the session
    const deletedSession = await prisma.session.deleteMany({
      where: {
        id: sessionId,
        userId
      }
    });
    
    if (deletedSession.count === 0) {
      return res.status(404).json({
        success: false,
        message: 'Session not found'
      });
    }
    
    logger.info('Session revoked', {
      userId,
      sessionId
    });
    
    res.json({
      success: true,
      message: 'Session revoked successfully'
    });
  })
);

export default router;
