import { PrismaClient } from '@prisma/client';
import { logger, performanceLogger, errorLogger } from './logger';
import { config } from '../config/config';

// Create Prisma client with logging and error handling
export const prisma = new PrismaClient({
  log: [
    {
      emit: 'event',
      level: 'query',
    },
    {
      emit: 'event',
      level: 'error',
    },
    {
      emit: 'event',
      level: 'info',
    },
    {
      emit: 'event',
      level: 'warn',
    },
  ],
  errorFormat: 'pretty',
});

// Log slow queries
prisma.$on('query', (e) => {
  const duration = e.duration;
  if (duration > 1000) { // Log queries taking more than 1 second
    performanceLogger.logSlowQuery(e.query, duration, e.params);
  }
});

// Log database errors
prisma.$on('error', (e) => {
  errorLogger.logDatabaseError('prisma_error', new Error(e.message));
});

// Log database info
prisma.$on('info', (e) => {
  logger.info('Database info', { message: e.message });
});

// Log database warnings
prisma.$on('warn', (e) => {
  logger.warn('Database warning', { message: e.message });
});

// Database health check
export async function checkDatabaseHealth(): Promise<{ healthy: boolean; latency?: number; error?: string }> {
  try {
    const start = Date.now();
    await prisma.$queryRaw`SELECT 1`;
    const latency = Date.now() - start;
    
    return { healthy: true, latency };
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown database error';
    errorLogger.logDatabaseError('health_check', error instanceof Error ? error : new Error(errorMessage));
    return { healthy: false, error: errorMessage };
  }
}

// Database connection management
export async function connectDatabase(): Promise<void> {
  try {
    await prisma.$connect();
    logger.info('✅ Database connected successfully');
  } catch (error) {
    errorLogger.logDatabaseError('connection', error instanceof Error ? error : new Error('Database connection failed'));
    throw error;
  }
}

export async function disconnectDatabase(): Promise<void> {
  try {
    await prisma.$disconnect();
    logger.info('✅ Database disconnected successfully');
  } catch (error) {
    errorLogger.logDatabaseError('disconnection', error instanceof Error ? error : new Error('Database disconnection failed'));
    throw error;
  }
}

// Transaction helper with retry logic
export async function withTransaction<T>(
  operation: (tx: PrismaClient) => Promise<T>,
  maxRetries: number = 3
): Promise<T> {
  let lastError: Error;
  
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await prisma.$transaction(async (tx) => {
        return await operation(tx as PrismaClient);
      });
    } catch (error) {
      lastError = error instanceof Error ? error : new Error('Transaction failed');
      
      if (attempt === maxRetries) {
        errorLogger.logDatabaseError('transaction_failed', lastError);
        throw lastError;
      }
      
      // Wait before retry (exponential backoff)
      const delay = Math.pow(2, attempt) * 100;
      await new Promise(resolve => setTimeout(resolve, delay));
      
      logger.warn(`Transaction attempt ${attempt} failed, retrying in ${delay}ms`, {
        error: lastError.message,
        attempt,
        maxRetries
      });
    }
  }
  
  throw lastError!;
}

// Batch operations helper
export async function batchOperation<T, R>(
  items: T[],
  operation: (item: T) => Promise<R>,
  batchSize: number = 100
): Promise<R[]> {
  const results: R[] = [];
  
  for (let i = 0; i < items.length; i += batchSize) {
    const batch = items.slice(i, i + batchSize);
    const batchPromises = batch.map(operation);
    
    try {
      const batchResults = await Promise.all(batchPromises);
      results.push(...batchResults);
    } catch (error) {
      errorLogger.logDatabaseError('batch_operation', error instanceof Error ? error : new Error('Batch operation failed'));
      throw error;
    }
  }
  
  return results;
}

// Soft delete helper
export async function softDelete(model: string, id: string): Promise<void> {
  try {
    // @ts-ignore - Dynamic model access
    await prisma[model].update({
      where: { id },
      data: { deletedAt: new Date() }
    });
    
    logger.info(`Soft deleted ${model}`, { id });
  } catch (error) {
    errorLogger.logDatabaseError('soft_delete', error instanceof Error ? error : new Error('Soft delete failed'));
    throw error;
  }
}

// Database cleanup utilities
export async function cleanupExpiredSessions(): Promise<number> {
  try {
    const result = await prisma.session.deleteMany({
      where: {
        expiresAt: {
          lt: new Date()
        }
      }
    });
    
    logger.info(`Cleaned up ${result.count} expired sessions`);
    return result.count;
  } catch (error) {
    errorLogger.logDatabaseError('cleanup_sessions', error instanceof Error ? error : new Error('Session cleanup failed'));
    throw error;
  }
}

export async function cleanupOldAnalytics(daysToKeep: number = 90): Promise<number> {
  try {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - daysToKeep);
    
    const result = await prisma.analyticsEvent.deleteMany({
      where: {
        createdAt: {
          lt: cutoffDate
        }
      }
    });
    
    logger.info(`Cleaned up ${result.count} old analytics events`);
    return result.count;
  } catch (error) {
    errorLogger.logDatabaseError('cleanup_analytics', error instanceof Error ? error : new Error('Analytics cleanup failed'));
    throw error;
  }
}

export async function cleanupOldAuditLogs(daysToKeep: number = 365): Promise<number> {
  try {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - daysToKeep);
    
    const result = await prisma.auditLog.deleteMany({
      where: {
        createdAt: {
          lt: cutoffDate
        }
      }
    });
    
    logger.info(`Cleaned up ${result.count} old audit logs`);
    return result.count;
  } catch (error) {
    errorLogger.logDatabaseError('cleanup_audit_logs', error instanceof Error ? error : new Error('Audit log cleanup failed'));
    throw error;
  }
}

// Database statistics
export async function getDatabaseStats(): Promise<{
  users: number;
  sessions: number;
  chatMessages: number;
  moodEntries: number;
  crisisEvents: number;
  payments: number;
}> {
  try {
    const [users, sessions, chatMessages, moodEntries, crisisEvents, payments] = await Promise.all([
      prisma.user.count(),
      prisma.session.count(),
      prisma.chatMessage.count(),
      prisma.moodEntry.count(),
      prisma.crisisEvent.count(),
      prisma.payment.count()
    ]);
    
    return {
      users,
      sessions,
      chatMessages,
      moodEntries,
      crisisEvents,
      payments
    };
  } catch (error) {
    errorLogger.logDatabaseError('get_stats', error instanceof Error ? error : new Error('Failed to get database stats'));
    throw error;
  }
}

// Initialize database connection on import
if (config.nodeEnv !== 'test') {
  connectDatabase().catch((error) => {
    logger.error('Failed to connect to database on startup', error);
    process.exit(1);
  });
}
