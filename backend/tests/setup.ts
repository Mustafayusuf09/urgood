import { PrismaClient } from '@prisma/client';
import { execSync } from 'child_process';
import { randomBytes } from 'crypto';

// Test database setup
const generateDatabaseUrl = () => {
  const testId = randomBytes(8).toString('hex');
  return `postgresql://test:test@localhost:5432/urgood_test_${testId}`;
};

// Set test environment
process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = generateDatabaseUrl();
process.env.JWT_SECRET = 'test-jwt-secret-key-for-testing-only-32-chars-minimum';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret-key-for-testing-only-32-chars-minimum';
process.env.ENCRYPTION_KEY = 'test-encryption-key-32-chars-min';
process.env.OPENAI_API_KEY = 'sk-test-key-for-testing';
process.env.FIREBASE_PROJECT_ID = 'test-project';
process.env.FIREBASE_PRIVATE_KEY = '-----BEGIN PRIVATE KEY-----\ntest-key\n-----END PRIVATE KEY-----';
process.env.FIREBASE_CLIENT_EMAIL = 'test@test-project.iam.gserviceaccount.com';
process.env.STRIPE_SECRET_KEY = 'sk_test_test_key';
process.env.STRIPE_WEBHOOK_SECRET = 'whsec_test_webhook_secret';
process.env.STRIPE_PREMIUM_MONTHLY_PRICE_ID = 'price_test_monthly';
process.env.STRIPE_PREMIUM_YEARLY_PRICE_ID = 'price_test_yearly';
process.env.EMAIL_FROM = 'test@urgood.app';
process.env.REDIS_URL = 'redis://localhost:6379/1'; // Use different DB for tests

let prisma: PrismaClient;

// Global setup
beforeAll(async () => {
  // Create test database
  try {
    execSync(`createdb ${process.env.DATABASE_URL?.split('/').pop()}`, { stdio: 'ignore' });
  } catch (error) {
    // Database might already exist
  }
  
  // Initialize Prisma
  prisma = new PrismaClient({
    datasources: {
      db: {
        url: process.env.DATABASE_URL || 'postgresql://test:test@localhost:5432/urgood_test'
      }
    }
  });
  
  // Run migrations
  execSync('npx prisma migrate deploy', { 
    env: { ...process.env, DATABASE_URL: process.env.DATABASE_URL },
    stdio: 'ignore'
  });
  
  // Connect to database
  await prisma.$connect();
}, 30000);

// Global teardown
afterAll(async () => {
  // Disconnect from database
  await prisma.$disconnect();
  
  // Drop test database
  try {
    execSync(`dropdb ${process.env.DATABASE_URL?.split('/').pop()}`, { stdio: 'ignore' });
  } catch (error) {
    // Ignore errors
  }
}, 10000);

// Clean database between tests
beforeEach(async () => {
  // Delete all data in reverse dependency order
  await prisma.auditLog.deleteMany();
  await prisma.analyticsEvent.deleteMany();
  await prisma.payment.deleteMany();
  await prisma.crisisEvent.deleteMany();
  await prisma.moodEntry.deleteMany();
  await prisma.chatMessage.deleteMany();
  await prisma.session.deleteMany();
  await prisma.user.deleteMany();
  await prisma.rateLimit.deleteMany();
  await prisma.featureFlag.deleteMany();
  await prisma.systemHealth.deleteMany();
});

export { prisma };
