import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import { config } from '../config/config';
import { prisma } from '../utils/database';
import { logger, securityLogger } from '../utils/logger';
import { cacheService } from '../utils/redis';

// Extend Request interface to include user
declare global {
  namespace Express {
    interface Request {
      user?: {
        id: string;
        email?: string;
        subscriptionStatus: string;
        role?: string;
      };
    }
  }
}

export interface JWTPayload {
  userId: string;
  email?: string;
  subscriptionStatus: string;
  role?: string;
  iat?: number;
  exp?: number;
}

// Generate JWT tokens
export function generateTokens(payload: Omit<JWTPayload, 'iat' | 'exp'>) {
  const accessToken = jwt.sign(payload, config.security.jwtSecret, {
    expiresIn: '15m',
    issuer: 'urgood-api',
    audience: 'urgood-app'
  });
  
  const refreshToken = jwt.sign(
    { userId: payload.userId },
    config.security.jwtRefreshSecret,
    {
      expiresIn: '7d',
      issuer: 'urgood-api',
      audience: 'urgood-app'
    }
  );
  
  return { accessToken, refreshToken };
}

// Verify JWT token
export function verifyToken(token: string, secret: string): JWTPayload | null {
  try {
    const decoded = jwt.verify(token, secret, {
      issuer: 'urgood-api',
      audience: 'urgood-app'
    }) as JWTPayload;
    
    return decoded;
  } catch (error) {
    if (error instanceof jwt.JsonWebTokenError) {
      logger.warn('Invalid JWT token', { error: error.message });
    } else if (error instanceof jwt.TokenExpiredError) {
      logger.info('JWT token expired');
    }
    return null;
  }
}

// Hash password
export async function hashPassword(password: string): Promise<string> {
  return bcrypt.hash(password, config.security.bcryptRounds);
}

// Verify password
export async function verifyPassword(password: string, hash: string): Promise<boolean> {
  return bcrypt.compare(password, hash);
}

// Authentication middleware
export async function authMiddleware(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({
        success: false,
        message: 'Access token required'
      });
      return;
    }
    
    const token = authHeader.substring(7);
    const decoded = verifyToken(token, config.security.jwtSecret);
    
    if (!decoded) {
      res.status(401).json({
        success: false,
        message: 'Invalid or expired token'
      });
      return;
    }
    
    // Check if user exists and is active
    const cacheKey = `user:${decoded.userId}`;
    let user: any = await cacheService.get(cacheKey);
    
    if (!user) {
      user = await prisma.user.findUnique({
        where: { 
          id: decoded.userId,
          deletedAt: null
        },
        select: {
          id: true,
          email: true,
          subscriptionStatus: true,
          emailVerified: true,
          lastActiveAt: true
        }
      });
      
      if (user) {
        // Cache user for 5 minutes
        await cacheService.set(cacheKey, user, 300);
      }
    }
    
    if (!user) {
      res.status(401).json({
        success: false,
        message: 'User not found'
      });
      return;
    }
    
    // Update last active time (async, don't wait)
    prisma.user.update({
      where: { id: user.id },
      data: { lastActiveAt: new Date() }
    }).catch(error => {
      logger.error('Failed to update last active time', { userId: user.id, error });
    });
    
    // Attach user to request
    req.user = {
      id: user.id,
      ...(user.email && { email: user.email }),
      subscriptionStatus: user.subscriptionStatus,
      role: 'user' // Default role, can be extended
    };
    
    next();
  } catch (error) {
    logger.error('Authentication middleware error', error);
    res.status(500).json({
      success: false,
      message: 'Authentication error'
    });
  }
}

// Optional authentication middleware (doesn't fail if no token)
export async function optionalAuthMiddleware(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      next();
      return;
    }
    
    const token = authHeader.substring(7);
    const decoded = verifyToken(token, config.security.jwtSecret);
    
    if (decoded) {
      const user = await prisma.user.findUnique({
        where: { 
          id: decoded.userId,
          deletedAt: null
        },
        select: {
          id: true,
          email: true,
          subscriptionStatus: true
        }
      });
      
      if (user) {
        req.user = {
          id: user.id,
          ...(user.email && { email: user.email }),
          subscriptionStatus: user.subscriptionStatus,
          role: 'user'
        };
      }
    }
    
    next();
  } catch (error) {
    logger.error('Optional authentication middleware error', error);
    next(); // Continue without authentication
  }
}

// Role-based authorization middleware
export function requireRole(roles: string | string[]) {
  const allowedRoles = Array.isArray(roles) ? roles : [roles];
  
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!req.user) {
      res.status(401).json({
        success: false,
        message: 'Authentication required'
      });
      return;
    }
    
    const userRole = req.user.role || 'user';
    
    if (!allowedRoles.includes(userRole)) {
      securityLogger.logSecurityEvent('unauthorized_access_attempt', {
        userId: req.user.id,
        requiredRoles: allowedRoles,
        userRole,
        endpoint: req.path,
        method: req.method
      }, 'medium');
      
      res.status(403).json({
        success: false,
        message: 'Insufficient permissions'
      });
      return;
    }
    
    next();
  };
}

// Subscription-based authorization middleware
export function requireSubscription(requiredLevel: 'FREE' | 'PREMIUM_MONTHLY' | 'TRIAL') {
  const subscriptionHierarchy = {
    'FREE': 0,
    'TRIAL': 1,
    'PREMIUM_MONTHLY': 2
  };
  
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!req.user) {
      res.status(401).json({
        success: false,
        message: 'Authentication required'
      });
      return;
    }
    
    const userLevel = subscriptionHierarchy[req.user.subscriptionStatus as keyof typeof subscriptionHierarchy] || 0;
    const requiredLevelValue = subscriptionHierarchy[requiredLevel];
    
    if (userLevel < requiredLevelValue) {
      res.status(402).json({
        success: false,
        message: 'Premium subscription required',
        requiredSubscription: requiredLevel,
        currentSubscription: req.user.subscriptionStatus
      });
      return;
    }
    
    next();
  };
}

// Email verification middleware
export function requireEmailVerification(req: Request, res: Response, next: NextFunction): void {
  if (!req.user) {
    res.status(401).json({
      success: false,
      message: 'Authentication required'
    });
    return;
  }
  
  // Check email verification status
  prisma.user.findUnique({
    where: { id: req.user.id },
    select: { emailVerified: true }
  }).then(user => {
    if (!user?.emailVerified) {
      res.status(403).json({
        success: false,
        message: 'Email verification required'
      });
      return;
    }
    
    next();
  }).catch(error => {
    logger.error('Email verification check error', error);
    res.status(500).json({
      success: false,
      message: 'Verification check failed'
    });
  });
}

// Rate limiting by user
export function rateLimitByUser(windowMs: number, maxRequests: number) {
  return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    if (!req.user) {
      next();
      return;
    }
    
    try {
      const { rateLimitService } = await import('../utils/redis');
      const identifier = `user:${req.user.id}`;
      const windowSeconds = Math.floor(windowMs / 1000);
      
      const result = await rateLimitService.checkRateLimit(identifier, windowSeconds, maxRequests);
      
      res.set({
        'X-RateLimit-Limit': maxRequests.toString(),
        'X-RateLimit-Remaining': result.remaining.toString(),
        'X-RateLimit-Reset': result.resetTime.toString()
      });
      
      if (!result.allowed) {
        securityLogger.logSecurityEvent('rate_limit_exceeded', {
          userId: req.user.id,
          endpoint: req.path,
          method: req.method,
          windowMs,
          maxRequests
        }, 'low');
        
        res.status(429).json({
          success: false,
          message: 'Rate limit exceeded',
          retryAfter: result.resetTime - Math.floor(Date.now() / 1000)
        });
        return;
      }
      
      next();
    } catch (error) {
      logger.error('User rate limiting error', error);
      next(); // Continue on error
    }
  };
}

// Session validation middleware
export async function validateSession(req: Request, res: Response, next: NextFunction): Promise<void> {
  if (!req.user) {
    next();
    return;
  }
  
  try {
    const sessionToken = req.headers['x-session-token'] as string;
    
    if (!sessionToken) {
      next();
      return;
    }
    
    const session = await prisma.session.findFirst({
      where: { 
        token: sessionToken,
        userId: req.user.id,
        expiresAt: {
          gt: new Date()
        }
      }
    });
    
    if (!session) {
      res.status(401).json({
        success: false,
        message: 'Invalid or expired session'
      });
      return;
    }
    
    // Update session last activity
    await prisma.session.update({
      where: { id: session.id },
      data: { updatedAt: new Date() }
    });
    
    next();
  } catch (error) {
    logger.error('Session validation error', error);
    res.status(500).json({
      success: false,
      message: 'Session validation failed'
    });
  }
}

// IP-based security middleware
export function securityByIP(req: Request, res: Response, next: NextFunction): void {
  const clientIP = req.ip || req.connection.remoteAddress || 'unknown';
  
  // Log authentication attempts
  if (req.path.includes('/auth/')) {
    securityLogger.logAuthAttempt(
      req.body.email || 'unknown',
      false, // Will be updated in auth handler
      clientIP,
      req.get('User-Agent')
    );
  }
  
  // Check for suspicious patterns
  const suspiciousPatterns = [
    /bot/i,
    /crawler/i,
    /spider/i,
    /scraper/i
  ];
  
  const userAgent = req.get('User-Agent') || '';
  const isSuspicious = suspiciousPatterns.some(pattern => pattern.test(userAgent));
  
  if (isSuspicious) {
    securityLogger.logSuspiciousActivity(
      req.user?.id || 'anonymous',
      'suspicious_user_agent',
      { userAgent, ip: clientIP },
      clientIP
    );
  }
  
  next();
}

// Refresh token middleware
export async function refreshTokenMiddleware(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const { refreshToken } = req.body;
    
    if (!refreshToken) {
      res.status(400).json({
        success: false,
        message: 'Refresh token required'
      });
      return;
    }
    
    const decoded = verifyToken(refreshToken, config.security.jwtRefreshSecret);
    
    if (!decoded) {
      res.status(401).json({
        success: false,
        message: 'Invalid refresh token'
      });
      return;
    }
    
    // Check if refresh token exists in database
    const session = await prisma.session.findFirst({
      where: { 
        refreshToken,
        userId: decoded.userId,
        expiresAt: {
          gt: new Date()
        }
      },
      include: {
        user: {
          select: {
            id: true,
            email: true,
            subscriptionStatus: true,
            deletedAt: true
          }
        }
      }
    });
    
    if (!session || session.user.deletedAt) {
      res.status(401).json({
        success: false,
        message: 'Invalid refresh token'
      });
      return;
    }
    
    req.user = {
      id: session.user.id,
      ...(session.user.email && { email: session.user.email }),
      subscriptionStatus: session.user.subscriptionStatus,
      role: 'user'
    };
    
    next();
  } catch (error) {
    logger.error('Refresh token middleware error', error);
    res.status(500).json({
      success: false,
      message: 'Token refresh failed'
    });
  }
}

export default {
  authMiddleware,
  optionalAuthMiddleware,
  requireRole,
  requireSubscription,
  requireEmailVerification,
  rateLimitByUser,
  validateSession,
  securityByIP,
  refreshTokenMiddleware,
  generateTokens,
  verifyToken,
  hashPassword,
  verifyPassword
};
