import { Router } from 'express';
import { Request, Response } from 'express';
import Stripe from 'stripe';
import { config } from '../config/config';
import { prisma } from '../utils/database';
import { logger, businessLogger } from '../utils/logger';
import { auditEvents } from '../middleware/auditLogger';

const router = Router();

// Initialize Stripe with the secret key
const stripe = new Stripe(config.stripe.secretKey, {
  apiVersion: '2023-10-16'
});

/**
 * POST /webhooks/stripe
 * Handle Stripe webhook events for subscription management
 */
router.post('/stripe', async (req: Request, res: Response) => {
  const sig = req.headers['stripe-signature'] as string;
  
  if (!sig) {
    logger.warn('Missing Stripe signature header');
    return res.status(400).send('Missing signature');
  }

  let event: Stripe.Event;

  try {
    // Verify webhook signature
    event = stripe.webhooks.constructEvent(
      req.body,
      sig,
      config.stripe.webhookSecret
    );
  } catch (err) {
    logger.error('Webhook signature verification failed', { error: err });
    return res.status(400).send(`Webhook Error: ${err instanceof Error ? err.message : 'Unknown error'}`);
  }

  logger.info('Stripe webhook received', { 
    type: event.type, 
    id: event.id 
  });

  try {
    switch (event.type) {
      case 'customer.subscription.created':
        await handleSubscriptionCreated(event.data.object as Stripe.Subscription);
        break;
        
      case 'customer.subscription.updated':
        await handleSubscriptionUpdated(event.data.object as Stripe.Subscription);
        break;
        
      case 'customer.subscription.deleted':
        await handleSubscriptionDeleted(event.data.object as Stripe.Subscription);
        break;
        
      case 'invoice.payment_succeeded':
        await handlePaymentSucceeded(event.data.object as Stripe.Invoice);
        break;
        
      case 'invoice.payment_failed':
        await handlePaymentFailed(event.data.object as Stripe.Invoice);
        break;
        
      case 'customer.subscription.trial_will_end':
        await handleTrialWillEnd(event.data.object as Stripe.Subscription);
        break;

      default:
        logger.info('Unhandled webhook event type', { type: event.type });
    }

    res.json({ received: true });
  } catch (error) {
    logger.error('Webhook processing failed', { 
      eventType: event.type, 
      eventId: event.id, 
      error: error instanceof Error ? error.message : 'Unknown error' 
    });
    res.status(500).json({ error: 'Webhook processing failed' });
  }
});

async function handleSubscriptionCreated(subscription: Stripe.Subscription) {
  const customerId = subscription.customer as string;
  
  // Find user by Stripe customer ID
  const user = await prisma.user.findFirst({
    where: { stripeCustomerId: customerId }
  });

  if (!user) {
    logger.error('User not found for subscription created event', { customerId });
    return;
  }

  // Update user subscription status
  await prisma.user.update({
    where: { id: user.id },
    data: {
      subscriptionStatus: 'PREMIUM_MONTHLY',
      subscriptionId: subscription.id,
      subscriptionEndsAt: new Date(subscription.current_period_end * 1000)
    }
  });

  logger.info('Subscription created via webhook', {
    userId: user.id,
    subscriptionId: subscription.id
  });

  businessLogger.logPaymentEvent(user.id, 'subscription_created_webhook', 0, 'usd', {
    subscriptionId: subscription.id
  });
}

async function handleSubscriptionUpdated(subscription: Stripe.Subscription) {
  const customerId = subscription.customer as string;
  
  const user = await prisma.user.findFirst({
    where: { stripeCustomerId: customerId }
  });

  if (!user) {
    logger.error('User not found for subscription updated event', { customerId });
    return;
  }

  // Determine subscription status based on Stripe status
  let subscriptionStatus: 'PREMIUM_MONTHLY' | 'TRIAL' | 'FREE';
  switch (subscription.status) {
    case 'active':
      subscriptionStatus = 'PREMIUM_MONTHLY';
      break;
    case 'trialing':
      subscriptionStatus = 'TRIAL';
      break;
    case 'canceled':
    case 'incomplete_expired':
    case 'unpaid':
      subscriptionStatus = 'FREE';
      break;
    default:
      subscriptionStatus = 'FREE';
  }

  await prisma.user.update({
    where: { id: user.id },
    data: {
      subscriptionStatus,
      subscriptionEndsAt: new Date(subscription.current_period_end * 1000)
    }
  });

  logger.info('Subscription updated via webhook', {
    userId: user.id,
    subscriptionId: subscription.id,
    status: subscription.status,
    newStatus: subscriptionStatus
  });
}

async function handleSubscriptionDeleted(subscription: Stripe.Subscription) {
  const customerId = subscription.customer as string;
  
  const user = await prisma.user.findFirst({
    where: { stripeCustomerId: customerId }
  });

  if (!user) {
    logger.error('User not found for subscription deleted event', { customerId });
    return;
  }

  // Set user back to free tier
  await prisma.user.update({
    where: { id: user.id },
    data: {
      subscriptionStatus: 'FREE',
      subscriptionId: null,
      subscriptionEndsAt: null
    }
  });

  logger.info('Subscription deleted via webhook', {
    userId: user.id,
    subscriptionId: subscription.id
  });

  businessLogger.logPaymentEvent(user.id, 'subscription_deleted_webhook', 0, 'usd', {
    subscriptionId: subscription.id
  });
}

async function handlePaymentSucceeded(invoice: Stripe.Invoice) {
  const customerId = invoice.customer as string;
  
  const user = await prisma.user.findFirst({
    where: { stripeCustomerId: customerId }
  });

  if (!user) {
    logger.error('User not found for payment succeeded event', { customerId });
    return;
  }

  // Create payment record
  await prisma.payment.create({
    data: {
      userId: user.id,
      stripePaymentId: invoice.payment_intent as string || invoice.id,
      amount: invoice.amount_paid,
      currency: invoice.currency,
      status: 'SUCCEEDED',
      productId: 'core_monthly',
      subscriptionId: invoice.subscription as string,
      periodStart: invoice.period_start ? new Date(invoice.period_start * 1000) : null,
      periodEnd: invoice.period_end ? new Date(invoice.period_end * 1000) : null
    }
  });

  logger.info('Payment succeeded via webhook', {
    userId: user.id,
    invoiceId: invoice.id,
    amount: invoice.amount_paid
  });

  businessLogger.logPaymentEvent(user.id, 'payment_succeeded', invoice.amount_paid, invoice.currency);
}

async function handlePaymentFailed(invoice: Stripe.Invoice) {
  const customerId = invoice.customer as string;
  
  const user = await prisma.user.findFirst({
    where: { stripeCustomerId: customerId }
  });

  if (!user) {
    logger.error('User not found for payment failed event', { customerId });
    return;
  }

  logger.warn('Payment failed via webhook', {
    userId: user.id,
    invoiceId: invoice.id,
    amount: invoice.amount_due
  });

  businessLogger.logPaymentEvent(user.id, 'payment_failed', invoice.amount_due, invoice.currency, {
    invoiceId: invoice.id,
    attemptCount: invoice.attempt_count
  });

  // TODO: Send email notification to user about failed payment
  // TODO: Implement retry logic or grace period before downgrading
}

async function handleTrialWillEnd(subscription: Stripe.Subscription) {
  const customerId = subscription.customer as string;
  
  const user = await prisma.user.findFirst({
    where: { stripeCustomerId: customerId }
  });

  if (!user) {
    logger.error('User not found for trial will end event', { customerId });
    return;
  }

  logger.info('Trial will end via webhook', {
    userId: user.id,
    subscriptionId: subscription.id,
    trialEnd: subscription.trial_end
  });

  // TODO: Send email notification about trial ending
  // TODO: Prompt user to add payment method
}

export default router;
