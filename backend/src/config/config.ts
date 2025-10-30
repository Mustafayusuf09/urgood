import dotenv from 'dotenv';
import { z } from 'zod';

// Load environment variables
dotenv.config();

// Environment validation schema
const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  PORT: z.string().transform(Number).default('3000'),
  API_VERSION: z.string().default('v1'),
  
  // Database
  DATABASE_URL: z.string().min(1, 'DATABASE_URL is required'),
  REDIS_URL: z.string().default('redis://localhost:6379'),
  
  // Security
  JWT_SECRET: z.string().min(32, 'JWT_SECRET must be at least 32 characters'),
  JWT_REFRESH_SECRET: z.string().min(32, 'JWT_REFRESH_SECRET must be at least 32 characters'),
  ENCRYPTION_KEY: z.string().min(32, 'ENCRYPTION_KEY must be at least 32 characters'),
  BCRYPT_ROUNDS: z.string().transform(Number).default('12'),
  
  // Rate Limiting
  RATE_LIMIT_WINDOW_MS: z.string().transform(Number).default('900000'),
  RATE_LIMIT_MAX_REQUESTS: z.string().transform(Number).default('100'),
  
  // OpenAI
  OPENAI_API_KEY: z.string().min(1, 'OPENAI_API_KEY is required'),
  OPENAI_MODEL: z.string().default('gpt-4o'),
  OPENAI_MAX_TOKENS: z.string().transform(Number).default('1500'),
  OPENAI_TEMPERATURE: z.string().transform(Number).default('0.8'),
  
  // Firebase
  FIREBASE_PROJECT_ID: z.string().min(1, 'FIREBASE_PROJECT_ID is required'),
  FIREBASE_PRIVATE_KEY: z.string().min(1, 'FIREBASE_PRIVATE_KEY is required'),
  FIREBASE_CLIENT_EMAIL: z.string().email('FIREBASE_CLIENT_EMAIL must be valid email'),
  
  // Stripe
  STRIPE_SECRET_KEY: z.string().min(1, 'STRIPE_SECRET_KEY is required'),
  STRIPE_WEBHOOK_SECRET: z.string().min(1, 'STRIPE_WEBHOOK_SECRET is required'),
  STRIPE_PREMIUM_MONTHLY_PRICE_ID: z.string().min(1, 'STRIPE_PREMIUM_MONTHLY_PRICE_ID is required'),
  STRIPE_PREMIUM_YEARLY_PRICE_ID: z.string().optional(),
  
  // Email
  EMAIL_FROM: z.string().email('EMAIL_FROM must be valid email'),
  SENDGRID_API_KEY: z.string().optional(),
  SMTP_HOST: z.string().optional(),
  SMTP_PORT: z.string().transform(Number).optional(),
  SMTP_USER: z.string().optional(),
  SMTP_PASS: z.string().optional(),
  
  // Monitoring
  LOG_LEVEL: z.enum(['error', 'warn', 'info', 'debug']).default('info'),
  SENTRY_DSN: z.string().optional(),
  
  // File Upload
  MAX_FILE_SIZE: z.string().transform(Number).default('10485760'),
  ALLOWED_FILE_TYPES: z.string().default('image/jpeg,image/png,image/gif,image/webp'),
  
  // CORS
  CORS_ORIGIN: z.string().default('http://localhost:3000'),
  
  // SSL/TLS
  SSL_CERT_PATH: z.string().optional(),
  SSL_KEY_PATH: z.string().optional(),
  
  // Health Checks
  HEALTH_CHECK_INTERVAL: z.string().transform(Number).default('30000'),
  HEALTH_CHECK_TIMEOUT: z.string().transform(Number).default('5000'),
  
  // Crisis Detection
  CRISIS_KEYWORDS: z.string().default('suicide,kill myself,end it all,want to die,hurt myself'),
  CRISIS_WEBHOOK_URL: z.string().url().optional(),
  EMERGENCY_CONTACT_EMAIL: z.string().email().optional(),
  
  // Feature Flags
  FEATURE_VOICE_CHAT_ENABLED: z.string().transform(val => val === 'true').default('true'),
  FEATURE_CRISIS_DETECTION_ENABLED: z.string().transform(val => val === 'true').default('true'),
  FEATURE_ANALYTICS_ENABLED: z.string().transform(val => val === 'true').default('true'),
  FEATURE_PREMIUM_FEATURES_ENABLED: z.string().transform(val => val === 'true').default('true'),
});

// Validate environment variables
const env = envSchema.parse(process.env);

// Production security validation
if (env.NODE_ENV === 'production') {
  const productionSecurityChecks = [
    {
      key: 'JWT_SECRET',
      value: env.JWT_SECRET,
      invalid: ['DEVELOPMENT_ONLY_JWT_SECRET_CHANGE_FOR_PRODUCTION', 'your-super-secret-jwt-key-change-this-in-production'],
      message: 'JWT_SECRET must be changed from development default for production'
    },
    {
      key: 'JWT_REFRESH_SECRET', 
      value: env.JWT_REFRESH_SECRET,
      invalid: ['DEVELOPMENT_ONLY_REFRESH_SECRET_CHANGE_FOR_PRODUCTION', 'your-super-secret-refresh-key-change-this-in-production'],
      message: 'JWT_REFRESH_SECRET must be changed from development default for production'
    },
    {
      key: 'ENCRYPTION_KEY',
      value: env.ENCRYPTION_KEY,
      invalid: ['DEVELOPMENT_ONLY_ENCRYPTION_KEY_32_CHARS', 'your-32-character-encryption-key-here'],
      message: 'ENCRYPTION_KEY must be changed from development default for production'
    },
    {
      key: 'OPENAI_API_KEY',
      value: env.OPENAI_API_KEY,
      invalid: ['DEVELOPMENT_ONLY_REPLACE_WITH_REAL_OPENAI_KEY', 'sk-your-openai-api-key-here'],
      message: 'OPENAI_API_KEY must be set to a real API key for production'
    },
    {
      key: 'STRIPE_SECRET_KEY',
      value: env.STRIPE_SECRET_KEY,
      invalid: ['DEVELOPMENT_ONLY_REPLACE_WITH_STRIPE_TEST_KEY', 'sk_test_your_stripe_secret_key_here'],
      message: 'STRIPE_SECRET_KEY must be set to production key (starts with sk_live_) for production'
    }
  ];

  const securityErrors: string[] = [];
  
  for (const check of productionSecurityChecks) {
    if (check.invalid.includes(check.value)) {
      securityErrors.push(`❌ ${check.message}`);
    }
  }

  // Additional production checks
  if (env.STRIPE_SECRET_KEY.startsWith('sk_test_')) {
    securityErrors.push('❌ STRIPE_SECRET_KEY must use live keys (sk_live_) in production, not test keys');
  }

  if (env.BCRYPT_ROUNDS < 12) {
    securityErrors.push('❌ BCRYPT_ROUNDS must be at least 12 for production security');
  }

  if (securityErrors.length > 0) {
    console.error('🚨 PRODUCTION SECURITY VALIDATION FAILED:');
    securityErrors.forEach(error => console.error(error));
    console.error('');
    console.error('💡 To fix these issues:');
    console.error('1. Copy env.production.template to .env');
    console.error('2. Replace all placeholder values with real production values');
    console.error('3. Ensure Stripe keys start with sk_live_ for production');
    console.error('4. Generate strong secrets with: openssl rand -base64 32');
    console.error('');
    process.exit(1);
  }

  console.log('✅ Production security validation passed');
}

export const config = {
  nodeEnv: env.NODE_ENV,
  port: env.PORT,
  apiVersion: env.API_VERSION,
  
  database: {
    url: env.DATABASE_URL,
  },
  
  redis: {
    url: env.REDIS_URL,
  },
  
  security: {
    jwtSecret: env.JWT_SECRET,
    jwtRefreshSecret: env.JWT_REFRESH_SECRET,
    encryptionKey: env.ENCRYPTION_KEY,
    bcryptRounds: env.BCRYPT_ROUNDS,
  },
  
  rateLimit: {
    windowMs: env.RATE_LIMIT_WINDOW_MS,
    maxRequests: env.RATE_LIMIT_MAX_REQUESTS,
  },
  
  openai: {
    apiKey: env.OPENAI_API_KEY,
    model: env.OPENAI_MODEL,
    maxTokens: env.OPENAI_MAX_TOKENS,
    temperature: env.OPENAI_TEMPERATURE,
  },
  
  firebase: {
    projectId: env.FIREBASE_PROJECT_ID,
    privateKey: env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
    clientEmail: env.FIREBASE_CLIENT_EMAIL,
  },
  
  stripe: {
    secretKey: env.STRIPE_SECRET_KEY,
    webhookSecret: env.STRIPE_WEBHOOK_SECRET,
    premiumMonthlyPriceId: env.STRIPE_PREMIUM_MONTHLY_PRICE_ID,
    premiumYearlyPriceId: env.STRIPE_PREMIUM_YEARLY_PRICE_ID,
  },
  
  email: {
    from: env.EMAIL_FROM,
    sendgridApiKey: env.SENDGRID_API_KEY,
    smtp: {
      host: env.SMTP_HOST,
      port: env.SMTP_PORT,
      user: env.SMTP_USER,
      pass: env.SMTP_PASS,
    },
  },
  
  monitoring: {
    logLevel: env.LOG_LEVEL,
    sentryDsn: env.SENTRY_DSN,
  },
  
  fileUpload: {
    maxFileSize: env.MAX_FILE_SIZE,
    allowedFileTypes: env.ALLOWED_FILE_TYPES.split(','),
  },
  
  cors: {
    origin: env.CORS_ORIGIN.split(','),
  },
  
  ssl: {
    certPath: env.SSL_CERT_PATH,
    keyPath: env.SSL_KEY_PATH,
  },
  
  healthCheck: {
    interval: env.HEALTH_CHECK_INTERVAL,
    timeout: env.HEALTH_CHECK_TIMEOUT,
  },
  
  crisis: {
    keywords: env.CRISIS_KEYWORDS.split(',').map(k => k.trim().toLowerCase()),
    webhookUrl: env.CRISIS_WEBHOOK_URL,
    emergencyContactEmail: env.EMERGENCY_CONTACT_EMAIL,
  },
  
  features: {
    voiceChatEnabled: env.FEATURE_VOICE_CHAT_ENABLED,
    crisisDetectionEnabled: env.FEATURE_CRISIS_DETECTION_ENABLED,
    analyticsEnabled: env.FEATURE_ANALYTICS_ENABLED,
    premiumFeaturesEnabled: env.FEATURE_PREMIUM_FEATURES_ENABLED,
  },
  
  // Computed values
  isDevelopment: env.NODE_ENV === 'development',
  isProduction: env.NODE_ENV === 'production',
  isTest: env.NODE_ENV === 'test',
} as const;

// Validate critical configuration
if (config.isProduction) {
  if (config.security.jwtSecret.length < 64) {
    throw new Error('JWT_SECRET must be at least 64 characters in production');
  }
  
  if (!config.ssl.certPath || !config.ssl.keyPath) {
    console.warn('⚠️  SSL certificates not configured for production');
  }
  
  if (!config.monitoring.sentryDsn) {
    console.warn('⚠️  Sentry DSN not configured for production monitoring');
  }
}
