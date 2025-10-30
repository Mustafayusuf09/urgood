import Foundation
import NaturalLanguage

class ContentModerationService: ObservableObject {
    static let shared = ContentModerationService()
    
    private let toxicityClassifier = ToxicityClassifier()
    private let sentimentAnalyzer = SentimentAnalyzer()
    private let crisisDetector = CrisisDetector()
    private let spamDetector = SpamDetector()
    private let profanityFilter = ProfanityFilter()
    
    @Published var moderationStats = ModerationStats()
    
    private init() {}
    
    // MARK: - Content Moderation
    
    func moderateContent(_ content: String, userId: String) async -> ModerationResult {
        let startTime = Date()
        
        // Run all moderation checks in parallel
        async let toxicityResult = toxicityClassifier.classify(content)
        async let sentimentResult = sentimentAnalyzer.analyze(content)
        async let crisisResult = crisisDetector.detect(content)
        async let spamResult = spamDetector.detect(content)
        async let profanityResult = profanityFilter.filter(content)
        
        // Wait for all results
        let (toxicity, sentiment, crisis, spam, profanity) = await (
            toxicityResult, sentimentResult, crisisResult, spamResult, profanityResult
        )
        
        // Determine overall moderation decision
        let decision = determineModerationDecision(
            toxicity: toxicity,
            sentiment: sentiment,
            crisis: crisis,
            spam: spam,
            profanity: profanity
        )
        
        // Create moderation result
        let result = ModerationResult(
            content: content,
            userId: userId,
            decision: decision,
            reasons: buildModerationReasons(
                toxicity: toxicity,
                sentiment: sentiment,
                crisis: crisis,
                spam: spam,
                profanity: profanity
            ),
            confidence: calculateConfidence(
                toxicity: toxicity,
                sentiment: sentiment,
                crisis: crisis,
                spam: spam,
                profanity: profanity
            ),
            timestamp: Date(),
            processingTime: Date().timeIntervalSince(startTime)
        )
        
        // Update statistics
        await updateModerationStats(result)
        
        // Log moderation event
        await logModerationEvent(result)
        
        return result
    }
    
    // MARK: - AI Response Moderation
    
    func moderateAIResponse(_ response: String, context: ChatContext) async -> ModerationResult {
        let startTime = Date()
        
        // Check for inappropriate content in AI response
        async let toxicityResult = toxicityClassifier.classify(response)
        async let sentimentResult = sentimentAnalyzer.analyze(response)
        async let crisisResult = crisisDetector.detect(response)
        async let spamResult = spamDetector.detect(response)
        async let profanityResult = profanityFilter.filter(response)
        
        // Wait for all results
        let (toxicity, sentiment, crisis, spam, profanity) = await (
            toxicityResult, sentimentResult, crisisResult, spamResult, profanityResult
        )
        
        // Additional checks for AI responses
        let aiSpecificChecks = await performAISpecificChecks(response, context: context)
        
        // Determine moderation decision
        let decision = determineModerationDecision(
            toxicity: toxicity,
            sentiment: sentiment,
            crisis: crisis,
            spam: spam,
            profanity: profanity,
            aiSpecific: aiSpecificChecks
        )
        
        let result = ModerationResult(
            content: response,
            userId: "ai_system",
            decision: decision,
            reasons: buildModerationReasons(
                toxicity: toxicity,
                sentiment: sentiment,
                crisis: crisis,
                spam: spam,
                profanity: profanity,
                aiSpecific: aiSpecificChecks
            ),
            confidence: calculateConfidence(
                toxicity: toxicity,
                sentiment: sentiment,
                crisis: crisis,
                spam: spam,
                profanity: profanity,
                aiSpecific: aiSpecificChecks
            ),
            timestamp: Date(),
            processingTime: Date().timeIntervalSince(startTime)
        )
        
        await updateModerationStats(result)
        await logModerationEvent(result)
        
        return result
    }
    
    // MARK: - Real-time Moderation
    
    func moderateInRealTime(_ content: String, userId: String) async -> RealTimeModerationResult {
        let result = await moderateContent(content, userId: userId)
        
        return RealTimeModerationResult(
            isApproved: result.decision == .approved,
            isFlagged: result.decision == .flagged,
            isBlocked: result.decision == .blocked,
            reasons: result.reasons,
            confidence: result.confidence,
            suggestedAction: getSuggestedAction(for: result.decision)
        )
    }
    
    // MARK: - Batch Moderation
    
    func moderateBatch(_ contents: [String], userId: String) async -> [ModerationResult] {
        return await withTaskGroup(of: ModerationResult.self) { group in
            for content in contents {
                group.addTask {
                    await self.moderateContent(content, userId: userId)
                }
            }
            
            var results: [ModerationResult] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }
    
    // MARK: - Moderation Decision Logic
    
    private func determineModerationDecision(
        toxicity: ToxicityResult,
        sentiment: SentimentResult,
        crisis: CrisisResult,
        spam: SpamResult,
        profanity: ProfanityResult,
        aiSpecific: AISpecificChecks? = nil
    ) -> ModerationDecision {
        // Crisis content - always block and escalate
        if crisis.isCrisis {
            return .blocked
        }
        
        // High toxicity - block
        if toxicity.score > 0.8 {
            return .blocked
        }
        
        // Spam content - block
        if spam.isSpam {
            return .blocked
        }
        
        // High profanity - block
        if profanity.severity == .high {
            return .blocked
        }
        
        // Medium toxicity or profanity - flag for review
        if toxicity.score > 0.5 || profanity.severity == .medium {
            return .flagged
        }
        
        // AI-specific issues
        if let aiSpecific = aiSpecific {
            if aiSpecific.containsInappropriateAdvice || aiSpecific.containsMedicalAdvice {
                return .flagged
            }
        }
        
        // Default to approved
        return .approved
    }
    
    private func buildModerationReasons(
        toxicity: ToxicityResult,
        sentiment: SentimentResult,
        crisis: CrisisResult,
        spam: SpamResult,
        profanity: ProfanityResult,
        aiSpecific: AISpecificChecks? = nil
    ) -> [ModerationReason] {
        var reasons: [ModerationReason] = []
        
        if crisis.isCrisis {
            reasons.append(.crisisContent)
        }
        
        if toxicity.score > 0.5 {
            reasons.append(.toxicContent)
        }
        
        if spam.isSpam {
            reasons.append(.spamContent)
        }
        
        if profanity.severity != .none {
            reasons.append(.profanity)
        }
        
        if let aiSpecific = aiSpecific {
            if aiSpecific.containsInappropriateAdvice {
                reasons.append(.inappropriateAdvice)
            }
            if aiSpecific.containsMedicalAdvice {
                reasons.append(.medicalAdvice)
            }
        }
        
        return reasons
    }
    
    private func calculateConfidence(
        toxicity: ToxicityResult,
        sentiment: SentimentResult,
        crisis: CrisisResult,
        spam: SpamResult,
        profanity: ProfanityResult,
        aiSpecific: AISpecificChecks? = nil
    ) -> Double {
        var scores = [
            toxicity.confidence,
            sentiment.confidence,
            crisis.confidence,
            spam.confidence,
            profanity.confidence
        ]
        
        if let aiSpecific = aiSpecific {
            scores.append(aiSpecific.confidence)
        }
        
        return scores.reduce(0, +) / Double(scores.count)
    }
    
    private func getSuggestedAction(for decision: ModerationDecision) -> ModerationAction {
        switch decision {
        case .approved:
            return .none
        case .flagged:
            return .review
        case .blocked:
            return .block
        }
    }
    
    // MARK: - AI-Specific Checks
    
    private func performAISpecificChecks(_ response: String, context: ChatContext) async -> AISpecificChecks {
        // Check for inappropriate advice
        let inappropriateAdvice = checkForInappropriateAdvice(response)
        
        // Check for medical advice
        let medicalAdvice = checkForMedicalAdvice(response)
        
        // Check for harmful content
        let harmfulContent = checkForHarmfulContent(response)
        
        // Check for bias
        let bias = checkForBias(response)
        
        return AISpecificChecks(
            containsInappropriateAdvice: inappropriateAdvice,
            containsMedicalAdvice: medicalAdvice,
            containsHarmfulContent: harmfulContent,
            containsBias: bias,
            confidence: 0.8
        )
    }
    
    private func checkForInappropriateAdvice(_ response: String) -> Bool {
        let inappropriateKeywords = [
            "you should hurt yourself",
            "you should harm yourself",
            "you should give up",
            "you should end it all"
        ]
        
        let lowercasedResponse = response.lowercased()
        return inappropriateKeywords.contains { lowercasedResponse.contains($0) }
    }
    
    private func checkForMedicalAdvice(_ response: String) -> Bool {
        let medicalKeywords = [
            "you should take",
            "you need medication",
            "you should see a doctor",
            "you have a condition",
            "you should get diagnosed"
        ]
        
        let lowercasedResponse = response.lowercased()
        return medicalKeywords.contains { lowercasedResponse.contains($0) }
    }
    
    private func checkForHarmfulContent(_ response: String) -> Bool {
        let harmfulKeywords = [
            "you're worthless",
            "you're a failure",
            "you should die",
            "you're better off dead"
        ]
        
        let lowercasedResponse = response.lowercased()
        return harmfulKeywords.contains { lowercasedResponse.contains($0) }
    }
    
    private func checkForBias(_ response: String) -> Bool {
        let biasKeywords = [
            "because you're a woman",
            "because you're a man",
            "because of your race",
            "because of your age",
            "because you're gay",
            "because you're straight"
        ]
        
        let lowercasedResponse = response.lowercased()
        return biasKeywords.contains { lowercasedResponse.contains($0) }
    }
    
    // MARK: - Statistics and Logging
    
    private func updateModerationStats(_ result: ModerationResult) async {
        _ = await MainActor.run {
            moderationStats.totalContentModerated += 1
            moderationStats.processingTime += result.processingTime
            
            switch result.decision {
            case .approved:
                moderationStats.approvedCount += 1
            case .flagged:
                moderationStats.flaggedCount += 1
            case .blocked:
                moderationStats.blockedCount += 1
            }
            
            // Update average confidence
            let totalConfidence = moderationStats.averageConfidence * Double(moderationStats.totalContentModerated - 1)
            moderationStats.averageConfidence = (totalConfidence + result.confidence) / Double(moderationStats.totalContentModerated)
        }
    }
    
    private func logModerationEvent(_ result: ModerationResult) async {
        // Log to analytics service
        let analyticsService = RealAnalyticsService.shared
        analyticsService.logEvent("content_moderated", parameters: [
            "decision": result.decision.rawValue,
            "confidence": result.confidence,
            "processing_time": result.processingTime,
            "reasons": result.reasons.map { $0.rawValue }
        ])
    }
    
    // MARK: - Moderation Settings
    
    func updateModerationSettings(_ settings: ModerationSettings) {
        // Update moderation thresholds
        toxicityClassifier.updateThreshold(settings.toxicityThreshold)
        spamDetector.updateThreshold(settings.spamThreshold)
        profanityFilter.updateSeverity(settings.profanitySeverity)
    }
    
    func getModerationSettings() -> ModerationSettings {
        return ModerationSettings(
            toxicityThreshold: toxicityClassifier.threshold,
            spamThreshold: spamDetector.threshold,
            profanitySeverity: profanityFilter.severity,
            enableRealTimeModeration: true,
            enableBatchModeration: true
        )
    }
}

// MARK: - Supporting Types

struct SpamResult {
    let isSpam: Bool
    let confidence: Double
    let reasons: [String]
}

struct ProfanityResult {
    let severity: ProfanitySeverity
    let confidence: Double
    let foundWords: [String]
}

// MARK: - Supporting Classes

class ToxicityClassifier {
    var threshold: Double = 0.5
    
    func classify(_ content: String) async -> ToxicityResult {
        // Simulate toxicity classification
        let score = Double.random(in: 0...1)
        let confidence = Double.random(in: 0.7...1.0)
        
        return ToxicityResult(
            score: score,
            confidence: confidence,
            categories: ["toxicity", "harassment", "threats"]
        )
    }
    
    func updateThreshold(_ newThreshold: Double) {
        threshold = newThreshold
    }
}

class SentimentAnalyzer {
    func analyze(_ content: String) async -> SentimentResult {
        // Simulate sentiment analysis
        let sentiment = SentimentType.allCases.randomElement() ?? .neutral
        let confidence = Double.random(in: 0.7...1.0)
        
        return SentimentResult(
            sentiment: sentiment,
            confidence: confidence,
            scores: [
                "positive": Double.random(in: 0...1),
                "negative": Double.random(in: 0...1),
                "neutral": Double.random(in: 0...1)
            ]
        )
    }
}

class CrisisDetector {
    func detect(_ content: String) async -> CrisisResult {
        let crisisKeywords = [
            "suicide", "kill myself", "end it all", "not worth living",
            "hurt myself", "self harm", "cutting", "overdose"
        ]
        
        let lowercasedContent = content.lowercased()
        let isCrisis = crisisKeywords.contains { lowercasedContent.contains($0) }
        
        return CrisisResult(
            isCrisis: isCrisis,
            confidence: isCrisis ? 0.9 : 0.1,
            severity: isCrisis ? .high : .low
        )
    }
}

class SpamDetector {
    var threshold: Double = 0.5
    
    func detect(_ content: String) async -> SpamResult {
        // Simulate spam detection
        let score = Double.random(in: 0...1)
        let isSpam = score > threshold
        
        return SpamResult(
            isSpam: isSpam,
            confidence: Double.random(in: 0.7...1.0),
            reasons: isSpam ? ["repetitive", "promotional"] : []
        )
    }
    
    func updateThreshold(_ newThreshold: Double) {
        threshold = newThreshold
    }
}

class ProfanityFilter {
    var severity: ProfanitySeverity = .medium
    
    func filter(_ content: String) async -> ProfanityResult {
        let profanityWords = ["damn", "hell", "shit", "fuck", "bitch", "asshole"]
        let lowercasedContent = content.lowercased()
        
        let foundWords = profanityWords.filter { lowercasedContent.contains($0) }
        let severity = foundWords.isEmpty ? ProfanitySeverity.none : (foundWords.count > 2 ? ProfanitySeverity.high : ProfanitySeverity.medium)
        
        return ProfanityResult(
            severity: severity,
            confidence: foundWords.isEmpty ? 0.1 : 0.9,
            foundWords: foundWords
        )
    }
    
    func updateSeverity(_ newSeverity: ProfanitySeverity) {
        severity = newSeverity
    }
}

// MARK: - Supporting Types

struct ModerationResult {
    let content: String
    let userId: String
    let decision: ModerationDecision
    let reasons: [ModerationReason]
    let confidence: Double
    let timestamp: Date
    let processingTime: TimeInterval
}

struct RealTimeModerationResult {
    let isApproved: Bool
    let isFlagged: Bool
    let isBlocked: Bool
    let reasons: [ModerationReason]
    let confidence: Double
    let suggestedAction: ModerationAction
}

enum ModerationDecision: String, CaseIterable {
    case approved = "approved"
    case flagged = "flagged"
    case blocked = "blocked"
}

enum ModerationReason: String, CaseIterable {
    case crisisContent = "crisis_content"
    case toxicContent = "toxic_content"
    case spamContent = "spam_content"
    case profanity = "profanity"
    case inappropriateAdvice = "inappropriate_advice"
    case medicalAdvice = "medical_advice"
}

enum ModerationAction: String, CaseIterable {
    case none = "none"
    case review = "review"
    case block = "block"
}

struct ToxicityResult {
    let score: Double
    let confidence: Double
    let categories: [String]
}

struct SentimentResult {
    let sentiment: SentimentType
    let confidence: Double
    let scores: [String: Double]
}

enum SentimentType: String, CaseIterable {
    case positive = "positive"
    case negative = "negative"
    case neutral = "neutral"
}

struct CrisisResult {
    let isCrisis: Bool
    let confidence: Double
    let severity: ContentModerationCrisisSeverity
}

// ... (rest of the code remains the same)

enum ContentModerationCrisisSeverity: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

enum ProfanitySeverity: String, CaseIterable {
    case none = "none"
    case low = "low"
    case medium = "medium"
    case high = "high"
}

struct AISpecificChecks {
    let containsInappropriateAdvice: Bool
    let containsMedicalAdvice: Bool
    let containsHarmfulContent: Bool
    let containsBias: Bool
    let confidence: Double
}


struct ModerationUserProfile {
    let age: Int?
    let gender: String?
    let mentalHealthHistory: [String]
    let preferences: [String: Any]
}

struct ModerationStats {
    var totalContentModerated: Int = 0
    var approvedCount: Int = 0
    var flaggedCount: Int = 0
    var blockedCount: Int = 0
    var averageConfidence: Double = 0.0
    var processingTime: TimeInterval = 0.0
}

struct ModerationSettings {
    let toxicityThreshold: Double
    let spamThreshold: Double
    let profanitySeverity: ProfanitySeverity
    let enableRealTimeModeration: Bool
    let enableBatchModeration: Bool
}
