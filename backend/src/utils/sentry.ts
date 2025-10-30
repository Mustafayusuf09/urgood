import * as Sentry from '@sentry/node';
import { ProfilingIntegration } from '@sentry/profiling-node';
import { config } from '../config/config';
import { logger } from './logger';

// Sentry configuration interface
interface SentryConfig {
  dsn: string;
  environment: string;
  release?: string;
  tracesSampleRate: number;
  profilesSampleRate: number;
  beforeSend?: (event: Sentry.Event) => Sentry.Event | null;
  beforeSendTransaction?: (event: Sentry.Transaction) => Sentry.Transaction | null;
}

// Initialize Sentry with comprehensive configuration
export function initializeSentry(): void {
  if (!config.monitoring.sentryDsn) {
    if (config.isProduction) {
      logger.warn('⚠️ Sentry DSN not configured for production environment');
    } else {
      logger.info('ℹ️ Sentry not configured for development environment');
    }
    return;
  }

  const sentryConfig: SentryConfig = {
    dsn: config.monitoring.sentryDsn,
    environment: config.nodeEnv,
    release: process.env.npm_package_version || '1.0.0',
    
    // Performance monitoring
    tracesSampleRate: config.isProduction ? 0.1 : 1.0, // 10% in production, 100% in dev
    profilesSampleRate: config.isProduction ? 0.1 : 1.0,
    
    // Filter sensitive data before sending to Sentry
    beforeSend: (event: Sentry.Event) => {
      // Remove sensitive information
      if (event.request?.headers) {
        delete event.request.headers.authorization;
        delete event.request.headers.cookie;
        delete event.request.headers['x-api-key'];
      }
      
      // Filter out operational errors in production
      if (config.isProduction && event.exception) {
        const error = event.exception.values?.[0];
        if (error?.type === 'AppError' && error.value?.includes('404')) {
          return null; // Don't send 404 errors to Sentry in production
        }
      }
      
      return event;
    },
    
    beforeSendTransaction: (event: Sentry.Transaction) => {
      // Filter out health check transactions
      if (event.transaction?.includes('/health') || event.transaction?.includes('/ping')) {
        return null;
      }
      return event;
    }
  };

  Sentry.init({
    ...sentryConfig,
    integrations: [
      // Default integrations
      new Sentry.Integrations.Http({ tracing: true }),
      new Sentry.Integrations.Express({ app: undefined }), // Will be set later
      new Sentry.Integrations.Prisma({ client: undefined }), // Will be set later
      
      // Performance profiling
      new ProfilingIntegration(),
      
      // Custom integrations for mental health app
      new Sentry.Integrations.OnUncaughtException({
        exitEvenIfOtherHandlersAreRegistered: false,
      }),
      new Sentry.Integrations.OnUnhandledRejection({
        mode: 'warn',
      }),
    ],
    
    // Additional configuration for mental health app
    attachStacktrace: true,
    sendDefaultPii: false, // Important for HIPAA compliance
    maxBreadcrumbs: 50,
    
    // Custom tags for better error categorization
    initialScope: {
      tags: {
        component: 'backend',
        service: 'urgood-api',
        version: process.env.npm_package_version || '1.0.0',
      },
      contexts: {
        app: {
          name: 'UrGood Backend',
          version: process.env.npm_package_version || '1.0.0',
        },
        runtime: {
          name: 'node',
          version: process.version,
        },
      },
    },
  });

  logger.info('✅ Sentry initialized successfully', {
    environment: config.nodeEnv,
    tracesSampleRate: sentryConfig.tracesSampleRate,
    profilesSampleRate: sentryConfig.profilesSampleRate,
  });
}

// Enhanced error capture with context
export function captureError(error: Error, context?: {
  user?: { id: string; email?: string };
  request?: { path: string; method: string; body?: any };
  extra?: Record<string, any>;
  tags?: Record<string, string>;
  level?: Sentry.SeverityLevel;
}): string {
  return Sentry.withScope((scope: Sentry.Scope) => {
    // Set user context (sanitized for HIPAA compliance)
    if (context?.user) {
      scope.setUser({
        id: context.user.id,
        // Don't include email in production for privacy
        ...(config.isDevelopment && context.user.email && { email: context.user.email }),
      });
    }

    // Set request context
    if (context?.request) {
      scope.setContext('request', {
        path: context.request.path,
        method: context.request.method,
        // Don't include request body in production for privacy
        ...(config.isDevelopment && context.request.body && { body: context.request.body }),
      });
    }

    // Set additional context
    if (context?.extra) {
      Object.entries(context.extra).forEach(([key, value]) => {
        scope.setExtra(key, value);
      });
    }

    // Set tags
    if (context?.tags) {
      Object.entries(context.tags).forEach(([key, value]) => {
        scope.setTag(key, value);
      });
    }

    // Set severity level
    if (context?.level) {
      scope.setLevel(context.level);
    }

    // Add mental health app specific tags
    scope.setTag('error_category', categorizeError(error));
    scope.setTag('is_operational', isOperationalError(error) ? 'true' : 'false');

    return Sentry.captureException(error);
  });
}

// Capture custom messages with context
export function captureMessage(
  message: string,
  level: Sentry.SeverityLevel = 'info',
  context?: {
    user?: { id: string; email?: string };
    extra?: Record<string, any>;
    tags?: Record<string, string>;
  }
): string {
  return Sentry.withScope((scope: Sentry.Scope) => {
    scope.setLevel(level);

    if (context?.user) {
      scope.setUser({
        id: context.user.id,
        ...(config.isDevelopment && context.user.email && { email: context.user.email }),
      });
    }

    if (context?.extra) {
      Object.entries(context.extra).forEach(([key, value]) => {
        scope.setExtra(key, value);
      });
    }

    if (context?.tags) {
      Object.entries(context.tags).forEach(([key, value]) => {
        scope.setTag(key, value);
      });
    }

    return Sentry.captureMessage(message, level);
  });
}

// Performance monitoring helpers
export function startTransaction(name: string, op: string): Sentry.Transaction {
  return Sentry.startTransaction({
    name,
    op,
    tags: {
      component: 'backend',
      service: 'urgood-api',
    },
  });
}

export function addBreadcrumb(
  message: string,
  category: string = 'default',
  level: Sentry.SeverityLevel = 'info',
  data?: Record<string, any>
): void {
  Sentry.addBreadcrumb({
    message,
    category,
    level,
    data,
    timestamp: Date.now() / 1000,
  });
}

// Mental health app specific error categorization
function categorizeError(error: Error): string {
  const message = error.message.toLowerCase();
  const stack = error.stack?.toLowerCase() || '';

  // Database errors
  if (message.includes('prisma') || message.includes('database') || stack.includes('prisma')) {
    return 'database';
  }

  // Authentication errors
  if (message.includes('unauthorized') || message.includes('token') || message.includes('auth')) {
    return 'authentication';
  }

  // External service errors
  if (message.includes('openai') || message.includes('stripe') || message.includes('firebase')) {
    return 'external_service';
  }

  // Crisis detection errors (high priority)
  if (message.includes('crisis') || message.includes('emergency')) {
    return 'crisis_detection';
  }

  // Voice chat errors
  if (message.includes('voice') || message.includes('audio') || message.includes('elevenlabs')) {
    return 'voice_chat';
  }

  // Validation errors
  if (message.includes('validation') || message.includes('invalid')) {
    return 'validation';
  }

  // Rate limiting
  if (message.includes('rate limit') || message.includes('too many requests')) {
    return 'rate_limiting';
  }

  return 'general';
}

// Check if error is operational (expected) vs programming error
function isOperationalError(error: Error): boolean {
  // Check if it's a known operational error type
  const operationalErrors = [
    'ValidationError',
    'NotFoundError',
    'UnauthorizedError',
    'ForbiddenError',
    'ConflictError',
    'RateLimitError',
  ];

  return operationalErrors.some(errorType => 
    error.constructor.name === errorType || 
    error.name === errorType
  );
}

// Crisis detection specific monitoring
export function captureTherapySessionError(
  error: Error,
  sessionId: string,
  userId: string,
  context?: Record<string, any>
): string {
  return captureError(error, {
    user: { id: userId },
    tags: {
      error_category: 'therapy_session',
      session_id: sessionId,
      priority: 'high',
    },
    extra: {
      sessionId,
      ...context,
    },
    level: 'error',
  });
}

// Voice chat specific monitoring
export function captureVoiceChatError(
  error: Error,
  userId: string,
  voiceProvider: string,
  context?: Record<string, any>
): string {
  return captureError(error, {
    user: { id: userId },
    tags: {
      error_category: 'voice_chat',
      voice_provider: voiceProvider,
      priority: 'medium',
    },
    extra: {
      voiceProvider,
      ...context,
    },
    level: 'warning',
  });
}

// Crisis detection monitoring (highest priority)
export function captureCrisisDetectionEvent(
  message: string,
  userId: string,
  severity: 'low' | 'medium' | 'high' | 'critical',
  context?: Record<string, any>
): string {
  const level: Sentry.SeverityLevel = severity === 'critical' ? 'fatal' : 
                                     severity === 'high' ? 'error' :
                                     severity === 'medium' ? 'warning' : 'info';

  return captureMessage(message, level, {
    user: { id: userId },
    tags: {
      event_type: 'crisis_detection',
      severity,
      priority: 'critical',
    },
    extra: {
      severity,
      ...context,
    },
  });
}

// Performance monitoring for critical operations
export function monitorCriticalOperation<T>(
  operationName: string,
  operation: () => Promise<T>,
  context?: Record<string, any>
): Promise<T> {
  const transaction = startTransaction(operationName, 'critical_operation');
  
  transaction.setData('context', context);
  
  return operation()
    .then((result) => {
      transaction.setStatus('ok');
      return result;
    })
    .catch((error) => {
      transaction.setStatus('internal_error');
      captureError(error, {
        tags: {
          operation: operationName,
          error_category: 'critical_operation',
        },
        ...(context && { extra: context }),
      });
      throw error;
    })
    .finally(() => {
      transaction.finish();
    });
}

// Health check monitoring
export function reportHealthStatus(
  status: 'healthy' | 'degraded' | 'unhealthy',
  services: Record<string, any>
): void {
  if (status !== 'healthy') {
    const level: Sentry.SeverityLevel = status === 'unhealthy' ? 'error' : 'warning';
    
    captureMessage(`System health status: ${status}`, level, {
      tags: {
        event_type: 'health_check',
        health_status: status,
      },
      extra: {
        services,
        timestamp: new Date().toISOString(),
      },
    });
  }
}

// Flush Sentry events (useful for graceful shutdown)
export async function flushSentry(timeout: number = 2000): Promise<boolean> {
  try {
    return await Sentry.flush(timeout);
  } catch (error) {
    logger.error('Failed to flush Sentry events', error);
    return false;
  }
}

// Export Sentry instance for advanced usage
export { Sentry };

export default {
  initializeSentry,
  captureError,
  captureMessage,
  startTransaction,
  addBreadcrumb,
  captureTherapySessionError,
  captureVoiceChatError,
  captureCrisisDetectionEvent,
  monitorCriticalOperation,
  reportHealthStatus,
  flushSentry,
  Sentry,
};
