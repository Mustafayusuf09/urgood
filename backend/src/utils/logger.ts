import winston from 'winston';
import { config } from '../config/config';

// Custom log format
const logFormat = winston.format.combine(
  winston.format.timestamp({
    format: 'YYYY-MM-DD HH:mm:ss'
  }),
  winston.format.errors({ stack: true }),
  winston.format.json(),
  winston.format.prettyPrint()
);

// Console format for development
const consoleFormat = winston.format.combine(
  winston.format.colorize(),
  winston.format.timestamp({
    format: 'HH:mm:ss'
  }),
  winston.format.printf(({ timestamp, level, message, ...meta }) => {
    let msg = `${timestamp} [${level}]: ${message}`;
    if (Object.keys(meta).length > 0) {
      msg += ` ${JSON.stringify(meta)}`;
    }
    return msg;
  })
);

// Enhanced log format with structured data
const structuredFormat = winston.format.combine(
  winston.format.timestamp({
    format: 'YYYY-MM-DD HH:mm:ss.SSS'
  }),
  winston.format.errors({ stack: true }),
  winston.format.json(),
  winston.format.printf(({ timestamp, level, message, service, environment, type, category, ...meta }) => {
    const baseLog: any = {
      '@timestamp': timestamp,
      level,
      message,
      service,
      environment,
      ...(type ? { type } : {}),
      ...(category ? { category } : {}),
    };
    
    // Add metadata
    if (Object.keys(meta).length > 0) {
      baseLog.metadata = meta;
    }
    
    return JSON.stringify(baseLog);
  })
);

// Create logger instance
export const logger = winston.createLogger({
  level: config.monitoring.logLevel,
  format: config.isProduction ? structuredFormat : logFormat,
  defaultMeta: {
    service: 'urgood-backend',
    environment: config.nodeEnv,
    version: process.env.npm_package_version || '1.0.0',
    nodeVersion: process.version,
    pid: process.pid
  },
  transports: [
    // Console transport for development
    new winston.transports.Console({
      format: config.isDevelopment ? consoleFormat : logFormat,
      handleExceptions: true,
      handleRejections: true
    }),
    
    // File transports for production
    ...(config.isProduction ? [
      new winston.transports.File({
        filename: 'logs/error.log',
        level: 'error',
        maxsize: 5242880, // 5MB
        maxFiles: 5,
        format: logFormat
      }),
      new winston.transports.File({
        filename: 'logs/combined.log',
        maxsize: 5242880, // 5MB
        maxFiles: 5,
        format: logFormat
      })
    ] : [])
  ],
  
  // Don't exit on handled exceptions
  exitOnError: false
});

// Stream for Morgan HTTP logging
export const logStream = {
  write: (message: string) => {
    logger.info(message.trim());
  }
};

// Structured logging interface
interface LogContext {
  userId?: string | undefined;
  sessionId?: string | undefined;
  requestId?: string | undefined;
  ip?: string | undefined;
  userAgent?: string | undefined;
  duration?: number | undefined;
  statusCode?: number | undefined;
  method?: string | undefined;
  path?: string | undefined;
  component?: string | undefined;
  operation?: string | undefined;
  [key: string]: any;
}

// Performance logging
export const performanceLogger = {
  logSlowQuery: (query: string, duration: number, params?: any) => {
    logger.warn('Slow database query detected', {
      type: 'performance',
      category: 'database',
      query: query.substring(0, 200), // Truncate for privacy
      duration,
      params: config.isDevelopment ? params : undefined,
      threshold: 1000,
      severity: duration > 5000 ? 'high' : 'medium'
    });
  },
  
  logSlowRequest: (method: string, path: string, duration: number, context?: LogContext) => {
    logger.warn('Slow API request detected', {
      type: 'performance',
      category: 'api',
      method,
      path,
      duration,
      threshold: 2000,
      severity: duration > 10000 ? 'high' : 'medium',
      ...context
    });
  },
  
  logMemoryUsage: (usage: NodeJS.MemoryUsage, context?: LogContext) => {
    const heapUsedMB = Math.round(usage.heapUsed / 1024 / 1024);
    const heapTotalMB = Math.round(usage.heapTotal / 1024 / 1024);
    const memoryUsagePercent = (usage.heapUsed / usage.heapTotal) * 100;
    
    const level = memoryUsagePercent > 90 ? 'error' : memoryUsagePercent > 75 ? 'warn' : 'info';
    
    logger.log(level, 'Memory usage report', {
      type: 'performance',
      category: 'memory',
      heapUsedMB,
      heapTotalMB,
      memoryUsagePercent: Math.round(memoryUsagePercent),
      rss: Math.round(usage.rss / 1024 / 1024),
      external: Math.round(usage.external / 1024 / 1024),
      ...context
    });
  }
};

// Error logging with categorization
export const errorLogger = {
  logError: (error: Error, context?: LogContext) => {
    logger.error('Application error', {
      type: 'error',
      category: categorizeError(error),
      message: error.message,
      stack: config.isDevelopment ? error.stack : undefined,
      name: error.name,
      ...context
    });
  },
  
  logDatabaseError: (operation: string, error: Error, context?: LogContext) => {
    logger.error('Database error', {
      type: 'error',
      category: 'database',
      operation,
      message: error.message,
      name: error.name,
      ...context
    });
  },
  
  logExternalServiceError: (service: string, error: Error, context?: LogContext) => {
    logger.error('External service error', {
      type: 'error',
      category: 'external_service',
      service,
      message: error.message,
      name: error.name,
      ...context
    });
  },
  
  logValidationError: (field: string, value: any, rule: string, context?: LogContext) => {
    logger.warn('Validation error', {
      type: 'error',
      category: 'validation',
      field,
      value: config.isDevelopment ? value : '[REDACTED]',
      rule,
      ...context
    });
  }
};

// Security logging functions
export const securityLogger = {
  logAuthAttempt: (email: string, success: boolean, ip: string, userAgent?: string) => {
    logger.info('Authentication attempt', {
      type: 'security',
      category: 'authentication',
      email: config.isDevelopment ? email : hashEmail(email),
      success,
      ip,
      userAgent,
      timestamp: new Date().toISOString()
    });
  },
  
  logSuspiciousActivity: (userId: string, activity: string, details: any, ip: string) => {
    logger.warn('Suspicious activity detected', {
      type: 'security',
      category: 'suspicious_activity',
      userId,
      activity,
      details,
      ip,
      severity: 'medium',
      timestamp: new Date().toISOString()
    });
  },
  
  logSecurityEvent: (event: string, details: any, severity: 'low' | 'medium' | 'high' | 'critical' = 'medium') => {
    const logLevel = severity === 'critical' ? 'error' : severity === 'high' ? 'warn' : 'info';
    logger.log(logLevel, `Security event: ${event}`, {
      type: 'security',
      category: 'security_event',
      event,
      severity,
      details,
      timestamp: new Date().toISOString()
    });
  },
  
  logDataAccess: (userId: string, resource: string, action: string, ip: string) => {
    logger.info('Data access', {
      type: 'security',
      category: 'data_access',
      userId,
      resource,
      action,
      ip,
      timestamp: new Date().toISOString()
    });
  },
  
  logPrivilegeEscalation: (userId: string, fromRole: string, toRole: string, ip: string) => {
    logger.warn('Privilege escalation attempt', {
      type: 'security',
      category: 'privilege_escalation',
      userId,
      fromRole,
      toRole,
      ip,
      severity: 'high',
      timestamp: new Date().toISOString()
    });
  }
};

// Mental health app specific logging
export const therapyLogger = {
  logSessionStart: (userId: string, sessionId: string, sessionType: string) => {
    logger.info('Therapy session started', {
      type: 'therapy',
      category: 'session',
      event: 'session_start',
      userId,
      sessionId,
      sessionType,
      timestamp: new Date().toISOString()
    });
  },
  
  logSessionEnd: (userId: string, sessionId: string, duration: number, outcome?: string) => {
    logger.info('Therapy session ended', {
      type: 'therapy',
      category: 'session',
      event: 'session_end',
      userId,
      sessionId,
      duration,
      outcome,
      timestamp: new Date().toISOString()
    });
  },
  
  logCrisisDetection: (userId: string, severity: string, keywords: string[], confidence: number) => {
    logger.error('Crisis situation detected', {
      type: 'therapy',
      category: 'crisis_detection',
      event: 'crisis_detected',
      userId,
      severity,
      keywordCount: keywords.length,
      confidence,
      priority: 'critical',
      timestamp: new Date().toISOString()
    });
  },
  
  logMoodEntry: (userId: string, moodScore: number, context?: string) => {
    logger.info('Mood entry recorded', {
      type: 'therapy',
      category: 'mood_tracking',
      event: 'mood_entry',
      userId,
      moodScore,
      context,
      timestamp: new Date().toISOString()
    });
  },
  
  logVoiceChatSession: (userId: string, provider: string, duration: number, quality?: string) => {
    logger.info('Voice chat session', {
      type: 'therapy',
      category: 'voice_chat',
      event: 'voice_session',
      userId,
      provider,
      duration,
      quality,
      timestamp: new Date().toISOString()
    });
  }
};

// Business metrics logging
export const metricsLogger = {
  logUserEngagement: (userId: string, action: string, duration?: number, metadata?: any) => {
    logger.info('User engagement event', {
      type: 'metrics',
      category: 'engagement',
      userId,
      action,
      duration,
      metadata,
      timestamp: new Date().toISOString()
    });
  },
  
  logSubscriptionEvent: (userId: string, event: string, plan?: string, amount?: number) => {
    logger.info('Subscription event', {
      type: 'metrics',
      category: 'subscription',
      userId,
      event,
      plan,
      amount,
      timestamp: new Date().toISOString()
    });
  },
  
  logFeatureUsage: (userId: string, feature: string, success: boolean, metadata?: any) => {
    logger.info('Feature usage', {
      type: 'metrics',
      category: 'feature_usage',
      userId,
      feature,
      success,
      metadata,
      timestamp: new Date().toISOString()
    });
  }
};

// Helper functions
function categorizeError(error: Error): string {
  const message = error.message.toLowerCase();
  const stack = error.stack?.toLowerCase() || '';
  
  if (message.includes('prisma') || message.includes('database')) return 'database';
  if (message.includes('unauthorized') || message.includes('token')) return 'authentication';
  if (message.includes('validation') || message.includes('invalid')) return 'validation';
  if (message.includes('rate limit')) return 'rate_limiting';
  if (message.includes('openai') || message.includes('stripe')) return 'external_service';
  if (message.includes('crisis') || message.includes('emergency')) return 'crisis';
  
  return 'general';
}

function hashEmail(email: string): string {
  // Simple hash for privacy - in production use proper hashing
  const crypto = require('crypto');
  return crypto.createHash('sha256').update(email).digest('hex').substring(0, 8);
}


// Structured logging for different environments
if (config.isProduction) {
  // In production, add additional metadata
  logger.defaultMeta = {
    ...logger.defaultMeta,
    hostname: require('os').hostname(),
    pid: process.pid
  };
}

// Handle uncaught exceptions and rejections
logger.exceptions.handle(
  new winston.transports.File({ filename: 'logs/exceptions.log' })
);

logger.rejections.handle(
  new winston.transports.File({ filename: 'logs/rejections.log' })
);

export default logger;
