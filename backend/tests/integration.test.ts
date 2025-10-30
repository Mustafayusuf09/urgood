import request from 'supertest';
import { app } from '../src/server';
import { prisma } from './setup';

describe('End-to-End Integration Tests', () => {
  describe('Complete User Journey', () => {
    let accessToken: string;
    let userId: string;
    let refreshToken: string;

    it('should complete full user registration and authentication flow', async () => {
      // 1. Register new user
      const registerResponse = await request(app)
        .post('/api/v1/auth/register')
        .send({
          email: 'integration@example.com',
          password: 'TestPassword123!',
          name: 'Integration Test User',
          timezone: 'UTC',
          language: 'en'
        })
        .expect(201);

      expect(registerResponse.body.success).toBe(true);
      accessToken = registerResponse.body.data.tokens.accessToken;
      refreshToken = registerResponse.body.data.tokens.refreshToken;
      userId = registerResponse.body.data.user.id;

      // 2. Verify user profile
      const profileResponse = await request(app)
        .get('/api/v1/users/profile')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(profileResponse.body.data.user.email).toBe('integration@example.com');
      expect(profileResponse.body.data.user.subscriptionStatus).toBe('FREE');

      // 3. Update profile
      const updateResponse = await request(app)
        .put('/api/v1/users/profile')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          name: 'Updated Integration User',
          timezone: 'America/New_York',
          preferences: {
            notifications: true,
            darkMode: false,
            crisisDetectionEnabled: true
          }
        })
        .expect(200);

      expect(updateResponse.body.data.user.name).toBe('Updated Integration User');
      expect(updateResponse.body.data.user.timezone).toBe('America/New_York');

      // 4. Send chat messages
      const chatResponse = await request(app)
        .post('/api/v1/chat/messages')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          content: 'Hello, I would like to talk about my day.',
          sessionId: '123e4567-e89b-12d3-a456-426614174000'
        })
        .expect(201);

      expect(chatResponse.body.data.userMessage.content).toBe('Hello, I would like to talk about my day.');
      expect(chatResponse.body.data.aiResponse.content).toBeDefined();

      // 5. Create mood entry
      const moodResponse = await request(app)
        .post('/api/v1/mood/entries')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          mood: 4,
          tags: ['happy', 'productive'],
          notes: 'Had a great day at work!'
        })
        .expect(201);

      expect(moodResponse.body.data.moodEntry.mood).toBe(4);
      expect(moodResponse.body.data.moodEntry.tags).toEqual(['happy', 'productive']);

      // 6. Get user statistics
      const statsResponse = await request(app)
        .get('/api/v1/users/stats')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(statsResponse.body.data.stats.totalMessages).toBeGreaterThan(0);
      expect(statsResponse.body.data.stats.totalCheckins).toBe(1);

      // 7. Get analytics dashboard
      const analyticsResponse = await request(app)
        .get('/api/v1/analytics/dashboard')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(analyticsResponse.body.data.dashboard.overview).toBeDefined();
      expect(analyticsResponse.body.data.dashboard.periodStats).toBeDefined();

      // 8. Refresh token
      const refreshResponse = await request(app)
        .post('/api/v1/auth/refresh')
        .send({ refreshToken })
        .expect(200);

      expect(refreshResponse.body.data.tokens.accessToken).toBeDefined();
      const newAccessToken = refreshResponse.body.data.tokens.accessToken;

      // 9. Use new token
      const newProfileResponse = await request(app)
        .get('/api/v1/users/profile')
        .set('Authorization', `Bearer ${newAccessToken}`)
        .expect(200);

      expect(newProfileResponse.body.data.user.id).toBe(userId);

      // 10. Logout
      const logoutResponse = await request(app)
        .post('/api/v1/auth/logout')
        .set('Authorization', `Bearer ${newAccessToken}`)
        .expect(200);

      expect(logoutResponse.body.success).toBe(true);

      // 11. Verify token is invalidated
      await request(app)
        .get('/api/v1/users/profile')
        .set('Authorization', `Bearer ${newAccessToken}`)
        .expect(401);
    });
  });

  describe('Crisis Detection and Response Flow', () => {
    let accessToken: string;
    let userId: string;

    beforeEach(async () => {
      const response = await request(app)
        .post('/api/v1/auth/register')
        .send({
          email: 'crisis@example.com',
          password: 'TestPassword123!',
          name: 'Crisis Test User'
        });
      
      accessToken = response.body.data.tokens.accessToken;
      userId = response.body.data.user.id;
    });

    it('should handle crisis detection and response workflow', async () => {
      // 1. Send message with crisis content
      const crisisMessage = 'I am feeling hopeless and want to hurt myself';
      
      const chatResponse = await request(app)
        .post('/api/v1/chat/messages')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ content: crisisMessage })
        .expect(201);

      expect(chatResponse.body.data.crisisDetected).toBe(true);
      expect(chatResponse.body.data.crisisLevel).toBeDefined();

      // 2. Verify crisis event was created
      const crisisEvents = await prisma.crisisEvent.findMany({
        where: { userId }
      });
      expect(crisisEvents).toHaveLength(1);
      expect(crisisEvents[0]?.level).toBeDefined();

      // 3. Get crisis resources
      const resourcesResponse = await request(app)
        .get('/api/v1/crisis/resources')
        .expect(200);

      expect(resourcesResponse.body.data.resources.immediate).toBeDefined();
      expect(resourcesResponse.body.data.resources.support).toBeDefined();
      expect(resourcesResponse.body.data.resources.coping).toBeDefined();

      // 4. Check crisis events endpoint
      const eventsResponse = await request(app)
        .get('/api/v1/crisis/events')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(eventsResponse.body.data.events).toHaveLength(1);
      expect(eventsResponse.body.data.events[0].level).toBeDefined();
    });
  });

  describe('Subscription and Billing Flow', () => {
    let accessToken: string;
    let userId: string;

    beforeEach(async () => {
      const response = await request(app)
        .post('/api/v1/auth/register')
        .send({
          email: 'billing@example.com',
          password: 'TestPassword123!',
          name: 'Billing Test User'
        });
      
      accessToken = response.body.data.tokens.accessToken;
      userId = response.body.data.user.id;
    });

    it('should handle subscription workflow', async () => {
      // 1. Get available plans
      const plansResponse = await request(app)
        .get('/api/v1/billing/plans')
        .expect(200);

      expect(plansResponse.body.data.plans).toHaveLength(2);
      const corePlan = plansResponse.body.data.plans.find((p: any) => p.id === 'core_monthly');
      expect(corePlan).toBeDefined();

      // 2. Check initial subscription status
      const initialStatusResponse = await request(app)
        .get('/api/v1/billing/subscription')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(initialStatusResponse.body.data.subscription.status).toBe('FREE');

      // 3. Create subscription (mock)
      const subscribeResponse = await request(app)
        .post('/api/v1/billing/subscribe')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          planId: 'core_monthly',
          paymentMethodId: 'pm_test_card'
        })
        .expect(201);

      expect(subscribeResponse.body.success).toBe(true);
      expect(subscribeResponse.body.data.status).toBe('PREMIUM_MONTHLY');

      // 4. Verify subscription status updated
      const updatedStatusResponse = await request(app)
        .get('/api/v1/billing/subscription')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(updatedStatusResponse.body.data.subscription.status).toBe('PREMIUM_MONTHLY');

      // 5. Test premium features (unlimited messages)
      // Send more than free limit
      for (let i = 0; i < 15; i++) {
        await request(app)
          .post('/api/v1/chat/messages')
          .set('Authorization', `Bearer ${accessToken}`)
          .send({ content: `Premium message ${i + 1}` })
          .expect(201);
      }

      // 6. Cancel subscription
      const cancelResponse = await request(app)
        .post('/api/v1/billing/cancel')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(cancelResponse.body.success).toBe(true);

      // 7. Verify cancellation
      const cancelledStatusResponse = await request(app)
        .get('/api/v1/billing/subscription')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(cancelledStatusResponse.body.data.subscription.status).toBe('CANCELLED');
    });
  });

  describe('Data Export and Privacy Flow', () => {
    let accessToken: string;
    let userId: string;

    beforeEach(async () => {
      const response = await request(app)
        .post('/api/v1/auth/register')
        .send({
          email: 'privacy@example.com',
          password: 'TestPassword123!',
          name: 'Privacy Test User'
        });
      
      accessToken = response.body.data.tokens.accessToken;
      userId = response.body.data.user.id;

      // Create some test data
      await request(app)
        .post('/api/v1/chat/messages')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ content: 'Test message for export' });

      await request(app)
        .post('/api/v1/mood/entries')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ mood: 3, tags: ['neutral'], notes: 'Test mood entry' });
    });

    it('should handle data export and account deletion', async () => {
      // 1. Export user data
      const exportResponse = await request(app)
        .get('/api/v1/users/export-data')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(exportResponse.body.data.user).toBeDefined();
      expect(exportResponse.body.data.chatMessages).toHaveLength(2); // User + AI message
      expect(exportResponse.body.data.moodEntries).toHaveLength(1);

      // 2. Export chat history
      const chatExportResponse = await request(app)
        .get('/api/v1/chat/export?format=json')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(chatExportResponse.body.messages).toHaveLength(2);

      // 3. Delete account
      const deleteResponse = await request(app)
        .delete('/api/v1/users/delete-account')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          password: 'TestPassword123!',
          confirmation: 'DELETE_MY_ACCOUNT'
        })
        .expect(200);

      expect(deleteResponse.body.success).toBe(true);

      // 4. Verify account is deleted (soft delete)
      const user = await prisma.user.findUnique({
        where: { id: userId }
      });
      expect(user?.deletedAt).toBeTruthy();

      // 5. Verify cannot login with deleted account
      await request(app)
        .post('/api/v1/auth/login')
        .send({
          email: 'privacy@example.com',
          password: 'TestPassword123!'
        })
        .expect(401);
    });
  });

  describe('Rate Limiting and Security', () => {
    let accessToken: string;

    beforeEach(async () => {
      const response = await request(app)
        .post('/api/v1/auth/register')
        .send({
          email: 'security@example.com',
          password: 'TestPassword123!',
          name: 'Security Test User'
        });
      
      accessToken = response.body.data.tokens.accessToken;
    });

    it('should enforce rate limiting', async () => {
      // Test rate limiting on chat messages (10 per minute for free users)
      const promises = [];
      
      // Send 10 messages (should succeed)
      for (let i = 0; i < 10; i++) {
        promises.push(
          request(app)
            .post('/api/v1/chat/messages')
            .set('Authorization', `Bearer ${accessToken}`)
            .send({ content: `Rate limit test message ${i + 1}` })
        );
      }

      const responses = await Promise.all(promises);
      responses.forEach(response => {
        expect(response.status).toBe(201);
      });

      // 11th message should be rate limited
      const rateLimitedResponse = await request(app)
        .post('/api/v1/chat/messages')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ content: 'This should be rate limited' });

      expect(rateLimitedResponse.status).toBe(429);
      expect(rateLimitedResponse.body.message).toContain('Rate limit exceeded');
    });

    it('should validate input and sanitize content', async () => {
      // Test XSS prevention
      const xssPayload = '<script>alert("xss")</script>Hello';
      
      const response = await request(app)
        .post('/api/v1/chat/messages')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ content: xssPayload })
        .expect(201);

      // Verify XSS was sanitized
      const message = await prisma.chatMessage.findFirst({
        where: { 
          userId: response.body.data.userMessage.userId,
          role: 'USER'
        }
      });
      expect(message?.content).not.toContain('<script>');
    });
  });

  describe('Health and Monitoring', () => {
    it('should provide health check endpoint', async () => {
      const response = await request(app)
        .get('/health')
        .expect(200);

      expect(response.body.status).toBeDefined();
      expect(response.body.services).toBeDefined();
      expect(response.body.services.database).toBeDefined();
    });

    it('should provide API documentation', async () => {
      const response = await request(app)
        .get('/api/docs')
        .expect(200);

      expect(response.text).toContain('swagger');
    });
  });
});
