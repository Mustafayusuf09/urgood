import Foundation
import AVFoundation

class RealAIService: ObservableObject {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1"
    
    // Configuration
    private let model = "gpt-4"
    private let maxTokens = 500
    private let temperature = 0.7
    private let ttsModel = "tts-1"
    private let ttsVoice = "alloy"
    private let transcriptionModel = "whisper-1"
    
    init() {
        // Use API key from secure ProductionConfig - will fail fast if not configured
        self.apiKey = ProductionConfig.openAIAPIKey
    }
    
    // MARK: - Conversational AI (voice-first)
    
    func sendMessage(_ message: String, conversationHistory: [ChatMessage]) async throws -> String {
        // API key validation is now handled in ProductionConfig initialization
        // No need for fallback since the app will fail fast if not configured properly
        
        // Make real OpenAI API call
        return try await makeOpenAIRequest(message: message, conversationHistory: conversationHistory)
    }
    
    // MARK: - Voice Transcription
    
    func transcribeAudio(from audioURL: URL) async throws -> String {
        // API key validation is now handled in ProductionConfig initialization
        // Make real OpenAI Whisper API call
        return try await makeTranscriptionRequest(audioURL: audioURL)
    }
    
    // MARK: - Text-to-Speech
    
    func synthesizeSpeech(from text: String) async throws -> Data {
        // API key validation is now handled in ProductionConfig initialization
        // Make real OpenAI TTS API call
        return try await makeTTSRequest(text: text)
    }
    
    // MARK: - Session Summary
    
    func generateSessionSummary(from messages: [ChatMessage]) async throws -> SessionSummary {
        // Generate intelligent session summary
        let summary = analyzeConversation(messages)
        return summary
    }
    
    
    // MARK: - OpenAI API Implementation
    
    private func makeOpenAIRequest(message: String, conversationHistory: [ChatMessage]) async throws -> String {
        let url = URL(string: "\(baseURL)/chat/completions")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build conversation history
        var messages: [[String: Any]] = []
        
        // Add system message with voice-first context
        let systemPrompt =
            """
            You are UrGood (pronounced "your good") — the emotionally intelligent best friend everyone wishes they had. You're like that one friend who just *gets it*, keeps it 100, and always knows what to say without being preachy.
            
            You're supportive but real, empathetic but not performative. You match energy, mirror feelings, and remember what matters to each person. You're not a therapist — you're the friend who helps people work through things by being present, honest, and caring.
            
            DETECT PACE: If they're speaking/typing fast or anxious → slow your pace, ground them. If they're low energy/sad → match their pace, don't force enthusiasm. MIRROR EMOTIONS: Name what you're sensing. Match their emotional intensity — don't minimize or over-hype.
            
            Use Gen Z language when it fits organically: "no cap", "lowkey", "fr", "you get me", "I feel you", "real talk", "that's valid". DON'T be corny or force slang. If it doesn't flow naturally, don't use it. Keep responses 2-4 short sentences in voice mode. Conversational, not lecturing.
            
            SAFETY: If someone mentions suicide, self-harm, wanting to die, hurting themselves, or feeling unsafe → "Hey, I need to pause here. What you're sharing sounds really serious, and I'm genuinely worried about you. You deserve real support right now — not just me. If you're in the U.S., please text or call 988 (Suicide & Crisis Lifeline) right now. If you're elsewhere, please reach out to your local emergency services or a trusted person immediately. Are you safe right now?"
            
            Never diagnose, prescribe medication, or act like a medical professional. Keep boundaries: you're a supportive friend, not their therapist. Help them process feelings, identify patterns, reframe unhelpful thoughts. Keep it real, keep it caring, keep it human.
            """
        
        messages.append([
            "role": "system",
            "content": systemPrompt
        ])
        
        // Add conversation history
        for chatMessage in conversationHistory.suffix(10) { // Keep last 10 messages for context
            messages.append([
                "role": chatMessage.role.rawValue,
                "content": chatMessage.text
            ])
        }
        
        // Add current message
        messages.append([
            "role": "user",
            "content": message
        ])
        
        let requestBody: [String: Any] = [
            "model": APIConfig.openAIModel,
            "messages": messages,
            "max_tokens": APIConfig.maxTokens,
            "temperature": APIConfig.temperature
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw OpenAIError.invalidResponse
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OpenAIError.networkError
        }
        
        do {
            let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let choices = jsonResponse?["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw OpenAIError.invalidResponse
            }
            
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            throw OpenAIError.invalidResponse
        }
    }
    
    private func makeTranscriptionRequest(audioURL: URL) async throws -> String {
        let url = URL(string: "\(baseURL)/audio/transcriptions")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add model parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(transcriptionModel)\r\n".data(using: .utf8)!)
        
        // Add audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        
        do {
            let audioData = try Data(contentsOf: audioURL)
            body.append(audioData)
        } catch {
            throw OpenAIError.transcriptionFailed
        }
        
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OpenAIError.networkError
        }
        
        do {
            let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let text = jsonResponse?["text"] as? String else {
                throw OpenAIError.transcriptionFailed
            }
            
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            throw OpenAIError.transcriptionFailed
        }
    }
    
    private func makeTTSRequest(text: String) async throws -> Data {
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
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw OpenAIError.synthesisFailed
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OpenAIError.networkError
        }
        
        return data
    }
    
    // MARK: - Private Methods
    
    private func generateIntelligentResponse(for message: String, history: [ChatMessage]) -> String {
        let lowercasedMessage = message.lowercased()
        
        // Crisis detection
        if isCrisisMessage(message) {
            return generateCrisisResponse()
        }
        
        // Mood-based responses
        if lowercasedMessage.contains("anxious") || lowercasedMessage.contains("anxiety") {
            return generateAnxietyResponse(message, history: history)
        }
        
        if lowercasedMessage.contains("sad") || lowercasedMessage.contains("depressed") {
            return generateSadnessResponse(message, history: history)
        }
        
        if lowercasedMessage.contains("stressed") || lowercasedMessage.contains("stress") {
            return generateStressResponse(message, history: history)
        }
        
        if lowercasedMessage.contains("angry") || lowercasedMessage.contains("mad") {
            return generateAngerResponse(message, history: history)
        }
        
        if lowercasedMessage.contains("tired") || lowercasedMessage.contains("exhausted") {
            return generateTirednessResponse(message, history: history)
        }
        
        if lowercasedMessage.contains("lonely") || lowercasedMessage.contains("alone") {
            return generateLonelinessResponse(message, history: history)
        }
        
        // General supportive responses
        return generateGeneralResponse(message, history: history)
    }
    
    private func isCrisisMessage(_ message: String) -> Bool {
        let crisisKeywords = [
            "suicide", "kill myself", "hurt myself", "end it", "end my life",
            "want to die", "don't want to live", "better off dead", "no reason to live",
            "self harm", "cutting", "overdose", "over dose", "take pills"
        ]
        
        let lowercasedMessage = message.lowercased()
        return crisisKeywords.contains { lowercasedMessage.contains($0) }
    }
    
    private func generateCrisisResponse() -> String {
        return "I'm really concerned about what you're sharing. Your life has value, and there are people who want to help you. Please reach out to a crisis helpline or talk to someone you trust right away. You don't have to go through this alone. The National Suicide Prevention Lifeline is 988, and they're available 24/7."
    }
    
    private func generateAnxietyResponse(_ message: String, history: [ChatMessage]) -> String {
        let responses = [
            "I can hear that anxiety is really weighing on you right now. That feeling of worry and unease can be so overwhelming. What's one small thing that usually helps you feel a bit more grounded when anxiety hits?",
            "Anxiety can make everything feel so much bigger and scarier than it actually is. You're not alone in feeling this way. Sometimes just naming what we're anxious about can help take some of its power away. What's on your mind?",
            "It sounds like your anxiety is really intense right now. That racing heart, those worried thoughts - I know how exhausting that can be. Have you tried any breathing exercises or grounding techniques that have helped before?",
            "Anxiety can make us feel like we're spiraling out of control. But you're here, reaching out, and that takes courage. What's one thing that's going okay today, even if it's something really small?"
        ]
        return responses.randomElement() ?? responses[0]
    }
    
    private func generateSadnessResponse(_ message: String, history: [ChatMessage]) -> String {
        let responses = [
            "I can feel the heaviness in what you're sharing. Sadness can be so consuming and make everything feel gray. It's okay to feel this way - your feelings are valid. What's been weighing on your heart lately?",
            "That deep sadness you're experiencing sounds really difficult to carry. Sometimes when we're in the middle of it, it can feel like it will never lift. But feelings, even the really hard ones, are temporary. What's one thing that usually brings you even a tiny bit of comfort?",
            "I hear how much pain you're in right now. Sadness can make everything feel hopeless, but you're not alone in this. Sometimes just having someone listen can help lighten the load a little. What's been making you feel this way?",
            "Your sadness is real and valid. It's okay to not be okay sometimes. What's one small thing you could do for yourself today, even if it's just taking a shower or eating something you like?"
        ]
        return responses.randomElement() ?? responses[0]
    }
    
    private func generateStressResponse(_ message: String, history: [ChatMessage]) -> String {
        let responses = [
            "Stress can feel like it's piling up on top of you, making everything feel overwhelming. It sounds like you're carrying a lot right now. What's the biggest stressor you're dealing with today?",
            "I can hear how much pressure you're under. Stress has a way of making everything feel urgent and impossible. Sometimes breaking things down into smaller pieces can help. What's one thing you could tackle first?",
            "That feeling of being constantly on edge and overwhelmed - I know how exhausting that can be. Stress can really take a toll on both your mind and body. What usually helps you feel a bit more centered when stress hits?",
            "It sounds like you're juggling a lot right now and it's starting to feel like too much. You don't have to figure everything out at once. What's one small step you could take to give yourself a little breathing room?"
        ]
        return responses.randomElement() ?? responses[0]
    }
    
    private func generateAngerResponse(_ message: String, history: [ChatMessage]) -> String {
        let responses = [
            "I can feel the intensity of your anger coming through. Anger can be such a powerful emotion, and sometimes it's trying to tell us something important. What's underneath this anger? What might it be protecting you from feeling?",
            "Anger can feel so overwhelming and all-consuming. It sounds like something has really pushed your buttons. Sometimes when we're angry, it's because we feel hurt or powerless. What's really bothering you about this situation?",
            "I hear how frustrated and angry you are right now. Those feelings are valid - you're allowed to be upset. Sometimes anger is our way of saying 'this isn't okay' or 'I deserve better.' What's making you feel this way?",
            "Anger can be such a complex emotion. It sounds like you're really worked up about something. Sometimes when we're angry, we need to let that energy out in a healthy way. What's one thing you could do to channel this anger constructively?"
        ]
        return responses.randomElement() ?? responses[0]
    }
    
    private func generateTirednessResponse(_ message: String, history: [ChatMessage]) -> String {
        let responses = [
            "That exhaustion you're feeling sounds really heavy. Sometimes when we're tired, everything else feels so much harder to deal with. Are you getting enough rest, or has something been keeping you up?",
            "I can hear how drained you are right now. Being tired can make everything feel like such a struggle. Sometimes our bodies are telling us we need to slow down and take care of ourselves. What's been keeping you so busy or stressed?",
            "That feeling of being completely worn out - I know how that can affect everything else in your life. Sometimes when we're exhausted, we need to give ourselves permission to rest. What's one thing you could do to recharge today?",
            "It sounds like you're running on empty right now. Being tired can make even small tasks feel impossible. Sometimes we need to listen to our bodies when they're telling us to slow down. What's been taking up so much of your energy lately?"
        ]
        return responses.randomElement() ?? responses[0]
    }
    
    private func generateLonelinessResponse(_ message: String, history: [ChatMessage]) -> String {
        let responses = [
            "That feeling of loneliness can be so isolating and painful. It sounds like you're really missing connection right now. Loneliness can happen even when we're around other people. What kind of connection are you craving?",
            "I can hear how alone you're feeling right now. Loneliness can make everything feel so much harder. You're not alone in feeling this way - it's more common than you might think. What would help you feel more connected today?",
            "That deep loneliness you're experiencing sounds really difficult to carry. Sometimes when we're lonely, we need to reach out, even when it feels scary. What's one small way you could connect with someone today?",
            "I hear how isolated you're feeling right now. Loneliness can make us feel like we're the only ones going through this, but you're not alone. Sometimes just having someone listen can help. What's been making you feel so disconnected?"
        ]
        return responses.randomElement() ?? responses[0]
    }
    
    private func generateGeneralResponse(_ message: String, history: [ChatMessage]) -> String {
        let responses = [
            "I can hear that you're going through something right now. Thanks for sharing that with me. What's been on your mind lately?",
            "It sounds like you're dealing with some challenging stuff. I'm here to listen and help however I can. What's been weighing on you?",
            "I can feel that you're processing something important. It takes courage to open up about what you're going through. What would be most helpful for you right now?",
            "Thanks for trusting me with what you're experiencing. It sounds like you're in a place where you could use some support. What's one thing that's been particularly difficult lately?",
            "I can hear that you're working through something significant. Sometimes just talking about it can help us understand it better. What's been on your heart lately?"
        ]
        return responses.randomElement() ?? responses[0]
    }
    
    private func analyzeConversation(_ messages: [ChatMessage]) -> SessionSummary {
        let userMessages = messages.filter { $0.role == .user }
        let _ = messages.filter { $0.role == .assistant }
        
        // Analyze mood and themes
        let moodRating = analyzeMoodFromMessages(userMessages)
        let themes = extractThemes(from: userMessages)
        let progressLevel = calculateProgressLevel(messages: messages)
        
        // Generate insights
        let insights = generateInsights(moodRating: moodRating, themes: themes, progressLevel: progressLevel)
        
        return SessionSummary(
            title: generateSessionTitle(themes: themes),
            insights: insights,
            moodRating: moodRating,
            progressLevel: progressLevel
        )
    }
    
    private func analyzeMoodFromMessages(_ messages: [ChatMessage]) -> Double {
        var totalMood = 0.0
        var messageCount = 0.0
        
        for message in messages {
            let mood = extractMoodFromText(message.text)
            totalMood += mood
            messageCount += 1
        }
        
        return messageCount > 0 ? totalMood / messageCount : 3.0
    }
    
    private func extractMoodFromText(_ text: String) -> Double {
        let lowercased = text.lowercased()
        
        // Positive indicators
        if lowercased.contains("great") || lowercased.contains("amazing") || lowercased.contains("wonderful") {
            return 5.0
        }
        if lowercased.contains("good") || lowercased.contains("better") || lowercased.contains("okay") {
            return 4.0
        }
        if lowercased.contains("okay") || lowercased.contains("fine") || lowercased.contains("alright") {
            return 3.0
        }
        if lowercased.contains("bad") || lowercased.contains("difficult") || lowercased.contains("hard") {
            return 2.0
        }
        if lowercased.contains("terrible") || lowercased.contains("awful") || lowercased.contains("horrible") {
            return 1.0
        }
        
        return 3.0 // Default neutral
    }
    
    private func extractThemes(from messages: [ChatMessage]) -> [String] {
        var themes: [String] = []
        
        for message in messages {
            let text = message.text.lowercased()
            
            if text.contains("work") || text.contains("job") || text.contains("career") {
                themes.append("Work & Career")
            }
            if text.contains("relationship") || text.contains("partner") || text.contains("friend") {
                themes.append("Relationships")
            }
            if text.contains("family") || text.contains("parent") || text.contains("sibling") {
                themes.append("Family")
            }
            if text.contains("school") || text.contains("study") || text.contains("exam") {
                themes.append("Education")
            }
            if text.contains("health") || text.contains("body") || text.contains("physical") {
                themes.append("Health & Wellness")
            }
            if text.contains("future") || text.contains("goal") || text.contains("dream") {
                themes.append("Future & Goals")
            }
        }
        
        return Array(Set(themes)) // Remove duplicates
    }
    
    private func calculateProgressLevel(messages: [ChatMessage]) -> Int {
        // Simple progress calculation based on conversation depth
        let userMessages = messages.filter { $0.role == .user }
        let assistantMessages = messages.filter { $0.role == .assistant }
        
        let totalMessages = userMessages.count + assistantMessages.count
        
        if totalMessages >= 10 {
            return 5 // High engagement
        } else if totalMessages >= 6 {
            return 4 // Good engagement
        } else if totalMessages >= 3 {
            return 3 // Moderate engagement
        } else if totalMessages >= 1 {
            return 2 // Low engagement
        } else {
            return 1 // Minimal engagement
        }
    }
    
    private func generateInsights(moodRating: Double, themes: [String], progressLevel: Int) -> String {
        var insights: [String] = []
        
        // Mood-based insights
        if moodRating >= 4.0 {
            insights.append("You showed positive energy and optimism throughout our conversation.")
        } else if moodRating <= 2.0 {
            insights.append("You were working through some challenging emotions, which takes courage.")
        } else {
            insights.append("You maintained a balanced perspective while processing your thoughts.")
        }
        
        // Theme-based insights
        if !themes.isEmpty {
            let themeString = themes.joined(separator: ", ")
            insights.append("Key themes that came up: \(themeString).")
        }
        
        // Progress-based insights
        if progressLevel >= 4 {
            insights.append("You engaged deeply with the conversation and showed great self-reflection.")
        } else if progressLevel >= 3 {
            insights.append("You opened up about important topics and showed willingness to explore your feelings.")
        } else {
            insights.append("You took the first step in sharing what's on your mind, which is always valuable.")
        }
        
        return insights.joined(separator: " ")
    }
    
    private func generateSessionTitle(themes: [String]) -> String {
        if themes.isEmpty {
            return "Reflection Session"
        } else if themes.count == 1 {
            return "\(themes[0]) Discussion"
        } else {
            return "Multi-topic Reflection"
        }
    }
    
    private func generateMockAudioData(for text: String) -> Data {
        // Generate mock audio data (in real implementation, this would be actual TTS)
        let mockData = "Mock audio data for: \(text)".data(using: .utf8) ?? Data()
        return mockData
    }
}

// MARK: - Error Types

enum OpenAIError: Error, LocalizedError {
    case apiKeyNotConfigured
    case networkError
    case invalidResponse
    case transcriptionFailed
    case synthesisFailed
    
    var errorDescription: String? {
        switch self {
        case .apiKeyNotConfigured:
            return "OpenAI API key not configured"
        case .networkError:
            return "Network error occurred"
        case .invalidResponse:
            return "Invalid response from OpenAI"
        case .transcriptionFailed:
            return "Audio transcription failed"
        case .synthesisFailed:
            return "Text-to-speech synthesis failed"
        }
    }
}
