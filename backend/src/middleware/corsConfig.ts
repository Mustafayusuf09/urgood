import { CorsOptions } from 'cors';
import { config } from '../config/config';
import { logger } from '../utils/logger';
import { captureMessage } from '../utils/sentry';

// Production domains for UrGood
const PRODUCTION_DOMAINS = [
  'https://urgood.app',
  'https://www.urgood.app',
  'https://api.urgood.app',
  'https://admin.urgood.app',
  'https://dashboard.urgood.app'
];

// Development domains
const DEVELOPMENT_DOMAINS = [
  'http://localhost:3000',
  'http://localhost:3001',
  'http://localhost:5173',
  'http://localhost:8080',
  'http://127.0.0.1:3000',
  'http://127.0.0.1:3001',
  'http://127.0.0.1:5173',
  'http://127.0.0.1:8080'
];

// Mobile app schemes
const MOBILE_SCHEMES = [
  'urgood://',
  'com.urgood.urgood://'
];

// Get allowed origins based on environment
function getAllowedOrigins(): string[] {
  const origins: string[] = [];

  if (config.isProduction) {
    // Production: Only allow production domains
    origins.push(...PRODUCTION_DOMAINS);
    
    // Add any custom production origins from environment
    const customOrigins = process.env.CORS_ALLOWED_ORIGINS?.split(',') || [];
    origins.push(...customOrigins.filter(origin => origin.trim()));
    
    logger.info('CORS configured for production', { 
      allowedOrigins: origins.length,
      domains: origins 
    });
  } else {
    // Development: Allow development domains + production for testing
    origins.push(...DEVELOPMENT_DOMAINS);
    origins.push(...PRODUCTION_DOMAINS);
    
    // Add any custom development origins
    const customOrigins = process.env.CORS_ALLOWED_ORIGINS?.split(',') || [];
    origins.push(...customOrigins.filter(origin => origin.trim()));
    
    logger.info('CORS configured for development', { 
      allowedOrigins: origins.length 
    });
  }

  // Always allow mobile app schemes
  origins.push(...MOBILE_SCHEMES);

  return origins;
}

// Dynamic origin validation
function validateOrigin(origin: string | undefined, callback: (err: Error | null, allow?: boolean) => void) {
  // Allow requests with no origin (mobile apps, Postman, etc.)
  if (!origin) {
    return callback(null, true);
  }

  const allowedOrigins = getAllowedOrigins();
  
  // Check exact matches
  if (allowedOrigins.includes(origin)) {
    return callback(null, true);
  }

  // Check mobile schemes
  if (MOBILE_SCHEMES.some(scheme => origin.startsWith(scheme))) {
    return callback(null, true);
  }

  // In development, be more permissive with localhost variants
  if (config.isDevelopment) {
    // Allow any localhost with different ports
    if (origin.match(/^https?:\/\/(localhost|127\.0\.0\.1|0\.0\.0\.0)(:\d+)?$/)) {
      logger.debug('CORS: Allowing development localhost origin', { origin });
      return callback(null, true);
    }

    // Allow file:// protocol for local development
    if (origin.startsWith('file://')) {
      logger.debug('CORS: Allowing file protocol for development', { origin });
      return callback(null, true);
    }
  }

  // Log blocked origins for monitoring
  logger.warn('CORS: Origin blocked', { 
    origin, 
    allowedOrigins: allowedOrigins.length,
    environment: config.nodeEnv
  });

  // Report suspicious CORS attempts in production
  if (config.isProduction) {
    captureMessage(`Blocked CORS request from unauthorized origin: ${origin}`, 'warning', {
      tags: {
        security_event: 'cors_blocked',
        origin: origin
      },
      extra: {
        allowedOrigins: allowedOrigins.length,
        userAgent: 'unknown' // Will be filled by the request context
      }
    });
  }

  callback(new Error(`CORS: Origin ${origin} not allowed`), false);
}

// CORS configuration for different environments
export const corsConfig: CorsOptions = {
  origin: validateOrigin,
  
  // Allow credentials for authentication
  credentials: true,
  
  // Allowed methods for mental health app
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  
  // Allowed headers
  allowedHeaders: [
    'Origin',
    'X-Requested-With',
    'Content-Type',
    'Accept',
    'Authorization',
    'X-API-Key',
    'X-Device-ID',
    'X-Platform',
    'X-App-Version',
    'X-Session-ID',
    'X-Request-ID',
    'API-Version',
    'Cache-Control',
    'Pragma'
  ],
  
  // Expose headers that the client can access
  exposedHeaders: [
    'X-Total-Count',
    'X-Page-Count',
    'X-Current-Page',
    'X-Rate-Limit-Remaining',
    'X-Rate-Limit-Reset',
    'API-Version',
    'API-Supported-Versions',
    'Deprecation',
    'Sunset',
    'Link'
  ],
  
  // Preflight cache duration (24 hours)
  maxAge: 86400,
  
  // Handle preflight requests
  preflightContinue: false,
  optionsSuccessStatus: 204
};

// Enhanced CORS middleware with logging and monitoring
export function corsMiddleware() {
  return (req: any, res: any, next: any) => {
    const origin = req.headers.origin;
    const method = req.method;
    const userAgent = req.headers['user-agent'];

    // Log CORS requests for monitoring
    if (method === 'OPTIONS') {
      logger.debug('CORS preflight request', {
        origin,
        method,
        requestedMethod: req.headers['access-control-request-method'],
        requestedHeaders: req.headers['access-control-request-headers'],
        userAgent
      });
    }

    // Add security headers
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('X-Frame-Options', 'DENY');
    res.setHeader('X-XSS-Protection', '1; mode=block');
    
    if (config.isProduction) {
      res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains; preload');
    }

    // Apply CORS
    const cors = require('cors')(corsConfig);
    cors(req, res, (err: any) => {
      if (err) {
        logger.warn('CORS error', {
          error: err.message,
          origin,
          method,
          userAgent
        });
        
        return res.status(403).json({
          success: false,
          error: 'CORS_ERROR',
          message: 'Cross-origin request not allowed'
        });
      }
      
      next();
    });
  };
}

// Specific CORS configuration for webhooks (more restrictive)
export const webhookCorsConfig: CorsOptions = {
  origin: (origin, callback) => {
    // Webhooks should only come from trusted services
    const trustedWebhookOrigins = [
      'https://api.stripe.com',
      'https://hooks.stripe.com',
      'https://api.github.com',
      'https://hooks.slack.com'
    ];

    if (!origin || trustedWebhookOrigins.includes(origin)) {
      callback(null, true);
    } else {
      logger.warn('Webhook CORS: Untrusted origin', { origin });
      callback(new Error('Webhook origin not allowed'), false);
    }
  },
  credentials: false,
  methods: ['POST'],
  allowedHeaders: ['Content-Type', 'X-Stripe-Signature', 'X-Hub-Signature-256'],
  maxAge: 300 // 5 minutes
};

// CORS configuration for Socket.IO
export const socketCorsConfig = {
  origin: getAllowedOrigins(),
  credentials: true,
  methods: ['GET', 'POST']
};

// Utility functions for CORS management
export class CORSManager {
  static addAllowedOrigin(origin: string) {
    const allowedOrigins = getAllowedOrigins();
    if (!allowedOrigins.includes(origin)) {
      // In a real implementation, this would update a database or config
      logger.info('CORS: Added new allowed origin', { origin });
    }
  }

  static removeAllowedOrigin(origin: string) {
    // In a real implementation, this would update a database or config
    logger.info('CORS: Removed allowed origin', { origin });
  }

  static getAllowedOrigins() {
    return getAllowedOrigins();
  }

  static validateOriginSync(origin: string): boolean {
    const allowedOrigins = getAllowedOrigins();
    
    if (allowedOrigins.includes(origin)) {
      return true;
    }

    if (MOBILE_SCHEMES.some(scheme => origin.startsWith(scheme))) {
      return true;
    }

    if (config.isDevelopment && origin.match(/^https?:\/\/(localhost|127\.0\.0\.1|0\.0\.0\.0)(:\d+)?$/)) {
      return true;
    }

    return false;
  }

  static getSecurityHeaders() {
    const headers: Record<string, string> = {
      'X-Content-Type-Options': 'nosniff',
      'X-Frame-Options': 'DENY',
      'X-XSS-Protection': '1; mode=block',
      'Referrer-Policy': 'strict-origin-when-cross-origin'
    };

    if (config.isProduction) {
      headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains; preload';
      headers['Content-Security-Policy'] = "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self' https://api.urgood.app wss://api.urgood.app;";
    }

    return headers;
  }
}

// Export for testing
export { PRODUCTION_DOMAINS, DEVELOPMENT_DOMAINS, MOBILE_SCHEMES, getAllowedOrigins, validateOrigin };

export default {
  corsConfig,
  corsMiddleware,
  webhookCorsConfig,
  socketCorsConfig,
  CORSManager
};
