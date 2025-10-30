import request from 'supertest';
import { app } from '../src/server';
import { prisma } from './setup';

describe('Voice Chat E2E Tests', () => {
  let premiumAccessToken: string;
  let freeAccessToken: string;
  let premiumUserId: string;
  let freeUserId: string;

  beforeEach(async () => {
    // Create premium user
    const premiumResponse = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: `premium-${Date.now()}@example.com`,
        password: 'TestPassword123!',
        name: 'Premium User'
      });
    
    premiumAccessToken = premiumResponse.body.data.tokens.accessToken;
    premiumUserId = premiumResponse.body.data.user.id;

    // Upgrade to premium
    await prisma.user.update({
      where: { id: premiumUserId },
      data: { subscriptionStatus: 'PREMIUM_MONTHLY' }
    });

    // Create free user
    const freeResponse = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: `free-${Date.now()}@example.com`,
        password: 'TestPassword123!',
        name: 'Free User'
      });
    
    freeAccessToken = freeResponse.body.data.tokens.accessToken;
    freeUserId = freeResponse.body.data.user.id;
  });

  afterEach(async () => {
    // Clean up voice usage records
    await prisma.voiceUsage.deleteMany({
      where: {
        userId: { in: [premiumUserId, freeUserId] }
      }
    });
  });

  describe('Voice Authorization', () => {
    it('should authorize premium user for voice chat', async () => {
      const response = await request(app)
        .post('/api/v1/voice/authorize')
        .set('Authorization', `Bearer ${premiumAccessToken}`)
        .send({
          sessionId: 'test-session-123',
          userId: premiumUserId
        })
        .expect(200);

      expect(response.body.authorized).toBe(true);
      expect(response.body.userId).toBe(premiumUserId);
      expect(response.body.dailySessions).toBeDefined();
      expect(response.body.dailySessions.status).toBe('available');
      expect(response.body.dailySessions.softCapReached).toBe(false);
      expect(response.body.rateLimits).toBeDefined();
      expect(response.body.rateLimits.requestsPerMinute).toBe(60);
    });

    it('should reject free user from voice chat', async () => {
      const response = await request(app)
        .post('/api/v1/voice/authorize')
        .set('Authorization', `Bearer ${freeAccessToken}`)
        .send({
          sessionId: 'test-session-456',
          userId: freeUserId
        })
        .expect(403);

      expect(response.body.error).toBe('Voice chat requires premium subscription');
      expect(response.body.code).toBe('PREMIUM_REQUIRED');
    });

    it('should require authentication', async () => {
      const response = await request(app)
        .post('/api/v1/voice/authorize')
        .send({ sessionId: 'test-session' })
        .expect(401);

      expect(response.body.success).toBe(false);
      expect(response.body.message).toContain('Access token required');
    });
  });

  describe('Voice Session Tracking', () => {
    it('should track session start', async () => {
      const response = await request(app)
        .post('/api/v1/voice/session/start')
        .set('Authorization', `Bearer ${premiumAccessToken}`)
        .expect(200);

      expect(response.body.sessionId).toBeDefined();
      expect(response.body.startedAt).toBeDefined();
      expect(response.body.status).toBe('active');
      expect(response.body.dailySessions).toBeDefined();
      expect(response.body.dailySessions.sessionsStartedThisMonth).toBeGreaterThan(0);

      // Verify database record
      const usage = await prisma.voiceUsage.findFirst({
        where: { userId: premiumUserId }
      });
      expect(usage).toBeTruthy();
      expect(usage?.sessionsStarted).toBeGreaterThan(0);
    });

    it('should track session end with duration', async () => {
      // Start session first
      const startResponse = await request(app)
        .post('/api/v1/voice/session/start')
        .set('Authorization', `Bearer ${premiumAccessToken}`);

      const sessionId = startResponse.body.sessionId;

      // End session with duration
      const duration = 120; // 2 minutes
      const messageCount = 10;

      const endResponse = await request(app)
        .post('/api/v1/voice/session/end')
        .set('Authorization', `Bearer ${premiumAccessToken}`)
        .send({
          sessionId,
          duration,
          messageCount
        })
        .expect(200);

      expect(endResponse.body.sessionId).toBeDefined();
      expect(endResponse.body.endedAt).toBeDefined();
      expect(endResponse.body.status).toBe('completed');
      expect(endResponse.body.dailySessions).toBeDefined();

      // Verify database record updated
      const usage = await prisma.voiceUsage.findFirst({
        where: { userId: premiumUserId }
      });
      expect(usage).toBeTruthy();
      expect(usage?.sessionsCompleted).toBeGreaterThan(0);
      expect(usage?.secondsUsed).toBeGreaterThanOrEqual(120);
    });

    it('should increment session counters correctly', async () => {
      // Start multiple sessions
      await request(app)
        .post('/api/v1/voice/session/start')
        .set('Authorization', `Bearer ${premiumAccessToken}`);

      await request(app)
        .post('/api/v1/voice/session/start')
        .set('Authorization', `Bearer ${premiumAccessToken}`);

      // Verify count
      const usage = await prisma.voiceUsage.findFirst({
        where: { userId: premiumUserId }
      });
      expect(usage?.sessionsStarted).toBeGreaterThanOrEqual(2);
    });
  });

  describe('Soft Cap Detection', () => {
    it('should detect soft cap when 100 minutes reached', async () => {
      // Set usage to soft cap threshold
      const { start, end } = {
        start: new Date(Date.UTC(new Date().getUTCFullYear(), new Date().getUTCMonth(), 1)),
        end: new Date(Date.UTC(new Date().getUTCFullYear(), new Date().getUTCMonth() + 1, 1))
      };

      await prisma.voiceUsage.create({
        data: {
          userId: premiumUserId,
          periodStart: start,
          periodEnd: end,
          secondsUsed: 100 * 60, // 100 minutes
          sessionsStarted: 5,
          sessionsCompleted: 5
        }
      });

      const response = await request(app)
        .post('/api/v1/voice/authorize')
        .set('Authorization', `Bearer ${premiumAccessToken}`)
        .send({ sessionId: 'test-session' })
        .expect(200);

      expect(response.body.dailySessions.softCapReached).toBe(true);
      expect(response.body.dailySessions.status).toBe('soft_cap_reached');
      expect(response.body.message).toContain('soft-cap mode');
    });

    it('should track soft cap status in session end', async () => {
      // Start session
      const startResponse = await request(app)
        .post('/api/v1/voice/session/start')
        .set('Authorization', `Bearer ${premiumAccessToken}`);

      // Set usage just below threshold
      const { start, end } = {
        start: new Date(Date.UTC(new Date().getUTCFullYear(), new Date().getUTCMonth(), 1)),
        end: new Date(Date.UTC(new Date().getUTCFullYear(), new Date().getUTCMonth() + 1, 1))
      };

      await prisma.voiceUsage.updateMany({
        where: {
          userId: premiumUserId,
          periodStart: start,
          periodEnd: end
        },
        data: {
          secondsUsed: 99 * 60 // Just below 100 minutes
        }
      });

      // End session with enough duration to hit soft cap
      const endResponse = await request(app)
        .post('/api/v1/voice/session/end')
        .set('Authorization', `Bearer ${premiumAccessToken}`)
        .send({
          sessionId: startResponse.body.sessionId,
          duration: 120, // 2 minutes - should push over soft cap
          messageCount: 5
        })
        .expect(200);

      // Should now show soft cap reached
      expect(endResponse.body.dailySessions.softCapReached).toBe(true);
    });
  });

  describe('Voice Status Endpoint', () => {
    it('should return service status', async () => {
      const response = await request(app)
        .get('/api/v1/voice/status')
        .expect(200);

      expect(response.body.status).toBe('online');
      expect(response.body.openaiConfigured).toBeDefined();
      expect(response.body.model).toBeDefined();
    });
  });

  describe('End-to-End Voice Flow', () => {
    it('should complete full voice session lifecycle', async () => {
      // 1. Authorize
      const authResponse = await request(app)
        .post('/api/v1/voice/authorize')
        .set('Authorization', `Bearer ${premiumAccessToken}`)
        .send({ sessionId: 'e2e-session-123' })
        .expect(200);

      expect(authResponse.body.authorized).toBe(true);

      // 2. Start session
      const startResponse = await request(app)
        .post('/api/v1/voice/session/start')
        .set('Authorization', `Bearer ${premiumAccessToken}`)
        .expect(200);

      const sessionId = startResponse.body.sessionId;
      expect(sessionId).toBeDefined();

      // 3. End session
      const endResponse = await request(app)
        .post('/api/v1/voice/session/end')
        .set('Authorization', `Bearer ${premiumAccessToken}`)
        .send({
          sessionId,
          duration: 180, // 3 minutes
          messageCount: 15
        })
        .expect(200);

      expect(endResponse.body.status).toBe('completed');

      // 4. Verify usage recorded
      const usage = await prisma.voiceUsage.findFirst({
        where: { userId: premiumUserId }
      });
      expect(usage).toBeTruthy();
      expect(usage?.sessionsStarted).toBeGreaterThan(0);
      expect(usage?.sessionsCompleted).toBeGreaterThan(0);
      expect(usage?.secondsUsed).toBeGreaterThanOrEqual(180);
    });
  });
});

