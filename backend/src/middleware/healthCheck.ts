import { Request, Response } from 'express';
import { checkDatabaseHealth } from '../utils/database';
import { checkRedisHealth } from '../utils/redis';
import { logger } from '../utils/logger';
import { config } from '../config/config';

// Health check status interface
interface HealthStatus {
  status: 'healthy' | 'degraded' | 'unhealthy';
  timestamp: string;
  uptime: number;
  version: string;
  environment: string;
  services: {
    database: ServiceHealth;
    redis: ServiceHealth;
    memory: ServiceHealth;
    cpu: ServiceHealth;
  };
  metrics: {
    memoryUsage: NodeJS.MemoryUsage;
    cpuUsage: number;
    loadAverage: number[];
  };
}

interface ServiceHealth {
  status: 'healthy' | 'degraded' | 'unhealthy';
  latency?: number;
  error?: string;
  lastCheck: string;
}

// Cache health check results to avoid overwhelming services
let lastHealthCheck: HealthStatus | null = null;
let lastHealthCheckTime = 0;
const HEALTH_CHECK_CACHE_TTL = 30000; // 30 seconds

// Get CPU usage percentage
function getCPUUsage(): Promise<number> {
  return new Promise((resolve) => {
    const startUsage = process.cpuUsage();
    const startTime = process.hrtime();
    
    setTimeout(() => {
      const currentUsage = process.cpuUsage(startUsage);
      const currentTime = process.hrtime(startTime);
      
      const totalTime = currentTime[0] * 1000000 + currentTime[1] / 1000; // microseconds
      const totalCPU = currentUsage.user + currentUsage.system;
      const cpuPercent = (totalCPU / totalTime) * 100;
      
      resolve(Math.min(100, Math.max(0, cpuPercent)));
    }, 100);
  });
}

// Check memory health
function checkMemoryHealth(): ServiceHealth {
  const memUsage = process.memoryUsage();
  const totalMemory = memUsage.heapTotal;
  const usedMemory = memUsage.heapUsed;
  const memoryUsagePercent = (usedMemory / totalMemory) * 100;
  
  let status: 'healthy' | 'degraded' | 'unhealthy' = 'healthy';
  
  if (memoryUsagePercent > 90) {
    status = 'unhealthy';
  } else if (memoryUsagePercent > 75) {
    status = 'degraded';
  }
  
  return {
    status,
    lastCheck: new Date().toISOString()
  };
}

// Check CPU health
async function checkCPUHealth(): Promise<ServiceHealth> {
  const cpuUsage = await getCPUUsage();
  
  let status: 'healthy' | 'degraded' | 'unhealthy' = 'healthy';
  
  if (cpuUsage > 90) {
    status = 'unhealthy';
  } else if (cpuUsage > 75) {
    status = 'degraded';
  }
  
  return {
    status,
    lastCheck: new Date().toISOString()
  };
}

// Perform comprehensive health check
async function performHealthCheck(): Promise<HealthStatus> {
  const now = Date.now();
  
  // Return cached result if still valid
  if (lastHealthCheck && (now - lastHealthCheckTime) < HEALTH_CHECK_CACHE_TTL) {
    return lastHealthCheck;
  }
  
  try {
    // Check all services in parallel
    const [databaseHealth, redisHealth, memoryHealth, cpuHealth] = await Promise.all([
      checkDatabaseHealth(),
      checkRedisHealth(),
      Promise.resolve(checkMemoryHealth()),
      checkCPUHealth()
    ]);
    
    // Get system metrics
    const memoryUsage = process.memoryUsage();
    const cpuUsage = await getCPUUsage();
    const loadAverage = require('os').loadavg();
    
    // Map service health results
    const services = {
      database: {
        status: databaseHealth.healthy ? 'healthy' : 'unhealthy',
        latency: databaseHealth.latency,
        error: databaseHealth.error,
        lastCheck: new Date().toISOString()
      } as ServiceHealth,
      
      redis: {
        status: redisHealth.healthy ? 'healthy' : 'degraded', // Redis is not critical
        latency: redisHealth.latency,
        error: redisHealth.error,
        lastCheck: new Date().toISOString()
      } as ServiceHealth,
      
      memory: memoryHealth,
      cpu: cpuHealth
    };
    
    // Determine overall status
    let overallStatus: 'healthy' | 'degraded' | 'unhealthy' = 'healthy';
    
    // Critical services (database) must be healthy
    if (services.database.status === 'unhealthy') {
      overallStatus = 'unhealthy';
    }
    // If any service is degraded or unhealthy, overall is degraded
    else if (Object.values(services).some(service => service.status !== 'healthy')) {
      overallStatus = 'degraded';
    }
    
    const healthStatus: HealthStatus = {
      status: overallStatus,
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      version: process.env.npm_package_version || '1.0.0',
      environment: config.nodeEnv,
      services,
      metrics: {
        memoryUsage,
        cpuUsage,
        loadAverage
      }
    };
    
    // Cache the result
    lastHealthCheck = healthStatus;
    lastHealthCheckTime = now;
    
    return healthStatus;
    
  } catch (error) {
    logger.error('Health check failed', error);
    
    const errorHealthStatus: HealthStatus = {
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      version: process.env.npm_package_version || '1.0.0',
      environment: config.nodeEnv,
      services: {
        database: { status: 'unhealthy', error: 'Health check failed', lastCheck: new Date().toISOString() },
        redis: { status: 'unhealthy', error: 'Health check failed', lastCheck: new Date().toISOString() },
        memory: { status: 'unhealthy', error: 'Health check failed', lastCheck: new Date().toISOString() },
        cpu: { status: 'unhealthy', error: 'Health check failed', lastCheck: new Date().toISOString() }
      },
      metrics: {
        memoryUsage: process.memoryUsage(),
        cpuUsage: 0,
        loadAverage: [0, 0, 0]
      }
    };
    
    return errorHealthStatus;
  }
}

// Health check endpoint handler
export async function healthCheck(req: Request, res: Response): Promise<void> {
  try {
    const healthStatus = await performHealthCheck();
    
    // Set appropriate HTTP status code
    let statusCode = 200;
    if (healthStatus.status === 'degraded') {
      statusCode = 200; // Still operational
    } else if (healthStatus.status === 'unhealthy') {
      statusCode = 503; // Service unavailable
    }
    
    // Add cache headers
    res.set({
      'Cache-Control': 'no-cache, no-store, must-revalidate',
      'Pragma': 'no-cache',
      'Expires': '0'
    });
    
    res.status(statusCode).json(healthStatus);
    
  } catch (error) {
    logger.error('Health check endpoint error', error);
    
    res.status(500).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: 'Health check failed'
    });
  }
}

// Readiness check (for Kubernetes)
export async function readinessCheck(req: Request, res: Response): Promise<void> {
  try {
    const databaseHealth = await checkDatabaseHealth();
    
    if (databaseHealth.healthy) {
      res.status(200).json({
        status: 'ready',
        timestamp: new Date().toISOString()
      });
    } else {
      res.status(503).json({
        status: 'not ready',
        timestamp: new Date().toISOString(),
        error: databaseHealth.error
      });
    }
    
  } catch (error) {
    logger.error('Readiness check error', error);
    
    res.status(503).json({
      status: 'not ready',
      timestamp: new Date().toISOString(),
      error: 'Readiness check failed'
    });
  }
}

// Liveness check (for Kubernetes)
export async function livenessCheck(req: Request, res: Response): Promise<void> {
  // Simple liveness check - if the process is running, it's alive
  res.status(200).json({
    status: 'alive',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
}

// Startup check (for Kubernetes)
export async function startupCheck(req: Request, res: Response): Promise<void> {
  try {
    // Check if all critical services are initialized
    const databaseHealth = await checkDatabaseHealth();
    
    if (databaseHealth.healthy) {
      res.status(200).json({
        status: 'started',
        timestamp: new Date().toISOString()
      });
    } else {
      res.status(503).json({
        status: 'starting',
        timestamp: new Date().toISOString(),
        error: databaseHealth.error
      });
    }
    
  } catch (error) {
    logger.error('Startup check error', error);
    
    res.status(503).json({
      status: 'starting',
      timestamp: new Date().toISOString(),
      error: 'Startup check failed'
    });
  }
}

// Detailed health check for monitoring systems
export async function detailedHealthCheck(req: Request, res: Response): Promise<void> {
  try {
    const healthStatus = await performHealthCheck();
    
    // Add additional system information
    const detailedHealth = {
      ...healthStatus,
      system: {
        platform: process.platform,
        arch: process.arch,
        nodeVersion: process.version,
        pid: process.pid,
        ppid: process.ppid
      },
      dependencies: {
        // Add version information for critical dependencies
        prisma: require('@prisma/client/package.json').version,
        redis: require('ioredis/package.json').version,
        express: require('express/package.json').version
      }
    };
    
    let statusCode = 200;
    if (healthStatus.status === 'unhealthy') {
      statusCode = 503;
    }
    
    res.status(statusCode).json(detailedHealth);
    
  } catch (error) {
    logger.error('Detailed health check error', error);
    
    res.status(500).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: 'Detailed health check failed'
    });
  }
}

// Periodic health monitoring
export function startHealthMonitoring(): void {
  const interval = config.healthCheck.interval;
  
  setInterval(async () => {
    try {
      const healthStatus = await performHealthCheck();
      
      if (healthStatus.status === 'unhealthy') {
        logger.error('System health check failed', {
          status: healthStatus.status,
          services: healthStatus.services
        });
      } else if (healthStatus.status === 'degraded') {
        logger.warn('System health degraded', {
          status: healthStatus.status,
          services: healthStatus.services
        });
      }
      
    } catch (error) {
      logger.error('Health monitoring error', error);
    }
  }, interval);
  
  logger.info(`Health monitoring started with ${interval}ms interval`);
}

// Load balancer health check (simple and fast)
export async function loadBalancerHealthCheck(req: Request, res: Response): Promise<void> {
  // Ultra-fast health check for load balancers
  // Only checks if the process is running and can respond
  res.status(200).json({
    status: 'ok',
    timestamp: Date.now()
  });
}

// Deep health check with all services
export async function deepHealthCheck(req: Request, res: Response): Promise<void> {
  try {
    const healthStatus = await performHealthCheck();
    
    // Add additional checks for deep monitoring
    const deepHealth = {
      ...healthStatus,
      checks: {
        database: await checkDatabaseHealth(),
        redis: await checkRedisHealth(),
        diskSpace: await checkDiskSpace(),
        networkConnectivity: await checkNetworkConnectivity()
      },
      performance: {
        responseTime: Date.now(),
        memoryPressure: getMemoryPressure(),
        eventLoopLag: getEventLoopLag()
      }
    };
    
    let statusCode = 200;
    if (healthStatus.status === 'unhealthy') {
      statusCode = 503;
    } else if (healthStatus.status === 'degraded') {
      statusCode = 200; // Still serving traffic
    }
    
    res.status(statusCode).json(deepHealth);
    
  } catch (error) {
    logger.error('Deep health check error', error);
    
    res.status(500).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: 'Deep health check failed'
    });
  }
}

// Metrics endpoint for monitoring systems
export async function metricsEndpoint(req: Request, res: Response): Promise<void> {
  try {
    const memUsage = process.memoryUsage();
    const cpuUsage = await getCPUUsage();
    const uptime = process.uptime();
    
    // Prometheus-style metrics
    const metrics = [
      `# HELP urgood_uptime_seconds Total uptime in seconds`,
      `# TYPE urgood_uptime_seconds counter`,
      `urgood_uptime_seconds ${uptime}`,
      ``,
      `# HELP urgood_memory_usage_bytes Memory usage in bytes`,
      `# TYPE urgood_memory_usage_bytes gauge`,
      `urgood_memory_usage_bytes{type="rss"} ${memUsage.rss}`,
      `urgood_memory_usage_bytes{type="heapTotal"} ${memUsage.heapTotal}`,
      `urgood_memory_usage_bytes{type="heapUsed"} ${memUsage.heapUsed}`,
      `urgood_memory_usage_bytes{type="external"} ${memUsage.external}`,
      ``,
      `# HELP urgood_cpu_usage_percent CPU usage percentage`,
      `# TYPE urgood_cpu_usage_percent gauge`,
      `urgood_cpu_usage_percent ${cpuUsage}`,
      ``,
      `# HELP urgood_nodejs_version Node.js version info`,
      `# TYPE urgood_nodejs_version info`,
      `urgood_nodejs_version{version="${process.version}"} 1`,
      ``
    ].join('\n');
    
    res.set('Content-Type', 'text/plain; version=0.0.4; charset=utf-8');
    res.status(200).send(metrics);
    
  } catch (error) {
    logger.error('Metrics endpoint error', error);
    res.status(500).send('# Error generating metrics\n');
  }
}

// Status page endpoint
export async function statusPageEndpoint(req: Request, res: Response): Promise<void> {
  try {
    const healthStatus = await performHealthCheck();
    
    // Generate HTML status page
    const html = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>UrGood System Status</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; border-radius: 8px; padding: 30px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .status { padding: 15px; border-radius: 6px; margin: 10px 0; font-weight: 500; }
        .healthy { background: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
        .degraded { background: #fff3cd; color: #856404; border: 1px solid #ffeaa7; }
        .unhealthy { background: #f8d7da; color: #721c24; border: 1px solid #f5c6cb; }
        .metric { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #eee; }
        .service-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin: 20px 0; }
        .service-card { padding: 15px; border: 1px solid #ddd; border-radius: 6px; }
        h1 { color: #333; margin-bottom: 30px; }
        h2 { color: #555; margin-top: 30px; }
        .timestamp { color: #666; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎯 UrGood System Status</h1>
        
        <div class="status ${healthStatus.status}">
            Overall Status: ${healthStatus.status.toUpperCase()}
        </div>
        
        <div class="timestamp">
            Last Updated: ${healthStatus.timestamp}<br>
            Uptime: ${Math.floor(healthStatus.uptime / 3600)}h ${Math.floor((healthStatus.uptime % 3600) / 60)}m
        </div>
        
        <h2>Services</h2>
        <div class="service-grid">
            ${Object.entries(healthStatus.services).map(([name, service]) => `
                <div class="service-card">
                    <h3>${name.charAt(0).toUpperCase() + name.slice(1)}</h3>
                    <div class="status ${service.status}">${service.status.toUpperCase()}</div>
                    ${service.latency ? `<div>Latency: ${service.latency}ms</div>` : ''}
                    ${service.error ? `<div style="color: #d32f2f; font-size: 0.9em;">${service.error}</div>` : ''}
                </div>
            `).join('')}
        </div>
        
        <h2>System Metrics</h2>
        <div class="metric"><span>Memory Usage</span><span>${Math.round(healthStatus.metrics.memoryUsage.heapUsed / 1024 / 1024)} MB</span></div>
        <div class="metric"><span>CPU Usage</span><span>${healthStatus.metrics.cpuUsage.toFixed(1)}%</span></div>
        <div class="metric"><span>Load Average</span><span>${healthStatus.metrics.loadAverage.map(l => l.toFixed(2)).join(', ')}</span></div>
        <div class="metric"><span>Environment</span><span>${healthStatus.environment}</span></div>
        <div class="metric"><span>Version</span><span>${healthStatus.version}</span></div>
        
        <script>
            // Auto-refresh every 30 seconds
            setTimeout(() => window.location.reload(), 30000);
        </script>
    </div>
</body>
</html>`;
    
    res.set('Content-Type', 'text/html');
    res.status(200).send(html);
    
  } catch (error) {
    logger.error('Status page error', error);
    res.status(500).send('<h1>Error loading status page</h1>');
  }
}

// Helper functions for additional checks
async function checkDiskSpace(): Promise<{ available: number; used: number; total: number }> {
  try {
    const fs = require('fs').promises;
    const stats = await fs.statfs('.');
    
    return {
      available: stats.bavail * stats.bsize,
      used: (stats.blocks - stats.bavail) * stats.bsize,
      total: stats.blocks * stats.bsize
    };
  } catch {
    return { available: 0, used: 0, total: 0 };
  }
}

async function checkNetworkConnectivity(): Promise<{ external: boolean; dns: boolean }> {
  try {
    const dns = require('dns').promises;
    
    // Check DNS resolution
    const dnsCheck = await dns.lookup('google.com').then(() => true).catch(() => false);
    
    // Check external connectivity (simplified)
    const externalCheck = dnsCheck; // In a real implementation, you might ping an external service
    
    return {
      external: externalCheck,
      dns: dnsCheck
    };
  } catch {
    return { external: false, dns: false };
  }
}

function getMemoryPressure(): number {
  const memUsage = process.memoryUsage();
  return (memUsage.heapUsed / memUsage.heapTotal) * 100;
}

function getEventLoopLag(): number {
  // Simplified event loop lag measurement
  const start = process.hrtime.bigint();
  setImmediate(() => {
    const lag = Number(process.hrtime.bigint() - start) / 1000000; // Convert to ms
    return lag;
  });
  return 0; // Placeholder - real implementation would use async measurement
}

export default {
  healthCheck,
  readinessCheck,
  livenessCheck,
  startupCheck,
  detailedHealthCheck,
  loadBalancerHealthCheck,
  deepHealthCheck,
  metricsEndpoint,
  statusPageEndpoint,
  startHealthMonitoring
};
