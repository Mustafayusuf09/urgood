import Redis, { Cluster } from 'ioredis';
import { config } from '../config/config';
import { logger, errorLogger } from './logger';

// Redis connection configuration
const redisConfig = {
  maxRetriesPerRequest: 3,
  lazyConnect: true,
  keepAlive: 30000,
  connectTimeout: 10000,
  commandTimeout: 5000,
  retryDelayOnFailover: 100,
  enableReadyCheck: true,
  // Connection pool settings
  family: 4,
  db: 0,
  // Reconnection settings
  reconnectOnError: (err: Error) => {
    const targetError = 'READONLY';
    return err.message.includes(targetError);
  },
};

// Determine if we're using cluster mode
const isClusterMode = process.env.REDIS_CLUSTER_ENABLED === 'true';
const clusterNodes = process.env.REDIS_CLUSTER_NODES?.split(',') || [];

// Create Redis client (cluster or single instance)
export const redis: Redis | Cluster = isClusterMode && clusterNodes.length > 0
  ? new Cluster(clusterNodes.map(node => {
      const [host, port] = node.split(':');
      return { host: host || 'localhost', port: parseInt(port) || 6379 };
    }), {
      redisOptions: {
        ...redisConfig,
        ...(process.env.REDIS_PASSWORD && { password: process.env.REDIS_PASSWORD }),
      },
      enableOfflineQueue: false,
      slotsRefreshTimeout: 10000,
      slotsRefreshInterval: 5000,
    })
  : new Redis(config.redis.url, redisConfig);

// Redis event handlers
redis.on('connect', () => {
  logger.info('✅ Redis connected successfully');
});

redis.on('ready', () => {
  logger.info('✅ Redis ready for operations');
});

redis.on('error', (error) => {
  errorLogger.logExternalServiceError('redis', error);
});

redis.on('close', () => {
  logger.warn('⚠️ Redis connection closed');
});

redis.on('reconnecting', () => {
  logger.info('🔄 Redis reconnecting...');
});

// This function is now defined later in the file with cluster support

// Cache utilities
export class CacheService {
  private static instance: CacheService;
  
  public static getInstance(): CacheService {
    if (!CacheService.instance) {
      CacheService.instance = new CacheService();
    }
    return CacheService.instance;
  }
  
  // Set cache with TTL
  async set(key: string, value: any, ttlSeconds: number = 3600): Promise<void> {
    try {
      const serializedValue = JSON.stringify(value);
      await redis.setex(key, ttlSeconds, serializedValue);
    } catch (error) {
      errorLogger.logExternalServiceError('redis', error instanceof Error ? error : new Error('Cache set failed'));
      throw error;
    }
  }
  
  // Get cache value
  async get<T>(key: string): Promise<T | null> {
    try {
      const value = await redis.get(key);
      if (!value) return null;
      
      return JSON.parse(value) as T;
    } catch (error) {
      errorLogger.logExternalServiceError('redis', error instanceof Error ? error : new Error('Cache get failed'));
      return null; // Return null on error to allow fallback
    }
  }
  
  // Delete cache key
  async delete(key: string): Promise<void> {
    try {
      await redis.del(key);
    } catch (error) {
      errorLogger.logExternalServiceError('redis', error instanceof Error ? error : new Error('Cache delete failed'));
      throw error;
    }
  }
  
  // Check if key exists
  async exists(key: string): Promise<boolean> {
    try {
      const result = await redis.exists(key);
      return result === 1;
    } catch (error) {
      errorLogger.logExternalServiceError('redis', error instanceof Error ? error : new Error('Cache exists check failed'));
      return false;
    }
  }
  
  // Set TTL for existing key
  async expire(key: string, ttlSeconds: number): Promise<void> {
    try {
      await redis.expire(key, ttlSeconds);
    } catch (error) {
      errorLogger.logExternalServiceError('redis', error instanceof Error ? error : new Error('Cache expire failed'));
      throw error;
    }
  }
  
  // Get TTL for key
  async getTTL(key: string): Promise<number> {
    try {
      return await redis.ttl(key);
    } catch (error) {
      errorLogger.logExternalServiceError('redis', error instanceof Error ? error : new Error('Cache TTL check failed'));
      return -1;
    }
  }
  
  // Increment counter
  async increment(key: string, by: number = 1): Promise<number> {
    try {
      return await redis.incrby(key, by);
    } catch (error) {
      errorLogger.logExternalServiceError('redis', error instanceof Error ? error : new Error('Cache increment failed'));
      throw error;
    }
  }
  
  // Add to set
  async addToSet(key: string, ...values: string[]): Promise<number> {
    try {
      return await redis.sadd(key, ...values);
    } catch (error) {
      errorLogger.logExternalServiceError('redis', error instanceof Error ? error : new Error('Cache set add failed'));
      throw error;
    }
  }
  
  // Check if member exists in set
  async isInSet(key: string, value: string): Promise<boolean> {
    try {
      const result = await redis.sismember(key, value);
      return result === 1;
    } catch (error) {
      errorLogger.logExternalServiceError('redis', error instanceof Error ? error : new Error('Cache set check failed'));
      return false;
    }
  }
  
  // Get all members of set
  async getSetMembers(key: string): Promise<string[]> {
    try {
      return await redis.smembers(key);
    } catch (error) {
      errorLogger.logExternalServiceError('redis', error instanceof Error ? error : new Error('Cache set members failed'));
      return [];
    }
  }
  
  // Push to list
  async pushToList(key: string, ...values: string[]): Promise<number> {
    try {
      return await redis.lpush(key, ...values);
    } catch (error) {
      errorLogger.logExternalServiceError('redis', error instanceof Error ? error : new Error('Cache list push failed'));
      throw error;
    }
  }
  
  // Get list range
  async getListRange(key: string, start: number = 0, end: number = -1): Promise<string[]> {
    try {
      return await redis.lrange(key, start, end);
    } catch (error) {
      errorLogger.logExternalServiceError('redis', error instanceof Error ? error : new Error('Cache list range failed'));
      return [];
    }
  }
  
  // Clear all cache (use with caution)
  async clear(): Promise<void> {
    try {
      await redis.flushdb();
      logger.warn('🗑️ Redis cache cleared');
    } catch (error) {
      errorLogger.logExternalServiceError('redis', error instanceof Error ? error : new Error('Cache clear failed'));
      throw error;
    }
  }
}

// Rate limiting utilities
export class RateLimitService {
  private static instance: RateLimitService;
  
  public static getInstance(): RateLimitService {
    if (!RateLimitService.instance) {
      RateLimitService.instance = new RateLimitService();
    }
    return RateLimitService.instance;
  }
  
  // Check and increment rate limit
  async checkRateLimit(
    identifier: string,
    windowSeconds: number,
    maxRequests: number
  ): Promise<{ allowed: boolean; remaining: number; resetTime: number }> {
    try {
      const key = `rate_limit:${identifier}`;
      const now = Math.floor(Date.now() / 1000);
      const windowStart = now - windowSeconds;
      
      // Use Redis pipeline for atomic operations
      const pipeline = redis.pipeline();
      
      // Remove old entries
      pipeline.zremrangebyscore(key, '-inf', windowStart);
      
      // Count current requests
      pipeline.zcard(key);
      
      // Add current request
      pipeline.zadd(key, now, `${now}-${Math.random()}`);
      
      // Set expiration
      pipeline.expire(key, windowSeconds);
      
      const results = await pipeline.exec();
      
      if (!results) {
        throw new Error('Redis pipeline failed');
      }
      
      const currentCount = (results[1]?.[1] as number) || 0;
      const allowed = currentCount < maxRequests;
      const remaining = Math.max(0, maxRequests - currentCount - 1);
      const resetTime = now + windowSeconds;
      
      return { allowed, remaining, resetTime };
    } catch (error) {
      errorLogger.logExternalServiceError('redis', error instanceof Error ? error : new Error('Rate limit check failed'));
      // On error, allow the request but log the issue
      return { allowed: true, remaining: maxRequests - 1, resetTime: Math.floor(Date.now() / 1000) + windowSeconds };
    }
  }
  
  // Get current rate limit status
  async getRateLimitStatus(
    identifier: string,
    windowSeconds: number,
    maxRequests: number
  ): Promise<{ count: number; remaining: number; resetTime: number }> {
    try {
      const key = `rate_limit:${identifier}`;
      const now = Math.floor(Date.now() / 1000);
      const windowStart = now - windowSeconds;
      
      // Clean old entries and count current
      await redis.zremrangebyscore(key, '-inf', windowStart);
      const count = await redis.zcard(key);
      
      const remaining = Math.max(0, maxRequests - count);
      const resetTime = now + windowSeconds;
      
      return { count, remaining, resetTime };
    } catch (error) {
      errorLogger.logExternalServiceError('redis', error instanceof Error ? error : new Error('Rate limit status check failed'));
      return { count: 0, remaining: maxRequests, resetTime: Math.floor(Date.now() / 1000) + windowSeconds };
    }
  }
}

// Session management utilities
export class SessionService {
  private static instance: SessionService;
  
  public static getInstance(): SessionService {
    if (!SessionService.instance) {
      SessionService.instance = new SessionService();
    }
    return SessionService.instance;
  }
  
  // Store session data
  async storeSession(sessionId: string, data: any, ttlSeconds: number = 86400): Promise<void> {
    try {
      const key = `session:${sessionId}`;
      await redis.setex(key, ttlSeconds, JSON.stringify(data));
    } catch (error) {
      errorLogger.logExternalServiceError('redis', error instanceof Error ? error : new Error('Session store failed'));
      throw error;
    }
  }
  
  // Get session data
  async getSession(sessionId: string): Promise<any | null> {
    try {
      const key = `session:${sessionId}`;
      const data = await redis.get(key);
      return data ? JSON.parse(data) : null;
    } catch (error) {
      errorLogger.logExternalServiceError('redis', error instanceof Error ? error : new Error('Session get failed'));
      return null;
    }
  }
  
  // Delete session
  async deleteSession(sessionId: string): Promise<void> {
    try {
      const key = `session:${sessionId}`;
      await redis.del(key);
    } catch (error) {
      errorLogger.logExternalServiceError('redis', error instanceof Error ? error : new Error('Session delete failed'));
      throw error;
    }
  }
  
  // Extend session TTL
  async extendSession(sessionId: string, ttlSeconds: number = 86400): Promise<void> {
    try {
      const key = `session:${sessionId}`;
      await redis.expire(key, ttlSeconds);
    } catch (error) {
      errorLogger.logExternalServiceError('redis', error instanceof Error ? error : new Error('Session extend failed'));
      throw error;
    }
  }
}

// Export service instances
export const cacheService = CacheService.getInstance();
export const rateLimitService = RateLimitService.getInstance();
export const sessionService = SessionService.getInstance();

// Enhanced Redis connection management
export class RedisConnectionManager {
  private static instance: RedisConnectionManager;
  private isConnected = false;
  private connectionAttempts = 0;
  private maxConnectionAttempts = 5;
  
  public static getInstance(): RedisConnectionManager {
    if (!RedisConnectionManager.instance) {
      RedisConnectionManager.instance = new RedisConnectionManager();
    }
    return RedisConnectionManager.instance;
  }
  
  async connect(): Promise<void> {
    if (this.isConnected) return;
    
    try {
      this.connectionAttempts++;
      
      if (isClusterMode) {
        logger.info('🔗 Connecting to Redis Cluster...');
      } else {
        logger.info('🔗 Connecting to Redis instance...');
      }
      
      await redis.connect();
      this.isConnected = true;
      this.connectionAttempts = 0;
      
      logger.info(`✅ Redis connected successfully (${isClusterMode ? 'cluster' : 'single'} mode)`);
    } catch (error) {
      logger.error(`❌ Redis connection attempt ${this.connectionAttempts} failed:`, error);
      
      if (this.connectionAttempts < this.maxConnectionAttempts) {
        const delay = Math.pow(2, this.connectionAttempts) * 1000; // Exponential backoff
        logger.info(`🔄 Retrying Redis connection in ${delay}ms...`);
        
        setTimeout(() => {
          this.connect().catch(() => {
            // Error already logged above
          });
        }, delay);
      } else {
        logger.error('💥 Max Redis connection attempts reached. App will run without cache.');
      }
    }
  }
  
  async disconnect(): Promise<void> {
    if (!this.isConnected) return;
    
    try {
      await redis.disconnect();
      this.isConnected = false;
      logger.info('✅ Redis disconnected successfully');
    } catch (error) {
      logger.error('❌ Redis disconnection failed:', error);
    }
  }
  
  getConnectionStatus(): { connected: boolean; mode: string; attempts: number } {
    return {
      connected: this.isConnected,
      mode: isClusterMode ? 'cluster' : 'single',
      attempts: this.connectionAttempts
    };
  }
}

// Export connection manager instance
export const redisConnectionManager = RedisConnectionManager.getInstance();

// Enhanced Redis health check with cluster support
export async function checkRedisHealth(): Promise<{ 
  healthy: boolean; 
  latency?: number; 
  error?: string;
  mode: string;
  clusterInfo?: any;
}> {
  try {
    const start = Date.now();
    await redis.ping();
    const latency = Date.now() - start;
    
    let clusterInfo = undefined;
    if (isClusterMode && redis instanceof Cluster) {
      try {
        clusterInfo = {
          nodes: redis.nodes('all').length,
          masters: redis.nodes('master').length,
          slaves: redis.nodes('slave').length,
        };
      } catch (clusterError) {
        logger.warn('Could not get cluster info:', clusterError);
      }
    }
    
    return { 
      healthy: true, 
      latency, 
      mode: isClusterMode ? 'cluster' : 'single',
      clusterInfo 
    };
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown Redis error';
    return { 
      healthy: false, 
      error: errorMessage,
      mode: isClusterMode ? 'cluster' : 'single'
    };
  }
}

// Initialize Redis connection
if (config.nodeEnv !== 'test') {
  redisConnectionManager.connect().catch((error) => {
    logger.error('Failed to initialize Redis connection manager', error);
  });
}

// Graceful shutdown handler
process.on('SIGTERM', async () => {
  logger.info('🛑 SIGTERM received, closing Redis connection...');
  await redisConnectionManager.disconnect();
});

process.on('SIGINT', async () => {
  logger.info('🛑 SIGINT received, closing Redis connection...');
  await redisConnectionManager.disconnect();
});
