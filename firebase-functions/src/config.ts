import * as functions from 'firebase-functions';

/**
 * Secure configuration management for Firebase Functions
 * Handles environment variables and Firebase config with validation
 */

export interface FunctionConfig {
  openai: {
    key: string;
  };
  elevenlabs: {
    key: string;
  };
  environment: {
    nodeEnv: 'development' | 'production';
    region: string;
  };
  security: {
    maxRateLimit: number;
    sessionTimeoutMinutes: number;
  };
}

/**
 * Get secure configuration with validation
 */
export function getConfig(): FunctionConfig {
  // Get OpenAI API key
  const openaiKey = functions.config().openai?.key || process.env.OPENAI_API_KEY;
  if (!openaiKey || openaiKey === 'your-openai-api-key-here') {
    throw new Error('OPENAI_API_KEY not configured. Set with: firebase functions:config:set openai.key="your-key"');
  }

  // Get ElevenLabs API key
  const elevenLabsKey = functions.config().elevenlabs?.key || process.env.ELEVENLABS_API_KEY;
  if (!elevenLabsKey || elevenLabsKey === 'your-elevenlabs-api-key-here') {
    throw new Error('ELEVENLABS_API_KEY not configured. Set with: firebase functions:config:set elevenlabs.key="your-key"');
  }

  // Environment detection
  const nodeEnv = (process.env.NODE_ENV as 'development' | 'production') || 'development';
  const region = process.env.FUNCTION_REGION || 'us-central1';

  // Security settings
  const maxRateLimit = parseInt(process.env.MAX_RATE_LIMIT || '100', 10);
  const sessionTimeoutMinutes = parseInt(process.env.SESSION_TIMEOUT_MINUTES || '60', 10);

  return {
    openai: {
      key: openaiKey,
    },
    elevenlabs: {
      key: elevenLabsKey,
    },
    environment: {
      nodeEnv,
      region,
    },
    security: {
      maxRateLimit,
      sessionTimeoutMinutes,
    },
  };
}

/**
 * Validate configuration on startup
 */
export function validateConfig(): void {
  try {
    const config = getConfig();
    
    console.log('🔧 Firebase Functions Configuration:');
    console.log(`  Environment: ${config.environment.nodeEnv}`);
    console.log(`  Region: ${config.environment.region}`);
    console.log(`  OpenAI Key: ${config.openai.key.substring(0, 10)}...`);
    console.log(`  ElevenLabs Key: ${config.elevenlabs.key.substring(0, 10)}...`);
    console.log(`  Max Rate Limit: ${config.security.maxRateLimit}`);
    console.log(`  Session Timeout: ${config.security.sessionTimeoutMinutes} minutes`);
    console.log('✅ Configuration validation passed');
    
  } catch (error) {
    console.error('❌ Configuration validation failed:', error);
    throw error;
  }
}

/**
 * Get environment-specific settings
 */
export function getEnvironmentSettings() {
  const config = getConfig();
  const isProduction = config.environment.nodeEnv === 'production';
  
  return {
    isProduction,
    isDevelopment: !isProduction,
    rateLimits: {
      voiceChat: isProduction ? 5 : 20,        // Sessions per hour
      tts: isProduction ? 30 : 100,            // Requests per minute
      general: isProduction ? 100 : 500,       // General API calls per hour
    },
    subscriptionRequired: {
      voiceChat: isProduction,                 // Require premium in production
      advancedFeatures: isProduction,          // Require premium for advanced features
    },
    logging: {
      level: isProduction ? 'info' : 'debug',
      includeUserData: !isProduction,         // Only log user data in development
    },
  };
}

/**
 * Security headers for HTTP functions
 */
export const securityHeaders = {
  'Content-Type': 'application/json',
  'X-Content-Type-Options': 'nosniff',
  'X-Frame-Options': 'DENY',
  'X-XSS-Protection': '1; mode=block',
  'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
  'Referrer-Policy': 'strict-origin-when-cross-origin',
};

/**
 * CORS configuration
 */
export const corsConfig = {
  origin: [
    'https://urgood-dc7f0.web.app',
    'https://urgood-dc7f0.firebaseapp.com',
    'https://urgood.app',
    ...(process.env.NODE_ENV === 'development' ? ['http://localhost:3000', 'http://127.0.0.1:3000'] : []),
  ],
  credentials: true,
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
};
