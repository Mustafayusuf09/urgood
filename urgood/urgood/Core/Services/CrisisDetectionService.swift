import Foundation

class CrisisDetectionService: ObservableObject {
    @Published var crisisDetected = false
    @Published var crisisLevel: CrisisLevel = .none
    @Published var detectedKeywords: [String] = []
    
    private let crisisKeywords = [
        // High severity
        "suicide": 3, "kill myself": 3, "hurt myself": 3, "end it": 3, "end my life": 3,
        "want to die": 3, "don't want to live": 3, "better off dead": 3, "no reason to live": 3,
        "self harm": 3, "cutting": 3, "overdose": 3, "over dose": 3, "take pills": 3,
        "jump off": 3, "crash car": 3, "drive into": 3, "gun": 3, "weapon": 3,
        
        // Medium severity
        "can't go on": 2, "give up": 2, "hopeless": 2, "worthless": 2, "useless": 2,
        "hate myself": 2, "deserve to die": 2, "world be better": 2, "burden": 2,
        "everyone hates me": 2, "no one cares": 2, "alone forever": 2,
        
        // Low severity (but still concerning)
        "want to disappear": 1, "wish i was dead": 1, "not worth it": 1, "pointless": 1,
        "can't handle this": 1, "too much": 1, "breaking down": 1, "falling apart": 1
    ]
    
    private let contextKeywords = [
        "planning", "tonight", "tomorrow", "soon", "ready", "prepared", "method", "how to"
    ]
    
    func detectCrisis(in text: String) -> Bool {
        let lowercasedText = text.lowercased()
        var maxSeverity = 0
        var detectedKeywords: [String] = []
        
        // Check for crisis keywords
        for (keyword, severity) in crisisKeywords {
            if lowercasedText.contains(keyword) {
                maxSeverity = max(maxSeverity, severity)
                detectedKeywords.append(keyword)
            }
        }
        
        // Check for context that might increase severity
        let hasContext = contextKeywords.contains { lowercasedText.contains($0) }
        if hasContext && maxSeverity > 0 {
            maxSeverity = min(maxSeverity + 1, 3)
        }
        
        // Update crisis state
        DispatchQueue.main.async {
            self.crisisDetected = maxSeverity > 0
            self.detectedKeywords = detectedKeywords
            self.crisisLevel = CrisisLevel(rawValue: maxSeverity) ?? .none
        }
        
        return maxSeverity > 0
    }
    
    func getCrisisResponse() -> String {
        switch crisisLevel {
        case .none:
            return ""
        case .low:
            return "I'm concerned about what you're sharing. It sounds like you're going through a really difficult time. Your feelings are valid, and you don't have to face this alone. Would you like to talk about what's making you feel this way?"
        case .medium:
            return "I'm really worried about what you're telling me. It sounds like you're in a lot of pain right now. Your life has value, and there are people who want to help you. Please consider reaching out to someone you trust or a crisis helpline."
        case .high:
            return "I'm very concerned about what you're sharing. Your life has value, and there are people who want to help you. Please reach out to a crisis helpline or talk to someone you trust right away. You don't have to go through this alone. The National Suicide Prevention Lifeline is 988, and they're available 24/7."
        }
    }
    
    func getCrisisResources() -> [String: String] {
        return [
            "US Crisis Line": "988",
            "US Crisis Text": "Text HOME to 741741",
            "Canada": "1-833-456-4566",
            "UK Samaritans": "116 123",
            "Australia Lifeline": "13 11 14",
            "International": "https://findahelpline.com",
            "Emergency Services": "911 (US) or your local emergency number"
        ]
    }
    
    func getDetailedCrisisResources() -> [CrisisResource] {
        return [
            CrisisResource(
                id: "crisis_001",
                title: "988 Suicide & Crisis Lifeline",
                description: "24/7 free and confidential support. Text HOME to 741741",
                phoneNumber: "988",
                website: "https://988lifeline.org",
                location: "United States",
                availability: "24/7",
                priority: 1
            ),
            CrisisResource(
                id: "crisis_002",
                title: "Talk Suicide Canada",
                description: "24/7 bilingual crisis support. Text 45645",
                phoneNumber: "1-833-456-4566",
                website: "https://talksuicide.ca",
                location: "Canada",
                availability: "24/7",
                priority: 1
            ),
            CrisisResource(
                id: "crisis_003",
                title: "Samaritans",
                description: "Free 24/7 emotional support",
                phoneNumber: "116 123",
                website: "https://samaritans.org",
                location: "United Kingdom",
                availability: "24/7",
                priority: 1
            ),
            CrisisResource(
                id: "crisis_004",
                title: "Lifeline",
                description: "24/7 crisis support and suicide prevention. Text 0477 13 11 14",
                phoneNumber: "13 11 14",
                website: "https://lifeline.org.au",
                location: "Australia",
                availability: "24/7",
                priority: 1
            ),
            CrisisResource(
                id: "crisis_005",
                title: "Find a Helpline",
                description: "Directory of crisis helplines worldwide",
                phoneNumber: nil,
                website: "https://findahelpline.com",
                location: "International",
                availability: "24/7",
                priority: 2
            )
        ]
    }
    
    func getCrisisDisclaimer() -> String {
        return "This app is not a substitute for professional mental health care. If you're experiencing a mental health crisis, please contact your local crisis services or emergency services immediately."
    }
    
    func getCrisisHelpMessage() -> String {
        return "I'm concerned about what you're sharing. Your life has value, and there are people who want to help you. Please reach out to a crisis helpline or talk to someone you trust. You don't have to go through this alone."
    }
}

// MARK: - Supporting Models
// Note: CrisisLevel is defined in Models.swift
// CrisisResource is defined in APICache.swift to avoid duplication
