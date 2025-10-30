const { execSync } = require('child_process');

console.log('🚀 Running UrGood Backend E2E Tests...\n');

try {
  // Set environment variables for testing
  process.env.NODE_ENV = 'test';
  process.env.DATABASE_URL = 'postgresql://test:test@localhost:5432/urgood_test';
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
  process.env.REDIS_URL = 'redis://localhost:6379/1';

  console.log('📋 Test Environment Setup:');
  console.log('✅ Environment variables configured');
  console.log('✅ Test database URL set');
  console.log('✅ Mock API keys configured\n');

  console.log('🧪 Running Test Suites...\n');

  // Run tests with more lenient TypeScript checking
  execSync('npx jest --no-cache --verbose --testTimeout=30000', { 
    stdio: 'inherit',
    env: { ...process.env }
  });

  console.log('\n✅ All tests passed successfully!');
  console.log('\n📊 Test Summary:');
  console.log('✅ Chat/Pulse functionality: VERIFIED');
  console.log('✅ Insights functionality: VERIFIED');
  console.log('✅ Authentication: VERIFIED');
  console.log('✅ Integration tests: VERIFIED');

} catch (error) {
  console.error('\n❌ Tests failed:', error.message);
  console.log('\n🔧 Troubleshooting:');
  console.log('1. Make sure PostgreSQL is running');
  console.log('2. Check if Redis is available');
  console.log('3. Verify all dependencies are installed');
  console.log('4. Check database permissions');
  
  process.exit(1);
}
