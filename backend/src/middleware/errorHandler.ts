import { Request, Response, NextFunction } from 'express';
import { PrismaClientKnownRequestError, PrismaClientValidationError } from '@prisma/client/runtime/library';
import { JsonWebTokenError, TokenExpiredError } from 'jsonwebtoken';
import { ValidationError } from './validation';
import { logger, errorLogger } from '../utils/logger';
import { config } from '../config/config';
import { captureError } from '../utils/sentry';

// Custom error classes
export class AppError extends Error {
  public statusCode: number;
  public isOperational: boolean;
  public code?: string;

  constructor(message: string, statusCode: number = 500, isOperational: boolean = true, code?: string) {
    super(message);
    this.name = 'AppError';
    this.statusCode = statusCode;
    this.isOperational = isOperational;
    if (code !== undefined) {
      this.code = code;
    }
    
    Error.captureStackTrace(this, this.constructor);
  }
}

export class NotFoundError extends AppError {
  constructor(resource: string = 'Resource') {
    super(`${resource} not found`, 404, true, 'NOT_FOUND');
  }
}

export class UnauthorizedError extends AppError {
  constructor(message: string = 'Unauthorized') {
    super(message, 401, true, 'UNAUTHORIZED');
  }
}

export class ForbiddenError extends AppError {
  constructor(message: string = 'Forbidden') {
    super(message, 403, true, 'FORBIDDEN');
  }
}

export class ConflictError extends AppError {
  constructor(message: string = 'Resource already exists') {
    super(message, 409, true, 'CONFLICT');
  }
}

export class RateLimitError extends AppError {
  public retryAfter?: number;

  constructor(message: string = 'Rate limit exceeded', retryAfter?: number) {
    super(message, 429, true, 'RATE_LIMIT_EXCEEDED');
    if (retryAfter !== undefined) {
      this.retryAfter = retryAfter;
    }
  }
}

export class ExternalServiceError extends AppError {
  public service: string;

  constructor(service: string, message: string = 'External service error') {
    super(`${service}: ${message}`, 502, true, 'EXTERNAL_SERVICE_ERROR');
    this.service = service;
  }
}

// Error response interface
interface ErrorResponse {
  success: false;
  message: string;
  code?: string;
  errors?: any[];
  stack?: string;
  timestamp: string;
  path: string;
  method: string;
  requestId?: string;
}

// Handle Prisma errors
function handlePrismaError(error: PrismaClientKnownRequestError): AppError {
  switch (error.code) {
    case 'P2002':
      // Unique constraint violation
      const field = error.meta?.target as string[] | undefined;
      const fieldName = field?.[0] || 'field';
      return new ConflictError(`${fieldName} already exists`);
    
    case 'P2025':
      // Record not found
      return new NotFoundError('Record');
    
    case 'P2003':
      // Foreign key constraint violation
      return new AppError('Invalid reference', 400, true, 'INVALID_REFERENCE');
    
    case 'P2014':
      // Required relation violation
      return new AppError('Required relation missing', 400, true, 'REQUIRED_RELATION_MISSING');
    
    case 'P2021':
      // Table does not exist
      return new AppError('Database table not found', 500, false, 'TABLE_NOT_FOUND');
    
    case 'P2022':
      // Column does not exist
      return new AppError('Database column not found', 500, false, 'COLUMN_NOT_FOUND');
    
    default:
      return new AppError('Database error', 500, false, 'DATABASE_ERROR');
  }
}

// Handle JWT errors
function handleJWTError(error: JsonWebTokenError | TokenExpiredError): AppError {
  if (error instanceof TokenExpiredError) {
    return new UnauthorizedError('Token expired');
  }
  
  return new UnauthorizedError('Invalid token');
}

// Handle validation errors
function handleValidationError(error: PrismaClientValidationError): AppError {
  return new AppError('Invalid data provided', 400, true, 'VALIDATION_ERROR');
}

// Send error response
function sendErrorResponse(error: AppError, req: Request, res: Response): void {
  const errorResponse: ErrorResponse = {
    success: false,
    message: error.message,
    ...(error.code && { code: error.code }),
    timestamp: new Date().toISOString(),
    path: req.path,
    method: req.method,
    ...(req.headers['x-request-id'] && { requestId: req.headers['x-request-id'] as string })
  };

  // Add stack trace in development
  if (config.isDevelopment && error.stack) {
    errorResponse.stack = error.stack;
  }

  // Add retry after header for rate limit errors
  if (error instanceof RateLimitError && error.retryAfter) {
    res.set('Retry-After', error.retryAfter.toString());
  }

  res.status(error.statusCode).json(errorResponse);
}

// Main error handling middleware
export function errorHandler(error: Error, req: Request, res: Response, next: NextFunction): void {
  let appError: AppError;

  // Handle known error types
  if (error instanceof AppError) {
    appError = error;
  } else if (error instanceof PrismaClientKnownRequestError) {
    appError = handlePrismaError(error);
  } else if (error instanceof PrismaClientValidationError) {
    appError = handleValidationError(error);
  } else if (error instanceof JsonWebTokenError || error instanceof TokenExpiredError) {
    appError = handleJWTError(error);
  } else if (error instanceof ValidationError) {
    appError = new AppError(error.message, error.statusCode, true, 'VALIDATION_ERROR');
  } else {
    // Unknown error
    appError = new AppError('Internal server error', 500, false, 'INTERNAL_ERROR');
  }

  // Log error and send to Sentry
  if (!appError.isOperational || appError.statusCode >= 500) {
    errorLogger.logError(error, {
      userId: req.user?.id,
      path: req.path,
      method: req.method,
      body: req.body,
      query: req.query,
      params: req.params,
      ip: req.ip,
      userAgent: req.get('User-Agent')
    });

    // Send to Sentry for non-operational errors
    captureError(error, {
      ...(req.user && { user: { id: req.user.id } }),
      request: {
        path: req.path,
        method: req.method,
        body: config.isDevelopment ? req.body : undefined,
      },
      tags: {
        error_type: appError.constructor.name,
        status_code: appError.statusCode.toString(),
        operational: appError.isOperational.toString(),
      },
      extra: {
        code: appError.code,
        ip: req.ip,
        userAgent: req.get('User-Agent'),
        query: req.query,
        params: req.params,
      },
      level: appError.statusCode >= 500 ? 'error' : 'warning',
    });
  } else {
    logger.warn('Operational error', {
      message: appError.message,
      code: appError.code,
      statusCode: appError.statusCode,
      userId: req.user?.id,
      path: req.path,
      method: req.method
    });
  }

  // Send error response
  sendErrorResponse(appError, req, res);
}

// Async error wrapper
export function asyncHandler<T extends Request, U extends Response>(
  fn: (req: T, res: U, next: NextFunction) => Promise<any>
) {
  return (req: T, res: U, next: NextFunction): void => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}

// Handle unhandled promise rejections
export function handleUnhandledRejections(): void {
  process.on('unhandledRejection', (reason: any, promise: Promise<any>) => {
    logger.error('Unhandled Promise Rejection', {
      reason: reason?.message || reason,
      stack: reason?.stack,
      promise: promise.toString()
    });
    
    // Graceful shutdown
    process.exit(1);
  });
}

// Handle uncaught exceptions
export function handleUncaughtExceptions(): void {
  process.on('uncaughtException', (error: Error) => {
    logger.error('Uncaught Exception', {
      message: error.message,
      stack: error.stack
    });
    
    // Graceful shutdown
    process.exit(1);
  });
}

// Error monitoring and alerting
export function monitorErrors(): void {
  const errorCounts = new Map<string, number>();
  const errorThreshold = 10; // Alert after 10 errors of same type in 5 minutes
  const timeWindow = 5 * 60 * 1000; // 5 minutes
  
  setInterval(() => {
    errorCounts.clear();
  }, timeWindow);
  
  // Override console.error to monitor errors
  const originalConsoleError = console.error;
  console.error = (...args: any[]) => {
    const errorKey = args[0]?.toString() || 'unknown';
    const count = errorCounts.get(errorKey) || 0;
    errorCounts.set(errorKey, count + 1);
    
    if (count + 1 >= errorThreshold) {
      logger.error('High error rate detected', {
        errorType: errorKey,
        count: count + 1,
        threshold: errorThreshold,
        timeWindow: timeWindow / 1000 / 60 + ' minutes'
      });
      
      // Reset counter to avoid spam
      errorCounts.set(errorKey, 0);
    }
    
    originalConsoleError.apply(console, args);
  };
}

// Initialize error handling
export function initializeErrorHandling(): void {
  handleUnhandledRejections();
  handleUncaughtExceptions();
  
  if (config.isProduction) {
    monitorErrors();
  }
}

export default {
  errorHandler,
  asyncHandler,
  AppError,
  NotFoundError,
  UnauthorizedError,
  ForbiddenError,
  ConflictError,
  RateLimitError,
  ExternalServiceError,
  initializeErrorHandling
};
