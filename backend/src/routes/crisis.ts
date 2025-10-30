import { Router } from 'express';
import { body, query } from 'express-validator';
import { prisma } from '../utils/database';
import { validateRequest } from '../middleware/validation';
import { asyncHandler } from '../middleware/errorHandler';
import { auditEvents } from '../middleware/auditLogger';
import { logger, businessLogger } from '../utils/logger';

const router = Router();

/**
 * @swagger
 * /crisis/events:
 *   post:
 *     summary: Report a crisis event
 *     tags: [Crisis]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - level
 *               - message
 *             properties:
 *               level:
 *                 type: string
 *                 enum: [LOW, MEDIUM, HIGH, CRITICAL]
 *               message:
 *                 type: string
 *               actionTaken:
 *                 type: string
 *     responses:
 *       201:
 *         description: Crisis event reported successfully
 */
router.post('/events',
  [
    body('level').isIn(['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']).withMessage('Invalid crisis level'),
    body('message').isLength({ min: 1, max: 2000 }).withMessage('Message must be between 1 and 2000 characters'),
    body('actionTaken').optional().isLength({ max: 1000 }).withMessage('Action taken must be less than 1000 characters')
  ],
  validateRequest,
  asyncHandler(async (req, res) => {
    const userId = req.user!.id;
    const { level, message, actionTaken } = req.body;
    
    // Create crisis event
    const crisisEvent = await prisma.crisisEvent.create({
      data: {
        userId,
        level,
        message: message.substring(0, 500), // Truncate for privacy
        actionTaken,
        resolved: false
      },
      select: {
        id: true,
        level: true,
        message: true,
        actionTaken: true,
        resolved: true,
        createdAt: true
      }
    });
    
    // Log crisis event
    auditEvents.crisisEvent(userId, level, req);
    businessLogger.logCrisisEvent(userId, level, message, actionTaken);
    
    // Handle crisis response based on level
    await handleCrisisResponse(crisisEvent, userId);
    
    logger.error('Crisis event reported', {
      userId,
      crisisEventId: crisisEvent.id,
      level
    });
    
    res.status(201).json({
      success: true,
      message: 'Crisis event reported successfully',
      data: { 
        crisisEvent,
        resources: getCrisisResources(level)
      }
    });
  })
);

/**
 * @swagger
 * /crisis/events:
 *   get:
 *     summary: Get crisis events for user
 *     tags: [Crisis]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: resolved
 *         schema:
 *           type: boolean
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           minimum: 1
 *           maximum: 50
 *           default: 10
 *     responses:
 *       200:
 *         description: Crisis events retrieved successfully
 */
router.get('/events',
  [
    query('resolved').optional().isBoolean().toBoolean(),
    query('limit').optional().isInt({ min: 1, max: 50 }).toInt()
  ],
  validateRequest,
  asyncHandler(async (req, res) => {
    const userId = req.user!.id;
    const resolved = req.query.resolved as boolean;
    const limit = parseInt(req.query.limit as string) || 10;
    
    const where: any = { userId };
    if (typeof resolved === 'boolean') {
      where.resolved = resolved;
    }
    
    const events = await prisma.crisisEvent.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: limit,
      select: {
        id: true,
        level: true,
        message: true,
        actionTaken: true,
        resolved: true,
        createdAt: true,
        updatedAt: true
      }
    });
    
    res.json({
      success: true,
      data: { events }
    });
  })
);

/**
 * @swagger
 * /crisis/resources:
 *   get:
 *     summary: Get crisis support resources
 *     tags: [Crisis]
 *     responses:
 *       200:
 *         description: Crisis resources retrieved successfully
 */
router.get('/resources',
  asyncHandler(async (req, res) => {
    const resources = {
      immediate: {
        title: 'Immediate Help',
        description: 'If you are in immediate danger, please contact emergency services',
        contacts: [
          {
            name: 'Emergency Services',
            number: '911',
            description: 'For immediate life-threatening emergencies'
          },
          {
            name: 'National Suicide Prevention Lifeline',
            number: '988',
            description: '24/7 crisis support and suicide prevention'
          },
          {
            name: 'Crisis Text Line',
            number: 'Text HOME to 741741',
            description: '24/7 text-based crisis support'
          }
        ]
      },
      support: {
        title: 'Support Resources',
        description: 'Professional support and counseling services',
        resources: [
          {
            name: 'National Alliance on Mental Illness (NAMI)',
            website: 'https://nami.org',
            phone: '1-800-950-NAMI (6264)',
            description: 'Mental health support and resources'
          },
          {
            name: 'Mental Health America',
            website: 'https://mhanational.org',
            description: 'Mental health screening and resources'
          },
          {
            name: 'Substance Abuse and Mental Health Services Administration (SAMHSA)',
            website: 'https://samhsa.gov',
            phone: '1-800-662-HELP (4357)',
            description: 'Treatment referral and information service'
          }
        ]
      },
      coping: {
        title: 'Coping Strategies',
        description: 'Immediate coping techniques you can try',
        strategies: [
          {
            name: 'Deep Breathing',
            description: 'Take slow, deep breaths. Inhale for 4 counts, hold for 4, exhale for 4.'
          },
          {
            name: 'Grounding Technique',
            description: 'Name 5 things you can see, 4 you can touch, 3 you can hear, 2 you can smell, 1 you can taste.'
          },
          {
            name: 'Reach Out',
            description: 'Contact a trusted friend, family member, or mental health professional.'
          },
          {
            name: 'Safe Space',
            description: 'Go to a safe, comfortable place where you feel secure.'
          }
        ]
      }
    };
    
    res.json({
      success: true,
      data: { resources }
    });
  })
);

// Helper function to handle crisis response
async function handleCrisisResponse(crisisEvent: any, userId: string): Promise<void> {
  const { level, id } = crisisEvent;
  
  try {
    switch (level) {
      case 'CRITICAL':
        // Immediate intervention required
        logger.error('CRITICAL crisis event - immediate intervention required', {
          userId,
          crisisEventId: id
        });
        
        // TODO: Implement immediate response
        // - Send alert to crisis response team
        // - Trigger emergency contact notification
        // - Escalate to human support immediately
        break;
        
      case 'HIGH':
        // Urgent response needed within 1 hour
        logger.warn('HIGH crisis event - urgent response needed', {
          userId,
          crisisEventId: id
        });
        
        // TODO: Implement urgent response
        // - Queue for priority human support
        // - Send notification to support team
        // - Follow up within 1 hour
        break;
        
      case 'MEDIUM':
        // Response needed within 24 hours
        logger.warn('MEDIUM crisis event - response needed within 24h', {
          userId,
          crisisEventId: id
        });
        
        // TODO: Implement standard response
        // - Queue for human support
        // - Send resources and coping strategies
        // - Follow up within 24 hours
        break;
        
      case 'LOW':
        // Monitor and provide resources
        logger.info('LOW crisis event - monitoring and resources provided', {
          userId,
          crisisEventId: id
        });
        
        // TODO: Implement monitoring response
        // - Provide self-help resources
        // - Schedule check-in
        // - Monitor for escalation
        break;
    }
    
    // Update crisis event with response initiated
    await prisma.crisisEvent.update({
      where: { id },
      data: {
        actionTaken: `Crisis response initiated for ${level} level event`,
        updatedAt: new Date()
      }
    });
    
  } catch (error) {
    logger.error('Crisis response handling failed', {
      userId,
      crisisEventId: id,
      level,
      error: error instanceof Error ? error.message : 'Unknown error'
    });
  }
}

// Helper function to get crisis resources based on level
function getCrisisResources(level: string) {
  const baseResources = {
    emergencyNumber: '988',
    crisisTextLine: 'Text HOME to 741741',
    emergencyServices: '911'
  };
  
  switch (level) {
    case 'CRITICAL':
      return {
        ...baseResources,
        immediateAction: 'Please contact emergency services (911) or the National Suicide Prevention Lifeline (988) immediately.',
        priority: 'IMMEDIATE'
      };
      
    case 'HIGH':
      return {
        ...baseResources,
        immediateAction: 'Please consider contacting the National Suicide Prevention Lifeline (988) or Crisis Text Line.',
        priority: 'URGENT'
      };
      
    case 'MEDIUM':
      return {
        ...baseResources,
        immediateAction: 'Consider reaching out to a mental health professional or trusted person.',
        priority: 'IMPORTANT'
      };
      
    default:
      return {
        ...baseResources,
        immediateAction: 'Take care of yourself and consider talking to someone you trust.',
        priority: 'SUPPORTIVE'
      };
  }
}

export default router;
