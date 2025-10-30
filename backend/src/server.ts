import express from 'express';
import cors from 'cors';
import { corsMiddleware, socketCorsConfig, webhookCorsConfig } from './middleware/corsConfig';
import helmet from 'helmet';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import slowDown from 'express-slow-down';
import mongoSanitize from 'express-mongo-sanitize';
import hpp from 'hpp';
import morgan from 'morgan';
import { createServer } from 'http';
import { Server as SocketIOServer } from 'socket.io';
import swaggerUi from 'swagger-ui-express';
import swaggerJSDoc from 'swagger-jsdoc';

import { config } from './config/config';
import { logger } from './utils/logger';
import { initializeSentry } from './utils/sentry';
import { errorHandler } from './middleware/errorHandler';
import { notFoundHandler } from './middleware/notFoundHandler';
import { authMiddleware } from './middleware/auth';
import { apiVersioning, responseTransformer, mentalHealthResponseTransformer, API_VERSIONS, VersionStrategy } from './middleware/apiVersioning';
import { sanitizeInput, validateContentLength } from './middleware/requestValidation';
import { auditLogger } from './middleware/auditLogger';
import { 
  healthCheck, 
  readinessCheck, 
  livenessCheck, 
  startupCheck, 
  detailedHealthCheck,
  loadBalancerHealthCheck,
  deepHealthCheck,
  metricsEndpoint,
  statusPageEndpoint 
} from './middleware/healthCheck';
import { prisma } from './utils/database';
import { redis } from './utils/redis';

// Import routes
import authRoutes from './routes/auth';
import userRoutes from './routes/users';
import chatRoutes from './routes/chat';
import moodRoutes from './routes/mood';
import crisisRoutes from './routes/crisis';
import analyticsRoutes from './routes/analytics';
import billingRoutes from './routes/billing';
import adminRoutes from './routes/admin';
// import { voiceChatRouter, setupVoiceWebSocket } from './routes/voiceChat';
import voiceRoutes from './routes/voice';
import webhookRoutes from './routes/webhooks';

// Initialize Sentry first (must be before other imports)
initializeSentry();

const app = express();
const server = createServer(app);
const io = new SocketIOServer(server, {
  cors: socketCorsConfig
});

// Swagger configuration
const swaggerOptions = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'UrGood API',
      version: '1.0.0',
      description: 'Production-ready API for UrGood mental health app',
      contact: {
        name: 'UrGood Team',
        email: 'api@urgood.app'
      }
    },
    servers: [
      {
        url: `http://localhost:${config.port}/api/v1`,
        description: 'Development server'
      },
      {
        url: 'https://api.urgood.app/v1',
        description: 'Production server'
      }
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT'
        }
      }
    }
  },
  apis: ['./src/routes/*.ts']
};

const swaggerSpec = swaggerJSDoc(swaggerOptions);

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'"],
      fontSrc: ["'self'"],
      objectSrc: ["'none'"],
      mediaSrc: ["'self'"],
      frameSrc: ["'none'"]
    }
  },
  crossOriginEmbedderPolicy: false
}));

// Enhanced CORS configuration with production domains
app.use(corsMiddleware());

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Compression
app.use(compression());

// Security sanitization
app.use(mongoSanitize());
app.use(hpp());

// Logging
if (config.nodeEnv !== 'test') {
  app.use(morgan('combined', {
    stream: {
      write: (message: string) => logger.info(message.trim())
    }
  }));
}

// Rate limiting
const limiter = rateLimit({
  windowMs: config.rateLimit.windowMs,
  max: config.rateLimit.maxRequests,
  message: {
    error: 'Too many requests from this IP, please try again later.',
    retryAfter: Math.ceil(config.rateLimit.windowMs / 1000)
  },
  standardHeaders: true,
  legacyHeaders: false,
  skip: (req) => {
    // Skip rate limiting for health checks
    return req.path === '/health' || req.path === '/api/v1/health';
  }
});

app.use(limiter);

// Slow down repeated requests
const speedLimiter = slowDown({
  windowMs: 15 * 60 * 1000, // 15 minutes
  delayAfter: 50, // Allow 50 requests per windowMs without delay
  delayMs: 500, // Add 500ms delay per request after delayAfter
  maxDelayMs: 20000, // Maximum delay of 20 seconds
});

app.use(speedLimiter);

// Health check endpoints (before auth middleware)
app.get('/health', healthCheck);
app.get('/api/v1/health', healthCheck);

// Kubernetes health checks
app.get('/health/ready', readinessCheck);
app.get('/health/live', livenessCheck);
app.get('/health/startup', startupCheck);

// Load balancer health checks
app.get('/health/lb', loadBalancerHealthCheck);
app.get('/ping', loadBalancerHealthCheck);

// Detailed monitoring endpoints
app.get('/health/detailed', detailedHealthCheck);
app.get('/health/deep', deepHealthCheck);

// Metrics and status endpoints
app.get('/metrics', metricsEndpoint);
app.get('/status', statusPageEndpoint);

// API documentation
app.use('/api/docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

// Audit logging middleware
app.use(auditLogger);

// API routes with versioning and authentication
const apiRouter = express.Router();

// Apply API versioning middleware
apiRouter.use(apiVersioning({
  strategy: VersionStrategy.URL_PATH, // Use URL path strategy: /api/v1/...
  defaultVersion: API_VERSIONS.CURRENT,
  strict: false // Allow fallback to default version
}));

// Apply input validation and sanitization
apiRouter.use(validateContentLength(10 * 1024 * 1024)); // 10MB limit
apiRouter.use(sanitizeInput);

// Apply response transformers
apiRouter.use(responseTransformer);
apiRouter.use(mentalHealthResponseTransformer);

// Add API version info endpoint
apiRouter.get('/version', (req, res) => {
  res.json({
    success: true,
    data: {
      current: API_VERSIONS.CURRENT,
      supported: API_VERSIONS.SUPPORTED,
      deprecated: API_VERSIONS.DEPRECATED,
      requestedVersion: req.apiVersion,
      detectionMethod: req.versionDetectionMethod
    }
  });
});

// Public routes (no auth required)
apiRouter.use('/auth', authRoutes);

// Webhook routes (raw body parsing for Stripe) with restricted CORS
app.use('/api/v1/webhooks', cors(webhookCorsConfig), express.raw({ type: 'application/json' }), webhookRoutes);

// Protected routes (auth required)
apiRouter.use('/users', authMiddleware, userRoutes);
apiRouter.use('/chat', authMiddleware, chatRoutes);
apiRouter.use('/mood', authMiddleware, moodRoutes);
apiRouter.use('/crisis', authMiddleware, crisisRoutes);
apiRouter.use('/analytics', authMiddleware, analyticsRoutes);
apiRouter.use('/billing', authMiddleware, billingRoutes);
apiRouter.use('/admin', authMiddleware, adminRoutes);
// apiRouter.use('/voice-chat', voiceChatRouter);
apiRouter.use('/voice', voiceRoutes);

app.use('/api/v1', apiRouter);
app.use('/api', apiRouter); // Also mount without version for backward compatibility

// Socket.IO for real-time features
io.use(async (socket, next) => {
  try {
    // Authenticate socket connections
    const token = socket.handshake.auth.token || socket.handshake.headers.authorization?.replace('Bearer ', '');
    
    if (!token) {
      return next(new Error('Authentication token required'));
    }

    // Import auth utilities
    const { verifyToken } = await import('./middleware/auth');
    const decoded = verifyToken(token, config.security.jwtSecret);
    
    if (!decoded) {
      return next(new Error('Invalid or expired token'));
    }

    // Verify user exists and is active
    const user = await prisma.user.findUnique({
      where: { 
        id: decoded.userId,
        deletedAt: null
      },
      select: {
        id: true,
        email: true,
        subscriptionStatus: true
      }
    });

    if (!user) {
      return next(new Error('User not found'));
    }

    // Attach user info to socket
    socket.data.user = {
      id: user.id,
      email: user.email,
      subscriptionStatus: user.subscriptionStatus
    };

    logger.info('Socket authenticated', { userId: user.id, socketId: socket.id });
    next();
  } catch (error) {
    logger.error('Socket authentication error', { error });
    next(new Error('Authentication failed'));
  }
});

io.on('connection', (socket) => {
  const user = socket.data.user;
  logger.info(`Client connected: ${socket.id}`, { userId: user?.id });
  
  socket.on('join-room', (roomId: string) => {
    // Validate room access (users can only join their own rooms)
    if (user && roomId.startsWith(`user_${user.id}_`)) {
      socket.join(roomId);
      logger.info(`Client ${socket.id} joined room ${roomId}`, { userId: user.id });
    } else {
      socket.emit('error', { message: 'Unauthorized room access' });
      logger.warn(`Unauthorized room access attempt`, { userId: user?.id, roomId, socketId: socket.id });
    }
  });
  
  socket.on('leave-room', (roomId: string) => {
    socket.leave(roomId);
    logger.info(`Client ${socket.id} left room ${roomId}`, { userId: user?.id });
  });
  
  socket.on('disconnect', () => {
    logger.info(`Client disconnected: ${socket.id}`, { userId: user?.id });
  });
});

// Error handling middleware (must be last)
app.use(notFoundHandler);
app.use(errorHandler);

// Graceful shutdown
process.on('SIGTERM', async () => {
  logger.info('SIGTERM received, shutting down gracefully');
  
  server.close(() => {
    logger.info('HTTP server closed');
  });
  
  await prisma.$disconnect();
  await redis.quit();
  
  process.exit(0);
});

process.on('SIGINT', async () => {
  logger.info('SIGINT received, shutting down gracefully');
  
  server.close(() => {
    logger.info('HTTP server closed');
  });
  
  await prisma.$disconnect();
  await redis.quit();
  
  process.exit(0);
});

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  logger.error('Uncaught Exception:', error);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});

const PORT = config.port || 3000;

server.listen(PORT, () => {
  logger.info(`🚀 Server running on port ${PORT}`);
  logger.info(`📚 API Documentation: http://localhost:${PORT}/api/docs`);
  logger.info(`🏥 Health Check: http://localhost:${PORT}/health`);
  logger.info(`🌍 Environment: ${config.nodeEnv}`);
  
  // Voice WebSocket server is currently disabled (no implementation present)
});

export { app, io };
