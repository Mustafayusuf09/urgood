import Foundation
import AVFoundation

class OpenAIService: ObservableObject {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1"
    
    // Configuration from APIConfig
    private let model: String
    private let maxTokens: Int
    private let temperature: Double
    private let transcriptionModel: String
    
    // TTS Configuration (for OpenAI TTS - though ElevenLabs is preferred)
    private let ttsModel = "tts-1"
    private let ttsVoice = "alloy"
    
    // Rate limiting and caching services
    private let rateLimitingService = RateLimitingService.shared
    private let responseCacheService = ResponseCacheService.shared
    private let circuitBreakerService = CircuitBreakerService.shared
    
    // Request tracking
    private var activeRequests: Set<UUID> = []
    private let requestQueue = DispatchQueue(label: "openai-requests", qos: .userInitiated)
    
    init() {
        self.apiKey = APIConfig.openAIAPIKey
        self.model = APIConfig.openAIModel
        self.maxTokens = APIConfig.maxTokens
        self.temperature = APIConfig.temperature
        self.transcriptionModel = APIConfig.transcriptionModel
        // NOTE: Text-to-speech now uses ElevenLabs exclusively
    }
    
    // MARK: - Conversational AI (voice-first)
    
    func sendMessage(_ message: String, conversationHistory: [ChatMessage]) async throws -> String {
        guard APIConfig.isConfigured else {
            print("❌ API Key not configured")
            throw OpenAIError.apiKeyNotConfigured
        }
        
        // Check circuit breaker
        guard circuitBreakerService.canExecuteRequest(for: "openai-chat") else {
            print("🚫 Circuit breaker is open for OpenAI chat service")
            throw OpenAIError.serviceUnavailable
        }
        
        // Check cache first
        let cacheKey = responseCacheService.generateCacheKey(message: message, conversationHistory: conversationHistory)
        if let cachedResponse = responseCacheService.getCachedResponse(for: cacheKey) {
            print("💾 Using cached response for message")
            return cachedResponse
        }
        
        // Check rate limiting (assuming free user for now - TODO: get actual subscription status)
        let userId = getCurrentUserId()
        guard rateLimitingService.canMakeRequest(userId: userId, isPremium: false) else {
            let resetTime = rateLimitingService.getTimeUntilReset(userId: userId)
            throw OpenAIError.rateLimitExceeded(resetTime: resetTime)
        }
        
        print("🔑 API Key configured: \(apiKey.prefix(10))...")
        print("🤖 Using model: \(model)")
        print("🌡️ Temperature: \(temperature)")
        print("📝 Max tokens: \(maxTokens)")
        
        // Record the request
        rateLimitingService.recordRequest(userId: userId, isPremium: false)
        
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Analyze conversation context for therapeutic appropriateness
        let context = analyzeConversationContext(message, conversationHistory: conversationHistory)
        
        // Get user insights for personalization
        let userInsights = await getUserInsights()
        let contextualSlang = getContextualSlang(context: context, userMessage: message)
        let appContext = getAppContext(userMessage: message, conversationHistory: conversationHistory)
        
        // Detect if user needs immediate coping support
        let needsCoping = detectCopingNeed(message: message)
        let crisisLevel = detectCrisisLanguage(message: message)
        
                // Build conversation context
        var messages: [[String: String]] = [
            [
                "role": "system",
                "content": """
                You are **UrGood** (pronounced "your good"), a Gen Z-first mental health coach. Show up like a grounded hype bestie (ages 17–25) who knows CBT/DBT inside out and respects boundaries. Help people:
                (1) discover new, personally relevant patterns about themselves,
                (2) regulate their current mood/situation, and
                (3) choose a next action they can realistically do today.

                **Core Principles:**
                - Discovery First: ask focused, low-effort questions that reveal patterns about triggers, thoughts, feelings, body sensations, and behaviors.
                - One Step Forward: every exchange ends with a small, doable next action or reflection prompt.
                - CBT Toolkit: identify automatic thoughts, cognitive distortions, evidence-for/against, balanced reframe, behavioral activation.
                - DBT Toolkit: mindfulness (observe, describe, non-judgment), TIPP, STOP, radical acceptance, self-soothing, opposite action, DEAR MAN.
                - Adaptive Depth: if user is dysregulated, use DBT first (ground → regulate). If stable, use CBT for insight/reframe + a behavioral experiment.
                - Micro-Experiments: turn insights into 5–10 minute experiments. Log hypotheses → results → learnings.
                - Measurable: use 0–10 scales for mood/stress/urge; re-rate after an exercise to show change.
                - Agency & Choice: offer 2–3 options; let the user pick.

                **Therapeutic Frame:**
                Evidence-informed CBT (cognitive restructuring, behavioral activation, thought records) + DBT (mindfulness, distress tolerance, emotion regulation, interpersonal effectiveness).

                **Style:**
                - Warm, collaborative, curious; short paragraphs; concrete steps.
                - Sounds like a supportive Gen Z peer mentor: authentic, hype, never cringe or performative.
                - Sprinkle current slang or emoji only if it enhances connection (max once per turn). Favor words like "no cap", "low-key", "bestie", "you ate" over dated slang.
                - Mirror the user’s energy. If they’re dysregulated, be grounding and calm. If they’re celebrating, hype them up.

                **Voice & UX:**
                - Short, concrete, non-clinical language that references Gen Z life (campus vibes, roommates, side hustles, creator burnout, finals, digital overload).
                - VOICE MODE: Keep responses conversational and natural for speech. Use contractions (I'm, you're, let's), natural pauses, and speak like you're having a real conversation with a friend.
                - Avoid long lists or bullet points in voice mode - speak in flowing, natural sentences.
                - Use vocal fillers sparingly and naturally: "you know", "like", "I mean" - but don't overdo it.
                - No diagnosis, no moralizing.
                - If the app indicates "Pulse/Chat," prioritize grounding or quick support.
                - If "Insights," prioritize pattern discovery + reframes.
                - If "Profile/You," support values, strengths, routines.
                - Turn insights into micro-experiments that fit Gen Z schedules (class breaks, co-working, gaming queues).

                **End Every Turn With:**
                - (a) a *single* next step or reflection question, or
                - (b) a choice of 2–3 short options (each <10 minutes).
                - If it builds motivation, mention streaks, habit XP, or badges—but never guilt-trip.

                **Safety:**
                - If user mentions imminent self-harm, intent, plan, or inability to stay safe → say you're not a crisis service, share crisis options, encourage reaching out to a trusted person; keep messages calm and brief, ask if they are safe right now.
                - If severe symptoms or persistent impairment → suggest professional help and practical pathways (e.g., "Would you like a short checklist to find a therapist?")

                **Dialogue Policy (behavior tree):**
                1. Check safety → If red flags → crisis protocol (short, supportive, resource-forward).
                2. State detect → highly_dysregulated → DBT regulate (TIPP/STOP/soothe) → re-rate → move to discovery.
                3. Discovery → 1–2 targeted questions (triggers / thoughts / feelings / body / behavior).
                4. CBT/DBT intervention → pick one tool based on user state and goal.
                5. Micro-experiment/next step → specific, ≤10 min, time-boxed.
                6. Measure → "From 0–10, where are you now?" Log deltas.
                7. Reflect → "What did you learn about yourself?" Capture insight.

                **CBT Tools (translate into Gen Z-friendly language):**
                - Identify automatic thoughts: "What thought just jumped in?"
                - Challenge distortions: "Is that 100% facts, or do you have receipts showing otherwise?"
                - Evidence for/against: "What backs this up? Any proof it’s not the full story?"
                - Balanced reframe: "A more balanced take could be..."
                - Behavioral activation: "What's one tiny move to boost your vibe 1%?"

                **DBT Tools (keep them non-cringe):**
                - TIPP: cold water splash, 30s wall push-ups, paced breathing 4:6, muscle squeeze + release
                - STOP: Pause → breathe → notice → move with intention
                - Mindfulness: "What's happening in your body right now?"
                - Opposite action: "If you did the opposite of what this feeling wants, what would that look like?"
                - DEAR MAN: Craft a two-sentence script that sounds like you.

                **Discovery Prompts:**
                - "What happened right before the feeling spiked—notifications, roommate vibes, campus energy?"
                - "If this feeling had a playlist, what's the top track and why?"
                - "What pattern have you noticed this week: time of day, people, classes, screens?"
                - "What's the smallest action that moves you 1% toward how you want to feel?"
                - "What would 70% done look like so perfectionism doesn’t steal your energy?"
                - "What's one kinder assumption you could test about this situation?"

                **Micro-Exercises (ready to suggest):**
                - TIPP: cold water 60–90s; paced breathing 2–3 min; brief muscle tensing
                - Grounding 5-4-3-2-1: senses scan 90s
                - Opposite Action: pick emotion → choose opposite behavior for 5 minutes
                - BA Sprints: 7-minute "70% good enough"
                - DEAR MAN: two-sentence script
                - Worry Parking: write list now → schedule 10 min tomorrow

                **Crisis Response:**
                "I'm not a crisis service, but you deserve support. If you're in danger or feel you might act on these thoughts, call your local emergency number now or a crisis line. Are you safe right now?"

                **Guardrails:**
                - Not a clinician; crisis routing protocol; avoids diagnosis; encourages professional help when appropriate.
                - Keep assistant turns short (≤120 words), end with one next step or two options.
                - Use 0–10 ratings often, plus re-rate after skills.
                - Avoid clinical labels/diagnoses entirely.
                - Seed safety examples with compassionate, concise language.

                **Current Context:**
                - App context: \(appContext.isEmpty ? "General chat" : appContext)
                - Interaction mode: VOICE CONVERSATION - Speak naturally, conversationally, and warmly.
                - Cultural seasoning: \(contextualSlang ?? "none - keep it authentic and empathetic")
                - User insights: \(userInsights)
                - Needs coping support: \(needsCoping)
                - Crisis level: \(crisisLevel)
                - Remember: slang is seasoning, not the main dish. Use sparingly and only when it enhances empathy.
                
                **Personalization Notes:**
                - Previously helpful techniques: \(userInsights["successfulTechniques"] ?? [])
                - Common triggers: \(userInsights["commonTriggers"] ?? [])
                - Recent mood average: \(userInsights["averageMood"] ?? 5.0)/10
                - If crisis level is HIGH or CRITICAL, prioritize safety resources immediately
                - If needsCoping is true, offer grounding techniques first

                **End every response with either:**
                1. A single next step or reflection question, OR
                2. A choice of 2-3 short options (each <10 minutes)

                Your goal is to help users discover patterns, regulate their mood, and take one small step forward today.
                """
            ]
        ]
        
        // Add conversation history (last 10 messages to stay within context limits)
        let recentMessages = conversationHistory.suffix(10)
        for message in recentMessages {
            messages.append([
                "role": message.role == .user ? "user" : "assistant",
                "content": message.text
            ])
        }
        
        // Add current message
        messages.append([
            "role": "user",
            "content": message
        ])
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": maxTokens,
            "temperature": temperature
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = APIConfig.requestTimeout
        
        print("🚀 Sending request to OpenAI API...")
        
        // Execute request with retry logic
        let (data, response) = try await executeRequestWithRetry(request: request, serviceName: "openai-chat")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let errorMessage = errorResponse?["error"] as? [String: Any]
            let message = errorMessage?["message"] as? String ?? "Unknown error"
            
            // Handle specific error cases
            if httpResponse.statusCode == 401 {
                throw OpenAIError.apiKeyInvalid
            } else if httpResponse.statusCode == 429 {
                throw OpenAIError.rateLimitExceeded(resetTime: 60.0)
            } else if httpResponse.statusCode >= 500 {
                throw OpenAIError.serverError
            } else {
                throw OpenAIError.apiError(statusCode: httpResponse.statusCode, message: message)
            }
        }
        
        let responseData = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = responseData?["choices"] as? [[String: Any]]
        let firstChoice = choices?.first
        let message = firstChoice?["message"] as? [String: Any]
        let content = message?["content"] as? String
        
        print("📝 AI Response content: \(content ?? "No content")")
        
        guard let content = content else {
            print("❌ No content in response")
            circuitBreakerService.recordFailure(for: "openai-chat")
            throw OpenAIError.invalidResponse
        }
        
        // Record success and cache response
        circuitBreakerService.recordSuccess(for: "openai-chat")
        responseCacheService.cacheResponse(content, for: cacheKey)
        
        return content
    }
    
    // MARK: - Speech-to-Text (Transcription)
    
    func transcribeAudio(from audioURL: URL) async throws -> String {
        guard APIConfig.isConfigured else {
            throw OpenAIError.apiKeyNotConfigured
        }
        
        print("🎤 Starting audio transcription...")
        print("📁 Audio file: \(audioURL.lastPathComponent)")
        
        let url = URL(string: "\(baseURL)/audio/transcriptions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(try Data(contentsOf: audioURL))
        body.append("\r\n".data(using: .utf8)!)
        
        // Add model
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(transcriptionModel)\r\n".data(using: .utf8)!)
        
        // Add language (optional, but helpful for accuracy)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("en\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("🚀 Sending transcription request to OpenAI...")
        print("📊 Request body size: \(body.count) bytes")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid response type")
            throw OpenAIError.invalidResponse
        }
        
        print("📡 Response status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let errorMessage = errorResponse?["error"] as? [String: Any]
            let message = errorMessage?["message"] as? String ?? "Unknown error"
            
            print("❌ Transcription failed with status \(httpResponse.statusCode): \(message)")
            
            if httpResponse.statusCode == 401 {
                throw OpenAIError.apiKeyInvalid
            } else if httpResponse.statusCode == 429 {
                throw OpenAIError.rateLimitExceeded(resetTime: 60.0)
            } else {
                throw OpenAIError.apiError(statusCode: httpResponse.statusCode, message: message)
            }
        }
        
        let responseData = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let text = responseData?["text"] as? String
        
        guard let text = text else {
            print("❌ No text in transcription response")
            throw OpenAIError.invalidResponse
        }
        
        print("✅ Transcription successful: \(text)")
        return text
    }
    
    // MARK: - Text-to-Speech
    
    func synthesizeSpeech(from text: String) async throws -> Data {
        guard APIConfig.isConfigured else {
            throw OpenAIError.apiKeyNotConfigured
        }
        
        print("🔊 Starting speech synthesis...")
        print("📝 Text length: \(text.count) characters")
        print("🎵 Using voice: \(ttsVoice), model: \(ttsModel)")
        
        let url = URL(string: "\(baseURL)/audio/speech")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": ttsModel,
            "input": text,
            "voice": ttsVoice,
            "response_format": "mp3",
            "speed": 1.0
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("🚀 Sending TTS request to OpenAI...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid TTS response type")
            throw OpenAIError.invalidResponse
        }
        
        print("📡 TTS Response status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let errorMessage = errorResponse?["error"] as? [String: Any]
            let message = errorMessage?["message"] as? String ?? "Unknown error"
            
            print("❌ TTS failed with status \(httpResponse.statusCode): \(message)")
            
            if httpResponse.statusCode == 401 {
                throw OpenAIError.apiKeyInvalid
            } else if httpResponse.statusCode == 429 {
                throw OpenAIError.rateLimitExceeded(resetTime: 60.0)
            } else {
                throw OpenAIError.apiError(statusCode: httpResponse.statusCode, message: message)
            }
        }
        
        print("✅ TTS successful, audio data size: \(data.count) bytes")
        return data
    }
    
    // MARK: - Session Summaries
    
    func generateSessionSummary(from messages: [ChatMessage]) async throws -> SessionSummary {
        guard APIConfig.isConfigured else {
            throw OpenAIError.apiKeyNotConfigured
        }
        
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build conversation context for summary
        let conversationText = messages.map { "\($0.role.rawValue): \($0.text)" }.joined(separator: "\n")
        
        let messages: [[String: String]] = [
            [
                "role": "system",
                "content": """
                You are an AI assistant that creates helpful session summaries for mental health conversations. 
                Analyze the conversation and provide:
                1. A brief title (2-4 words)
                2. Key themes discussed
                3. Main insights or breakthroughs
                4. Overall mood/emotional state (1-5 scale)
                5. Progress made or challenges overcome
                
                Keep summaries concise, supportive, and focused on growth and positive outcomes.
                """
            ],
            [
                "role": "user",
                "content": "Please analyze this conversation and provide a summary:\n\n\(conversationText)"
            ]
        ]
        
        let requestBody: [String: Any] = [
            "model": APIConfig.summaryModel,
            "messages": messages,
            "max_tokens": APIConfig.summaryMaxTokens,
            "temperature": APIConfig.summaryTemperature
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let errorMessage = errorResponse?["error"] as? [String: Any]
            let message = errorMessage?["message"] as? String ?? "Unknown error"
            
            if httpResponse.statusCode == 401 {
                throw OpenAIError.apiKeyInvalid
            } else if httpResponse.statusCode == 429 {
                throw OpenAIError.rateLimitExceeded(resetTime: 60.0)
            } else {
                throw OpenAIError.apiError(statusCode: httpResponse.statusCode, message: message)
            }
        }
        
        let responseData = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = responseData?["choices"] as? [[String: Any]]
        let firstChoice = choices?.first
        let message = firstChoice?["message"] as? [String: Any]
        let content = message?["content"] as? String
        
        guard let content = content else {
            throw OpenAIError.invalidResponse
        }
        
        // Parse the AI response into structured data
        return parseSessionSummary(content)
    }
    
    
    // MARK: - Helper Methods
    
    private func parseSessionSummary(_ content: String) -> SessionSummary {
        // Simple parsing - in a real app, you might use more sophisticated parsing
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        let title = lines.first?.replacingOccurrences(of: "Title:", with: "").trimmingCharacters(in: .whitespaces) ?? "Session"
        let insights = lines.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespaces)
        
        return SessionSummary(
            title: title,
            insights: insights,
            moodRating: 3.0, // Default neutral
            progressLevel: 3 // Default moderate
        )
    }
    
    // MARK: - App Context Analysis
    
    /// Get comprehensive app context for the AI to provide better assistance
    private func getAppContext(userMessage: String, conversationHistory: [ChatMessage]) -> String {
        var context = ""
        
        // Add user's recent activity context
        let recentMessages = conversationHistory.suffix(5)
        if !recentMessages.isEmpty {
            context += "Recent conversation topics: "
            let topics = recentMessages.compactMap { message in
                if message.role == .user {
                    return extractMainTopic(from: message.text)
                }
                return nil
            }
            context += topics.joined(separator: ", ")
            context += "\n"
        }
        
        // Add app feature suggestions based on message content
        let message = userMessage.lowercased()
        
        if message.contains("mood") || message.contains("feeling") || message.contains("emotion") {
            context += "User seems interested in mood tracking - suggest Insights tab for check-ins and mood logging.\n"
        }
        
        
        if message.contains("progress") || message.contains("improvement") || message.contains("better") {
            context += "User is focused on growth - suggest reviewing session summaries in Insights tab.\n"
        }
        
        // Enhanced crisis detection
        let crisisKeywords = ["crisis", "emergency", "suicide", "kill myself", "end it all", "hurt myself", "self harm", "can't go on", "want to die", "not worth it", "better off dead", "give up", "hopeless", "helpless", "trapped", "no way out"]
        if crisisKeywords.contains(where: { message.contains($0) }) {
            context += "🚨 CRISIS DETECTED - provide immediate support and crisis resources. Use empathetic language and direct to professional help.\n"
        }
        
        if message.contains("premium") || message.contains("upgrade") || message.contains("unlimited") {
            context += "User interested in premium features - explain benefits of unlimited messages and advanced insights.\n"
        }
        
        // Add app usage context (non-sensitive)
        let totalMessages = conversationHistory.count
        if totalMessages > 0 {
            context += "User has \(totalMessages) total messages in their history - they're an active user.\n"
        }
        
        // Add session context
        let today = Calendar.current.startOfDay(for: Date())
        let todaysMessages = conversationHistory.filter { message in
            Calendar.current.isDate(message.date, inSameDayAs: today)
        }
        
        if !todaysMessages.isEmpty {
            context += "User has been active today with \(todaysMessages.count) messages.\n"
        }
        
        return context
    }
    
    /// Extract main topic from user message for context
    private func extractMainTopic(from message: String) -> String? {
        let message = message.lowercased()
        
        if message.contains("anxiety") || message.contains("worried") || message.contains("nervous") {
            return "anxiety"
        } else if message.contains("depressed") || message.contains("sad") || message.contains("down") {
            return "depression"
        } else if message.contains("stress") || message.contains("overwhelmed") || message.contains("pressure") {
            return "stress"
        } else if message.contains("relationship") || message.contains("friend") || message.contains("family") {
            return "relationships"
        } else if message.contains("work") || message.contains("school") || message.contains("career") {
            return "work/school"
        } else if message.contains("sleep") || message.contains("tired") || message.contains("energy") {
            return "sleep/energy"
        } else if message.contains("self-care") || message.contains("wellness") || message.contains("health") {
            return "self-care"
        }
        
        return nil
    }
    
    // MARK: - Cultural Context Analysis
    
    /// Analyze the conversation context to determine appropriate cultural seasoning
    private func analyzeConversationContext(_ userMessage: String, conversationHistory: [ChatMessage]) -> ConversationContext {
        let message = userMessage.lowercased()
        
        // Enhanced crisis detection
        let crisisKeywords = ["crisis", "emergency", "suicide", "kill myself", "end it all", "hurt myself", "self harm", "can't go on", "want to die", "not worth it", "better off dead", "give up", "hopeless", "helpless", "trapped", "no way out"]
        if crisisKeywords.contains(where: { message.contains($0) }) {
            return .crisis
        }
        
        // Check for serious/upset indicators
        let seriousKeywords = ["terrible", "awful", "worst", "hate", "destroyed", "broken", "hopeless", "anxiety", "panic", "overwhelming", "devastated", "crushed", "shattered", "desperate", "frustrated", "angry", "rage"]
        let seriousCount = seriousKeywords.filter { message.contains($0) }.count
        if seriousCount >= 2 {
            return .serious
        }
        
        // Check for celebration/achievement indicators
        let celebrationKeywords = ["accomplished", "success", "proud", "achieved", "won", "got the job", "passed", "finished", "breakthrough", "progress", "improvement", "better", "proud of myself", "did it", "made it"]
        if celebrationKeywords.contains(where: { message.contains($0) }) {
            return .celebration
        }
        
        // Check for encouragement-seeking indicators
        let encouragementKeywords = ["struggling", "difficult", "hard", "stressed", "overwhelmed", "help", "advice", "stuck", "confused", "lost", "unsure", "don't know what to do", "need guidance", "feeling lost"]
        if encouragementKeywords.contains(where: { message.contains($0) }) {
            return .encouragement
        }
        
        let goalKeywords = ["goal", "plan", "routine", "schedule", "goal-setting", "habit", "structure", "roadmap", "milestone", "challenge", "commit", "commitment", "consistency", "tracking", "level up"]
        if goalKeywords.contains(where: { message.contains($0) }) {
            return .goalSetting
        }

        // Check for therapeutic exploration indicators
        let explorationKeywords = ["why do I", "what if", "I wonder", "thinking about", "reflecting", "realized", "noticed", "pattern", "always", "never", "everyone", "nobody", "should", "must", "have to"]
        if explorationKeywords.contains(where: { message.contains($0) }) {
            return .exploration
        }
        
        // Default to casual for general conversation
        return .casual
    }
    
    /// Get appropriate slang for the conversation context
    private func getContextualSlang(context: ConversationContext, userMessage: String) -> String? {
        guard CulturalConfig.isSlangAppropriate(context: context, userMessage: userMessage) else {
            return nil
        }
        
        return CulturalConfig.getRandomSlang(context: context, userMessage: userMessage)
    }
    
    // MARK: - Helper Methods
    
    private func executeRequestWithRetry(request: URLRequest, serviceName: String) async throws -> (Data, URLResponse) {
        var lastError: Error?
        
        for attempt in 1...APIConfig.retryAttempts {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                // Check for HTTP errors
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode >= 500 {
                        // Server error - record failure and retry
                        circuitBreakerService.recordFailure(for: serviceName)
                        throw OpenAIError.serverError
                    } else if httpResponse.statusCode == 429 {
                        // Rate limit - don't retry immediately
                        circuitBreakerService.recordFailure(for: serviceName)
                        throw OpenAIError.rateLimitExceeded(resetTime: 60.0)
                    } else if httpResponse.statusCode >= 400 {
                        // Client error - don't retry
                        let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                        let errorMessage = (errorData?["error"] as? [String: Any])?["message"] as? String ?? "Unknown error"
                        circuitBreakerService.recordFailure(for: serviceName)
                        throw OpenAIError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
                    }
                }
                
                return (data, response)
                
            } catch {
                lastError = error
                circuitBreakerService.recordFailure(for: serviceName)
                
                // Don't retry on certain errors
                if let openAIError = error as? OpenAIError {
                    switch openAIError {
                    case .apiKeyInvalid, .apiKeyNotConfigured:
                        throw error
                    default:
                        break
                    }
                }
                
                // Wait before retry with exponential backoff
                if attempt < APIConfig.retryAttempts {
                    let delay = APIConfig.baseRetryDelay * pow(2.0, Double(attempt - 1))
                    print("🔄 Request failed, retrying in \(delay)s (attempt \(attempt)/\(APIConfig.retryAttempts))")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        // All retries failed
        if let lastError = lastError {
            throw lastError
        } else {
            throw OpenAIError.networkError(NSError(domain: "OpenAIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "All retry attempts failed"]))
        }
    }
    
    private func getCurrentUserId() -> String {
        // TODO: Get actual user ID from authentication service
        return "default-user"
    }
    
    // MARK: - Therapy Knowledge Integration
    
    private func detectCopingNeed(message: String) -> Bool {
        let lowerMessage = message.lowercased()
        let copingTriggers = [
            "anxious", "panic", "overwhelmed", "stressed", "can't cope",
            "breaking down", "losing it", "freaking out", "spiraling"
        ]
        return copingTriggers.contains { lowerMessage.contains($0) }
    }
    
    private func detectCrisisLanguage(message: String) -> String {
        let lowerMessage = message.lowercased()
        
        // Critical indicators
        let criticalKeywords = ["want to die", "kill myself", "end it all", "suicide", "better off dead"]
        if criticalKeywords.contains(where: { lowerMessage.contains($0) }) {
            return "CRITICAL"
        }
        
        // High risk indicators
        let highRiskKeywords = ["hopeless", "worthless", "no point living", "giving up"]
        if highRiskKeywords.contains(where: { lowerMessage.contains($0) }) {
            return "HIGH"
        }
        
        // Moderate indicators
        let moderateKeywords = ["can't cope", "overwhelming", "breaking down"]
        if moderateKeywords.contains(where: { lowerMessage.contains($0) }) {
            return "MODERATE"
        }
        
        return "LOW"
    }
    
    private func getUserInsights() async -> [String: Any] {
        // Get user insights from local storage
        let localStore = EnhancedLocalStore.shared
        
        var insights: [String: Any] = [:]
        
        // Get successful techniques from chat history
        let recentMessages = localStore.chatMessages.suffix(20)
        var successfulTechniques: [String] = []
        
        for message in recentMessages {
            if message.role == .assistant {
                // Look for technique mentions
                let content = message.text.lowercased()
                if content.contains("breathing") || content.contains("breath") {
                    successfulTechniques.append("breathing")
                }
                if content.contains("grounding") {
                    successfulTechniques.append("grounding")
                }
                if content.contains("reframe") || content.contains("thought") {
                    successfulTechniques.append("cognitive-reframing")
                }
            }
        }
        
        insights["successfulTechniques"] = Array(Set(successfulTechniques))
        
        // Get mood patterns from recent entries
        let recentMoods = localStore.moodEntries.suffix(10)
        let averageMood = recentMoods.isEmpty ? 5.0 : Double(recentMoods.map { $0.mood }.reduce(0, +)) / Double(recentMoods.count)
        insights["averageMood"] = averageMood
        
        // Identify common triggers from mood tags
        var triggers: [String] = []
        for entry in recentMoods {
            for tag in entry.tags {
                let tagName = tag.name.lowercased()
                if tagName.contains("work") || tagName.contains("job") {
                    triggers.append("work-stress")
                }
                if tagName.contains("social") || tagName.contains("friends") {
                    triggers.append("social-anxiety")
                }
                if tagName.contains("school") || tagName.contains("exam") {
                    triggers.append("academic-pressure")
                }
            }
        }
        insights["commonTriggers"] = Array(Set(triggers))
        
        return insights
    }
    
    // MARK: - Error Handling
    
    enum OpenAIError: LocalizedError {
        case apiKeyNotConfigured
        case apiKeyInvalid
        case invalidResponse
        case apiError(statusCode: Int, message: String)
        case rateLimitExceeded(resetTime: TimeInterval)
        case serverError
        case serviceUnavailable
        case networkError(Error)
        case transcriptionFailed
        case synthesisFailed
        
        var errorDescription: String? {
            switch self {
            case .apiKeyNotConfigured:
                return APIConfig.apiKeyNotConfiguredMessage
            case .apiKeyInvalid:
                return "Invalid API key. Please check your OpenAI API key and try again."
            case .invalidResponse:
                return "Invalid response from OpenAI API"
            case .apiError(let statusCode, let message):
                return "OpenAI API error (\(statusCode)): \(message)"
            case .rateLimitExceeded(let resetTime):
                let minutes = Int(resetTime / 60)
                let seconds = Int(resetTime.truncatingRemainder(dividingBy: 60))
                return "Rate limit exceeded. Try again in \(minutes)m \(seconds)s."
            case .serverError:
                return "OpenAI servers are experiencing issues. Please try again later."
            case .serviceUnavailable:
                return "AI service is temporarily unavailable. Please try again in a few minutes."
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .transcriptionFailed:
                return "Failed to transcribe audio. Please try recording again."
            case .synthesisFailed:
                return "Failed to generate speech. Please try again."
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .apiKeyNotConfigured:
                return "Add your OpenAI API key to APIConfig.swift"
            case .apiKeyInvalid:
                return "Verify your API key at https://platform.openai.com/api-keys"
            case .rateLimitExceeded:
                return "Wait a moment before trying again"
            case .serverError:
                return "Check OpenAI status at https://status.openai.com"
            case .serviceUnavailable:
                return "The service will automatically retry. Please wait a few minutes."
            case .transcriptionFailed:
                return "Ensure you have a stable internet connection and try recording again"
            case .synthesisFailed:
                return "Check your internet connection and try again"
            default:
                return "Check your internet connection and try again"
            }
        }
    }
}

// MARK: - Extensions

extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
