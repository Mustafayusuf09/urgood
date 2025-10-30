import { Router } from 'express';
import { body, query, param } from 'express-validator';
import { prisma } from '../utils/database';
import { validateRequest, validationRules, detectCrisisContent, filterSensitiveContent } from '../middleware/validation';
import { detectCrisisLevel, getCopingExercise, CRISIS_PROTOCOLS } from '../services/therapyKnowledgeBase';
import { EnhancedOpenAIService } from '../services/enhancedOpenAIService';
import { asyncHandler } from '../middleware/errorHandler';
import { requireSubscription, rateLimitByUser } from '../middleware/auth';
import { auditEvents } from '../middleware/auditLogger';
import { logger, businessLogger } from '../utils/logger';
import { cacheService } from '../utils/redis';
import { config } from '../config/config';

const router = Router();

// OpenAI service (would be imported from a service file)
class OpenAIService {
  async generateResponse(message: string, conversationHistory: any[], userId: string): Promise<string> {
    // This is a mock implementation - in reality, this would call OpenAI API
    // with proper error handling, rate limiting, and cost tracking
    
    // Simulate AI response generation
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    const responses = [
      "I understand you're going through a difficult time. Can you tell me more about what's been on your mind?",
      "That sounds challenging. How are you feeling about this situation right now?",
      "Thank you for sharing that with me. What would be most helpful for you right now?",
      "I hear you. It's completely normal to feel this way. What usually helps you when you're feeling like this?",
      "That's a lot to process. Would you like to talk about what's been the most difficult part?"
    ];
    
    return responses[Math.floor(Math.random() * responses.length)];
  }
}

const openAIService = new OpenAIService();
const enhancedOpenAIService = new EnhancedOpenAIService(process.env.OPENAI_API_KEY || '');

// Helper function to get user insights for personalization
async function getUserInsights(userId: string) {
  try {
    // Get user preferences
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { preferences: true }
    });

    // Get recent mood entries to identify patterns
    const recentMoods = await prisma.moodEntry.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 30,
      select: { mood: true, createdAt: true, notes: true }
    });

    // Analyze conversation history for successful techniques
    const recentChats = await prisma.chatMessage.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 50,
      select: { role: true, content: true, createdAt: true }
    });

    // Extract insights from conversation patterns
    const patterns = enhancedOpenAIService.analyzeUserPatterns(recentChats);

    return {
      preferences: user?.preferences as any,
      successfulTechniques: patterns.preferredTechniques,
      triggers: patterns.commonTriggers,
      patterns: patterns.moodPatterns,
      moodTrends: recentMoods.map(mood => ({
        mood: mood.mood,
        date: mood.createdAt
      }))
    };
  } catch (error) {
    logger.error('Error getting user insights', { userId, error });
    return null;
  }
}

/**
 * @swagger
 * /chat/messages:
 *   post:
 *     summary: Send a chat message
 *     tags: [Chat]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - content
 *             properties:
 *               content:
 *                 type: string
 *                 minLength: 1
 *                 maxLength: 4000
 *               sessionId:
 *                 type: string
 *                 format: uuid
 *               metadata:
 *                 type: object
 *     responses:
 *       201:
 *         description: Message sent successfully
 *       402:
 *         description: Premium subscription required
 *       429:
 *         description: Rate limit exceeded
 */
router.post('/messages',
  validationRules.chatMessage,
  validateRequest,
  rateLimitByUser(60 * 1000, 10), // 10 messages per minute
  asyncHandler(async (req, res) => {
    const userId = req.user!.id;
    const { content, sessionId, metadata } = req.body;
    
    // Check subscription limits for free users
    if (req.user!.subscriptionStatus === 'FREE') {
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      
      const todayMessageCount = await prisma.chatMessage.count({
        where: {
          userId,
          role: 'USER',
          createdAt: { gte: today }
        }
      });
      
      const dailyLimit = (config as any).openai?.dailyMessageLimit ?? 10;
      if (todayMessageCount >= dailyLimit) {
        return res.status(402).json({
          success: false,
          message: 'Daily message limit reached. Upgrade to premium for unlimited messages.',
          code: 'DAILY_LIMIT_EXCEEDED'
        });
      }
    }
    
    // Filter sensitive content
    const { filtered: filteredContent, flagged } = filterSensitiveContent(content);
    
    if (flagged) {
      logger.warn('Sensitive content detected in message', {
        userId,
        originalLength: content.length,
        filteredLength: filteredContent.length
      });
    }
    
    // Enhanced crisis detection using therapy knowledge base
    const crisisDetection = detectCrisisLevel(content);
    const { isCrisis, level } = detectCrisisContent(content);
    
    // Use the more sophisticated detection if confidence is high
    const finalCrisisLevel = crisisDetection.confidence > 0.5 ? crisisDetection.level : level;
    const isEnhancedCrisis = crisisDetection.confidence > 0.3;
    
    if (isCrisis || isEnhancedCrisis) {
      // Create crisis event with enhanced detection data
      await prisma.crisisEvent.create({
        data: {
          userId,
          level: finalCrisisLevel,
          message: content.substring(0, 500), // Truncate for privacy
          resolved: false,
          metadata: {
            detectionConfidence: crisisDetection.confidence,
            detectionMethod: 'enhanced_therapy_kb'
          }
        }
      });
      
      // Log crisis event
      auditEvents.crisisEvent(userId, finalCrisisLevel, req);
      businessLogger.logCrisisEvent(userId, finalCrisisLevel, content);
      
      // Trigger enhanced crisis response workflow
      if (finalCrisisLevel === 'CRITICAL') {
        // Immediate escalation for critical cases
        logger.error('Critical crisis detected', { userId, content: content.substring(0, 100) });
        // TODO: Notify emergency contacts, trigger immediate intervention
      }
    }
    
    // Get recent conversation history
    const conversationHistory = await prisma.chatMessage.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 10,
      select: {
        role: true,
        content: true,
        createdAt: true
      }
    });
    
    // Save user message
    const userMessage = await prisma.chatMessage.create({
      data: {
        userId,
        role: 'USER',
        content: filteredContent,
        sessionId,
        metadata: {
          ...metadata,
          originalLength: content.length,
          filtered: flagged,
          crisisDetected: isCrisis,
          crisisLevel: isCrisis ? level : null
        }
      },
      select: {
        id: true,
        role: true,
        content: true,
        createdAt: true,
        metadata: true
      }
    });
    
    // Generate AI response
    let aiResponse: string;
    let aiMessageId: string | null = null;
    
    try {
      // Enhanced crisis response using therapy knowledge base
      if (isEnhancedCrisis || isCrisis) {
        const crisisProtocol = CRISIS_PROTOCOLS.find(p => p.level === finalCrisisLevel);
        if (crisisProtocol) {
          aiResponse = crisisProtocol.response;
          
          // Add resources for moderate to critical levels
          if (['MODERATE', 'HIGH', 'CRITICAL'].includes(finalCrisisLevel)) {
            aiResponse += '\n\nImmediate support resources:\n' + 
              crisisProtocol.resources.map(resource => `• ${resource}`).join('\n');
          }
          
          // For critical cases, add urgent messaging
          if (finalCrisisLevel === 'CRITICAL') {
            aiResponse = '🚨 ' + aiResponse + '\n\nThis is an emergency. Please reach out for help immediately.';
          }
        } else {
          // Fallback to original crisis response
          aiResponse = isCrisis && level === 'CRITICAL' 
            ? "I'm very concerned about what you've shared. Your safety is important. Please reach out to a crisis helpline immediately: National Suicide Prevention Lifeline: 988. Would you like me to help you find local emergency resources?"
            : "I hear that you're going through a really difficult time. Thank you for trusting me with this. While I'm here to support you, I want to make sure you have access to professional help if you need it. How are you feeling right now?";
        }
      } else {
        // Get user insights for personalization
        const userInsights = await getUserInsights(userId);
        
        // Use enhanced OpenAI service with therapy knowledge
        aiResponse = await enhancedOpenAIService.generateTherapyResponse(
          filteredContent,
          conversationHistory,
          userId,
          userInsights
        );
      }
      
      // Save AI response
      const aiMessage = await prisma.chatMessage.create({
        data: {
          userId,
          role: 'ASSISTANT',
          content: aiResponse,
          sessionId,
          metadata: {
            model: 'gpt-4o',
            tokens: aiResponse.length / 4, // Rough estimate
            cost: 0.001, // Rough estimate
            crisisResponse: isCrisis
          }
        },
        select: {
          id: true,
          role: true,
          content: true,
          createdAt: true,
          metadata: true
        }
      });
      
      aiMessageId = aiMessage.id;
      
      // Log AI interaction
      businessLogger.logAIInteraction(
        userId,
        'gpt-4o',
        aiResponse.length / 4,
        0.001,
        1000
      );
      
    } catch (error) {
      logger.error('AI response generation failed', {
        userId,
        error: error instanceof Error ? error.message : 'Unknown error'
      });
      
      aiResponse = "I'm sorry, I'm having trouble responding right now. Please try again in a moment.";
    }
    
    // Update user stats
    await prisma.user.update({
      where: { id: userId },
      data: {
        messagesThisWeek: { increment: 1 },
        lastActiveAt: new Date()
      }
    });
    
    // Clear relevant caches
    await cacheService.delete(`user_profile:${userId}`);
    
    logger.info('Chat message processed', {
      userId,
      messageId: userMessage.id,
      aiMessageId,
      crisisDetected: isCrisis,
      filtered: flagged
    });
    
    res.status(201).json({
      success: true,
      message: 'Message sent successfully',
      data: {
        userMessage,
        aiResponse: {
          id: aiMessageId,
          role: 'ASSISTANT',
          content: aiResponse,
          createdAt: new Date().toISOString()
        },
        crisisDetected: isCrisis,
        crisisLevel: isCrisis ? level : null
      }
    });
  })
);

/**
 * @swagger
 * /chat/messages:
 *   get:
 *     summary: Get chat message history
 *     tags: [Chat]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           minimum: 1
 *           default: 1
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           minimum: 1
 *           maximum: 100
 *           default: 20
 *       - in: query
 *         name: sessionId
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Messages retrieved successfully
 */
router.get('/messages',
  [
    query('page').optional().isInt({ min: 1 }).toInt(),
    query('limit').optional().isInt({ min: 1, max: 100 }).toInt(),
    query('sessionId').optional().isUUID()
  ],
  validateRequest,
  asyncHandler(async (req, res) => {
    const userId = req.user!.id;
    const page = parseInt(req.query.page as string) || 1;
    const limit = parseInt(req.query.limit as string) || 20;
    const sessionId = req.query.sessionId as string;
    const offset = (page - 1) * limit;
    
    // Build where clause
    const where: any = { userId };
    if (sessionId) {
      where.sessionId = sessionId;
    }
    
    // Get messages with pagination
    const [messages, totalCount] = await Promise.all([
      prisma.chatMessage.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: offset,
        take: limit,
        select: {
          id: true,
          role: true,
          content: true,
          sessionId: true,
          createdAt: true,
          metadata: true
        }
      }),
      prisma.chatMessage.count({ where })
    ]);
    
    const totalPages = Math.ceil(totalCount / limit);
    
    res.json({
      success: true,
      data: {
        messages: messages.reverse(), // Reverse to show oldest first
        pagination: {
          page,
          limit,
          totalCount,
          totalPages,
          hasNext: page < totalPages,
          hasPrev: page > 1
        }
      }
    });
  })
);

/**
 * @swagger
 * /chat/messages/{messageId}:
 *   delete:
 *     summary: Delete a chat message
 *     tags: [Chat]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: messageId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Message deleted successfully
 *       404:
 *         description: Message not found
 */
router.delete('/messages/:messageId',
  param('messageId').isUUID().withMessage('Invalid message ID'),
  validateRequest,
  asyncHandler(async (req, res) => {
    const userId = req.user!.id;
    const { messageId } = req.params;
    
    // Delete the message (only user's own messages)
    const deletedMessage = await prisma.chatMessage.deleteMany({
      where: {
        id: messageId,
        userId,
        role: 'USER' // Only allow deleting user messages, not AI responses
      }
    });
    
    if (deletedMessage.count === 0) {
      return res.status(404).json({
        success: false,
        message: 'Message not found or cannot be deleted'
      });
    }
    
    logger.info('Chat message deleted', {
      userId,
      messageId
    });
    
    res.json({
      success: true,
      message: 'Message deleted successfully'
    });
  })
);

/**
 * @swagger
 * /chat/sessions:
 *   get:
 *     summary: Get chat sessions
 *     tags: [Chat]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Sessions retrieved successfully
 */
router.get('/sessions',
  asyncHandler(async (req, res) => {
    const userId = req.user!.id;
    
    // Get distinct sessions with latest message info
    const sessions = await prisma.chatMessage.groupBy({
      by: ['sessionId'],
      where: { 
        userId,
        sessionId: { not: null }
      },
      _count: { id: true },
      _max: { createdAt: true }
    });
    
    // Get session details
    const sessionDetails = await Promise.all(
      sessions.map(async (session) => {
        const latestMessage = await prisma.chatMessage.findFirst({
          where: {
            userId,
            sessionId: session.sessionId
          },
          orderBy: { createdAt: 'desc' },
          select: {
            content: true,
            role: true,
            createdAt: true
          }
        });
        
        return {
          sessionId: session.sessionId,
          messageCount: session._count.id,
          lastActivity: session._max.createdAt,
          latestMessage: latestMessage?.content.substring(0, 100) + '...',
          latestMessageRole: latestMessage?.role
        };
      })
    );
    
    res.json({
      success: true,
      data: { sessions: sessionDetails }
    });
  })
);

/**
 * @swagger
 * /chat/export:
 *   get:
 *     summary: Export chat history
 *     tags: [Chat]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: format
 *         schema:
 *           type: string
 *           enum: [json, txt]
 *           default: json
 *       - in: query
 *         name: startDate
 *         schema:
 *           type: string
 *           format: date
 *       - in: query
 *         name: endDate
 *         schema:
 *           type: string
 *           format: date
 *     responses:
 *       200:
 *         description: Chat history exported successfully
 */
router.get('/export',
  [
    query('format').optional().isIn(['json', 'txt']),
    query('startDate').optional().isISO8601().toDate(),
    query('endDate').optional().isISO8601().toDate()
  ],
  validateRequest,
  asyncHandler(async (req, res) => {
    const userId = req.user!.id;
    const format = req.query.format as string || 'json';
    const startDate = req.query.startDate as Date;
    const endDate = req.query.endDate as Date;
    
    // Build date filter
    const dateFilter: any = {};
    if (startDate) dateFilter.gte = startDate;
    if (endDate) dateFilter.lte = endDate;
    
    // Get all messages
    const messages = await prisma.chatMessage.findMany({
      where: {
        userId,
        ...(Object.keys(dateFilter).length > 0 && { createdAt: dateFilter })
      },
      orderBy: { createdAt: 'asc' },
      select: {
        id: true,
        role: true,
        content: true,
        sessionId: true,
        createdAt: true
      }
    });
    
    // Log data export
    auditEvents.dataExport(userId, 'chat_history', req);
    
    if (format === 'txt') {
      // Generate text format
      const textContent = messages.map(msg => 
        `[${msg.createdAt.toISOString()}] ${msg.role}: ${msg.content}`
      ).join('\n\n');
      
      res.setHeader('Content-Type', 'text/plain');
      res.setHeader('Content-Disposition', 'attachment; filename="chat_history.txt"');
      res.send(textContent);
    } else {
      // JSON format
      res.setHeader('Content-Type', 'application/json');
      res.setHeader('Content-Disposition', 'attachment; filename="chat_history.json"');
      res.json({
        exportedAt: new Date().toISOString(),
        userId,
        messageCount: messages.length,
        messages
      });
    }
  })
);

/**
 * @swagger
 * /chat/clear:
 *   delete:
 *     summary: Clear all chat history
 *     tags: [Chat]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - confirmation
 *             properties:
 *               confirmation:
 *                 type: string
 *                 enum: ['CLEAR_ALL_MESSAGES']
 *     responses:
 *       200:
 *         description: Chat history cleared successfully
 */
router.delete('/clear',
  body('confirmation')
    .equals('CLEAR_ALL_MESSAGES')
    .withMessage('Confirmation must be "CLEAR_ALL_MESSAGES"'),
  validateRequest,
  asyncHandler(async (req, res) => {
    const userId = req.user!.id;
    
    // Delete all chat messages for the user
    const deletedMessages = await prisma.chatMessage.deleteMany({
      where: { userId }
    });
    
    logger.info('Chat history cleared', {
      userId,
      deletedCount: deletedMessages.count
    });
    
    res.json({
      success: true,
      message: 'Chat history cleared successfully',
      deletedCount: deletedMessages.count
    });
  })
);

export default router;
