import Foundation

class AgentHandoffService: ObservableObject {
    // MARK: - Published Properties
    
    @Published var availableAgents: [VoiceAgent] = [
        .therapyCompanion,
        .crisisSupport,
        .moodTracker,
        .sleepCoach
    ]
    
    @Published var currentAgent: VoiceAgent = .therapyCompanion
    @Published var handoffInProgress: Bool = false
    
    // MARK: - Private Properties
    
    private var conversationContext: String = ""
    private var handoffReason: String = ""
    
    // MARK: - Public Methods
    
    func requestHandoff(to agent: VoiceAgent, reason: String, context: String) -> AgentHandoffRequest {
        return AgentHandoffRequest(
            fromAgent: currentAgent,
            toAgent: agent,
            reason: reason,
            context: context,
            timestamp: Date()
        )
    }
    
    func executeHandoff(_ request: AgentHandoffRequest) async throws -> AgentHandoffResult {
        handoffInProgress = true
        defer { handoffInProgress = false }
        
        print("🔄 Executing agent handoff from \(request.fromAgent) to \(request.toAgent)")
        
        // Validate handoff request
        try validateHandoffRequest(request)
        
        // Prepare handoff context
        let handoffContext = prepareHandoffContext(request)
        
        // Update current agent
        currentAgent = request.toAgent
        
        // Generate handoff message
        let handoffMessage = generateHandoffMessage(request, context: handoffContext)
        
        print("✅ Agent handoff completed successfully")
        
        return AgentHandoffResult(
            success: true,
            newAgent: request.toAgent,
            handoffMessage: handoffMessage,
            context: handoffContext
        )
    }
    
    func getHandoffTools() -> [RealtimeTool] {
        return [
            createCrisisHandoffTool(),
            createSpecialistHandoffTool(),
            createEmergencyResourcesTool()
        ]
    }
    
    // MARK: - Private Methods
    
    private func validateHandoffRequest(_ request: AgentHandoffRequest) throws {
        // Check if target agent is available
        guard availableAgents.contains(request.toAgent) else {
            throw AgentHandoffError.agentNotAvailable
        }
        
        // Validate handoff reason
        guard !request.reason.isEmpty else {
            throw AgentHandoffError.invalidReason
        }
        
        // Check if handoff is appropriate
        if request.toAgent == request.fromAgent {
            throw AgentHandoffError.sameAgent
        }
    }
    
    private func prepareHandoffContext(_ request: AgentHandoffRequest) -> HandoffContext {
        return HandoffContext(
            previousAgent: request.fromAgent,
            conversationSummary: request.context,
            handoffReason: request.reason,
            timestamp: request.timestamp,
            urgencyLevel: determineUrgencyLevel(request)
        )
    }
    
    private func determineUrgencyLevel(_ request: AgentHandoffRequest) -> UrgencyLevel {
        let lowercaseReason = request.reason.lowercased()
        let lowercaseContext = request.context.lowercased()
        
        // Crisis indicators
        let crisisKeywords = ["suicide", "self-harm", "hurt myself", "end it all", "kill myself", "emergency", "crisis"]
        if crisisKeywords.contains(where: { lowercaseReason.contains($0) || lowercaseContext.contains($0) }) {
            return .critical
        }
        
        // High priority indicators
        let highPriorityKeywords = ["panic", "anxiety attack", "can't breathe", "overwhelmed", "breakdown"]
        if highPriorityKeywords.contains(where: { lowercaseReason.contains($0) || lowercaseContext.contains($0) }) {
            return .high
        }
        
        // Specialized care indicators
        if request.toAgent == .crisisSupport {
            return .high
        }
        
        return .normal
    }
    
    private func generateHandoffMessage(_ request: AgentHandoffRequest, context: HandoffContext) -> String {
        switch request.toAgent {
        case .crisisSupport:
            return generateCrisisHandoffMessage(context)
        case .therapyCompanion:
            return generateTherapyHandoffMessage(context)
        case .moodTracker:
            return generateMoodTrackerHandoffMessage(context)
        case .sleepCoach:
            return generateSleepCoachHandoffMessage(context)
        }
    }
    
    private func generateCrisisHandoffMessage(_ context: HandoffContext) -> String {
        return """
        I understand you're going through a really difficult time right now, and I want to make sure you get the best support possible. I'm connecting you with our crisis support specialist who is specially trained to help in situations like this.
        
        Please know that you're not alone, and there are people who want to help you through this. The specialist will be with you in just a moment.
        """
    }
    
    private func generateTherapyHandoffMessage(_ context: HandoffContext) -> String {
        return """
        I'm glad we could talk about this together. I'm now connecting you with our therapy companion who can provide more focused support for what you're experiencing.
        
        They'll have the context of our conversation and can help you work through these feelings in a deeper way.
        """
    }
    
    private func generateMoodTrackerHandoffMessage(_ context: HandoffContext) -> String {
        return """
        It sounds like tracking your mood patterns could be really helpful. I'm connecting you with our mood tracking specialist who can help you understand your emotional patterns better.
        
        They'll help you identify triggers and develop strategies for managing your moods.
        """
    }
    
    private func generateSleepCoachHandoffMessage(_ context: HandoffContext) -> String {
        return """
        Sleep is so important for mental health, and I think our sleep coach can really help you with this. I'm connecting you with them now.
        
        They specialize in helping people develop healthy sleep habits and address sleep-related concerns.
        """
    }
    
    // MARK: - Tool Creation Methods
    
    private func createCrisisHandoffTool() -> RealtimeTool {
        return RealtimeTool(
            type: "function",
            function: RealtimeFunction(
                name: "handoff_to_crisis_support",
                description: """
                Transfer the conversation to a crisis support specialist when the user mentions:
                - Thoughts of self-harm or suicide
                - Feeling like they want to hurt themselves
                - Emergency mental health situations
                - Overwhelming crisis situations
                
                Always use this tool if you detect any risk of self-harm.
                """,
                parameters: RealtimeFunctionParameters(
                    type: "object",
                    properties: [
                        "reason": RealtimeProperty(
                            type: "string",
                            description: "The specific reason for the crisis handoff",
                            enum: nil
                        ),
                        "urgency_level": RealtimeProperty(
                            type: "string",
                            description: "The urgency level of the situation",
                            enum: ["high", "critical"]
                        ),
                        "context": RealtimeProperty(
                            type: "string",
                            description: "Relevant context from the conversation",
                            enum: nil
                        )
                    ],
                    required: ["reason", "urgency_level", "context"]
                )
            )
        )
    }
    
    private func createSpecialistHandoffTool() -> RealtimeTool {
        return RealtimeTool(
            type: "function",
            function: RealtimeFunction(
                name: "handoff_to_specialist",
                description: """
                Transfer the conversation to a specialized agent when the user needs:
                - Mood tracking and pattern analysis
                - Sleep coaching and sleep hygiene
                - Specific therapeutic techniques
                
                Use this when the user's needs would be better served by a specialist.
                """,
                parameters: RealtimeFunctionParameters(
                    type: "object",
                    properties: [
                        "specialist_type": RealtimeProperty(
                            type: "string",
                            description: "The type of specialist needed",
                            enum: ["mood_tracker", "sleep_coach", "therapy_companion"]
                        ),
                        "reason": RealtimeProperty(
                            type: "string",
                            description: "Why this specialist is needed",
                            enum: nil
                        ),
                        "context": RealtimeProperty(
                            type: "string",
                            description: "Relevant conversation context for the handoff",
                            enum: nil
                        )
                    ],
                    required: ["specialist_type", "reason", "context"]
                )
            )
        )
    }
    
    private func createEmergencyResourcesTool() -> RealtimeTool {
        return RealtimeTool(
            type: "function",
            function: RealtimeFunction(
                name: "provide_emergency_resources",
                description: """
                Provide emergency mental health resources when the user is in crisis but may not need immediate handoff.
                Use this to give crisis hotline numbers and emergency resources.
                """,
                parameters: RealtimeFunctionParameters(
                    type: "object",
                    properties: [
                        "resource_type": RealtimeProperty(
                            type: "string",
                            description: "The type of emergency resource needed",
                            enum: ["crisis_hotline", "emergency_services", "local_resources"]
                        ),
                        "location": RealtimeProperty(
                            type: "string",
                            description: "User's location for local resources (optional)",
                            enum: nil
                        )
                    ],
                    required: ["resource_type"]
                )
            )
        )
    }
}

// MARK: - Supporting Types

struct AgentHandoffRequest {
    let fromAgent: VoiceAgent
    let toAgent: VoiceAgent
    let reason: String
    let context: String
    let timestamp: Date
}

struct AgentHandoffResult {
    let success: Bool
    let newAgent: VoiceAgent
    let handoffMessage: String
    let context: HandoffContext
}

struct HandoffContext {
    let previousAgent: VoiceAgent
    let conversationSummary: String
    let handoffReason: String
    let timestamp: Date
    let urgencyLevel: UrgencyLevel
}

enum UrgencyLevel {
    case normal
    case high
    case critical
}

enum AgentHandoffError: Error, LocalizedError {
    case agentNotAvailable
    case invalidReason
    case sameAgent
    case handoffFailed
    
    var errorDescription: String? {
        switch self {
        case .agentNotAvailable:
            return "The requested agent is not available"
        case .invalidReason:
            return "Invalid handoff reason provided"
        case .sameAgent:
            return "Cannot handoff to the same agent"
        case .handoffFailed:
            return "Agent handoff failed"
        }
    }
}
