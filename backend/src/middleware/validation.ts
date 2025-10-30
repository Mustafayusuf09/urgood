import { Request, Response, NextFunction } from 'express';
import Joi from 'joi';
import { body, param, query, validationResult } from 'express-validator';
import xss from 'xss';
import { logger, errorLogger } from '../utils/logger';

// Custom error class for validation errors
export class ValidationError extends Error {
  public statusCode: number;
  public errors: any[];

  constructor(message: string, errors: any[] = []) {
    super(message);
    this.name = 'ValidationError';
    this.statusCode = 400;
    this.errors = errors;
  }
}

// XSS sanitization options
const xssOptions = {
  whiteList: {}, // No HTML tags allowed
  stripIgnoreTag: true,
  stripIgnoreTagBody: ['script', 'style']
};

// Sanitize input data
export function sanitizeInput(data: any): any {
  if (typeof data === 'string') {
    return xss(data, xssOptions);
  }
  
  if (Array.isArray(data)) {
    return data.map(sanitizeInput);
  }
  
  if (data && typeof data === 'object') {
    const sanitized: any = {};
    for (const [key, value] of Object.entries(data)) {
      sanitized[key] = sanitizeInput(value);
    }
    return sanitized;
  }
  
  return data;
}

// Middleware to handle express-validator results
export function validateRequest(req: Request, res: Response, next: NextFunction): void {
  const errors = validationResult(req);
  
  if (!errors.isEmpty()) {
    const errorDetails = errors.array().map(error => ({
      field: error.type === 'field' ? error.path : error.type,
      message: error.msg,
      value: error.type === 'field' ? error.value : undefined
    }));
    
    errorLogger.logValidationError(
      errorDetails[0]?.field || 'unknown',
      errorDetails[0]?.value,
      errorDetails[0]?.message || 'validation_failed',
      req.user?.id
    );
    
    res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors: errorDetails
    });
    return;
  }
  
  // Sanitize request data
  req.body = sanitizeInput(req.body);
  req.query = sanitizeInput(req.query);
  req.params = sanitizeInput(req.params);
  
  next();
}

// Common validation schemas using Joi
export const schemas = {
  // User validation schemas
  userRegistration: Joi.object({
    email: Joi.string().email().max(255).required(),
    password: Joi.string().min(8).max(128).pattern(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/).required()
      .messages({
        'string.pattern.base': 'Password must contain at least one lowercase letter, one uppercase letter, one number, and one special character'
      }),
    name: Joi.string().max(100).optional(),
    timezone: Joi.string().max(50).optional(),
    language: Joi.string().length(2).optional()
  }),
  
  userLogin: Joi.object({
    email: Joi.string().email().max(255).required(),
    password: Joi.string().min(1).max(128).required()
  }),
  
  userUpdate: Joi.object({
    name: Joi.string().max(100).optional(),
    timezone: Joi.string().max(50).optional(),
    language: Joi.string().length(2).optional(),
    preferences: Joi.object({
      notifications: Joi.boolean().optional(),
      darkMode: Joi.boolean().optional(),
      dailyReminderTime: Joi.string().pattern(/^([01]?[0-9]|2[0-3]):[0-5][0-9]$/).optional(),
      crisisDetectionEnabled: Joi.boolean().optional()
    }).optional()
  }),
  
  // Chat message validation
  chatMessage: Joi.object({
    content: Joi.string().min(1).max(4000).required(),
    sessionId: Joi.string().uuid().optional(),
    metadata: Joi.object().optional()
  }),
  
  // Mood entry validation
  moodEntry: Joi.object({
    mood: Joi.number().integer().min(1).max(5).required(),
    tags: Joi.array().items(Joi.string().max(50)).max(10).optional(),
    notes: Joi.string().max(1000).optional()
  }),
  
  // Crisis event validation
  crisisEvent: Joi.object({
    level: Joi.string().valid('LOW', 'MEDIUM', 'HIGH', 'CRITICAL').required(),
    message: Joi.string().min(1).max(2000).required(),
    actionTaken: Joi.string().max(1000).optional()
  }),
  
  // Analytics event validation
  analyticsEvent: Joi.object({
    eventName: Joi.string().max(100).required(),
    properties: Joi.object().optional(),
    sessionId: Joi.string().uuid().optional()
  }),
  
  // Common parameter validations
  userId: Joi.string().uuid().required(),
  pagination: Joi.object({
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(100).default(20),
    sortBy: Joi.string().max(50).optional(),
    sortOrder: Joi.string().valid('asc', 'desc').default('desc')
  })
};

// Joi validation middleware factory
export function validateSchema(schema: Joi.ObjectSchema, source: 'body' | 'query' | 'params' = 'body') {
  return (req: Request, res: Response, next: NextFunction): void => {
    const data = req[source];
    const { error, value } = schema.validate(data, { 
      abortEarly: false,
      stripUnknown: true,
      convert: true
    });
    
    if (error) {
      const errorDetails = error.details.map(detail => ({
        field: detail.path.join('.'),
        message: detail.message,
        value: detail.context?.value
      }));
      
      errorLogger.logValidationError(
        errorDetails[0]?.field || 'unknown',
        errorDetails[0]?.value,
        'joi_validation_failed',
        req.user?.id
      );
      
      res.status(400).json({
        success: false,
        message: 'Validation failed',
        errors: errorDetails
      });
      return;
    }
    
    // Replace the source data with validated and sanitized data
    req[source] = sanitizeInput(value);
    next();
  };
}

// Express-validator validation rules
export const validationRules = {
  // User validation rules
  userRegistration: [
    body('email')
      .isEmail()
      .normalizeEmail()
      .isLength({ max: 255 })
      .withMessage('Valid email is required'),
    body('password')
      .isLength({ min: 8, max: 128 })
      .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/)
      .withMessage('Password must contain at least one lowercase letter, one uppercase letter, one number, and one special character'),
    body('name')
      .optional()
      .isLength({ max: 100 })
      .trim()
      .withMessage('Name must be less than 100 characters'),
    body('timezone')
      .optional()
      .isLength({ max: 50 })
      .withMessage('Invalid timezone'),
    body('language')
      .optional()
      .isLength({ min: 2, max: 2 })
      .withMessage('Language must be 2 characters')
  ],
  
  userLogin: [
    body('email')
      .isEmail()
      .normalizeEmail()
      .withMessage('Valid email is required'),
    body('password')
      .isLength({ min: 1, max: 128 })
      .withMessage('Password is required')
  ],
  
  // Chat message validation rules
  chatMessage: [
    body('content')
      .isLength({ min: 1, max: 4000 })
      .trim()
      .withMessage('Message content must be between 1 and 4000 characters'),
    body('sessionId')
      .optional()
      .isUUID()
      .withMessage('Session ID must be a valid UUID'),
    body('metadata')
      .optional()
      .isObject()
      .withMessage('Metadata must be an object')
  ],
  
  // Mood entry validation rules
  moodEntry: [
    body('mood')
      .isInt({ min: 1, max: 5 })
      .withMessage('Mood must be an integer between 1 and 5'),
    body('tags')
      .optional()
      .isArray({ max: 10 })
      .withMessage('Tags must be an array with maximum 10 items'),
    body('tags.*')
      .optional()
      .isLength({ max: 50 })
      .trim()
      .withMessage('Each tag must be less than 50 characters'),
    body('notes')
      .optional()
      .isLength({ max: 1000 })
      .trim()
      .withMessage('Notes must be less than 1000 characters')
  ],
  
  // Parameter validation rules
  userId: [
    param('userId')
      .isUUID()
      .withMessage('User ID must be a valid UUID')
  ],
  
  messageId: [
    param('messageId')
      .isUUID()
      .withMessage('Message ID must be a valid UUID')
  ],
  
  // Query parameter validation rules
  pagination: [
    query('page')
      .optional()
      .isInt({ min: 1 })
      .toInt()
      .withMessage('Page must be a positive integer'),
    query('limit')
      .optional()
      .isInt({ min: 1, max: 100 })
      .toInt()
      .withMessage('Limit must be between 1 and 100'),
    query('sortBy')
      .optional()
      .isLength({ max: 50 })
      .withMessage('Sort field must be less than 50 characters'),
    query('sortOrder')
      .optional()
      .isIn(['asc', 'desc'])
      .withMessage('Sort order must be asc or desc')
  ],
  
  dateRange: [
    query('startDate')
      .optional()
      .isISO8601()
      .toDate()
      .withMessage('Start date must be a valid ISO 8601 date'),
    query('endDate')
      .optional()
      .isISO8601()
      .toDate()
      .withMessage('End date must be a valid ISO 8601 date')
  ]
};

// File upload validation
export function validateFileUpload(
  allowedTypes: string[] = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'],
  maxSize: number = 10 * 1024 * 1024 // 10MB
) {
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!req.file) {
      res.status(400).json({
        success: false,
        message: 'No file uploaded'
      });
      return;
    }
    
    // Check file type
    if (!allowedTypes.includes(req.file.mimetype)) {
      res.status(400).json({
        success: false,
        message: `File type not allowed. Allowed types: ${allowedTypes.join(', ')}`
      });
      return;
    }
    
    // Check file size
    if (req.file.size > maxSize) {
      res.status(400).json({
        success: false,
        message: `File too large. Maximum size: ${Math.round(maxSize / 1024 / 1024)}MB`
      });
      return;
    }
    
    next();
  };
}

// Rate limiting validation
export function validateRateLimit(identifier: string, windowMs: number, maxRequests: number) {
  return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { rateLimitService } = await import('../utils/redis');
      const windowSeconds = Math.floor(windowMs / 1000);
      
      const result = await rateLimitService.checkRateLimit(identifier, windowSeconds, maxRequests);
      
      // Add rate limit headers
      res.set({
        'X-RateLimit-Limit': maxRequests.toString(),
        'X-RateLimit-Remaining': result.remaining.toString(),
        'X-RateLimit-Reset': result.resetTime.toString()
      });
      
      if (!result.allowed) {
        res.status(429).json({
          success: false,
          message: 'Rate limit exceeded',
          retryAfter: result.resetTime - Math.floor(Date.now() / 1000)
        });
        return;
      }
      
      next();
    } catch (error) {
      logger.error('Rate limit validation error:', error);
      // On error, allow the request but log the issue
      next();
    }
  };
}

// Content filtering for sensitive data
export function filterSensitiveContent(content: string): { filtered: string; flagged: boolean } {
  const sensitivePatterns = [
    // Personal information patterns
    /\b\d{3}-\d{2}-\d{4}\b/g, // SSN
    /\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b/g, // Credit card
    /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/g, // Email
    /\b\d{3}[\s-]?\d{3}[\s-]?\d{4}\b/g, // Phone number
  ];
  
  let filtered = content;
  let flagged = false;
  
  sensitivePatterns.forEach(pattern => {
    if (pattern.test(filtered)) {
      flagged = true;
      filtered = filtered.replace(pattern, '[REDACTED]');
    }
  });
  
  return { filtered, flagged };
}

// Crisis content detection
export function detectCrisisContent(content: string): { isCrisis: boolean; level: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL' } {
  const crisisKeywords = {
    CRITICAL: ['suicide', 'kill myself', 'end my life', 'want to die', 'planning to hurt'],
    HIGH: ['hurt myself', 'self harm', 'cutting', 'overdose', 'jump off'],
    MEDIUM: ['depressed', 'hopeless', 'worthless', 'can\'t go on', 'giving up'],
    LOW: ['sad', 'down', 'upset', 'anxious', 'worried']
  };
  
  const lowerContent = content.toLowerCase();
  
  for (const [level, keywords] of Object.entries(crisisKeywords)) {
    for (const keyword of keywords) {
      if (lowerContent.includes(keyword)) {
        return { 
          isCrisis: level !== 'LOW', 
          level: level as 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL' 
        };
      }
    }
  }
  
  return { isCrisis: false, level: 'LOW' };
}

export default {
  validateRequest,
  validateSchema,
  validationRules,
  schemas,
  sanitizeInput,
  validateFileUpload,
  validateRateLimit,
  filterSensitiveContent,
  detectCrisisContent,
  ValidationError
};
