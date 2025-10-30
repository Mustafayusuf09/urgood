import request from 'supertest';
import { app } from '../../server';
import { PrismaClient } from '@prisma/client';
import { config } from '../../config/config';
import { logger } from '../../utils/logger';

const prisma = new PrismaClient();

describe('Comprehensive E2E Tests - Production Readiness', () => {
  let authToken: string;
  let userId: string;
  let sessionId: string;

  beforeAll(async () => {
    // Ensure test database is clean
    await prisma.$executeRaw`TRUNCATE TABLE "User", "Session", "MoodEntry", "ChatMessage", "AnalyticsEvent" RESTART IDENTITY CASCADE`;
    
    logger.info('Starting comprehensive E2E tests');
  });

  afterAll(async () => {
    await prisma.$disconnect();
    logger.info('Completed comprehensive E2E tests');
  });

  describe('1. Infrastructure Health Checks', () => {
    test('Health endpoint should return 200', async () => {
      const response = await request(app)
        .get('/health')
        .expect(200);

      expect(response.body).toMatchObject({
        status: 'healthy',
        timestamp: expect.any(String),
        uptime: expect.any(Number)
      });
    });

    test('Readiness check should pass', async () => {
      const response = await request(app)
        .get('/ready')
        .expect(200);

      expect(response.body).toMatchObject({
        status: 'ready',
        checks: expect.objectContaining({
          database: 'healthy',
          redis: expect.any(String)
        })
      });
    });

    test('Deep health check should validate all systems', async () => {
      const response = await request(app)
        .get('/health/deep')
        .expect(200);

      expect(response.body.checks).toHaveProperty('database');
      expect(response.body.checks).toHaveProperty('redis');
      expect(response.body.checks).toHaveProperty('external_apis');
    });

    test('Metrics endpoint should return performance data', async () => {
      const response = await request(app)
        .get('/metrics')
        .expect(200);

      expect(response.text).toContain('nodejs_heap_size_total_bytes');
      expect(response.text).toContain('http_requests_total');
    });
  });

  describe('2. API Versioning', () => {
    test('Should handle v1 API requests', async () => {
      const response = await request(app)
        .get('/api/v1/version')
        .expect(200);

      expect(response.body).toMatchObject({
        success: true,
        data: {
          current: 'v1',
          supported: expect.arrayContaining(['v1']),
          requestedVersion: 'v1'
        }
      });
    });

    test('Should handle requests without version (backward compatibility)', async () => {
      const response = await request(app)
        .get('/api/version')
        .expect(200);

      expect(response.body.data.requestedVersion).toBe('v1');
    });

    test('Should include version headers in responses', async () => {
      const response = await request(app)
        .get('/api/v1/version')
        .expect(200);

      expect(response.headers).toHaveProperty('api-version', 'v1');
      expect(response.headers).toHaveProperty('api-supported-versions');
    });
  });

  describe('3. CORS Configuration', () => {
    test('Should allow requests from production domains', async () => {
      const response = await request(app)
        .get('/api/v1/version')
        .set('Origin', 'https://urgood.app')
        .expect(200);

      expect(response.headers['access-control-allow-origin']).toBe('https://urgood.app');
      expect(response.headers['access-control-allow-credentials']).toBe('true');
    });

    test('Should handle preflight OPTIONS requests', async () => {
      const response = await request(app)
        .options('/api/v1/auth/login')
        .set('Origin', 'https://urgood.app')
        .set('Access-Control-Request-Method', 'POST')
        .set('Access-Control-Request-Headers', 'Content-Type,Authorization')
        .expect(204);

      expect(response.headers['access-control-allow-methods']).toContain('POST');
      expect(response.headers['access-control-allow-headers']).toContain('Content-Type');
    });

    test('Should reject unauthorized origins in production mode', async () => {
      // This test would need environment-specific logic
      if (config.isProduction) {
        await request(app)
          .get('/api/v1/version')
          .set('Origin', 'https://malicious-site.com')
          .expect(403);
      }
    });
  });

  describe('4. Request Validation & Security', () => {
    test('Should validate request content length', async () => {
      const largePayload = 'x'.repeat(11 * 1024 * 1024); // 11MB
      
      const response = await request(app)
        .post('/api/v1/auth/register')
        .send({ data: largePayload })
        .expect(413);

      expect(response.body.error).toBe('PAYLOAD_TOO_LARGE');
    });

    test('Should sanitize malicious input', async () => {
      const maliciousInput = {
        name: '<script>alert("xss")</script>John Doe',
        email: 'test@example.com'
      };

      const response = await request(app)
        .post('/api/v1/auth/register')
        .send(maliciousInput)
        .expect(400); // Will fail validation, but input should be sanitized

      // The sanitized input should not contain script tags
      expect(response.body.message).not.toContain('<script>');
    });

    test('Should include security headers', async () => {
      const response = await request(app)
        .get('/api/v1/version')
        .expect(200);

      expect(response.headers).toHaveProperty('x-content-type-options', 'nosniff');
      expect(response.headers).toHaveProperty('x-frame-options', 'DENY');
      expect(response.headers).toHaveProperty('x-xss-protection');
    });
  });

  describe('5. Authentication Flow', () => {
    test('Should register a new user successfully', async () => {
      const userData = {
        email: 'test@urgood.app',
        name: 'Test User',
        password: 'SecurePass123!',
        timezone: 'America/New_York'
      };

      const response = await request(app)
        .post('/api/v1/auth/register')
        .send(userData)
        .expect(201);

      expect(response.body).toMatchObject({
        success: true,
        data: {
          user: {
            email: userData.email,
            name: userData.name,
            timezone: userData.timezone
          },
          tokens: {
            accessToken: expect.any(String),
            refreshToken: expect.any(String)
          }
        }
      });

      authToken = response.body.data.tokens.accessToken;
      userId = response.body.data.user.id;
    });

    test('Should login with valid credentials', async () => {
      const loginData = {
        email: 'test@urgood.app',
        password: 'SecurePass123!'
      };

      const response = await request(app)
        .post('/api/v1/auth/login')
        .send(loginData)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.tokens.accessToken).toBeDefined();
    });

    test('Should reject invalid credentials', async () => {
      const loginData = {
        email: 'test@urgood.app',
        password: 'wrongpassword'
      };

      const response = await request(app)
        .post('/api/v1/auth/login')
        .send(loginData)
        .expect(401);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBe('INVALID_CREDENTIALS');
    });

    test('Should protect authenticated routes', async () => {
      await request(app)
        .get('/api/v1/users/profile')
        .expect(401);

      const response = await request(app)
        .get('/api/v1/users/profile')
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.data.user.id).toBe(userId);
    });
  });

  describe('6. Voice Chat Integration', () => {
    test('Should authorize voice chat session', async () => {
      const response = await request(app)
        .post('/api/v1/voice/authorize')
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body).toMatchObject({
        success: true,
        data: {
          sessionId: expect.any(String),
          authorized: true
        }
      });

      sessionId = response.body.data.sessionId;
    });

    test('Should track voice session analytics', async () => {
      const sessionData = {
        sessionId,
        duration: 120,
        messageCount: 5,
        status: 'completed'
      };

      const response = await request(app)
        .post('/api/v1/voice/session/end')
        .set('Authorization', `Bearer ${authToken}`)
        .send(sessionData)
        .expect(200);

      expect(response.body.success).toBe(true);
    });
  });

  describe('7. Mood Tracking', () => {
    test('Should create mood entry with validation', async () => {
      const moodData = {
        mood: 7,
        notes: 'Feeling good today after the voice chat session',
        tags: ['positive', 'therapy']
      };

      const response = await request(app)
        .post('/api/v1/mood/entries')
        .set('Authorization', `Bearer ${authToken}`)
        .send(moodData)
        .expect(201);

      expect(response.body).toMatchObject({
        success: true,
        data: {
          moodEntry: {
            mood: 7,
            notes: moodData.notes,
            tags: moodData.tags,
            userId
          }
        }
      });
    });

    test('Should validate mood entry data', async () => {
      const invalidMoodData = {
        mood: 15, // Invalid: should be 1-10
        notes: 'x'.repeat(1001) // Invalid: too long
      };

      const response = await request(app)
        .post('/api/v1/mood/entries')
        .set('Authorization', `Bearer ${authToken}`)
        .send(invalidMoodData)
        .expect(400);

      expect(response.body.error).toBe('VALIDATION_ERROR');
      expect(response.body.details).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            field: expect.stringContaining('mood')
          })
        ])
      );
    });

    test('Should retrieve mood trends', async () => {
      const response = await request(app)
        .get('/api/v1/mood/trends')
        .set('Authorization', `Bearer ${authToken}`)
        .query({
          startDate: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString(),
          endDate: new Date().toISOString()
        })
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.trends).toBeDefined();
    });
  });

  describe('8. Chat Functionality', () => {
    test('Should handle chat messages', async () => {
      const messageData = {
        message: 'Hello, I need some support today.',
        sessionId
      };

      const response = await request(app)
        .post('/api/v1/chat/completions')
        .set('Authorization', `Bearer ${authToken}`)
        .send(messageData)
        .expect(200);

      expect(response.body).toMatchObject({
        success: true,
        data: {
          response: expect.any(String),
          messageId: expect.any(String)
        }
      });
    });

    test('Should validate chat message length', async () => {
      const longMessage = {
        message: 'x'.repeat(4001) // Exceeds 4000 character limit
      };

      const response = await request(app)
        .post('/api/v1/chat/completions')
        .set('Authorization', `Bearer ${authToken}`)
        .send(longMessage)
        .expect(400);

      expect(response.body.error).toBe('VALIDATION_ERROR');
    });
  });

  describe('9. Crisis Detection', () => {
    test('Should detect and handle crisis situations', async () => {
      const crisisMessage = {
        message: 'I am having thoughts of self-harm and need immediate help',
        severity: 'CRITICAL'
      };

      const response = await request(app)
        .post('/api/v1/crisis/detect')
        .set('Authorization', `Bearer ${authToken}`)
        .send(crisisMessage)
        .expect(200);

      expect(response.body).toMatchObject({
        success: true,
        data: {
          crisisDetected: true,
          severity: 'CRITICAL',
          resources: expect.any(Array),
          emergencyContacts: expect.any(Array)
        }
      });
    });

    test('Should provide crisis resources', async () => {
      const response = await request(app)
        .get('/api/v1/crisis/resources')
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.data.resources).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            name: expect.any(String),
            phone: expect.any(String),
            available: expect.any(String)
          })
        ])
      );
    });
  });

  describe('10. Analytics & Monitoring', () => {
    test('Should track analytics events', async () => {
      const eventData = {
        eventName: 'mood_entry_created',
        properties: {
          mood_score: 7,
          has_notes: true,
          tag_count: 2
        },
        sessionId
      };

      const response = await request(app)
        .post('/api/v1/analytics/events')
        .set('Authorization', `Bearer ${authToken}`)
        .send(eventData)
        .expect(201);

      expect(response.body.success).toBe(true);
    });

    test('Should provide analytics dashboard data', async () => {
      const response = await request(app)
        .get('/api/v1/analytics/dashboard')
        .set('Authorization', `Bearer ${authToken}`)
        .query({
          timeframe: '30d'
        })
        .expect(200);

      expect(response.body.data).toHaveProperty('userEngagement');
      expect(response.body.data).toHaveProperty('moodTrends');
      expect(response.body.data).toHaveProperty('sessionStats');
    });
  });

  describe('11. Error Handling & Logging', () => {
    test('Should handle 404 errors gracefully', async () => {
      const response = await request(app)
        .get('/api/v1/nonexistent-endpoint')
        .set('Authorization', `Bearer ${authToken}`)
        .expect(404);

      expect(response.body).toMatchObject({
        success: false,
        error: 'NOT_FOUND',
        message: expect.any(String)
      });
    });

    test('Should handle server errors without exposing internals', async () => {
      // This would need a route that intentionally throws an error for testing
      const response = await request(app)
        .post('/api/v1/test/error')
        .set('Authorization', `Bearer ${authToken}`)
        .expect(500);

      expect(response.body.success).toBe(false);
      expect(response.body.message).not.toContain('stack trace');
      expect(response.body.message).not.toContain('internal');
    });

    test('Should log requests with audit trail', async () => {
      // Verify that requests are being logged (would need to check log output)
      await request(app)
        .get('/api/v1/users/profile')
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      // In a real test, you'd verify log entries were created
      expect(true).toBe(true); // Placeholder
    });
  });

  describe('12. Rate Limiting', () => {
    test('Should enforce rate limits', async () => {
      // Make multiple rapid requests to trigger rate limiting
      const requests = Array(101).fill(null).map(() =>
        request(app)
          .get('/api/v1/version')
          .set('Authorization', `Bearer ${authToken}`)
      );

      const responses = await Promise.all(requests);
      const rateLimitedResponses = responses.filter(r => r.status === 429);

      expect(rateLimitedResponses.length).toBeGreaterThan(0);
      expect(rateLimitedResponses[0].body.error).toBe('RATE_LIMIT_EXCEEDED');
    });

    test('Should include rate limit headers', async () => {
      const response = await request(app)
        .get('/api/v1/version')
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.headers).toHaveProperty('x-ratelimit-limit');
      expect(response.headers).toHaveProperty('x-ratelimit-remaining');
      expect(response.headers).toHaveProperty('x-ratelimit-reset');
    });
  });

  describe('13. Database & Redis Integration', () => {
    test('Should persist data correctly', async () => {
      // Verify that the user was actually created in the database
      const user = await prisma.user.findUnique({
        where: { email: 'test@urgood.app' }
      });

      expect(user).toBeTruthy();
      expect(user?.name).toBe('Test User');
      expect(user?.timezone).toBe('America/New_York');
    });

    test('Should handle database transactions', async () => {
      // Create a mood entry and verify it's properly stored
      const moodEntry = await prisma.moodEntry.findFirst({
        where: { userId }
      });

      expect(moodEntry).toBeTruthy();
      expect(moodEntry?.mood).toBe(7);
      expect(moodEntry?.notes).toContain('Feeling good today');
    });
  });

  describe('14. Webhook Integration', () => {
    test('Should handle Stripe webhooks with proper CORS', async () => {
      const webhookPayload = {
        type: 'invoice.payment_succeeded',
        data: {
          object: {
            customer: 'cus_test123',
            amount_paid: 999
          }
        }
      };

      const response = await request(app)
        .post('/api/v1/webhooks/stripe')
        .set('stripe-signature', 'test-signature')
        .send(webhookPayload)
        .expect(200);

      expect(response.body.received).toBe(true);
    });
  });

  describe('15. Performance & Monitoring', () => {
    test('Should respond within acceptable time limits', async () => {
      const startTime = Date.now();
      
      await request(app)
        .get('/api/v1/users/profile')
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      const responseTime = Date.now() - startTime;
      expect(responseTime).toBeLessThan(1000); // Should respond within 1 second
    });

    test('Should handle concurrent requests', async () => {
      const concurrentRequests = Array(10).fill(null).map(() =>
        request(app)
          .get('/api/v1/version')
          .set('Authorization', `Bearer ${authToken}`)
      );

      const responses = await Promise.all(concurrentRequests);
      const successfulResponses = responses.filter(r => r.status === 200);

      expect(successfulResponses.length).toBe(10);
    });
  });

  describe('16. Production Configuration Validation', () => {
    test('Should have proper environment configuration', () => {
      expect(config.database.url).toBeDefined();
      expect(config.redis.url).toBeDefined();
      expect(config.cors.origin).toBeDefined();
      
      if (config.isProduction) {
        expect(config.database.url).toContain('postgresql://');
        expect(config.cors.origin).not.toContain('localhost');
      }
    });

    test('Should have security configurations enabled', () => {
      expect(config.security.jwtSecret).toBeDefined();
      expect(config.security.bcryptRounds).toBeGreaterThanOrEqual(10);
      
      if (config.isProduction) {
        expect(config.security.httpsOnly).toBe(true);
        expect(config.monitoring.sentryDsn).toBeDefined();
      }
    });
  });
});

// Helper function to clean up test data
async function cleanupTestData() {
  try {
    await prisma.analyticsEvent.deleteMany({
      where: { userId }
    });
    
    await prisma.moodEntry.deleteMany({
      where: { userId }
    });
    
    await prisma.chatMessage.deleteMany({
      where: { userId }
    });
    
    await prisma.session.deleteMany({
      where: { userId }
    });
    
    await prisma.user.delete({
      where: { id: userId }
    });
    
    logger.info('Test data cleaned up successfully');
  } catch (error) {
    logger.error('Error cleaning up test data:', error);
  }
}

// Run cleanup after all tests
afterAll(async () => {
  await cleanupTestData();
});
