import { logger } from '../utils/logger';

// Evidence-based therapy techniques for digital mental health
export interface TherapyTechnique {
  id: string;
  name: string;
  category: 'CBT' | 'DBT' | 'ACT' | 'BEHAVIORAL';
  description: string;
  application: string;
  duration: string;
  evidenceLevel: 'HIGH' | 'MODERATE' | 'EMERGING';
  citations: string[];
  contraindications?: string[];
}

export interface CopingExercise {
  id: string;
  name: string;
  technique: string;
  steps: string[];
  duration: string;
  triggers: string[];
  genZPrompt: string;
}

export interface CrisisProtocol {
  level: 'LOW' | 'MODERATE' | 'HIGH' | 'CRITICAL';
  keywords: string[];
  response: string;
  escalation: string[];
  resources: string[];
}

// Core therapy techniques with 2020-2024 evidence
export const THERAPY_TECHNIQUES: TherapyTechnique[] = [
  {
    id: 'cbt-micro-reframing',
    name: 'Rapid Cognitive Reframing',
    category: 'CBT',
    description: 'Quick 3-step thought challenging for automatic negative thoughts',
    application: 'Daily check-ins, anxiety spikes, rumination',
    duration: '2-3 minutes',
    evidenceLevel: 'HIGH',
    citations: [
      'Kladnitski et al. (2022) - Mobile CBT for adolescents',
      'Hall et al. (2021) - Digital thought records efficacy'
    ]
  },
  {
    id: 'dbt-tipp-stack',
    name: 'DBT TIPP Distress Tolerance',
    category: 'DBT',
    description: 'Temperature, Intense exercise, Paced breathing, Progressive muscle relaxation',
    application: 'Crisis moments, emotional overwhelm, self-harm urges',
    duration: '60-90 seconds',
    evidenceLevel: 'HIGH',
    citations: [
      'Stewart et al. (2020) - TIPP effectiveness in adolescents',
      'Rizvi et al. (2021) - Tele-DBT outcomes'
    ]
  },
  {
    id: 'act-values-diffusion',
    name: 'Values-Based Thought Diffusion',
    category: 'ACT',
    description: 'Notice-name-let go with values anchoring',
    application: 'Perfectionism, social anxiety, identity struggles',
    duration: '90 seconds',
    evidenceLevel: 'MODERATE',
    citations: [
      'Fang & Ding (2022) - ACT apps for college students',
      'Conrad et al. (2023) - Values-based interventions'
    ]
  },
  {
    id: 'behavioral-activation-micro',
    name: 'Burst Behavioral Activation',
    category: 'BEHAVIORAL',
    description: 'Single micro-action aligned with personal values',
    application: 'Depression, low motivation, isolation',
    duration: '5-15 minutes',
    evidenceLevel: 'HIGH',
    citations: [
      'Schleider et al. (2022) - Single-session BA for teens',
      'Rhew et al. (2020) - Digital BA validation'
    ]
  },
  {
    id: 'implementation-intentions',
    name: 'If-Then Habit Formation',
    category: 'BEHAVIORAL',
    description: 'Implementation intentions for consistent coping',
    application: 'Building healthy habits, breaking negative cycles',
    duration: 'Ongoing',
    evidenceLevel: 'HIGH',
    citations: [
      'Conrad et al. (2023) - Youth habit formation apps',
      'Gollwitzer (1999) - Implementation intentions theory'
    ]
  }
];

// Coping exercises with Gen Z-friendly prompts
export const COPING_EXERCISES: CopingExercise[] = [
  {
    id: 'box-breathing',
    name: 'Box Breathing Reset',
    technique: 'dbt-tipp-stack',
    steps: [
      'Find a comfortable spot and close your eyes or soften your gaze',
      'Breathe in for 4 counts, hold for 4, out for 4, hold for 4',
      'Repeat 4-6 cycles, focusing only on the counting',
      'Notice how your body feels different now'
    ],
    duration: '60-90 seconds',
    triggers: ['anxiety', 'panic', 'overwhelm', 'anger'],
    genZPrompt: 'Your nervous system is in overdrive right now. This breathing drill comes from DBT—clinics use it to dial emotions down in under two minutes. Ready to try it?'
  },
  {
    id: 'thought-check',
    name: 'Catch-Check-Change',
    technique: 'cbt-micro-reframing',
    steps: [
      'Catch it: What specific thought just went through your mind?',
      'Check it: Is this thought helpful or accurate right now?',
      'Change it: What would you tell a friend in this situation?',
      'Try on the new thought and see how it feels'
    ],
    duration: '2-3 minutes',
    triggers: ['negative self-talk', 'catastrophizing', 'rumination'],
    genZPrompt: 'That thought sounds heavy. Let\'s run it through a quick reality check—this is a CBT technique that helps separate facts from feelings.'
  },
  {
    id: 'values-anchor',
    name: 'Values Check-In',
    technique: 'act-values-diffusion',
    steps: [
      'Name the difficult feeling without judging it',
      'Remember: thoughts and feelings are temporary visitors',
      'What matters most to you in this situation?',
      'What small action aligns with that value right now?'
    ],
    duration: '90 seconds',
    triggers: ['identity crisis', 'peer pressure', 'perfectionism'],
    genZPrompt: 'Sounds like you\'re caught up in some intense thoughts. Let\'s step back and reconnect with what actually matters to you.'
  },
  {
    id: 'opposite-action',
    name: 'Opposite Action Challenge',
    technique: 'dbt-tipp-stack',
    steps: [
      'Notice the urge and name the emotion driving it',
      'Ask: Is this emotion fitting the facts right now?',
      'If not, what would the opposite action look like?',
      'Take one small step in that opposite direction'
    ],
    duration: '2-5 minutes',
    triggers: ['avoidance', 'isolation', 'self-harm urges', 'anger'],
    genZPrompt: 'Your brain is telling you to do one thing, but let\'s try something different. This is called opposite action—it\'s a DBT skill that can break negative cycles.'
  },
  {
    id: 'micro-activation',
    name: 'Do One Thing',
    technique: 'behavioral-activation-micro',
    steps: [
      'Pick one tiny action that aligns with your values',
      'Set a 5-minute timer',
      'Do just that one thing, nothing else',
      'Notice any shift in your mood or energy'
    ],
    duration: '5-15 minutes',
    triggers: ['depression', 'low motivation', 'hopelessness'],
    genZPrompt: 'Depression is telling you nothing matters, but let\'s test that theory. Research shows even tiny actions can shift your brain chemistry.'
  }
];

// Crisis detection and escalation protocols
export const CRISIS_PROTOCOLS: CrisisProtocol[] = [
  {
    level: 'LOW',
    keywords: ['sad', 'down', 'stressed', 'anxious', 'worried', 'tired'],
    response: 'I hear that you\'re going through a tough time right now. Thanks for sharing that with me—it takes courage to reach out.',
    escalation: ['offer coping exercise', 'validate feelings', 'check in later'],
    resources: []
  },
  {
    level: 'MODERATE',
    keywords: ['hopeless', 'worthless', 'can\'t cope', 'overwhelming', 'breaking down', 'giving up'],
    response: 'What you\'re feeling sounds really intense and difficult. I\'m glad you\'re talking about it instead of keeping it inside.',
    escalation: ['crisis coping skills', 'professional resources', 'safety planning'],
    resources: ['Crisis Text Line: Text HOME to 741741', '988 Suicide & Crisis Lifeline']
  },
  {
    level: 'HIGH',
    keywords: ['want to die', 'kill myself', 'end it all', 'suicide', 'better off dead', 'no point living'],
    response: 'I\'m very concerned about what you\'ve shared. Your life has value and there are people who want to help you through this.',
    escalation: ['immediate crisis resources', 'emergency contacts', 'safety check'],
    resources: [
      '988 Suicide & Crisis Lifeline: Call or text 988',
      'Crisis Text Line: Text HOME to 741741',
      'Emergency: Call 911',
      'Trevor Project (LGBTQ+): 1-866-488-7386'
    ]
  },
  {
    level: 'CRITICAL',
    keywords: ['tonight', 'today', 'right now', 'have a plan', 'pills', 'gun', 'bridge', 'rope'],
    response: 'This is a mental health emergency. Please reach out for immediate help—you don\'t have to go through this alone.',
    escalation: ['emergency services', 'crisis hotline', 'trusted adult'],
    resources: [
      'EMERGENCY: Call 911 immediately',
      '988 Suicide & Crisis Lifeline: Call or text 988',
      'Go to your nearest emergency room',
      'Call a trusted friend, family member, or counselor right now'
    ]
  }
];

// Validated screening tools (short forms for daily check-ins)
export const SCREENING_TOOLS = {
  PHQ2: {
    name: 'PHQ-2 Depression Screen',
    questions: [
      'Over the past 2 weeks, how often have you felt down, depressed, or hopeless?',
      'Over the past 2 weeks, how often have you had little interest or pleasure in doing things?'
    ],
    scale: ['Not at all', 'Several days', 'More than half the days', 'Nearly every day'],
    scoring: { low: [0, 2], moderate: [3, 4], high: [5, 6] },
    citation: 'Kroenke et al. (2003) - PHQ-2 validation'
  },
  GAD2: {
    name: 'GAD-2 Anxiety Screen',
    questions: [
      'Over the past 2 weeks, how often have you felt nervous, anxious, or on edge?',
      'Over the past 2 weeks, how often have you been unable to stop or control worrying?'
    ],
    scale: ['Not at all', 'Several days', 'More than half the days', 'Nearly every day'],
    scoring: { low: [0, 2], moderate: [3, 4], high: [5, 6] },
    citation: 'Kroenke et al. (2007) - GAD-2 validation'
  }
};

// Gen Z communication patterns and tone guidelines
export const COMMUNICATION_GUIDELINES = {
  tone: {
    authentic: 'Direct but warm, no forced slang or performative language',
    validating: 'Acknowledge feelings first before offering solutions',
    scientific: 'Mention evidence subtly ("This comes from DBT research...")',
    empowering: 'Focus on user agency and small wins'
  },
  avoid: [
    'Toxic positivity ("just think positive!")',
    'Minimizing ("it could be worse")',
    'Forced Gen Z slang ("that\'s so sus")',
    'Medical advice or diagnosis',
    'Overwhelming information dumps'
  ],
  structure: {
    validation: '1-2 sentences acknowledging their experience',
    education: 'Brief explanation of the technique/science',
    action: 'One specific, doable step',
    followUp: 'Check-in question or encouragement'
  }
};

// Personalization based on user insights
export interface UserInsightPattern {
  category: string;
  indicators: string[];
  recommendations: string[];
  techniques: string[];
}

export const PERSONALIZATION_PATTERNS: UserInsightPattern[] = [
  {
    category: 'anxiety-prone',
    indicators: ['frequent worry', 'catastrophizing', 'physical symptoms'],
    recommendations: ['breathing exercises', 'grounding techniques', 'thought challenging'],
    techniques: ['box-breathing', 'thought-check', 'values-anchor']
  },
  {
    category: 'depression-indicators',
    indicators: ['low motivation', 'hopelessness', 'isolation', 'sleep issues'],
    recommendations: ['behavioral activation', 'routine building', 'social connection'],
    techniques: ['micro-activation', 'opposite-action', 'implementation-intentions']
  },
  {
    category: 'perfectionist',
    indicators: ['all-or-nothing thinking', 'fear of failure', 'procrastination'],
    recommendations: ['self-compassion', 'values clarification', 'progress over perfection'],
    techniques: ['values-anchor', 'thought-check', 'micro-activation']
  },
  {
    category: 'social-anxiety',
    indicators: ['fear of judgment', 'avoidance', 'overthinking interactions'],
    recommendations: ['gradual exposure', 'self-compassion', 'reality testing'],
    techniques: ['thought-check', 'opposite-action', 'values-anchor']
  }
];

// Crisis detection function
export function detectCrisisLevel(message: string): { level: CrisisProtocol['level']; confidence: number } {
  const lowerMessage = message.toLowerCase();
  
  // Check for critical indicators first
  const criticalMatches = CRISIS_PROTOCOLS.find(p => p.level === 'CRITICAL')?.keywords.filter(keyword => 
    lowerMessage.includes(keyword)
  ).length || 0;
  
  if (criticalMatches > 0) {
    return { level: 'CRITICAL', confidence: Math.min(criticalMatches * 0.4, 1.0) };
  }
  
  // Check for high-risk indicators
  const highMatches = CRISIS_PROTOCOLS.find(p => p.level === 'HIGH')?.keywords.filter(keyword => 
    lowerMessage.includes(keyword)
  ).length || 0;
  
  if (highMatches > 0) {
    return { level: 'HIGH', confidence: Math.min(highMatches * 0.3, 1.0) };
  }
  
  // Check for moderate indicators
  const moderateMatches = CRISIS_PROTOCOLS.find(p => p.level === 'MODERATE')?.keywords.filter(keyword => 
    lowerMessage.includes(keyword)
  ).length || 0;
  
  if (moderateMatches > 1) {
    return { level: 'MODERATE', confidence: Math.min(moderateMatches * 0.2, 1.0) };
  }
  
  // Check for low-level indicators
  const lowMatches = CRISIS_PROTOCOLS.find(p => p.level === 'LOW')?.keywords.filter(keyword => 
    lowerMessage.includes(keyword)
  ).length || 0;
  
  if (lowMatches > 0) {
    return { level: 'LOW', confidence: Math.min(lowMatches * 0.1, 1.0) };
  }
  
  return { level: 'LOW', confidence: 0 };
}

// Get appropriate coping exercise based on triggers
export function getCopingExercise(triggers: string[], userInsights?: any): CopingExercise | null {
  const matchingExercises = COPING_EXERCISES.filter(exercise => 
    exercise.triggers.some(trigger => 
      triggers.some(userTrigger => userTrigger.toLowerCase().includes(trigger))
    )
  );
  
  if (matchingExercises.length === 0) {
    return COPING_EXERCISES[0]; // Default to box breathing
  }
  
  // If user has insights, prefer exercises they've used successfully before
  if (userInsights?.successfulTechniques) {
    const preferredExercise = matchingExercises.find(exercise => 
      userInsights.successfulTechniques.includes(exercise.id)
    );
    if (preferredExercise) return preferredExercise;
  }
  
  return matchingExercises[0];
}

// Generate personalized response based on user insights
export function generatePersonalizedPrompt(
  exercise: CopingExercise, 
  userInsights?: any
): string {
  let prompt = exercise.genZPrompt;
  
  // Add personalization if insights available
  if (userInsights?.preferences?.music && exercise.id === 'box-breathing') {
    prompt += ' Want to queue up some music while we do this?';
  }
  
  if (userInsights?.successfulTechniques?.includes(exercise.id)) {
    prompt = `You've found this helpful before—${prompt.toLowerCase()}`;
  }
  
  return prompt;
}

export default {
  THERAPY_TECHNIQUES,
  COPING_EXERCISES,
  CRISIS_PROTOCOLS,
  SCREENING_TOOLS,
  COMMUNICATION_GUIDELINES,
  PERSONALIZATION_PATTERNS,
  detectCrisisLevel,
  getCopingExercise,
  generatePersonalizedPrompt
};
