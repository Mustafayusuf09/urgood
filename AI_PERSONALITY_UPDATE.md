# AI Personality Update - Best Friend Configuration

## Summary
Updated the AI personality across all services to act as an emotionally intelligent best friend that:
- ✅ Detects tone and pace
- ✅ Mirrors emotions authentically
- ✅ Personalizes guidance over time
- ✅ Includes comprehensive safety rails and crisis handoffs
- ✅ Speaks authentic Gen Z language without being corny

## Files Updated

### 1. OpenAIRealtimeClient.swift (Voice Chat - Primary)
**Location:** `urgood/urgood/Core/Services/OpenAIRealtimeClient.swift`

Enhanced the real-time voice AI prompt with:
- **Tone & Emotional Intelligence**: Detects pace (fast/anxious vs low energy), mirrors emotions, reads the room
- **Communication Style**: Natural, conversational Gen Z language used organically (no cap, lowkey, fr, etc.)
- **Personalization**: Remembers patterns, tracks what helps them, acknowledges emotional baseline changes
- **Safety & Crisis Response**: Comprehensive protocol for suicide/self-harm mentions with immediate resource handoff
- **Guardrails**: Clear boundaries - not a therapist, no diagnosis, no medical advice
- **Best Friend Approach**: Validates → Reflects → Gently nudges → Empowers

### 2. OpenAIService.swift (Text Chat)
**Location:** `urgood/urgood/Core/Services/OpenAIService.swift`

Updated text-based chat AI to match voice personality:
- Same emotional intelligence and tone detection principles
- Leverages user insights for personalization (`userInsights`, `successfulTechniques`, `commonTriggers`, `averageMood`)
- Crisis detection with immediate safety protocol
- Adaptive response length (2-4 sentences for voice, slightly longer for text)
- Integrated with existing personalization system

### 3. RealAIService.swift (Backup/Alternative Service)
**Location:** `urgood/urgood/Core/Services/RealAIService.swift`

Simplified but consistent prompt:
- Core best friend identity maintained
- Pace detection and emotion mirroring
- Authentic Gen Z language guidelines
- Safety protocol for crisis situations
- Clear professional boundaries

## Key Personality Traits

### Emotional Intelligence
- **Detects Pace**: Adjusts response speed based on user's speaking/typing pace and emotional state
- **Mirrors Emotions**: Names what they're sensing, matches emotional intensity appropriately
- **Reads the Room**: Differentiates between dysregulated, reflective, and celebratory states

### Communication Style
- **Authentic Gen Z**: Uses "no cap", "lowkey", "fr", "you get me", "I feel you", "real talk", "that's valid"
- **Not Corny**: Only uses slang when it flows naturally, never forced
- **Conversational**: Speaks like texting a close friend, no formal language
- **Concise**: 2-4 sentences in voice mode, slightly longer in text

### Personalization Features
The AI now actively:
- References patterns from previous conversations
- Reminds users of techniques that worked before
- Acknowledges progress in emotional baseline
- Uses stored insights about successful techniques, common triggers, and mood averages

### Safety & Crisis Management
Comprehensive safety protocols for:
- **Critical Indicators**: Suicide, self-harm, wanting to die, feeling unsafe
- **Immediate Response**: Pauses normal conversation, provides 988 (US) and local emergency resources
- **Safety Check**: "Are you safe right now? Do you have someone nearby you can talk to?"
- **Professional Referral**: Encourages therapy for ongoing abuse, severe depression, serious mental illness

### Clear Boundaries
The AI maintains:
- Not a therapist or medical professional
- No diagnosis or medication recommendations
- No specific medical/legal/financial advice
- Supportive friend, not clinical provider

## Integration with Existing Systems

The updated prompts integrate with:
- **User Insights System**: `getUserInsights()` provides personalization data
- **Crisis Detection**: `detectCrisisLanguage()` and `detectCopingNeed()` functions
- **Context Analysis**: `analyzeConversationContext()` determines conversation state
- **Cultural Config**: `CulturalConfig.swift` manages appropriate slang usage
- **Conversation History**: Last 10 messages for context continuity

## Testing Recommendations

Test the following scenarios:
1. **Pace Detection**: Fast anxious speech vs slow sad speech
2. **Emotion Mirroring**: High energy celebration vs low energy check-in
3. **Personalization**: Repeated mentions of same issue across sessions
4. **Safety Rails**: Crisis language triggers immediate protocol
5. **Gen Z Language**: Natural flow, not forced or corny
6. **Boundary Setting**: Requests for medical diagnosis or prescription

## Configuration Notes

- Voice AI uses OpenAI Realtime API with server-side VAD
- Text chat uses GPT-4 with conversation history
- Temperature, max tokens, and other parameters remain as configured in `APIConfig.swift`
- Crisis resources default to 988 (US) with guidance for international users

## Next Steps

Consider:
- [ ] Add more granular emotion detection (beyond just pace)
- [ ] Expand personalization with long-term memory storage
- [ ] A/B test different Gen Z language frequencies
- [ ] Add sentiment analysis for better emotional mirroring
- [ ] Implement conversation recap feature for continuity across sessions
