import { Router } from 'express';
import { body } from 'express-validator';
import Stripe from 'stripe';
import { prisma } from '../utils/database';
import { validateRequest } from '../middleware/validation';
import { asyncHandler } from '../middleware/errorHandler';
import { auditEvents } from '../middleware/auditLogger';
import { logger, businessLogger } from '../utils/logger';
import { config } from '../config/config';

const router = Router();

// Initialize Stripe with the secret key
const stripe = new Stripe(config.stripe.secretKey, {
  apiVersion: '2023-10-16'
});

// Production Stripe service
class StripeService {
  async createCustomer(email: string, name?: string) {
    try {
      const customer = await stripe.customers.create({
        email,
        ...(name && { name }),
        metadata: {
          source: 'urgood-app'
        }
      });
      
      return {
        id: customer.id,
        email: customer.email,
        name: customer.name
      };
    } catch (error) {
      logger.error('Failed to create Stripe customer', { email, error });
      throw new Error('Failed to create customer');
    }
  }
  
  async createSubscription(customerId: string, priceId: string, paymentMethodId?: string) {
    try {
      const subscriptionData: Stripe.SubscriptionCreateParams = {
        customer: customerId,
        items: [{ price: priceId }],
        payment_behavior: 'default_incomplete',
        payment_settings: { save_default_payment_method: 'on_subscription' },
        expand: ['latest_invoice.payment_intent'],
        metadata: {
          source: 'urgood-app'
        }
      };

      if (paymentMethodId) {
        subscriptionData.default_payment_method = paymentMethodId;
      }

      const subscription = await stripe.subscriptions.create(subscriptionData);
      
      return {
        id: subscription.id,
        status: subscription.status,
        current_period_start: subscription.current_period_start,
        current_period_end: subscription.current_period_end,
        client_secret: (subscription.latest_invoice as Stripe.Invoice)?.payment_intent 
          ? ((subscription.latest_invoice as Stripe.Invoice).payment_intent as Stripe.PaymentIntent)?.client_secret
          : null
      };
    } catch (error) {
      logger.error('Failed to create Stripe subscription', { customerId, priceId, error });
      throw new Error('Failed to create subscription');
    }
  }
  
  async cancelSubscription(subscriptionId: string) {
    try {
      const subscription = await stripe.subscriptions.update(subscriptionId, {
        cancel_at_period_end: true
      });
      
      return {
        id: subscription.id,
        status: subscription.status,
        canceled_at: subscription.canceled_at,
        cancel_at_period_end: subscription.cancel_at_period_end
      };
    } catch (error) {
      logger.error('Failed to cancel Stripe subscription', { subscriptionId, error });
      throw new Error('Failed to cancel subscription');
    }
  }
  
  async createPaymentIntent(amount: number, currency: string = 'usd', customerId?: string) {
    try {
      const paymentIntentData: Stripe.PaymentIntentCreateParams = {
        amount,
        currency,
        automatic_payment_methods: { enabled: true },
        metadata: {
          source: 'urgood-app'
        }
      };

      if (customerId) {
        paymentIntentData.customer = customerId;
      }

      const paymentIntent = await stripe.paymentIntents.create(paymentIntentData);
      
      return {
        id: paymentIntent.id,
        client_secret: paymentIntent.client_secret,
        amount: paymentIntent.amount,
        currency: paymentIntent.currency,
        status: paymentIntent.status
      };
    } catch (error) {
      logger.error('Failed to create Stripe payment intent', { amount, currency, error });
      throw new Error('Failed to create payment intent');
    }
  }

  async retrieveSubscription(subscriptionId: string) {
    try {
      return await stripe.subscriptions.retrieve(subscriptionId);
    } catch (error) {
      logger.error('Failed to retrieve Stripe subscription', { subscriptionId, error });
      throw new Error('Failed to retrieve subscription');
    }
  }
}

const stripeService = new StripeService();

/**
 * @swagger
 * /billing/subscription:
 *   get:
 *     summary: Get current subscription status
 *     tags: [Billing]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Subscription status retrieved successfully
 */
router.get('/subscription',
  asyncHandler(async (req, res) => {
    const userId = req.user!.id;
    
    // Get user with subscription info
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        subscriptionStatus: true,
        subscriptionId: true,
        subscriptionEndsAt: true,
        stripeCustomerId: true
      }
    });
    
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }
    
    // Get recent payments
    const recentPayments = await prisma.payment.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 5,
      select: {
        id: true,
        amount: true,
        currency: true,
        status: true,
        productId: true,
        createdAt: true
      }
    });
    
    const subscription = {
      status: user.subscriptionStatus,
      subscriptionId: user.subscriptionId,
      endsAt: user.subscriptionEndsAt,
      stripeCustomerId: user.stripeCustomerId,
      recentPayments
    };
    
    res.json({
      success: true,
      data: { subscription }
    });
  })
);

/**
 * @swagger
 * /billing/plans:
 *   get:
 *     summary: Get available subscription plans
 *     tags: [Billing]
 *     responses:
 *       200:
 *         description: Subscription plans retrieved successfully
 */
router.get('/plans',
  asyncHandler(async (req, res) => {
    const plans = [
      {
        id: 'free',
        name: 'Free',
        price: 0,
        currency: 'usd',
        interval: 'month',
        features: [
          '10 AI conversations per day',
          'Basic mood tracking',
          'Crisis detection',
          'Community support'
        ],
        limitations: [
          'Limited daily messages',
          'No voice chat',
          'No advanced analytics'
        ]
      },
      {
        id: 'core_monthly',
        name: 'Core',
        price: 2499, // $24.99 in cents
        currency: 'usd',
        interval: 'month',
        stripePriceId: config.stripe.premiumMonthlyPriceId,
        features: [
          'Daily voice sessions',
          'Unlimited text conversations',
          'Priority support'
        ],
        popular: true
      },
    ];
    
    res.json({
      success: true,
      data: { plans }
    });
  })
);

/**
 * @swagger
 * /billing/subscribe:
 *   post:
 *     summary: Create a subscription
 *     tags: [Billing]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - planId
 *             properties:
 *               planId:
 *                 type: string
 *                 enum: [core_monthly]
 *               paymentMethodId:
 *                 type: string
 *     responses:
 *       201:
 *         description: Subscription created successfully
 */
router.post('/subscribe',
  [
    body('planId').isIn(['core_monthly']).withMessage('Invalid plan ID'),
    body('paymentMethodId').optional().isString().withMessage('Payment method ID must be a string')
  ],
  validateRequest,
  asyncHandler(async (req, res) => {
    const userId = req.user!.id;
    const { planId, paymentMethodId } = req.body;
    
    // Get user info
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        email: true,
        name: true,
        subscriptionStatus: true,
        stripeCustomerId: true
      }
    });
    
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }
    
    // Check if user already has Core subscription
    if (user.subscriptionStatus === 'PREMIUM_MONTHLY') {
      return res.status(400).json({
        success: false,
        message: 'User already has an active Core subscription'
      });
    }
    
    try {
      // Create Stripe customer if doesn't exist
      let stripeCustomerId = user.stripeCustomerId;
      if (!stripeCustomerId) {
        const customer = await stripeService.createCustomer(user.email!, user.name || undefined);
        stripeCustomerId = customer.id;
        
        await prisma.user.update({
          where: { id: userId },
          data: { stripeCustomerId }
        });
      }
      
      // Get price ID for monthly plan
      const priceId = config.stripe.premiumMonthlyPriceId;
      
      // Create subscription
      const subscription = await stripeService.createSubscription(stripeCustomerId, priceId, paymentMethodId);
      
      // Update user subscription status based on Stripe status
      let subscriptionStatus: string;
      if (subscription.status === 'active') {
        subscriptionStatus = 'PREMIUM_MONTHLY' as const;
      } else if (subscription.status === 'trialing') {
        subscriptionStatus = 'TRIAL' as const;
      } else {
        // For incomplete subscriptions, we'll wait for webhook confirmation
        subscriptionStatus = 'FREE' as const;
      }
      
      const subscriptionEndsAt = new Date(subscription.current_period_end * 1000);
      
      await prisma.user.update({
        where: { id: userId },
        data: {
          subscriptionStatus,
          subscriptionId: subscription.id,
          subscriptionEndsAt
        }
      });
      
      // Only create payment record if subscription is active
      if (subscription.status === 'active') {
        const amount = 1299; // $12.99 in cents
        await prisma.payment.create({
          data: {
            userId,
            stripePaymentId: subscription.id,
            amount,
            currency: 'usd',
            status: 'SUCCEEDED',
            productId: planId,
            subscriptionId: subscription.id,
            periodStart: new Date(subscription.current_period_start * 1000),
            periodEnd: subscriptionEndsAt
          }
        });
      }
      
      // Log subscription event
      auditEvents.subscriptionChange(userId, user.subscriptionStatus, subscriptionStatus, req);
      
      logger.info('Subscription created successfully', {
        userId,
        planId,
        subscriptionId: subscription.id,
        status: subscription.status
      });
      
      const responseData: any = {
        subscriptionId: subscription.id,
        status: subscriptionStatus,
        endsAt: subscriptionEndsAt
      };

      // Include client_secret for incomplete subscriptions that need payment confirmation
      if (subscription.client_secret) {
        responseData.clientSecret = subscription.client_secret;
        responseData.requiresPaymentMethod = true;
      }
      
      res.status(201).json({
        success: true,
        message: subscription.status === 'active' 
          ? 'Subscription created successfully' 
          : 'Subscription created - payment confirmation required',
        data: responseData
      });
      
    } catch (error) {
      logger.error('Subscription creation failed', {
        userId,
        planId,
        error: error instanceof Error ? error.message : 'Unknown error'
      });
      
      businessLogger.logPaymentEvent(userId, 'subscription_failed', 0, 'usd', { 
        planId, 
        error: error instanceof Error ? error.message : 'Unknown error' 
      });
      
      res.status(500).json({
        success: false,
        message: 'Failed to create subscription'
      });
    }
  })
);

/**
 * @swagger
 * /billing/cancel:
 *   post:
 *     summary: Cancel subscription
 *     tags: [Billing]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Subscription canceled successfully
 */
router.post('/cancel',
  asyncHandler(async (req, res) => {
    const userId = req.user!.id;
    
    // Get user subscription info
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        subscriptionStatus: true,
        subscriptionId: true
      }
    });
    
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }
    
    if (!user.subscriptionId || user.subscriptionStatus === 'FREE') {
      return res.status(400).json({
        success: false,
        message: 'No active subscription to cancel'
      });
    }
    
    try {
      // Cancel Stripe subscription
      await stripeService.cancelSubscription(user.subscriptionId);
      
      // Update user status to cancelled (but keep access until period ends)
      await prisma.user.update({
        where: { id: userId },
        data: {
          subscriptionStatus: 'CANCELLED'
        }
      });
      
      // Log cancellation
      auditEvents.subscriptionChange(userId, user.subscriptionStatus, 'CANCELLED', req);
      businessLogger.logPaymentEvent(userId, 'subscription_cancelled', 0, 'usd');
      
      logger.info('Subscription cancelled successfully', {
        userId,
        subscriptionId: user.subscriptionId
      });
      
      res.json({
        success: true,
        message: 'Subscription cancelled successfully. Access will continue until the end of your billing period.'
      });
      
    } catch (error) {
      logger.error('Subscription cancellation failed', {
        userId,
        subscriptionId: user.subscriptionId,
        error: error instanceof Error ? error.message : 'Unknown error'
      });
      
      res.status(500).json({
        success: false,
        message: 'Failed to cancel subscription'
      });
    }
  })
);

/**
 * @swagger
 * /billing/payment-intent:
 *   post:
 *     summary: Create payment intent for one-time payment
 *     tags: [Billing]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - amount
 *             properties:
 *               amount:
 *                 type: integer
 *                 minimum: 50
 *               currency:
 *                 type: string
 *                 default: usd
 *     responses:
 *       201:
 *         description: Payment intent created successfully
 */
router.post('/payment-intent',
  [
    body('amount').isInt({ min: 50 }).withMessage('Amount must be at least 50 cents'),
    body('currency').optional().isIn(['usd', 'eur', 'gbp']).withMessage('Invalid currency')
  ],
  validateRequest,
  asyncHandler(async (req, res) => {
    const userId = req.user!.id;
    const { amount, currency = 'usd' } = req.body;
    
    try {
      // Create payment intent
      const paymentIntent = await stripeService.createPaymentIntent(amount, currency);
      
      logger.info('Payment intent created', {
        userId,
        paymentIntentId: paymentIntent.id,
        amount,
        currency
      });
      
      res.status(201).json({
        success: true,
        message: 'Payment intent created successfully',
        data: {
          clientSecret: paymentIntent.client_secret,
          paymentIntentId: paymentIntent.id
        }
      });
      
    } catch (error) {
      logger.error('Payment intent creation failed', {
        userId,
        amount,
        currency,
        error: error instanceof Error ? error.message : 'Unknown error'
      });
      
      res.status(500).json({
        success: false,
        message: 'Failed to create payment intent'
      });
    }
  })
);

/**
 * @swagger
 * /billing/payments:
 *   get:
 *     summary: Get payment history
 *     tags: [Billing]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           minimum: 1
 *           maximum: 50
 *           default: 10
 *     responses:
 *       200:
 *         description: Payment history retrieved successfully
 */
router.get('/payments',
  asyncHandler(async (req, res) => {
    const userId = req.user!.id;
    const limit = parseInt(req.query.limit as string) || 10;
    
    const payments = await prisma.payment.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: Math.min(limit, 50),
      select: {
        id: true,
        amount: true,
        currency: true,
        status: true,
        productId: true,
        periodStart: true,
        periodEnd: true,
        createdAt: true
      }
    });
    
    res.json({
      success: true,
      data: { payments }
    });
  })
);

export default router;
