import request from 'supertest';
import { app } from '../src/server';
import { prisma } from './setup';

describe('Chat Endpoints', () => {
  let accessToken: string;
  let userId: string;

  beforeEach(async () => {
    // Register and get access token
    const response = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'test@example.com',
        password: 'TestPassword123!',
        name: 'Test User'
      });
    
    accessToken = response.body.data.tokens.accessToken;
    userId = response.body.data.user.id;
  });

  describe('POST /api/v1/chat/messages', () => {
    it('should send a chat message successfully', async () => {
      const messageData = {
        content: 'Hello, I need someone to talk to.',
        sessionId: '123e4567-e89b-12d3-a456-426614174000'
      };

      const response = await request(app)
        .post('/api/v1/chat/messages')
        .set('Authorization', `Bearer ${accessToken}`)
        .send(messageData)
        .expect(201);

      expect(response.body.success).toBe(true);
      expect(response.body.data.userMessage.content).toBe(messageData.content);
      expect(response.body.data.aiResponse.content).toBeDefined();
      expect(response.body.data.aiResponse.role).toBe('ASSISTANT');

      // Verify message was saved to database
      const messages = await prisma.chatMessage.findMany({
        where: { userId }
      });
      expect(messages).toHaveLength(2); // User message + AI response
    });

    it('should detect crisis content', async () => {
      const messageData = {
        content: 'I want to hurt myself and end my life.'
      };

      const response = await request(app)
        .post('/api/v1/chat/messages')
        .set('Authorization', `Bearer ${accessToken}`)
        .send(messageData)
        .expect(201);

      expect(response.body.success).toBe(true);
      expect(response.body.data.crisisDetected).toBe(true);
      expect(response.body.data.crisisLevel).toBeDefined();

      // Verify crisis event was created
      const crisisEvents = await prisma.crisisEvent.findMany({
        where: { userId }
      });
      expect(crisisEvents).toHaveLength(1);
      expect(crisisEvents[0]?.level).toBeDefined();
    });

    it('should filter sensitive content', async () => {
      const messageData = {
        content: 'My SSN is 123-45-6789 and my credit card is 4111-1111-1111-1111.'
      };

      const response = await request(app)
        .post('/api/v1/chat/messages')
        .set('Authorization', `Bearer ${accessToken}`)
        .send(messageData)
        .expect(201);

      expect(response.body.success).toBe(true);
      
      // Verify sensitive content was filtered in database
      const message = await prisma.chatMessage.findFirst({
        where: { userId, role: 'USER' }
      });
      expect(message?.content).toContain('[REDACTED]');
    });

    it('should enforce daily message limit for free users', async () => {
      // Send messages up to the limit
      for (let i = 0; i < 10; i++) {
        await request(app)
          .post('/api/v1/chat/messages')
          .set('Authorization', `Bearer ${accessToken}`)
          .send({ content: `Message ${i + 1}` })
          .expect(201);
      }

      // Next message should be rejected
      const response = await request(app)
        .post('/api/v1/chat/messages')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ content: 'This should be rejected' })
        .expect(402);

      expect(response.body.success).toBe(false);
      expect(response.body.message).toContain('Daily message limit');
    });

    it('should reject empty message', async () => {
      const response = await request(app)
        .post('/api/v1/chat/messages')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ content: '' })
        .expect(400);

      expect(response.body.success).toBe(false);
    });

    it('should reject message that is too long', async () => {
      const longMessage = 'a'.repeat(5000);
      
      const response = await request(app)
        .post('/api/v1/chat/messages')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ content: longMessage })
        .expect(400);

      expect(response.body.success).toBe(false);
    });
  });

  describe('GET /api/v1/chat/messages', () => {
    beforeEach(async () => {
      // Create some test messages
      await prisma.chatMessage.createMany({
        data: [
          {
            userId,
            role: 'USER',
            content: 'First message'
          },
          {
            userId,
            role: 'ASSISTANT',
            content: 'First response'
          },
          {
            userId,
            role: 'USER',
            content: 'Second message'
          },
          {
            userId,
            role: 'ASSISTANT',
            content: 'Second response'
          }
        ]
      });
    });

    it('should retrieve chat messages', async () => {
      const response = await request(app)
        .get('/api/v1/chat/messages')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.messages).toHaveLength(4);
      expect(response.body.data.pagination).toBeDefined();
    });

    it('should support pagination', async () => {
      const response = await request(app)
        .get('/api/v1/chat/messages?page=1&limit=2')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.messages).toHaveLength(2);
      expect(response.body.data.pagination.page).toBe(1);
      expect(response.body.data.pagination.limit).toBe(2);
      expect(response.body.data.pagination.totalCount).toBe(4);
    });

    it('should filter by session ID', async () => {
      const sessionId = '123e4567-e89b-12d3-a456-426614174000';
      
      // Create message with specific session ID
      await prisma.chatMessage.create({
        data: {
          userId,
          role: 'USER',
          content: 'Session message',
          sessionId
        }
      });

      const response = await request(app)
        .get(`/api/v1/chat/messages?sessionId=${sessionId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.messages).toHaveLength(1);
      expect(response.body.data.messages[0].sessionId).toBe(sessionId);
    });
  });

  describe('DELETE /api/v1/chat/messages/:messageId', () => {
    let messageId: string;

    beforeEach(async () => {
      // Create a test message
      const message = await prisma.chatMessage.create({
        data: {
          userId,
          role: 'USER',
          content: 'Test message to delete'
        }
      });
      messageId = message.id;
    });

    it('should delete user message successfully', async () => {
      const response = await request(app)
        .delete(`/api/v1/chat/messages/${messageId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);

      // Verify message was deleted
      const message = await prisma.chatMessage.findUnique({
        where: { id: messageId }
      });
      expect(message).toBeNull();
    });

    it('should not delete AI messages', async () => {
      // Create AI message
      const aiMessage = await prisma.chatMessage.create({
        data: {
          userId,
          role: 'ASSISTANT',
          content: 'AI response'
        }
      });

      const response = await request(app)
        .delete(`/api/v1/chat/messages/${aiMessage.id}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(404);

      expect(response.body.success).toBe(false);
    });

    it('should not delete other users messages', async () => {
      // Create another user and message
      const otherUserResponse = await request(app)
        .post('/api/v1/auth/register')
        .send({
          email: 'other@example.com',
          password: 'TestPassword123!',
          name: 'Other User'
        });

      const otherMessage = await prisma.chatMessage.create({
        data: {
          userId: otherUserResponse.body.data.user.id,
          role: 'USER',
          content: 'Other users message'
        }
      });

      const response = await request(app)
        .delete(`/api/v1/chat/messages/${otherMessage.id}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(404);

      expect(response.body.success).toBe(false);
    });
  });

  describe('GET /api/v1/chat/sessions', () => {
    beforeEach(async () => {
      // Create messages with different session IDs
      const sessionId1 = '123e4567-e89b-12d3-a456-426614174001';
      const sessionId2 = '123e4567-e89b-12d3-a456-426614174002';

      await prisma.chatMessage.createMany({
        data: [
          { userId, role: 'USER', content: 'Message 1', sessionId: sessionId1 },
          { userId, role: 'ASSISTANT', content: 'Response 1', sessionId: sessionId1 },
          { userId, role: 'USER', content: 'Message 2', sessionId: sessionId2 },
          { userId, role: 'ASSISTANT', content: 'Response 2', sessionId: sessionId2 }
        ]
      });
    });

    it('should retrieve chat sessions', async () => {
      const response = await request(app)
        .get('/api/v1/chat/sessions')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.sessions).toHaveLength(2);
      
      const session = response.body.data.sessions[0];
      expect(session.sessionId).toBeDefined();
      expect(session.messageCount).toBeDefined();
      expect(session.lastActivity).toBeDefined();
      expect(session.latestMessage).toBeDefined();
    });
  });

  describe('GET /api/v1/chat/export', () => {
    beforeEach(async () => {
      // Create test messages
      await prisma.chatMessage.createMany({
        data: [
          { userId, role: 'USER', content: 'Export test message 1' },
          { userId, role: 'ASSISTANT', content: 'Export test response 1' }
        ]
      });
    });

    it('should export chat history as JSON', async () => {
      const response = await request(app)
        .get('/api/v1/chat/export?format=json')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(response.headers['content-type']).toContain('application/json');
      expect(response.body.messages).toHaveLength(2);
      expect(response.body.userId).toBe(userId);
    });

    it('should export chat history as text', async () => {
      const response = await request(app)
        .get('/api/v1/chat/export?format=txt')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(response.headers['content-type']).toContain('text/plain');
      expect(response.text).toContain('Export test message 1');
      expect(response.text).toContain('Export test response 1');
    });
  });

  describe('DELETE /api/v1/chat/clear', () => {
    beforeEach(async () => {
      // Create test messages
      await prisma.chatMessage.createMany({
        data: [
          { userId, role: 'USER', content: 'Message to clear 1' },
          { userId, role: 'ASSISTANT', content: 'Response to clear 1' },
          { userId, role: 'USER', content: 'Message to clear 2' },
          { userId, role: 'ASSISTANT', content: 'Response to clear 2' }
        ]
      });
    });

    it('should clear all chat history', async () => {
      const response = await request(app)
        .delete('/api/v1/chat/clear')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ confirmation: 'CLEAR_ALL_MESSAGES' })
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.deletedCount).toBe(4);

      // Verify messages were deleted
      const messages = await prisma.chatMessage.findMany({
        where: { userId }
      });
      expect(messages).toHaveLength(0);
    });

    it('should require confirmation', async () => {
      const response = await request(app)
        .delete('/api/v1/chat/clear')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ confirmation: 'WRONG_CONFIRMATION' })
        .expect(400);

      expect(response.body.success).toBe(false);
    });
  });
});
