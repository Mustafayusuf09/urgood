import { prisma } from './database';
import { logger, metricsLogger } from './logger';
import { config } from '../config/config';
import { captureMessage } from './sentry';

// Analytics event types for mental health app
export interface AnalyticsEvent {
  userId?: string;
  eventName: string;
  properties?: Record<string, any>;
  sessionId?: string;
  deviceId?: string;
  platform?: string;
  version?: string;
  ipAddress?: string;
  userAgent?: string;
}

// Predefined event names for consistency
export const EventNames = {
  // User lifecycle
  USER_REGISTERED: 'user_registered',
  USER_LOGIN: 'user_login',
  USER_LOGOUT: 'user_logout',
  USER_PROFILE_UPDATED: 'user_profile_updated',
  
  // Therapy sessions
  THERAPY_SESSION_STARTED: 'therapy_session_started',
  THERAPY_SESSION_ENDED: 'therapy_session_ended',
  THERAPY_MESSAGE_SENT: 'therapy_message_sent',
  THERAPY_MESSAGE_RECEIVED: 'therapy_message_received',
  
  // Voice chat
  VOICE_SESSION_STARTED: 'voice_session_started',
  VOICE_SESSION_ENDED: 'voice_session_ended',
  VOICE_QUALITY_FEEDBACK: 'voice_quality_feedback',
  
  // Mood tracking
  MOOD_ENTRY_CREATED: 'mood_entry_created',
  MOOD_TREND_VIEWED: 'mood_trend_viewed',
  MOOD_INSIGHT_GENERATED: 'mood_insight_generated',
  
  // Crisis detection
  CRISIS_DETECTED: 'crisis_detected',
  CRISIS_RESOLVED: 'crisis_resolved',
  EMERGENCY_CONTACT_TRIGGERED: 'emergency_contact_triggered',
  
  // Subscription & billing
  SUBSCRIPTION_STARTED: 'subscription_started',
  SUBSCRIPTION_CANCELLED: 'subscription_cancelled',
  SUBSCRIPTION_RENEWED: 'subscription_renewed',
  PAYMENT_SUCCESSFUL: 'payment_successful',
  PAYMENT_FAILED: 'payment_failed',
  
  // Feature usage
  FEATURE_ACCESSED: 'feature_accessed',
  FEATURE_COMPLETED: 'feature_completed',
  ONBOARDING_STEP_COMPLETED: 'onboarding_step_completed',
  
  // Engagement
  DAILY_CHECKIN: 'daily_checkin',
  STREAK_MILESTONE: 'streak_milestone',
  GOAL_SET: 'goal_set',
  GOAL_ACHIEVED: 'goal_achieved',
  
  // App performance
  APP_LAUNCHED: 'app_launched',
  APP_BACKGROUNDED: 'app_backgrounded',
  ERROR_OCCURRED: 'error_occurred',
  SLOW_PERFORMANCE: 'slow_performance',
} as const;

// Analytics service class
export class AnalyticsService {
  private static instance: AnalyticsService;
  private eventQueue: AnalyticsEvent[] = [];
  private isProcessing = false;
  private batchSize = 50;
  private flushInterval = 30000; // 30 seconds
  
  public static getInstance(): AnalyticsService {
    if (!AnalyticsService.instance) {
      AnalyticsService.instance = new AnalyticsService();
    }
    return AnalyticsService.instance;
  }
  
  constructor() {
    // Start batch processing
    this.startBatchProcessing();
  }
  
  // Track a single event
  async track(event: AnalyticsEvent): Promise<void> {
    if (!config.features.analyticsEnabled) {
      logger.debug('Analytics disabled, skipping event', { eventName: event.eventName });
      return;
    }
    
    try {
      // Add timestamp and validation
      const enrichedEvent: AnalyticsEvent = {
        ...event,
        properties: {
          ...event.properties,
          timestamp: new Date().toISOString(),
          environment: config.nodeEnv,
        }
      };
      
      // Add to queue for batch processing
      this.eventQueue.push(enrichedEvent);
      
      // Log for debugging
      logger.debug('Analytics event queued', {
        eventName: event.eventName,
        userId: event.userId,
        queueSize: this.eventQueue.length
      });
      
      // Flush immediately for critical events
      if (this.isCriticalEvent(event.eventName)) {
        await this.flush();
      }
      
    } catch (error) {
      logger.error('Failed to track analytics event', {
        eventName: event.eventName,
        error: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }
  
  // Track multiple events at once
  async trackBatch(events: AnalyticsEvent[]): Promise<void> {
    for (const event of events) {
      await this.track(event);
    }
  }
  
  // Track user engagement
  async trackUserEngagement(userId: string, action: string, duration?: number, metadata?: any): Promise<void> {
    await this.track({
      userId,
      eventName: EventNames.FEATURE_ACCESSED,
      properties: {
        action,
        duration,
        ...metadata
      }
    });
    
    // Also log to metrics logger
    metricsLogger.logUserEngagement(userId, action, duration, metadata);
  }
  
  // Track therapy session events
  async trackTherapySession(userId: string, sessionId: string, event: 'started' | 'ended', properties?: any): Promise<void> {
    const eventName = event === 'started' ? EventNames.THERAPY_SESSION_STARTED : EventNames.THERAPY_SESSION_ENDED;
    
    await this.track({
      userId,
      sessionId,
      eventName,
      properties: {
        sessionType: 'chat',
        ...properties
      }
    });
  }
  
  // Track voice chat events
  async trackVoiceSession(userId: string, sessionId: string, event: 'started' | 'ended', properties?: any): Promise<void> {
    const eventName = event === 'started' ? EventNames.VOICE_SESSION_STARTED : EventNames.VOICE_SESSION_ENDED;
    
    await this.track({
      userId,
      sessionId,
      eventName,
      properties: {
        sessionType: 'voice',
        ...properties
      }
    });
  }
  
  // Track mood entries
  async trackMoodEntry(userId: string, moodScore: number, context?: string): Promise<void> {
    await this.track({
      userId,
      eventName: EventNames.MOOD_ENTRY_CREATED,
      properties: {
        moodScore,
        context,
        moodCategory: this.categorizeMood(moodScore)
      }
    });
  }
  
  // Track crisis events (high priority)
  async trackCrisisEvent(userId: string, severity: string, confidence: number, keywords?: string[]): Promise<void> {
    await this.track({
      userId,
      eventName: EventNames.CRISIS_DETECTED,
      properties: {
        severity,
        confidence,
        keywordCount: keywords?.length || 0,
        priority: 'critical'
      }
    });
    
    // Also send to Sentry for immediate alerting
    captureMessage(`Crisis detected for user ${userId}`, 'error', {
      user: { id: userId },
      tags: {
        event_type: 'crisis_detection',
        severity,
      },
      extra: {
        confidence,
        keywords: keywords?.length || 0,
      }
    });
  }
  
  // Track subscription events
  async trackSubscriptionEvent(userId: string, event: string, plan?: string, amount?: number): Promise<void> {
    await this.track({
      userId,
      eventName: event,
      properties: {
        plan,
        amount,
        currency: 'USD'
      }
    });
    
    // Also log to metrics logger
    metricsLogger.logSubscriptionEvent(userId, event, plan, amount);
  }
  
  // Track feature usage
  async trackFeatureUsage(userId: string, feature: string, success: boolean, metadata?: any): Promise<void> {
    await this.track({
      userId,
      eventName: EventNames.FEATURE_ACCESSED,
      properties: {
        feature,
        success,
        ...metadata
      }
    });
    
    // Also log to metrics logger
    metricsLogger.logFeatureUsage(userId, feature, success, metadata);
  }
  
  // Track performance issues
  async trackPerformanceIssue(type: string, duration: number, context?: any): Promise<void> {
    await this.track({
      eventName: EventNames.SLOW_PERFORMANCE,
      properties: {
        type,
        duration,
        threshold: type === 'api' ? 2000 : 1000,
        ...context
      }
    });
  }
  
  // Flush events immediately
  async flush(): Promise<void> {
    if (this.eventQueue.length === 0 || this.isProcessing) {
      return;
    }
    
    this.isProcessing = true;
    
    try {
      const eventsToProcess = this.eventQueue.splice(0, this.batchSize);
      
      if (eventsToProcess.length > 0) {
        await this.persistEvents(eventsToProcess);
        logger.info('Analytics events flushed', { count: eventsToProcess.length });
      }
      
    } catch (error) {
      logger.error('Failed to flush analytics events', {
        error: error instanceof Error ? error.message : 'Unknown error',
        queueSize: this.eventQueue.length
      });
    } finally {
      this.isProcessing = false;
    }
  }
  
  // Get analytics summary for user
  async getUserAnalytics(userId: string, days: number = 30): Promise<any> {
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);
    
    const [events, sessionCount, moodEntries] = await Promise.all([
      prisma.analyticsEvent.findMany({
        where: {
          userId,
          createdAt: { gte: startDate }
        },
        select: {
          eventName: true,
          properties: true,
          createdAt: true
        },
        orderBy: { createdAt: 'desc' }
      }),
      
      prisma.analyticsEvent.count({
        where: {
          userId,
          eventName: { in: [EventNames.THERAPY_SESSION_STARTED, EventNames.VOICE_SESSION_STARTED] },
          createdAt: { gte: startDate }
        }
      }),
      
      prisma.moodEntry.findMany({
        where: {
          userId,
          createdAt: { gte: startDate }
        },
        select: {
          mood: true,
          createdAt: true
        }
      })
    ]);
    
    // Calculate engagement metrics
    const eventsByType = events.reduce((acc, event) => {
      acc[event.eventName] = (acc[event.eventName] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);
    
    const averageMood = moodEntries.length > 0
      ? moodEntries.reduce((sum, entry) => sum + entry.mood, 0) / moodEntries.length
      : 0;
    
    return {
      period: `${days} days`,
      totalEvents: events.length,
      sessionCount,
      eventsByType,
      moodEntries: moodEntries.length,
      averageMood: Math.round(averageMood * 100) / 100,
      lastActivity: events[0]?.createdAt || null
    };
  }
  
  // Private methods
  private startBatchProcessing(): void {
    setInterval(async () => {
      if (this.eventQueue.length > 0) {
        await this.flush();
      }
    }, this.flushInterval);
  }
  
  private async persistEvents(events: AnalyticsEvent[]): Promise<void> {
    try {
      await prisma.analyticsEvent.createMany({
        data: events.map(event => ({
          userId: event.userId || null,
          eventName: event.eventName,
          properties: event.properties || {},
          sessionId: event.sessionId || null,
          deviceId: event.deviceId || null,
          platform: event.platform || null,
          version: event.version || null,
          ipAddress: event.ipAddress || null,
          userAgent: event.userAgent || null,
        }))
      });
      
    } catch (error) {
      logger.error('Failed to persist analytics events', {
        error: error instanceof Error ? error.message : 'Unknown error',
        eventCount: events.length
      });
      throw error;
    }
  }
  
  private isCriticalEvent(eventName: string): boolean {
    const criticalEvents = [
      EventNames.CRISIS_DETECTED,
      EventNames.EMERGENCY_CONTACT_TRIGGERED,
      EventNames.ERROR_OCCURRED
    ];
    return criticalEvents.includes(eventName as any);
  }
  
  private categorizeMood(moodScore: number): string {
    if (moodScore <= 2) return 'very_low';
    if (moodScore <= 4) return 'low';
    if (moodScore <= 6) return 'neutral';
    if (moodScore <= 8) return 'good';
    return 'excellent';
  }
}

// Export singleton instance
export const analytics = AnalyticsService.getInstance();

// Convenience functions for common events
export const trackEvent = (event: AnalyticsEvent) => analytics.track(event);
export const trackUserEngagement = (userId: string, action: string, duration?: number, metadata?: any) => 
  analytics.trackUserEngagement(userId, action, duration, metadata);
export const trackTherapySession = (userId: string, sessionId: string, event: 'started' | 'ended', properties?: any) =>
  analytics.trackTherapySession(userId, sessionId, event, properties);
export const trackVoiceSession = (userId: string, sessionId: string, event: 'started' | 'ended', properties?: any) =>
  analytics.trackVoiceSession(userId, sessionId, event, properties);
export const trackMoodEntry = (userId: string, moodScore: number, context?: string) =>
  analytics.trackMoodEntry(userId, moodScore, context);
export const trackCrisisEvent = (userId: string, severity: string, confidence: number, keywords?: string[]) =>
  analytics.trackCrisisEvent(userId, severity, confidence, keywords);
export const trackSubscriptionEvent = (userId: string, event: string, plan?: string, amount?: number) =>
  analytics.trackSubscriptionEvent(userId, event, plan, amount);
export const trackFeatureUsage = (userId: string, feature: string, success: boolean, metadata?: any) =>
  analytics.trackFeatureUsage(userId, feature, success, metadata);

export default analytics;
