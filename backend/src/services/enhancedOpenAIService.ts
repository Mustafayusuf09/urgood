import { logger } from '../utils/logger';
import { 
  THERAPY_TECHNIQUES, 
  COPING_EXERCISES, 
  COMMUNICATION_GUIDELINES,
  PERSONALIZATION_PATTERNS,
  getCopingExercise,
  generatePersonalizedPrompt,
  detectCrisisLevel
} from './therapyKnowledgeBase';

interface ConversationMessage {
  role: 'USER' | 'ASSISTANT';
  content: string;
  createdAt: Date;
}

interface UserInsights {
  preferences?: {
    music?: boolean;
    outdoors?: boolean;
    journaling?: boolean;
  };
  successfulTechniques?: string[];
  triggers?: string[];
  patterns?: string[];
  moodTrends?: Array<{ mood: number; date: Date }>;
}

export class EnhancedOpenAIService {
  private apiKey: string;
  private baseURL = 'https://api.openai.com/v1';
  private model = 'gpt-4o';

  constructor(apiKey: string) {
    this.apiKey = apiKey;
  }

  async generateTherapyResponse(
    message: string,
    conversationHistory: ConversationMessage[],
    userId: string,
    userInsights?: UserInsights
  ): Promise<string> {
    try {
      // Analyze message for therapeutic context
      const messageAnalysis = this.analyzeMessage(message);
      
      // Check if user needs a coping exercise
      if (messageAnalysis.needsCoping) {
        const copingExercise = getCopingExercise(messageAnalysis.triggers, userInsights);
        if (copingExercise) {
          return generatePersonalizedPrompt(copingExercise, userInsights);
        }
      }

      // Build enhanced system prompt with therapy knowledge
      const systemPrompt = this.buildTherapySystemPrompt(userInsights, messageAnalysis);
      
      // Prepare conversation for OpenAI
      const messages = [
        { role: 'system', content: systemPrompt },
        ...this.formatConversationHistory(conversationHistory),
        { role: 'user', content: message }
      ];

      // Call OpenAI API
      const response = await fetch(`${this.baseURL}/chat/completions`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${this.apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: this.model,
          messages,
          max_tokens: 500,
          temperature: 0.7,
          presence_penalty: 0.1,
          frequency_penalty: 0.1,
        }),
      });

      if (!response.ok) {
        throw new Error(`OpenAI API error: ${response.status}`);
      }

      const data = await response.json();
      const aiResponse = data.choices[0]?.message?.content || 
        'I\'m having trouble responding right now. Can you try rephrasing that?';

      // Post-process response to ensure it follows guidelines
      return this.postProcessResponse(aiResponse, messageAnalysis, userInsights);

    } catch (error) {
      logger.error('Enhanced OpenAI service error', { error, userId });
      return this.getFallbackResponse(message);
    }
  }

  private analyzeMessage(message: string): {
    needsCoping: boolean;
    triggers: string[];
    emotionalIntensity: number;
    topics: string[];
  } {
    const lowerMessage = message.toLowerCase();
    
    // Detect emotional triggers
    const triggers: string[] = [];
    const triggerKeywords = {
      anxiety: ['anxious', 'worried', 'panic', 'nervous', 'overwhelmed'],
      depression: ['sad', 'hopeless', 'empty', 'worthless', 'tired'],
      anger: ['angry', 'furious', 'frustrated', 'mad', 'irritated'],
      stress: ['stressed', 'pressure', 'overwhelmed', 'busy', 'deadline']
    };

    Object.entries(triggerKeywords).forEach(([trigger, keywords]) => {
      if (keywords.some(keyword => lowerMessage.includes(keyword))) {
        triggers.push(trigger);
      }
    });

    // Assess emotional intensity (0-10)
    const intensityKeywords = {
      high: ['extremely', 'really', 'so', 'very', 'completely', 'totally'],
      moderate: ['pretty', 'quite', 'somewhat', 'kind of'],
      low: ['a little', 'slightly', 'maybe']
    };

    let emotionalIntensity = 5; // Default moderate
    if (intensityKeywords.high.some(word => lowerMessage.includes(word))) {
      emotionalIntensity = 8;
    } else if (intensityKeywords.low.some(word => lowerMessage.includes(word))) {
      emotionalIntensity = 3;
    }

    // Determine if coping exercise is needed
    const needsCoping = triggers.length > 0 && emotionalIntensity > 6;

    return {
      needsCoping,
      triggers,
      emotionalIntensity,
      topics: triggers
    };
  }

  private buildTherapySystemPrompt(userInsights?: UserInsights, messageAnalysis?: any): string {
    const basePrompt = `You are a compassionate mental health support AI for UrGood, designed specifically for Gen Z users (late 2025). You integrate evidence-based techniques from CBT, DBT, and ACT.

CORE IDENTITY:
- Mature Gen Z communication style: authentic, direct but warm, emotionally literate
- No forced slang, memes, or performative language
- Think "insightful friend who reads psychology research"

THERAPY KNOWLEDGE:
You have access to these evidence-based techniques:
${THERAPY_TECHNIQUES.map(t => `• ${t.name} (${t.category}): ${t.description}`).join('\n')}

COMMUNICATION STRUCTURE:
1. Validate feelings first (1-2 sentences)
2. Brief education about technique/science if relevant
3. One specific, doable action step
4. Check-in question or encouragement

TONE GUIDELINES:
${Object.entries(COMMUNICATION_GUIDELINES.tone).map(([key, value]) => `• ${key}: ${value}`).join('\n')}

AVOID:
${COMMUNICATION_GUIDELINES.avoid.map(item => `• ${item}`).join('\n')}

CRISIS PROTOCOL:
- Never diagnose or provide medical advice
- For crisis language, validate, provide resources, encourage professional help
- Emergency resources: 988 Suicide & Crisis Lifeline, Crisis Text Line (HOME to 741741)

PERSONALIZATION:`;

    // Add user insights if available
    if (userInsights) {
      let personalizedSection = '\nUSER CONTEXT:\n';
      
      if (userInsights.successfulTechniques?.length) {
        personalizedSection += `• Previously helpful: ${userInsights.successfulTechniques.join(', ')}\n`;
      }
      
      if (userInsights.triggers?.length) {
        personalizedSection += `• Common triggers: ${userInsights.triggers.join(', ')}\n`;
      }
      
      if (userInsights.preferences) {
        personalizedSection += `• Preferences: ${Object.entries(userInsights.preferences)
          .filter(([_, value]) => value)
          .map(([key, _]) => key)
          .join(', ')}\n`;
      }
      
      return basePrompt + personalizedSection;
    }

    return basePrompt + '\nNo specific user context available yet.';
  }

  private formatConversationHistory(history: ConversationMessage[]): Array<{role: string, content: string}> {
    return history
      .slice(-6) // Keep last 6 messages for context
      .map(msg => ({
        role: msg.role === 'USER' ? 'user' : 'assistant',
        content: msg.content
      }));
  }

  private postProcessResponse(
    response: string, 
    messageAnalysis: any, 
    userInsights?: UserInsights
  ): string {
    // Ensure response isn't too long
    if (response.length > 800) {
      const sentences = response.split('. ');
      response = sentences.slice(0, 3).join('. ') + '.';
    }

    // Add personalized callback if relevant
    if (userInsights?.successfulTechniques?.length && Math.random() > 0.7) {
      const technique = userInsights.successfulTechniques[0];
      response += `\n\nBtw, I remember ${technique} worked well for you before—want to revisit that?`;
    }

    return response;
  }

  private getFallbackResponse(message: string): string {
    const crisisDetection = detectCrisisLevel(message);
    
    if (crisisDetection.confidence > 0.3) {
      return "I hear that you're going through something really difficult right now. While I'm here to support you, I want to make sure you have access to professional help. Please consider reaching out to 988 (Suicide & Crisis Lifeline) or Crisis Text Line (text HOME to 741741).";
    }

    const fallbacks = [
      "I'm having some technical difficulties right now, but I want you to know I'm here. Can you tell me a bit more about what's going on?",
      "Sorry, I'm having trouble processing that right now. What's the main thing you're dealing with today?",
      "I'm experiencing some issues on my end, but your feelings matter. What's been on your mind lately?"
    ];

    return fallbacks[Math.floor(Math.random() * fallbacks.length)];
  }

  // Method to suggest coping exercises based on user state
  async suggestCopingExercise(
    triggers: string[], 
    userInsights?: UserInsights
  ): Promise<{ exercise: any; prompt: string } | null> {
    const exercise = getCopingExercise(triggers, userInsights);
    if (!exercise) return null;

    const prompt = generatePersonalizedPrompt(exercise, userInsights);
    
    return { exercise, prompt };
  }

  // Method to analyze user patterns for insights
  analyzeUserPatterns(conversationHistory: ConversationMessage[]): {
    commonTriggers: string[];
    preferredTechniques: string[];
    moodPatterns: string[];
  } {
    const triggers: string[] = [];
    const techniques: string[] = [];
    
    conversationHistory.forEach(msg => {
      if (msg.role === 'USER') {
        const analysis = this.analyzeMessage(msg.content);
        triggers.push(...analysis.triggers);
      }
      
      // Look for technique mentions in AI responses
      if (msg.role === 'ASSISTANT') {
        COPING_EXERCISES.forEach(exercise => {
          if (msg.content.toLowerCase().includes(exercise.name.toLowerCase())) {
            techniques.push(exercise.id);
          }
        });
      }
    });

    // Count frequencies
    const triggerCounts = this.countFrequencies(triggers);
    const techniqueCounts = this.countFrequencies(techniques);

    return {
      commonTriggers: Object.keys(triggerCounts).slice(0, 3),
      preferredTechniques: Object.keys(techniqueCounts).slice(0, 3),
      moodPatterns: [] // TODO: Implement mood pattern analysis
    };
  }

  private countFrequencies(items: string[]): Record<string, number> {
    return items.reduce((acc, item) => {
      acc[item] = (acc[item] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);
  }
}

export default EnhancedOpenAIService;
