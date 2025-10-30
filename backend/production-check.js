#!/usr/bin/env node

/**
 * Production Readiness Check Script
 * Validates environment variables and critical configurations
 */

const fs = require('fs');
const path = require('path');

console.log('🚀 UrGood Backend - Production Readiness Check\n');

// Required environment variables for production
const requiredEnvVars = [
  'NODE_ENV',
  'DATABASE_URL',
  'JWT_SECRET',
  'JWT_REFRESH_SECRET',
  'ENCRYPTION_KEY',
  'OPENAI_API_KEY',
  'FIREBASE_PROJECT_ID',
  'FIREBASE_PRIVATE_KEY',
  'FIREBASE_CLIENT_EMAIL',
  'STRIPE_SECRET_KEY',
  'STRIPE_WEBHOOK_SECRET',
  'STRIPE_PREMIUM_MONTHLY_PRICE_ID',
  'EMAIL_FROM'
];

// Optional but recommended for production
const recommendedEnvVars = [
  'REDIS_URL',
  'SENTRY_DSN',
  'SENDGRID_API_KEY',
  'CORS_ORIGIN',
  'SSL_CERT_PATH',
  'SSL_KEY_PATH'
];

let hasErrors = false;
let hasWarnings = false;

// Check required environment variables
console.log('📋 Checking required environment variables...');
requiredEnvVars.forEach(envVar => {
  if (!process.env[envVar]) {
    console.error(`❌ Missing required environment variable: ${envVar}`);
    hasErrors = true;
  } else {
    console.log(`✅ ${envVar}`);
  }
});

// Check recommended environment variables
console.log('\n📋 Checking recommended environment variables...');
recommendedEnvVars.forEach(envVar => {
  if (!process.env[envVar]) {
    console.warn(`⚠️  Missing recommended environment variable: ${envVar}`);
    hasWarnings = true;
  } else {
    console.log(`✅ ${envVar}`);
  }
});

// Validate JWT secrets length
console.log('\n🔐 Validating security configuration...');
if (process.env.JWT_SECRET && process.env.JWT_SECRET.length < 32) {
  console.error('❌ JWT_SECRET must be at least 32 characters long');
  hasErrors = true;
} else {
  console.log('✅ JWT_SECRET length is adequate');
}

if (process.env.JWT_REFRESH_SECRET && process.env.JWT_REFRESH_SECRET.length < 32) {
  console.error('❌ JWT_REFRESH_SECRET must be at least 32 characters long');
  hasErrors = true;
} else {
  console.log('✅ JWT_REFRESH_SECRET length is adequate');
}

// Check if production mode is enabled
console.log('\n🌍 Environment configuration...');
if (process.env.NODE_ENV === 'production') {
  console.log('✅ Running in production mode');
  
  // Additional production checks
  if (process.env.JWT_SECRET && process.env.JWT_SECRET.length < 64) {
    console.warn('⚠️  JWT_SECRET should be at least 64 characters in production');
    hasWarnings = true;
  }
  
  if (!process.env.SSL_CERT_PATH || !process.env.SSL_KEY_PATH) {
    console.warn('⚠️  SSL certificates not configured - HTTPS recommended for production');
    hasWarnings = true;
  }
} else {
  console.warn('⚠️  Not running in production mode (NODE_ENV=' + (process.env.NODE_ENV || 'undefined') + ')');
  hasWarnings = true;
}

// Check if critical files exist
console.log('\n📁 Checking critical files...');
const criticalFiles = [
  'package.json',
  'prisma/schema.prisma',
  'src/server.ts',
  'src/config/config.ts'
];

criticalFiles.forEach(file => {
  if (fs.existsSync(path.join(__dirname, file))) {
    console.log(`✅ ${file}`);
  } else {
    console.error(`❌ Missing critical file: ${file}`);
    hasErrors = true;
  }
});

// Check database connection string format
console.log('\n🗄️  Database configuration...');
if (process.env.DATABASE_URL) {
  if (process.env.DATABASE_URL.startsWith('postgresql://') || process.env.DATABASE_URL.startsWith('postgres://')) {
    console.log('✅ PostgreSQL database URL format is valid');
  } else {
    console.warn('⚠️  DATABASE_URL format may be invalid (expected PostgreSQL)');
    hasWarnings = true;
  }
} else {
  console.error('❌ DATABASE_URL is required');
  hasErrors = true;
}

// Check OpenAI API key format
console.log('\n🤖 OpenAI configuration...');
if (process.env.OPENAI_API_KEY) {
  if (process.env.OPENAI_API_KEY.startsWith('sk-')) {
    console.log('✅ OpenAI API key format is valid');
  } else {
    console.error('❌ OPENAI_API_KEY format is invalid (should start with sk-)');
    hasErrors = true;
  }
} else {
  console.error('❌ OPENAI_API_KEY is required');
  hasErrors = true;
}

// Check Stripe configuration
console.log('\n💳 Stripe configuration...');
if (process.env.STRIPE_SECRET_KEY) {
  if (process.env.STRIPE_SECRET_KEY.startsWith('sk_')) {
    console.log('✅ Stripe secret key format is valid');
  } else {
    console.error('❌ STRIPE_SECRET_KEY format is invalid (should start with sk_)');
    hasErrors = true;
  }
} else {
  console.error('❌ STRIPE_SECRET_KEY is required');
  hasErrors = true;
}

if (process.env.STRIPE_WEBHOOK_SECRET) {
  if (process.env.STRIPE_WEBHOOK_SECRET.startsWith('whsec_')) {
    console.log('✅ Stripe webhook secret format is valid');
  } else {
    console.error('❌ STRIPE_WEBHOOK_SECRET format is invalid (should start with whsec_)');
    hasErrors = true;
  }
} else {
  console.error('❌ STRIPE_WEBHOOK_SECRET is required');
  hasErrors = true;
}

// Summary
console.log('\n📊 Production Readiness Summary');
console.log('================================');

if (hasErrors) {
  console.error('❌ CRITICAL ERRORS FOUND - Application is NOT production ready!');
  console.error('Please fix the errors above before deploying to production.');
  process.exit(1);
} else if (hasWarnings) {
  console.warn('⚠️  WARNINGS FOUND - Application may run but some features may be limited.');
  console.warn('Consider addressing the warnings above for optimal production performance.');
  console.log('✅ No critical errors found - Application is production ready with warnings.');
  process.exit(0);
} else {
  console.log('🎉 ALL CHECKS PASSED - Application is fully production ready!');
  process.exit(0);
}
