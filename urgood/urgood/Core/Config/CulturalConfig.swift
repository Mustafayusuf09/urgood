import Foundation

/// Cultural configuration for AI responses - keeps the coach current without being cringe
struct CulturalConfig {
    
    // MARK: - Gen Z Slang Dictionary (2025)
    
    /// Curated list of current Gen Z slang with usage context
    static let currentSlang: [String: SlangEntry] = [
        "rizz": SlangEntry(
            meaning: "charm or charisma",
            usage: "positive, confidence-building",
            example: "You've got serious rizz when you're in your element",
            frequency: .moderate
        ),
        "ate": SlangEntry(
            meaning: "delivered perfectly, crushed it",
            usage: "hype, celebration",
            example: "You absolutely ate with how you showed up for yourself today",
            frequency: .moderate
        ),
        "ate that": SlangEntry(
            meaning: "you did that flawlessly",
            usage: "validation, hype",
            example: "You set that boundary and ate that, bestie",
            frequency: .moderate
        ),
        "no crumbs": SlangEntry(
            meaning: "you nailed it so hard there's nothing left",
            usage: "praise, celebration",
            example: "You cleared that task, no crumbs left 🚀",
            frequency: .low
        ),
        "delulu": SlangEntry(
            meaning: "delusional, used playfully",
            usage: "gentle teasing, self-awareness",
            example: "Okay, maybe I was being a little delulu about that deadline",
            frequency: .low
        ),
        "main character": SlangEntry(
            meaning: "someone acting like the star of their story",
            usage: "confidence, empowerment",
            example: "You're totally the main character of your own comeback story",
            frequency: .moderate
        ),
        "brain rot": SlangEntry(
            meaning: "feeling overwhelmed by too much content/stress",
            usage: "relatable burnout, empathy",
            example: "I'm getting major brain rot from all these notifications",
            frequency: .low
        ),
        "lowkey": SlangEntry(
            meaning: "subtly, quietly, or secretly",
            usage: "softening statements, gentle emphasis",
            example: "Lowkey, you're handling this better than you think",
            frequency: .high
        ),
        "highkey": SlangEntry(
            meaning: "obviously, clearly, or very much",
            usage: "strong emphasis, validation",
            example: "Highkey proud of you for setting those boundaries",
            frequency: .moderate
        ),
        "periodt": SlangEntry(
            meaning: "period, end of discussion, emphasis",
            usage: "strong validation, confidence",
            example: "You deserve better treatment, periodt",
            frequency: .low
        ),
        "slay": SlangEntry(
            meaning: "doing something exceptionally well",
            usage: "celebration, achievement",
            example: "You absolutely slayed that presentation",
            frequency: .moderate
        ),
        "vibe check": SlangEntry(
            meaning: "assessing someone's emotional state",
            usage: "checking in, emotional awareness",
            example: "Let's do a quick vibe check - how are you really feeling?",
            frequency: .low
        ),
        "no cap": SlangEntry(
            meaning: "no lie, genuinely, for real",
            usage: "authenticity, sincerity",
            example: "No cap, you're making real progress here",
            frequency: .low
        ),
        "it's giving": SlangEntry(
            meaning: "it's giving off vibes of, it reminds me of",
            usage: "describing energy or feeling",
            example: "It's giving main character energy when you stand up for yourself",
            frequency: .moderate
        ),
        "bestie": SlangEntry(
            meaning: "best friend, close friend",
            usage: "warmth, closeness, support",
            example: "Bestie, you've got this! I believe in you",
            frequency: .moderate
        ),
        "slay queen/king": SlangEntry(
            meaning: "doing amazing, being fabulous",
            usage: "celebration, empowerment",
            example: "Slay queen! You handled that situation perfectly",
            frequency: .moderate
        ),
        "period pooh": SlangEntry(
            meaning: "period, end of discussion, emphasis",
            usage: "strong validation, confidence",
            example: "You deserve respect, period pooh",
            frequency: .low
        ),
        "that's so valid": SlangEntry(
            meaning: "that's completely understandable and reasonable",
            usage: "validation, empathy",
            example: "Your feelings about this are so valid",
            frequency: .high
        ),
        "big mood": SlangEntry(
            meaning: "relatable, I feel that",
            usage: "relatability, shared experience",
            example: "Feeling overwhelmed is such a big mood right now",
            frequency: .moderate
        ),
        "we love to see it": SlangEntry(
            meaning: "we love witnessing this positive thing",
            usage: "celebration, support",
            example: "You setting boundaries? We love to see it!",
            frequency: .moderate
        ),
        "not me": SlangEntry(
            meaning: "definitely not me, sarcastic denial",
            usage: "self-awareness, gentle humor",
            example: "Not me overthinking everything again...",
            frequency: .low
        ),
        "this hits different": SlangEntry(
            meaning: "this feels special or meaningful",
            usage: "acknowledging significance",
            example: "This conversation hits different - I feel really heard",
            frequency: .low
        ),
        "say less": SlangEntry(
            meaning: "I understand, no need to explain more",
            usage: "understanding, agreement",
            example: "You want to prioritize your mental health? Say less",
            frequency: .low
        ),
        "facts": SlangEntry(
            meaning: "true, I agree, that's correct",
            usage: "agreement, validation",
            example: "You need to take care of yourself first - facts",
            frequency: .moderate
        ),
        "this is it": SlangEntry(
            meaning: "this is the right approach, perfect",
            usage: "approval, encouragement",
            example: "This is it! You're finally putting yourself first",
            frequency: .low
        ),
        "go off": SlangEntry(
            meaning: "continue, you're doing great",
            usage: "encouragement, support",
            example: "Go off! Keep sharing what's on your mind",
            frequency: .low
        ),
        "that's the tea": SlangEntry(
            meaning: "that's the truth, that's what's happening",
            usage: "agreement, validation",
            example: "You recognizing your worth? That's the tea",
            frequency: .low
        ),
        "manifesting": SlangEntry(
            meaning: "hoping for, working towards",
            usage: "positive thinking, goal setting",
            example: "Manifesting better days for you ahead",
            frequency: .moderate
        ),
        "vibe": SlangEntry(
            meaning: "feeling, energy, atmosphere",
            usage: "emotional state, energy",
            example: "I'm getting good vibes from this conversation",
            frequency: .high
        ),
        "stan": SlangEntry(
            meaning: "strongly support, be a fan of",
            usage: "support, encouragement",
            example: "I stan you for taking care of your mental health",
            frequency: .low
        ),
        "glow-up": SlangEntry(
            meaning: "major positive transformation",
            usage: "progress, motivation",
            example: "This growth arc is a whole glow-up in real time",
            frequency: .moderate
        ),
        "soft launch": SlangEntry(
            meaning: "introducing something quietly",
            usage: "small steps, gentle starts",
            example: "Let's soft launch that habit with a 5-minute version",
            frequency: .low
        ),
        "hard launch": SlangEntry(
            meaning: "announce/show up confidently",
            usage: "confidence, commitment",
            example: "Hard launch your new morning routine this week?",
            frequency: .low
        ),
        "it's a lot": SlangEntry(
            meaning: "it's overwhelming, too much",
            usage: "acknowledging difficulty",
            example: "I know this situation is a lot right now",
            frequency: .moderate
        ),
        "we're here for it": SlangEntry(
            meaning: "we support this, we're excited about this",
            usage: "support, enthusiasm",
            example: "You prioritizing yourself? We're here for it!",
            frequency: .moderate
        )
    ]
    
    // MARK: - Usage Guidelines
    
    /// Maximum slang terms per message
    static let maxSlangPerMessage = 1
    
    /// Slang usage frequency by context
    static let contextFrequency: [ConversationContext: SlangFrequency] = [
        .crisis: .none,           // Never use slang in crisis situations
        .serious: .low,           // Minimal slang for serious topics
        .casual: .moderate,       // Moderate slang for casual conversations
        .celebration: .high,      // More slang for celebrations/achievements
        .encouragement: .moderate, // Moderate slang for encouragement
        .exploration: .low,        // Minimal slang for therapeutic exploration
        .goalSetting: .moderate
    ]
    
    // MARK: - Tone Guidelines
    
    /// When to use slang
    static let appropriateContexts: [String] = [
        "Building confidence and self-esteem",
        "Celebrating achievements and progress", 
        "Making conversations feel relatable and current",
        "Keeping things playful without losing the therapeutic vibe",
        "Softening difficult topics with gentle humor",
        "Creating connection through shared cultural references",
        "Validating feelings and experiences",
        "Encouraging self-care and boundaries",
        "Making mental health conversations less intimidating",
        "Building trust through authentic, modern language"
    ]
    
    /// When NOT to use slang
    static let inappropriateContexts: [String] = [
        "Crisis situations or serious mental health concerns",
        "When user is clearly upset or distressed",
        "Professional or formal conversations",
        "When it would feel forced or unnatural",
        "Multiple slang terms in one message",
        "When user explicitly wants a more structured, serious tone"
    ]
}

// MARK: - Supporting Types

struct SlangEntry {
    let meaning: String
    let usage: String
    let example: String
    let frequency: SlangFrequency
}

enum SlangFrequency: String, CaseIterable {
    case none = "none"
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    
    var weight: Double {
        switch self {
        case .none: return 0.0
        case .low: return 0.1
        case .moderate: return 0.3
        case .high: return 0.5
        }
    }
}



// MARK: - Cultural Seasoning Helper

extension CulturalConfig {
    
    /// Get appropriate slang for a given context
    static func getSlangForContext(_ context: ConversationContext, userMood: String? = nil) -> [String: SlangEntry] {
        let maxFrequency = contextFrequency[context] ?? .low
        
        return currentSlang.filter { (_, entry) in
            switch maxFrequency {
            case .none:
                return false
            case .low:
                return entry.frequency == .low
            case .moderate:
                return entry.frequency == .low || entry.frequency == .moderate
            case .high:
                return true
            }
        }
    }
    
    /// Check if slang usage is appropriate for the situation
    static func isSlangAppropriate(context: ConversationContext, userMessage: String) -> Bool {
        // Never use slang in crisis situations
        if context == .crisis {
            return false
        }
        
        // Check for distress indicators
        let distressKeywords = ["crisis", "emergency", "suicide", "hurt myself", "end it all", "can't go on"]
        if distressKeywords.contains(where: { userMessage.lowercased().contains($0) }) {
            return false
        }
        
        // Check if user is clearly upset
        let upsetKeywords = ["terrible", "awful", "worst", "hate", "destroyed", "broken", "hopeless"]
        let upsetCount = upsetKeywords.filter { userMessage.lowercased().contains($0) }.count
        if upsetCount >= 2 {
            return false
        }
        
        return true
    }
    
    /// Get a random appropriate slang term for the context
    static func getRandomSlang(context: ConversationContext, userMessage: String) -> String? {
        guard isSlangAppropriate(context: context, userMessage: userMessage) else {
            return nil
        }
        
        let availableSlang = getSlangForContext(context)
        var weightedSlang = availableSlang.flatMap { (term, entry) in
            Array(repeating: term, count: Int(entry.frequency.weight * 10))
        }
        
        // Add context-specific preferences
        if context == .celebration {
            weightedSlang.append(contentsOf: ["slay", "we love to see it", "period pooh", "this is it"])
        } else if context == .encouragement {
            weightedSlang.append(contentsOf: ["bestie", "that's so valid", "facts", "go off"])
        } else if context == .casual {
            weightedSlang.append(contentsOf: ["lowkey", "vibe", "big mood", "it's giving"])
        }
        
        return weightedSlang.randomElement()
    }
    
    /// Get contextual slang based on specific emotional states
    static func getSlangForMood(_ mood: String) -> [String] {
        let moodLower = mood.lowercased()
        
        switch moodLower {
        case let m where m.contains("anxious") || m.contains("worried"):
            return ["lowkey", "it's a lot", "that's so valid", "big mood"]
        case let m where m.contains("sad") || m.contains("down"):
            return ["that's so valid", "it's a lot", "big mood", "vibe"]
        case let m where m.contains("stressed") || m.contains("overwhelmed"):
            return ["it's a lot", "big mood", "that's so valid", "lowkey"]
        case let m where m.contains("confident") || m.contains("proud"):
            return ["slay", "we love to see it", "this is it", "go off"]
        case let m where m.contains("excited") || m.contains("happy"):
            return ["we love to see it", "this hits different", "manifesting", "we're here for it"]
        default:
            return ["lowkey", "vibe", "that's so valid", "facts"]
        }
    }
}
