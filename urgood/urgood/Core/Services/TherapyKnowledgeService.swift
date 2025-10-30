import Foundation

// Therapy knowledge service for evidence-based techniques
class TherapyKnowledgeService: ObservableObject {
    static let shared = TherapyKnowledgeService()
    
    private init() {}
    
    // MARK: - Coping Exercises
    
    struct CopingExercise {
        let id: String
        let name: String
        let category: String
        let steps: [String]
        let duration: String
        let triggers: [String]
        let genZPrompt: String
        let evidenceSource: String
    }
    
    let copingExercises: [CopingExercise] = [
        CopingExercise(
            id: "box-breathing",
            name: "Box Breathing Reset",
            category: "DBT-TIPP",
            steps: [
                "Find a comfortable spot and close your eyes or soften your gaze",
                "Breathe in for 4 counts, hold for 4, out for 4, hold for 4",
                "Repeat 4-6 cycles, focusing only on the counting",
                "Notice how your body feels different now"
            ],
            duration: "60-90 seconds",
            triggers: ["anxiety", "panic", "overwhelm", "anger"],
            genZPrompt: "Your nervous system is in overdrive right now. This breathing drill comes from DBT—clinics use it to dial emotions down in under two minutes. Ready to try it?",
            evidenceSource: "Stewart et al. (2020) - TIPP effectiveness in adolescents"
        ),
        
        CopingExercise(
            id: "thought-check",
            name: "Catch-Check-Change",
            category: "CBT",
            steps: [
                "Catch it: What specific thought just went through your mind?",
                "Check it: Is this thought helpful or accurate right now?",
                "Change it: What would you tell a friend in this situation?",
                "Try on the new thought and see how it feels"
            ],
            duration: "2-3 minutes",
            triggers: ["negative self-talk", "catastrophizing", "rumination"],
            genZPrompt: "That thought sounds heavy. Let's run it through a quick reality check—this is a CBT technique that helps separate facts from feelings.",
            evidenceSource: "Kladnitski et al. (2022) - Mobile CBT for adolescents"
        ),
        
        CopingExercise(
            id: "values-anchor",
            name: "Values Check-In",
            category: "ACT",
            steps: [
                "Name the difficult feeling without judging it",
                "Remember: thoughts and feelings are temporary visitors",
                "What matters most to you in this situation?",
                "What small action aligns with that value right now?"
            ],
            duration: "90 seconds",
            triggers: ["identity crisis", "peer pressure", "perfectionism"],
            genZPrompt: "Sounds like you're caught up in some intense thoughts. Let's step back and reconnect with what actually matters to you.",
            evidenceSource: "Fang & Ding (2022) - ACT apps for college students"
        ),
        
        CopingExercise(
            id: "opposite-action",
            name: "Opposite Action Challenge",
            category: "DBT",
            steps: [
                "Notice the urge and name the emotion driving it",
                "Ask: Is this emotion fitting the facts right now?",
                "If not, what would the opposite action look like?",
                "Take one small step in that opposite direction"
            ],
            duration: "2-5 minutes",
            triggers: ["avoidance", "isolation", "self-harm urges", "anger"],
            genZPrompt: "Your brain is telling you to do one thing, but let's try something different. This is called opposite action—it's a DBT skill that can break negative cycles.",
            evidenceSource: "Rizvi et al. (2021) - Tele-DBT outcomes"
        ),
        
        CopingExercise(
            id: "micro-activation",
            name: "Do One Thing",
            category: "Behavioral Activation",
            steps: [
                "Pick one tiny action that aligns with your values",
                "Set a 5-minute timer",
                "Do just that one thing, nothing else",
                "Notice any shift in your mood or energy"
            ],
            duration: "5-15 minutes",
            triggers: ["depression", "low motivation", "hopelessness"],
            genZPrompt: "Depression is telling you nothing matters, but let's test that theory. Research shows even tiny actions can shift your brain chemistry.",
            evidenceSource: "Schleider et al. (2022) - Single-session BA for teens"
        )
    ]
    
    // MARK: - Crisis Resources
    
    struct CrisisResource {
        let name: String
        let contact: String
        let description: String
        let demographic: String?
    }
    
    let crisisResources: [CrisisResource] = [
        CrisisResource(
            name: "988 Suicide & Crisis Lifeline",
            contact: "Call or text 988",
            description: "24/7 crisis support for anyone in emotional distress or suicidal crisis",
            demographic: nil
        ),
        CrisisResource(
            name: "Crisis Text Line",
            contact: "Text HOME to 741741",
            description: "24/7 text-based crisis support",
            demographic: nil
        ),
        CrisisResource(
            name: "Trevor Project",
            contact: "1-866-488-7386",
            description: "Crisis intervention and suicide prevention for LGBTQ+ youth",
            demographic: "LGBTQ+ youth"
        ),
        CrisisResource(
            name: "Trans Lifeline",
            contact: "877-565-8860",
            description: "Peer support hotline for transgender people",
            demographic: "Transgender"
        )
    ]
    
    // MARK: - Helper Methods
    
    func getCopingExercise(for triggers: [String], userInsights: [String: Any]? = nil) -> CopingExercise? {
        // Find exercises that match user's triggers
        let matchingExercises = copingExercises.filter { exercise in
            exercise.triggers.contains { trigger in
                triggers.contains { userTrigger in
                    userTrigger.lowercased().contains(trigger.lowercased())
                }
            }
        }
        
        // If user has successful techniques, prefer those
        if let successfulTechniques = userInsights?["successfulTechniques"] as? [String] {
            let preferredExercise = matchingExercises.first { exercise in
                successfulTechniques.contains { technique in
                    exercise.id.contains(technique) || exercise.category.lowercased().contains(technique)
                }
            }
            if let preferred = preferredExercise {
                return preferred
            }
        }
        
        // Return first matching exercise or default to breathing
        return matchingExercises.first ?? copingExercises.first { $0.id == "box-breathing" }
    }
    
    func detectCrisisLevel(in message: String) -> (level: String, confidence: Double) {
        let lowerMessage = message.lowercased()
        
        // Critical indicators
        let criticalKeywords = ["want to die", "kill myself", "end it all", "suicide", "better off dead", "have a plan"]
        let criticalMatches = criticalKeywords.filter { lowerMessage.contains($0) }.count
        if criticalMatches > 0 {
            return ("CRITICAL", min(Double(criticalMatches) * 0.4, 1.0))
        }
        
        // High risk indicators
        let highRiskKeywords = ["hopeless", "worthless", "no point living", "giving up", "can't go on"]
        let highMatches = highRiskKeywords.filter { lowerMessage.contains($0) }.count
        if highMatches > 0 {
            return ("HIGH", min(Double(highMatches) * 0.3, 1.0))
        }
        
        // Moderate indicators
        let moderateKeywords = ["can't cope", "overwhelming", "breaking down", "losing it"]
        let moderateMatches = moderateKeywords.filter { lowerMessage.contains($0) }.count
        if moderateMatches > 1 {
            return ("MODERATE", min(Double(moderateMatches) * 0.2, 1.0))
        }
        
        // Low-level indicators
        let lowKeywords = ["sad", "anxious", "stressed", "worried", "down"]
        let lowMatches = lowKeywords.filter { lowerMessage.contains($0) }.count
        if lowMatches > 0 {
            return ("LOW", min(Double(lowMatches) * 0.1, 1.0))
        }
        
        return ("NONE", 0.0)
    }
    
    func getCrisisResponse(for level: String) -> String {
        switch level {
        case "CRITICAL":
            return """
            🚨 I'm very concerned about what you've shared. This is a mental health emergency. 
            
            Please reach out for immediate help:
            • Call or text 988 (Suicide & Crisis Lifeline)
            • Text HOME to 741741 (Crisis Text Line)
            • Call 911 or go to your nearest emergency room
            • Reach out to a trusted friend, family member, or counselor right now
            
            You don't have to go through this alone. Help is available.
            """
            
        case "HIGH":
            return """
            I'm very concerned about what you've shared. Your life has value and there are people who want to help you through this.
            
            Immediate support resources:
            • 988 Suicide & Crisis Lifeline: Call or text 988
            • Crisis Text Line: Text HOME to 741741
            • Trevor Project (LGBTQ+): 1-866-488-7386
            
            Are you safe right now? Do you have someone you can reach out to?
            """
            
        case "MODERATE":
            return """
            What you're feeling sounds really intense and difficult. I'm glad you're talking about it instead of keeping it inside.
            
            Support resources:
            • Crisis Text Line: Text HOME to 741741
            • 988 Suicide & Crisis Lifeline
            
            Would you like to try a grounding technique to help you feel more stable right now?
            """
            
        default:
            return "I hear that you're going through a tough time right now. Thanks for sharing that with me—it takes courage to reach out."
        }
    }
    
    func generatePersonalizedPrompt(for exercise: CopingExercise, userInsights: [String: Any]? = nil) -> String {
        var prompt = exercise.genZPrompt
        
        // Add personalization based on insights
        if let successfulTechniques = userInsights?["successfulTechniques"] as? [String],
           successfulTechniques.contains(where: { exercise.id.contains($0) }) {
            prompt = "You've found this helpful before—\(prompt.lowercased())"
        }
        
        // Add context for music lovers
        if let preferences = userInsights?["preferences"] as? [String: Any],
           preferences["music"] as? Bool == true,
           exercise.id == "box-breathing" {
            prompt += " Want to queue up some music while we do this?"
        }
        
        return prompt
    }
    
    // MARK: - Screening Tools
    
    func getScreeningQuestions(type: String) -> [String] {
        switch type {
        case "PHQ-2":
            return [
                "Over the past 2 weeks, how often have you felt down, depressed, or hopeless?",
                "Over the past 2 weeks, how often have you had little interest or pleasure in doing things?"
            ]
        case "GAD-2":
            return [
                "Over the past 2 weeks, how often have you felt nervous, anxious, or on edge?",
                "Over the past 2 weeks, how often have you been unable to stop or control worrying?"
            ]
        default:
            return []
        }
    }
    
    func interpretScreeningScore(_ score: Int, type: String) -> (level: String, recommendation: String) {
        switch type {
        case "PHQ-2", "GAD-2":
            if score >= 5 {
                return ("HIGH", "Consider speaking with a mental health professional for a full assessment.")
            } else if score >= 3 {
                return ("MODERATE", "You might benefit from some additional support or coping strategies.")
            } else {
                return ("LOW", "Your responses suggest minimal symptoms at this time.")
            }
        default:
            return ("UNKNOWN", "Unable to interpret score.")
        }
    }
}

// MARK: - Communication Guidelines

extension TherapyKnowledgeService {
    
    struct CommunicationGuideline {
        static let matureGenZTone = """
        Conversational, concise, emotionally literate. Avoid memes/slang overload. 
        Think "insightful friend who reads psych research."
        """
        
        static let avoidList = [
            "Toxic positivity (\"just think positive!\")",
            "Minimizing (\"it could be worse\")",
            "Forced Gen Z slang (\"that's so sus\")",
            "Medical advice or diagnosis",
            "Overwhelming information dumps"
        ]
        
        static let structure = """
        1. Validate feelings first (1-2 sentences)
        2. Brief education about technique/science if relevant
        3. One specific, doable action step
        4. Check-in question or encouragement
        """
    }
    
    func getResponseStructure() -> String {
        return CommunicationGuideline.structure
    }
    
    func shouldAvoid() -> [String] {
        return CommunicationGuideline.avoidList
    }
}
