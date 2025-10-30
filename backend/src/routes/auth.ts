import { Router } from 'express';
import { body } from 'express-validator';
import { prisma } from '../utils/database';
import { 
  generateTokens, 
  hashPassword, 
  verifyPassword, 
  refreshTokenMiddleware 
} from '../middleware/auth';
import { validateRequest, validationRules } from '../middleware/validation';
import { asyncHandler } from '../middleware/errorHandler';
import { auditEvents } from '../middleware/auditLogger';
import { rateLimitByUser } from '../middleware/auth';
import { logger } from '../utils/logger';
import { analytics, EventNames } from '../utils/analytics';
import { cacheService } from '../utils/redis';
import crypto from 'crypto';
import { appleAuthService } from '../services/appleAuthService';

const router = Router();

/**
 * @swagger
 * /auth/register:
 *   post:
 *     summary: Register a new user
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - password
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *               password:
 *                 type: string
 *                 minLength: 8
 *               name:
 *                 type: string
 *               timezone:
 *                 type: string
 *               language:
 *                 type: string
 *     responses:
 *       201:
 *         description: User registered successfully
 *       400:
 *         description: Validation error
 *       409:
 *         description: User already exists
 */
router.post('/register', 
  validationRules.userRegistration,
  validateRequest,
  asyncHandler(async (req, res) => {
    const { email, password, name, timezone = 'UTC', language = 'en' } = req.body;
    
    // Check if user already exists
    const existingUser = await prisma.user.findUnique({
      where: { email }
    });
    
    if (existingUser) {
      securityLogger.logSecurityEvent('duplicate_registration_attempt', {
        email,
        ip: req.ip
      }, 'low');
      
      return res.status(409).json({
        success: false,
        message: 'User already exists'
      });
    }
    
    // Hash password
    const passwordHash = await hashPassword(password);
    
    // Generate email verification token
    const emailVerificationToken = crypto.randomBytes(32).toString('hex');
    
    // Create user
    const user = await prisma.user.create({
      data: {
        email,
        passwordHash,
        name,
        timezone,
        language,
        emailVerificationToken,
        subscriptionStatus: 'FREE'
      },
      select: {
        id: true,
        email: true,
        name: true,
        subscriptionStatus: true,
        createdAt: true,
        emailVerified: true
      }
    });
    
    // Generate tokens
    const { accessToken, refreshToken } = generateTokens({
      userId: user.id,
      email: user.email!,
      subscriptionStatus: user.subscriptionStatus
    });
    
    // Create session
    const session = await prisma.session.create({
      data: {
        userId: user.id,
        token: accessToken,
        refreshToken,
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days
        deviceId: req.headers['x-device-id'] as string,
        platform: req.headers['x-platform'] as string,
        ipAddress: req.ip,
        userAgent: req.get('User-Agent')
      }
    });
    
    // Log successful registration
    auditEvents.userLogin(user.id, true, req);
    securityLogger.logAuthAttempt(email, true, req.ip!, req.get('User-Agent'));
    
    logger.info('User registered successfully', {
      userId: user.id,
      email: user.email
    });
    
    res.status(201).json({
      success: true,
      message: 'User registered successfully',
      data: {
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
          subscriptionStatus: user.subscriptionStatus,
          emailVerified: user.emailVerified
        },
        tokens: {
          accessToken,
          refreshToken,
          expiresIn: 15 * 60 // 15 minutes
        }
      }
    });
  })
);

/**
 * @swagger
 * /auth/login:
 *   post:
 *     summary: Login user
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - password
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *               password:
 *                 type: string
 *     responses:
 *       200:
 *         description: Login successful
 *       401:
 *         description: Invalid credentials
 */
router.post('/login',
  validationRules.userLogin,
  validateRequest,
  asyncHandler(async (req, res) => {
    const { email, password } = req.body;
    
    // Find user
    const user = await prisma.user.findUnique({
      where: { 
        email,
        deletedAt: null
      },
      select: {
        id: true,
        email: true,
        name: true,
        passwordHash: true,
        subscriptionStatus: true,
        emailVerified: true,
        lastActiveAt: true
      }
    });
    
    if (!user) {
      securityLogger.logAuthAttempt(email, false, req.ip!, req.get('User-Agent'));
      
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials'
      });
    }
    
    // Verify password
    const isValidPassword = await verifyPassword(password, user.passwordHash!);
    
    if (!isValidPassword) {
      securityLogger.logAuthAttempt(email, false, req.ip!, req.get('User-Agent'));
      
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials'
      });
    }
    
    // Generate tokens
    const { accessToken, refreshToken } = generateTokens({
      userId: user.id,
      email: user.email!,
      subscriptionStatus: user.subscriptionStatus
    });
    
    // Create or update session
    const session = await prisma.session.upsert({
      where: {
        userId: user.id
      },
      update: {
        token: accessToken,
        refreshToken,
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        ipAddress: req.ip,
        userAgent: req.get('User-Agent'),
        updatedAt: new Date()
      },
      create: {
        userId: user.id,
        token: accessToken,
        refreshToken,
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        deviceId: req.headers['x-device-id'] as string,
        platform: req.headers['x-platform'] as string,
        ipAddress: req.ip,
        userAgent: req.get('User-Agent')
      }
    });
    
    // Update last active time
    await prisma.user.update({
      where: { id: user.id },
      data: { lastActiveAt: new Date() }
    });
    
    // Cache user data
    await cacheService.set(`user:${user.id}`, {
      id: user.id,
      email: user.email,
      subscriptionStatus: user.subscriptionStatus,
      emailVerified: user.emailVerified
    }, 300); // 5 minutes
    
    // Log successful login
    auditEvents.userLogin(user.id, true, req);
    securityLogger.logAuthAttempt(email, true, req.ip!, req.get('User-Agent'));
    
    logger.info('User logged in successfully', {
      userId: user.id,
      email: user.email
    });
    
    res.json({
      success: true,
      message: 'Login successful',
      data: {
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
          subscriptionStatus: user.subscriptionStatus,
          emailVerified: user.emailVerified,
          lastActiveAt: user.lastActiveAt
        },
        tokens: {
          accessToken,
          refreshToken,
          expiresIn: 15 * 60 // 15 minutes
        }
      }
    });
  })
);

/**
 * @swagger
 * /auth/refresh:
 *   post:
 *     summary: Refresh access token
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - refreshToken
 *             properties:
 *               refreshToken:
 *                 type: string
 *     responses:
 *       200:
 *         description: Token refreshed successfully
 *       401:
 *         description: Invalid refresh token
 */
router.post('/refresh',
  body('refreshToken').notEmpty().withMessage('Refresh token is required'),
  validateRequest,
  refreshTokenMiddleware,
  asyncHandler(async (req, res) => {
    const user = req.user!;
    
    // Generate new tokens
    const { accessToken, refreshToken } = generateTokens({
      userId: user.id,
      email: user.email!,
      subscriptionStatus: user.subscriptionStatus
    });
    
    // Update session with new tokens
    await prisma.session.updateMany({
      where: {
        userId: user.id,
        refreshToken: req.body.refreshToken
      },
      data: {
        token: accessToken,
        refreshToken,
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        updatedAt: new Date()
      }
    });
    
    logger.info('Token refreshed successfully', {
      userId: user.id
    });
    
    res.json({
      success: true,
      message: 'Token refreshed successfully',
      data: {
        tokens: {
          accessToken,
          refreshToken,
          expiresIn: 15 * 60 // 15 minutes
        }
      }
    });
  })
);

/**
 * @swagger
 * /auth/logout:
 *   post:
 *     summary: Logout user
 *     tags: [Authentication]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Logout successful
 */
router.post('/logout',
  // Note: We don't use authMiddleware here to allow logout even with expired tokens
  asyncHandler(async (req, res) => {
    const authHeader = req.headers.authorization;
    
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.substring(7);
      
      // Try to find and delete the session
      try {
        const session = await prisma.session.findFirst({
          where: { token },
          include: { user: { select: { id: true } } }
        });
        
        if (session) {
          await prisma.session.delete({
            where: { id: session.id }
          });
          
          // Clear user cache
          await cacheService.delete(`user:${session.user.id}`);
          
          // Log logout
          auditEvents.userLogout(session.user.id, req);
          
          logger.info('User logged out successfully', {
            userId: session.user.id
          });
        }
      } catch (error) {
        logger.error('Error during logout', error);
      }
    }
    
    res.json({
      success: true,
      message: 'Logout successful'
    });
  })
);

/**
 * @swagger
 * /auth/verify-email:
 *   post:
 *     summary: Verify email address
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - token
 *             properties:
 *               token:
 *                 type: string
 *     responses:
 *       200:
 *         description: Email verified successfully
 *       400:
 *         description: Invalid or expired token
 */
router.post('/verify-email',
  body('token').notEmpty().withMessage('Verification token is required'),
  validateRequest,
  asyncHandler(async (req, res) => {
    const { token } = req.body;
    
    // Find user with verification token
    const user = await prisma.user.findFirst({
      where: {
        emailVerificationToken: token,
        emailVerified: false,
        deletedAt: null
      }
    });
    
    if (!user) {
      return res.status(400).json({
        success: false,
        message: 'Invalid or expired verification token'
      });
    }
    
    // Update user as verified
    await prisma.user.update({
      where: { id: user.id },
      data: {
        emailVerified: true,
        emailVerificationToken: null
      }
    });
    
    // Clear user cache
    await cacheService.delete(`user:${user.id}`);
    
    logger.info('Email verified successfully', {
      userId: user.id,
      email: user.email
    });
    
    res.json({
      success: true,
      message: 'Email verified successfully'
    });
  })
);

/**
 * @swagger
 * /auth/forgot-password:
 *   post:
 *     summary: Request password reset
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *     responses:
 *       200:
 *         description: Password reset email sent
 */
router.post('/forgot-password',
  body('email').isEmail().normalizeEmail().withMessage('Valid email is required'),
  validateRequest,
  rateLimitByUser(15 * 60 * 1000, 3), // 3 requests per 15 minutes
  asyncHandler(async (req, res) => {
    const { email } = req.body;
    
    // Find user
    const user = await prisma.user.findUnique({
      where: { 
        email,
        deletedAt: null
      }
    });
    
    // Always return success to prevent email enumeration
    if (!user) {
      return res.json({
        success: true,
        message: 'If the email exists, a password reset link has been sent'
      });
    }
    
    // Generate reset token
    const resetToken = crypto.randomBytes(32).toString('hex');
    const resetExpires = new Date(Date.now() + 60 * 60 * 1000); // 1 hour
    
    // Update user with reset token
    await prisma.user.update({
      where: { id: user.id },
      data: {
        passwordResetToken: resetToken,
        passwordResetExpires: resetExpires
      }
    });
    
    // TODO: Send password reset email
    // await emailService.sendPasswordResetEmail(user.email, resetToken);
    
    logger.info('Password reset requested', {
      userId: user.id,
      email: user.email
    });
    
    res.json({
      success: true,
      message: 'If the email exists, a password reset link has been sent'
    });
  })
);

/**
 * @swagger
 * /auth/reset-password:
 *   post:
 *     summary: Reset password with token
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - token
 *               - password
 *             properties:
 *               token:
 *                 type: string
 *               password:
 *                 type: string
 *                 minLength: 8
 *     responses:
 *       200:
 *         description: Password reset successfully
 *       400:
 *         description: Invalid or expired token
 */
router.post('/reset-password',
  [
    body('token').notEmpty().withMessage('Reset token is required'),
    body('password')
      .isLength({ min: 8, max: 128 })
      .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/)
      .withMessage('Password must contain at least one lowercase letter, one uppercase letter, one number, and one special character')
  ],
  validateRequest,
  asyncHandler(async (req, res) => {
    const { token, password } = req.body;
    
    // Find user with valid reset token
    const user = await prisma.user.findFirst({
      where: {
        passwordResetToken: token,
        passwordResetExpires: {
          gt: new Date()
        },
        deletedAt: null
      }
    });
    
    if (!user) {
      return res.status(400).json({
        success: false,
        message: 'Invalid or expired reset token'
      });
    }
    
    // Hash new password
    const passwordHash = await hashPassword(password);
    
    // Update user password and clear reset token
    await prisma.user.update({
      where: { id: user.id },
      data: {
        passwordHash,
        passwordResetToken: null,
        passwordResetExpires: null
      }
    });
    
    // Invalidate all existing sessions
    await prisma.session.deleteMany({
      where: { userId: user.id }
    });
    
    // Clear user cache
    await cacheService.delete(`user:${user.id}`);
    
    // Log password change
    auditEvents.passwordChange(user.id, req);
    
    logger.info('Password reset successfully', {
      userId: user.id,
      email: user.email
    });
    
    res.json({
      success: true,
      message: 'Password reset successfully'
    });
  })
);

/**
 * @swagger
 * /auth/apple:
 *   post:
 *     summary: Authenticate with Apple ID token
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - identityToken
 *               - authorizationCode
 *             properties:
 *               identityToken:
 *                 type: string
 *                 description: Apple ID identity token (JWT)
 *               authorizationCode:
 *                 type: string
 *                 description: Apple authorization code
 *               user:
 *                 type: object
 *                 properties:
 *                   email:
 *                     type: string
 *                   name:
 *                     type: string
 *     responses:
 *       200:
 *         description: Apple authentication successful
 *       400:
 *         description: Invalid Apple ID token
 */
router.post('/apple',
  [
    body('identityToken').notEmpty().withMessage('Identity token is required'),
    body('authorizationCode').notEmpty().withMessage('Authorization code is required')
  ],
  validateRequest,
  asyncHandler(async (req, res) => {
    const { identityToken, authorizationCode, user } = req.body;
    
    try {
      // Verify Apple ID token
      const appleUser = await appleAuthService.verifyAppleToken(identityToken);
      
      if (!appleUser) {
        return res.status(400).json({
          success: false,
          message: 'Invalid Apple ID token'
        });
      }
      
      // Check if user already exists
      let existingUser = await prisma.user.findUnique({
        where: { appleId: appleUser.sub }
      });
      
      if (!existingUser) {
        // Create new user
        existingUser = await prisma.user.create({
          data: {
            appleId: appleUser.sub,
            email: user?.email || appleUser.email,
            name: user?.name || null,
            authProvider: 'apple',
            emailVerified: appleUser.email_verified === 'true',
            subscriptionStatus: 'FREE'
          },
          select: {
            id: true,
            email: true,
            name: true,
            subscriptionStatus: true,
            emailVerified: true,
            lastActiveAt: true,
            createdAt: true
          }
        });
        
        logger.info('New Apple user created', {
          userId: existingUser.id,
          appleId: appleUser.sub
        });
      } else {
        // Update existing user
        existingUser = await prisma.user.update({
          where: { id: existingUser.id },
          data: {
            lastActiveAt: new Date(),
            // Update email if not set and provided by Apple
            email: existingUser.email || user?.email || appleUser.email,
            // Update name if not set and provided
            name: existingUser.name || user?.name || null
          },
          select: {
            id: true,
            email: true,
            name: true,
            subscriptionStatus: true,
            emailVerified: true,
            lastActiveAt: true,
            createdAt: true
          }
        });
        
        logger.info('Existing Apple user updated', {
          userId: existingUser.id,
          appleId: appleUser.sub
        });
      }
      
      // Generate tokens
      const { accessToken, refreshToken } = generateTokens({
        userId: existingUser.id,
        email: existingUser.email!,
        subscriptionStatus: existingUser.subscriptionStatus
      });
      
      // Create session
      await prisma.session.create({
        data: {
          userId: existingUser.id,
          token: accessToken,
          refreshToken,
          expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days
          deviceId: req.headers['x-device-id'] as string,
          platform: req.headers['x-platform'] as string || 'ios',
          ipAddress: req.ip,
          userAgent: req.get('User-Agent')
        }
      });
      
      // Cache user data
      await cacheService.set(`user:${existingUser.id}`, {
        id: existingUser.id,
        email: existingUser.email,
        subscriptionStatus: existingUser.subscriptionStatus,
        emailVerified: existingUser.emailVerified
      }, 300); // 5 minutes
      
      // Log successful authentication
      auditEvents.userLogin(existingUser.id, true, req);
      securityLogger.logAuthAttempt(existingUser.email || appleUser.sub, true, req.ip!, req.get('User-Agent'));
      
      res.json({
        success: true,
        message: 'Apple authentication successful',
        data: {
          user: existingUser,
          tokens: {
            accessToken,
            refreshToken,
            expiresIn: 15 * 60 // 15 minutes
          }
        }
      });
      
    } catch (error) {
      logger.error('Apple authentication error', error);
      
      return res.status(400).json({
        success: false,
        message: 'Apple authentication failed'
      });
    }
  })
);


export default router;
