import { Request, Response, NextFunction } from 'express';
import { prisma } from '../utils/database';
import { logger, securityLogger } from '../utils/logger';

// Audit log levels
export enum AuditLevel {
  INFO = 'info',
  WARN = 'warn',
  ERROR = 'error',
  CRITICAL = 'critical'
}

// Audit event types
export enum AuditEventType {
  USER_LOGIN = 'user_login',
  USER_LOGOUT = 'user_logout',
  USER_REGISTER = 'user_register',
  USER_UPDATE = 'user_update',
  USER_DELETE = 'user_delete',
  PASSWORD_CHANGE = 'password_change',
  EMAIL_CHANGE = 'email_change',
  SUBSCRIPTION_CHANGE = 'subscription_change',
  PAYMENT_CREATED = 'payment_created',
  PAYMENT_FAILED = 'payment_failed',
  DATA_ACCESS = 'data_access',
  DATA_EXPORT = 'data_export',
  DATA_DELETE = 'data_delete',
  CRISIS_EVENT = 'crisis_event',
  ADMIN_ACTION = 'admin_action',
  SECURITY_VIOLATION = 'security_violation',
  RATE_LIMIT_EXCEEDED = 'rate_limit_exceeded',
  SUSPICIOUS_ACTIVITY = 'suspicious_activity'
}

// Audit log entry interface
export interface AuditLogEntry {
  userId?: string;
  action: string;
  resource: string;
  details?: Record<string, any>;
  ipAddress?: string;
  userAgent?: string;
  level?: AuditLevel;
  eventType?: AuditEventType;
}

// Sensitive fields that should be redacted in logs
const SENSITIVE_FIELDS = [
  'password',
  'passwordHash',
  'token',
  'refreshToken',
  'apiKey',
  'secret',
  'ssn',
  'creditCard',
  'bankAccount'
];

// Redact sensitive information from objects
function redactSensitiveData(obj: any): any {
  if (obj === null || obj === undefined) {
    return obj;
  }
  
  if (typeof obj === 'string') {
    // Check if the string looks like sensitive data
    if (obj.length > 20 && (obj.includes('Bearer') || obj.startsWith('sk-') || obj.startsWith('pk_'))) {
      return '[REDACTED]';
    }
    return obj;
  }
  
  if (Array.isArray(obj)) {
    return obj.map(redactSensitiveData);
  }
  
  if (typeof obj === 'object') {
    const redacted: any = {};
    for (const [key, value] of Object.entries(obj)) {
      const lowerKey = key.toLowerCase();
      if (SENSITIVE_FIELDS.some(field => lowerKey.includes(field))) {
        redacted[key] = '[REDACTED]';
      } else {
        redacted[key] = redactSensitiveData(value);
      }
    }
    return redacted;
  }
  
  return obj;
}

// Create audit log entry
export async function createAuditLog(entry: AuditLogEntry): Promise<void> {
  try {
    const auditLog = await prisma.auditLog.create({
      data: {
        userId: entry.userId || 'anonymous',
        action: entry.action,
        resource: entry.resource,
        details: entry.details ? redactSensitiveData(entry.details) : null,
        ipAddress: entry.ipAddress || 'unknown',
        userAgent: entry.userAgent || 'unknown'
      }
    });
    
    // Also log to application logger for real-time monitoring
    const logLevel = entry.level || AuditLevel.INFO;
    logger.log(logLevel, `Audit: ${entry.action}`, {
      auditId: auditLog.id,
      userId: entry.userId,
      resource: entry.resource,
      eventType: entry.eventType,
      ipAddress: entry.ipAddress,
      details: redactSensitiveData(entry.details)
    });
    
  } catch (error) {
    logger.error('Failed to create audit log', {
      error: error instanceof Error ? error.message : 'Unknown error',
      entry: redactSensitiveData(entry)
    });
  }
}

// Audit logging middleware
export function auditLogger(req: Request, res: Response, next: NextFunction): void {
  const startTime = Date.now();
  const originalSend = res.send;
  
  // Capture response
  res.send = function(body: any) {
    const endTime = Date.now();
    const duration = endTime - startTime;
    
    // Determine if this request should be audited
    const shouldAudit = shouldAuditRequest(req, res.statusCode);
    
    if (shouldAudit) {
      const auditEntry: AuditLogEntry = {
        userId: req.user?.id || 'anonymous',
        action: `${req.method} ${req.path}`,
        resource: determineResource(req.path),
        details: {
          method: req.method,
          path: req.path,
          statusCode: res.statusCode,
          duration,
          query: redactSensitiveData(req.query),
          params: redactSensitiveData(req.params),
          body: redactSensitiveData(req.body),
          responseSize: Buffer.byteLength(body || '', 'utf8')
        },
        ipAddress: getClientIP(req),
        userAgent: req.get('User-Agent') || 'unknown',
        level: determineAuditLevel(req, res.statusCode),
        eventType: determineEventType(req)
      };
      
      // Create audit log asynchronously
      createAuditLog(auditEntry).catch(error => {
        logger.error('Audit logging failed', error);
      });
    }
    
    return originalSend.call(this, body);
  };
  
  next();
}

// Determine if request should be audited
function shouldAuditRequest(req: Request, statusCode: number): boolean {
  // Always audit authentication and authorization endpoints
  if (req.path.includes('/auth/')) {
    return true;
  }
  
  // Always audit user management endpoints
  if (req.path.includes('/users/')) {
    return true;
  }
  
  // Always audit payment endpoints
  if (req.path.includes('/billing/') || req.path.includes('/payments/')) {
    return true;
  }
  
  // Always audit admin endpoints
  if (req.path.includes('/admin/')) {
    return true;
  }
  
  // Always audit crisis events
  if (req.path.includes('/crisis/')) {
    return true;
  }
  
  // Audit failed requests (4xx, 5xx)
  if (statusCode >= 400) {
    return true;
  }
  
  // Audit data modification operations
  if (['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method)) {
    return true;
  }
  
  // Skip health checks and other routine operations
  if (req.path === '/health' || req.path === '/api/v1/health') {
    return false;
  }
  
  return false;
}

// Determine resource from path
function determineResource(path: string): string {
  const pathSegments = path.split('/').filter(segment => segment);
  
  if (pathSegments.includes('auth')) return 'authentication';
  if (pathSegments.includes('users')) return 'user';
  if (pathSegments.includes('chat')) return 'chat';
  if (pathSegments.includes('mood')) return 'mood';
  if (pathSegments.includes('crisis')) return 'crisis';
  if (pathSegments.includes('billing')) return 'billing';
  if (pathSegments.includes('analytics')) return 'analytics';
  if (pathSegments.includes('admin')) return 'admin';
  
  return 'unknown';
}

// Determine audit level based on request and response
function determineAuditLevel(req: Request, statusCode: number): AuditLevel {
  // Critical for security violations and system errors
  if (statusCode === 401 || statusCode === 403) {
    return AuditLevel.CRITICAL;
  }
  
  // Error for server errors
  if (statusCode >= 500) {
    return AuditLevel.ERROR;
  }
  
  // Warning for client errors
  if (statusCode >= 400) {
    return AuditLevel.WARN;
  }
  
  // Critical for sensitive operations
  if (req.path.includes('/auth/') || req.path.includes('/admin/') || req.path.includes('/crisis/')) {
    return AuditLevel.CRITICAL;
  }
  
  return AuditLevel.INFO;
}

// Determine event type from request
function determineEventType(req: Request): AuditEventType {
  const path = req.path.toLowerCase();
  const method = req.method;
  
  // Authentication events
  if (path.includes('/auth/login')) return AuditEventType.USER_LOGIN;
  if (path.includes('/auth/logout')) return AuditEventType.USER_LOGOUT;
  if (path.includes('/auth/register')) return AuditEventType.USER_REGISTER;
  
  // User management events
  if (path.includes('/users/') && method === 'PUT') return AuditEventType.USER_UPDATE;
  if (path.includes('/users/') && method === 'DELETE') return AuditEventType.USER_DELETE;
  
  // Payment events
  if (path.includes('/billing/') || path.includes('/payments/')) {
    return AuditEventType.PAYMENT_CREATED;
  }
  
  // Crisis events
  if (path.includes('/crisis/')) return AuditEventType.CRISIS_EVENT;
  
  // Admin events
  if (path.includes('/admin/')) return AuditEventType.ADMIN_ACTION;
  
  // Data access events
  if (method === 'GET') return AuditEventType.DATA_ACCESS;
  
  return AuditEventType.DATA_ACCESS;
}

// Get client IP address
function getClientIP(req: Request): string {
  const forwardedFor = req.headers['x-forwarded-for'] as string;
  const realIP = req.headers['x-real-ip'] as string;
  const connectionIP = req.connection?.remoteAddress;
  const socketIP = req.socket?.remoteAddress;
  const reqIP = req.ip;
  
  const ip = forwardedFor ||
    realIP ||
    connectionIP ||
    socketIP ||
    reqIP ||
    'unknown';
    
  return (ip as string).split(',')[0].trim();
}

// Specific audit functions for common events
export const auditEvents = {
  userLogin: (userId: string, success: boolean, req: Request) => {
    createAuditLog({
      userId,
      action: success ? 'login_success' : 'login_failed',
      resource: 'authentication',
      details: { success },
      ipAddress: getClientIP(req),
      userAgent: req.get('User-Agent') || 'unknown',
      level: success ? AuditLevel.INFO : AuditLevel.WARN,
      eventType: AuditEventType.USER_LOGIN
    });
  },
  
  userLogout: (userId: string, req: Request) => {
    createAuditLog({
      userId,
      action: 'logout',
      resource: 'authentication',
      ipAddress: getClientIP(req),
      userAgent: req.get('User-Agent') || 'unknown',
      level: AuditLevel.INFO,
      eventType: AuditEventType.USER_LOGOUT
    });
  },
  
  passwordChange: (userId: string, req: Request) => {
    createAuditLog({
      userId,
      action: 'password_change',
      resource: 'user',
      ipAddress: getClientIP(req),
      userAgent: req.get('User-Agent') || 'unknown',
      level: AuditLevel.CRITICAL,
      eventType: AuditEventType.PASSWORD_CHANGE
    });
  },
  
  subscriptionChange: (userId: string, oldStatus: string, newStatus: string, req: Request) => {
    createAuditLog({
      userId,
      action: 'subscription_change',
      resource: 'billing',
      details: { oldStatus, newStatus },
      ipAddress: getClientIP(req),
      userAgent: req.get('User-Agent') || 'unknown',
      level: AuditLevel.INFO,
      eventType: AuditEventType.SUBSCRIPTION_CHANGE
    });
  },
  
  crisisEvent: (userId: string, level: string, req: Request) => {
    createAuditLog({
      userId,
      action: 'crisis_detected',
      resource: 'crisis',
      details: { level },
      ipAddress: getClientIP(req),
      userAgent: req.get('User-Agent') || 'unknown',
      level: AuditLevel.CRITICAL,
      eventType: AuditEventType.CRISIS_EVENT
    });
  },
  
  dataExport: (userId: string, dataType: string, req: Request) => {
    createAuditLog({
      userId,
      action: 'data_export',
      resource: 'user_data',
      details: { dataType },
      ipAddress: getClientIP(req),
      userAgent: req.get('User-Agent') || 'unknown',
      level: AuditLevel.CRITICAL,
      eventType: AuditEventType.DATA_EXPORT
    });
  },
  
  securityViolation: (userId: string | undefined, violation: string, details: any, req: Request) => {
    createAuditLog({
      userId: userId || 'anonymous',
      action: 'security_violation',
      resource: 'security',
      details: { violation, ...details },
      ipAddress: getClientIP(req),
      userAgent: req.get('User-Agent') || 'unknown',
      level: AuditLevel.CRITICAL,
      eventType: AuditEventType.SECURITY_VIOLATION
    });
  }
};

export default {
  auditLogger,
  createAuditLog,
  auditEvents,
  AuditLevel,
  AuditEventType
};
