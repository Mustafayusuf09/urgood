import { Request, Response, NextFunction } from 'express';
import { body, param, query, validationResult, ValidationChain } from 'express-validator';
import { z } from 'zod';
import { logger } from '../utils/logger';
import { captureError } from '../utils/sentry';

// Enhanced validation error class
export class ValidationError extends Error {
  public statusCode: number;
  public errors: any[];
  public isOperational: boolean;

  constructor(message: string, errors: any[] = [], statusCode: number = 400) {
    super(message);
    this.name = 'ValidationError';
    this.statusCode = statusCode;
    this.errors = errors;
    this.isOperational = true;
  }
}

// Request validation middleware using express-validator
export function validateRequest(req: Request, res: Response, next: NextFunction): void {
  const errors = validationResult(req);
  
  if (!errors.isEmpty()) {
    const errorDetails = errors.array().map(error => ({
      field: error.type === 'field' ? (error as any).path : 'unknown',
      message: error.msg,
      value: error.type === 'field' ? (error as any).value : undefined,
      location: error.type === 'field' ? (error as any).location : 'unknown'
    }));

    logger.warn('Request validation failed', {
      path: req.path,
      method: req.method,
      errors: errorDetails,
      body: req.body,
      query: req.query,
      params: req.params
    });

    res.status(400).json({
      success: false,
      error: 'VALIDATION_ERROR',
      message: 'Request validation failed',
      details: errorDetails
    });
    return;
  }

  next();
}

// Zod-based validation middleware
export function zodValidation(schema: z.ZodSchema) {
  return (req: Request, res: Response, next: NextFunction) => {
    try {
      const validatedData = schema.parse({
        body: req.body,
        query: req.query,
        params: req.params
      });

      // Replace request data with validated data
      req.body = validatedData.body || req.body;
      req.query = validatedData.query || req.query;
      req.params = validatedData.params || req.params;

      next();
    } catch (error) {
      if (error instanceof z.ZodError) {
        const errorDetails = error.errors.map(err => ({
          field: err.path.join('.'),
          message: err.message,
          code: err.code,
          value: 'received' in err ? err.received : undefined
        }));

        logger.warn('Zod validation failed', {
          path: req.path,
          method: req.method,
          errors: errorDetails
        });

        return res.status(400).json({
          success: false,
          error: 'VALIDATION_ERROR',
          message: 'Request validation failed',
          details: errorDetails
        });
      }

      next(error);
    }
  };
}

// Mental health app specific validation schemas
export const ValidationSchemas = {
  // User validation
  userRegistration: [
    body('email').isEmail().normalizeEmail().withMessage('Valid email is required'),
    body('name').trim().isLength({ min: 2, max: 50 }).withMessage('Name must be 2-50 characters'),
    body('password').isLength({ min: 8 }).matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/).withMessage('Password must be at least 8 characters with uppercase, lowercase, number, and special character'),
    body('timezone').optional().isString().withMessage('Timezone must be a string'),
    body('language').optional().isIn(['en', 'es', 'fr', 'de']).withMessage('Language must be supported')
  ],

  userLogin: [
    body('email').isEmail().normalizeEmail().withMessage('Valid email is required'),
    body('password').notEmpty().withMessage('Password is required')
  ],

  userUpdate: [
    body('name').optional().trim().isLength({ min: 2, max: 50 }).withMessage('Name must be 2-50 characters'),
    body('timezone').optional().isString().withMessage('Timezone must be a string'),
    body('language').optional().isIn(['en', 'es', 'fr', 'de']).withMessage('Language must be supported'),
    body('preferences').optional().isObject().withMessage('Preferences must be an object')
  ],

  // Mood validation
  moodEntry: [
    body('mood').isInt({ min: 1, max: 10 }).withMessage('Mood must be an integer between 1 and 10'),
    body('notes').optional().trim().isLength({ max: 1000 }).withMessage('Notes must not exceed 1000 characters'),
    body('tags').optional().isArray({ max: 10 }).withMessage('Tags must be an array with max 10 items'),
    body('tags.*').optional().trim().isLength({ min: 1, max: 50 }).withMessage('Each tag must be 1-50 characters')
  ],

  // Chat validation
  chatMessage: [
    body('message').trim().isLength({ min: 1, max: 4000 }).withMessage('Message must be 1-4000 characters'),
    body('sessionId').optional().isUUID().withMessage('Session ID must be a valid UUID'),
    body('metadata').optional().isObject().withMessage('Metadata must be an object')
  ],

  // Voice chat validation
  voiceSession: [
    body('sessionId').optional().isUUID().withMessage('Session ID must be a valid UUID'),
    body('duration').optional().isInt({ min: 0 }).withMessage('Duration must be a positive integer'),
    body('messageCount').optional().isInt({ min: 0 }).withMessage('Message count must be a positive integer')
  ],

  // Crisis detection validation
  crisisReport: [
    body('severity').isIn(['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']).withMessage('Severity must be LOW, MEDIUM, HIGH, or CRITICAL'),
    body('message').trim().isLength({ min: 1, max: 2000 }).withMessage('Message must be 1-2000 characters'),
    body('confidence').optional().isFloat({ min: 0, max: 1 }).withMessage('Confidence must be between 0 and 1'),
    body('keywords').optional().isArray().withMessage('Keywords must be an array'),
    body('actionTaken').optional().trim().isLength({ max: 1000 }).withMessage('Action taken must not exceed 1000 characters')
  ],

  // Analytics validation
  analyticsEvent: [
    body('eventName').trim().isLength({ min: 1, max: 100 }).withMessage('Event name must be 1-100 characters'),
    body('properties').optional().isObject().withMessage('Properties must be an object'),
    body('sessionId').optional().isUUID().withMessage('Session ID must be a valid UUID')
  ],

  // Billing validation
  subscription: [
    body('planId').isIn(['free', 'core_monthly']).withMessage('Invalid plan ID'),
    body('paymentMethodId').optional().isString().withMessage('Payment method ID must be a string')
  ],

  // Common parameter validation
  userId: param('userId').isUUID().withMessage('User ID must be a valid UUID'),
  sessionId: param('sessionId').isUUID().withMessage('Session ID must be a valid UUID'),
  entryId: param('entryId').isUUID().withMessage('Entry ID must be a valid UUID'),

  // Query parameter validation
  pagination: [
    query('page').optional().isInt({ min: 1 }).withMessage('Page must be a positive integer'),
    query('limit').optional().isInt({ min: 1, max: 100 }).withMessage('Limit must be between 1 and 100'),
    query('sortBy').optional().isString().withMessage('Sort by must be a string'),
    query('sortOrder').optional().isIn(['asc', 'desc']).withMessage('Sort order must be asc or desc')
  ],

  dateRange: [
    query('startDate').optional().isISO8601().withMessage('Start date must be a valid ISO 8601 date'),
    query('endDate').optional().isISO8601().withMessage('End date must be a valid ISO 8601 date')
  ]
};

// Zod schemas for more complex validation
export const ZodSchemas = {
  // User schemas
  userRegistration: z.object({
    body: z.object({
      email: z.string().email('Invalid email format'),
      name: z.string().min(2, 'Name too short').max(50, 'Name too long'),
      password: z.string()
        .min(8, 'Password too short')
        .regex(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/, 'Password must contain uppercase, lowercase, number, and special character'),
      timezone: z.string().optional(),
      language: z.enum(['en', 'es', 'fr', 'de']).optional()
    })
  }),

  // Mood entry with advanced validation
  moodEntry: z.object({
    body: z.object({
      mood: z.number().int().min(1).max(10),
      notes: z.string().max(1000).optional(),
      tags: z.array(z.string().min(1).max(50)).max(10).optional(),
      context: z.object({
        location: z.string().optional(),
        weather: z.string().optional(),
        activity: z.string().optional()
      }).optional()
    })
  }),

  // Chat message with content filtering
  chatMessage: z.object({
    body: z.object({
      message: z.string()
        .min(1, 'Message cannot be empty')
        .max(4000, 'Message too long')
        .refine(msg => msg.trim().length > 0, 'Message cannot be only whitespace'),
      sessionId: z.string().uuid().optional(),
      metadata: z.object({
        timestamp: z.string().datetime().optional(),
        platform: z.string().optional(),
        version: z.string().optional()
      }).optional()
    })
  }),

  // Crisis report with severity validation
  crisisReport: z.object({
    body: z.object({
      severity: z.enum(['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']),
      message: z.string().min(1).max(2000),
      confidence: z.number().min(0).max(1).optional(),
      keywords: z.array(z.string()).optional(),
      actionTaken: z.string().max(1000).optional(),
      contactEmergencyServices: z.boolean().optional()
    })
  })
};

// Sanitization middleware
export function sanitizeInput(req: Request, res: Response, next: NextFunction) {
  // Recursively sanitize object
  function sanitizeObject(obj: any): any {
    if (typeof obj === 'string') {
      return obj.trim().replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '');
    }
    
    if (Array.isArray(obj)) {
      return obj.map(sanitizeObject);
    }
    
    if (obj && typeof obj === 'object') {
      const sanitized: any = {};
      for (const [key, value] of Object.entries(obj)) {
        sanitized[key] = sanitizeObject(value);
      }
      return sanitized;
    }
    
    return obj;
  }

  // Sanitize request data
  req.body = sanitizeObject(req.body);
  req.query = sanitizeObject(req.query);
  req.params = sanitizeObject(req.params);

  next();
}

// Response validation middleware
export function validateResponse(schema: z.ZodSchema) {
  return (req: Request, res: Response, next: NextFunction) => {
    const originalJson = res.json;

    res.json = function(data: any) {
      try {
        // Validate response data
        const validatedData = schema.parse(data);
        return originalJson.call(this, validatedData);
      } catch (error) {
        if (error instanceof z.ZodError) {
          logger.error('Response validation failed', {
            path: req.path,
            method: req.method,
            errors: error.errors,
            data: typeof data === 'object' ? Object.keys(data) : typeof data
          });

          // In production, send a generic error to avoid exposing internal structure
          if (process.env.NODE_ENV === 'production') {
            return originalJson.call(this, {
              success: false,
              error: 'INTERNAL_ERROR',
              message: 'An error occurred processing your request'
            });
          }

          // In development, show validation details
          return originalJson.call(this, {
            success: false,
            error: 'RESPONSE_VALIDATION_ERROR',
            message: 'Response validation failed',
            details: error.errors
          });
        }

        return originalJson.call(this, data);
      }
    };

    next();
  };
}

// Content-Length validation
export function validateContentLength(maxSize: number = 10 * 1024 * 1024) { // 10MB default
  return (req: Request, res: Response, next: NextFunction) => {
    const contentLength = parseInt(req.headers['content-length'] || '0');
    
    if (contentLength > maxSize) {
      logger.warn('Request too large', {
        contentLength,
        maxSize,
        path: req.path,
        method: req.method,
        userAgent: req.get('User-Agent')
      });

      return res.status(413).json({
        success: false,
        error: 'PAYLOAD_TOO_LARGE',
        message: `Request size ${contentLength} bytes exceeds maximum ${maxSize} bytes`
      });
    }

    next();
  };
}

// Rate limiting validation
export function validateRateLimit(windowMs: number = 60000, max: number = 100) {
  const requests = new Map<string, { count: number; resetTime: number }>();

  return (req: Request, res: Response, next: NextFunction) => {
    const key = req.ip || 'unknown';
    const now = Date.now();
    const windowStart = now - windowMs;

    // Clean up old entries
    for (const [ip, data] of requests.entries()) {
      if (data.resetTime < windowStart) {
        requests.delete(ip);
      }
    }

    const current = requests.get(key) || { count: 0, resetTime: now + windowMs };
    
    if (current.resetTime < now) {
      current.count = 0;
      current.resetTime = now + windowMs;
    }

    current.count++;
    requests.set(key, current);

    // Set rate limit headers
    res.set({
      'X-RateLimit-Limit': max.toString(),
      'X-RateLimit-Remaining': Math.max(0, max - current.count).toString(),
      'X-RateLimit-Reset': new Date(current.resetTime).toISOString()
    });

    if (current.count > max) {
      logger.warn('Rate limit exceeded', {
        ip: key,
        count: current.count,
        max,
        path: req.path,
        method: req.method
      });

      return res.status(429).json({
        success: false,
        error: 'RATE_LIMIT_EXCEEDED',
        message: 'Too many requests, please try again later',
        retryAfter: Math.ceil((current.resetTime - now) / 1000)
      });
    }

    next();
  };
}

// Comprehensive validation middleware factory
export function createValidationMiddleware(options: {
  schema?: ValidationChain[];
  zodSchema?: z.ZodSchema;
  sanitize?: boolean;
  rateLimit?: { windowMs: number; max: number };
  maxContentLength?: number;
}) {
  const middlewares: any[] = [];

  // Content length validation
  if (options.maxContentLength) {
    middlewares.push(validateContentLength(options.maxContentLength));
  }

  // Rate limiting
  if (options.rateLimit) {
    middlewares.push(validateRateLimit(options.rateLimit.windowMs, options.rateLimit.max));
  }

  // Input sanitization
  if (options.sanitize) {
    middlewares.push(sanitizeInput);
  }

  // Schema validation
  if (options.schema) {
    middlewares.push(...options.schema);
    middlewares.push(validateRequest);
  }

  // Zod validation
  if (options.zodSchema) {
    middlewares.push(zodValidation(options.zodSchema));
  }

  return middlewares;
}

export default {
  ValidationSchemas,
  ZodSchemas,
  validateRequest,
  zodValidation,
  sanitizeInput,
  validateResponse,
  validateContentLength,
  validateRateLimit,
  createValidationMiddleware,
  ValidationError
};
