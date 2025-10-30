import Foundation
import Combine

class CustomerSupportService: ObservableObject {
    static let shared = CustomerSupportService()
    
    private let supportAPI = SupportAPI()
    private let chatbot = SupportChatbot()
    // Mock ticket system - replace with real implementation
    // private let ticketSystem = TicketSystem()
    
    @Published var isOnline = false
    @Published var supportAgents: [SupportAgent] = []
    @Published var activeTickets: [SupportTicket] = []
    
    private init() {
        setupSupportSystem()
    }
    
    // MARK: - Support System Setup
    
    private func setupSupportSystem() {
        // Initialize support agents
        supportAgents = [
            SupportAgent(id: "agent_1", name: "Sarah Johnson", status: .online, specialties: [.technical, .billing]),
            SupportAgent(id: "agent_2", name: "Michael Chen", status: .online, specialties: [.technical, .account]),
            SupportAgent(id: "agent_3", name: "Emily Davis", status: .away, specialties: [.billing, .general]),
            SupportAgent(id: "agent_4", name: "David Wilson", status: .offline, specialties: [.technical, .crisis])
        ]
        
        // Check system status
        checkSystemStatus()
    }
    
    private func checkSystemStatus() {
        // Simulate system status check
        isOnline = true
    }
    
    // MARK: - Chat Support
    
    func startChatSupport(userId: String, message: String) async -> ChatResponse {
        // Check if chatbot can handle the request
        if chatbot.canHandle(message: message) {
            return await chatbot.processMessage(message: message, userId: userId)
        } else {
            // Escalate to human agent
            return await escalateToHumanAgent(userId: userId, message: message)
        }
    }
    
    func sendMessage(_ message: String, userId: String) async -> ChatResponse {
        return await startChatSupport(userId: userId, message: message)
    }
    
    private func escalateToHumanAgent(userId: String, message: String) async -> ChatResponse {
        // Find available agent
        guard let agent = findAvailableAgent() else {
            return ChatResponse(
                message: "I'm sorry, all our support agents are currently busy. Please try again in a few minutes or submit a support ticket.",
                isFromBot: true,
                agentId: nil,
                timestamp: Date()
            )
        }
        
        // Create support ticket
        let ticket = SupportTicket(
            id: UUID().uuidString,
            userId: userId,
            subject: "Chat Support Request",
            description: message,
            priority: .medium,
            status: .open,
            assignedAgent: agent.id,
            createdAt: Date()
        )
        
        // Add to active tickets
        _ = await MainActor.run {
            activeTickets.append(ticket)
        }
        
        return ChatResponse(
            message: "I've connected you with \(agent.name), one of our support specialists. They'll be with you shortly.",
            isFromBot: true,
            agentId: agent.id,
            timestamp: Date()
        )
    }
    
    // MARK: - Ticket System
    
    func createTicket(_ request: SupportTicketRequest) async -> SupportTicket {
        let ticket = SupportTicket(
            id: UUID().uuidString,
            userId: request.userId,
            subject: request.subject,
            description: request.description,
            priority: request.priority,
            status: .open,
            assignedAgent: nil,
            createdAt: Date()
        )
        
        // Assign to appropriate agent
        let finalTicket: SupportTicket
        if let agent = findBestAgent(for: request) {
            finalTicket = SupportTicket(
                id: ticket.id,
                userId: ticket.userId,
                subject: ticket.subject,
                description: ticket.description,
                priority: ticket.priority,
                status: ticket.status,
                assignedAgent: agent.id,
                createdAt: ticket.createdAt
            )
        } else {
            finalTicket = ticket
        }
        
        // Add to active tickets
        _ = await MainActor.run {
            activeTickets.append(finalTicket)
        }
        
        // Notify assigned agent
        if let agentId = ticket.assignedAgent {
            notifyAgent(agentId: agentId, ticket: ticket)
        }
        
        return ticket
    }
    
    func updateTicket(_ ticketId: String, status: TicketStatus, message: String? = nil) async {
        guard let index = activeTickets.firstIndex(where: { $0.id == ticketId }) else { return }
        
        activeTickets[index].status = status
        activeTickets[index].updatedAt = Date()
        
        if let message = message {
            let update = TicketUpdate(
                id: UUID().uuidString,
                ticketId: ticketId,
                message: message,
                author: "System",
                timestamp: Date()
            )
            activeTickets[index].updates.append(update)
        }
    }
    
    func getTicket(_ ticketId: String) -> SupportTicket? {
        return activeTickets.first { $0.id == ticketId }
    }
    
    func getTicketsForUser(_ userId: String) -> [SupportTicket] {
        return activeTickets.filter { $0.userId == userId }
    }
    
    // MARK: - Agent Management
    
    private func findAvailableAgent() -> SupportAgent? {
        return supportAgents.first { $0.status == .online }
    }
    
    private func findBestAgent(for request: SupportTicketRequest) -> SupportAgent? {
        // Find agent with matching specialty
        let specialty = determineSpecialty(from: request)
        return supportAgents.first { agent in
            agent.status == .online && agent.specialties.contains(specialty)
        } ?? findAvailableAgent()
    }
    
    private func determineSpecialty(from request: SupportTicketRequest) -> SupportSpecialty {
        let subject = request.subject.lowercased()
        let description = request.description.lowercased()
        
        if subject.contains("billing") || subject.contains("payment") || description.contains("subscription") {
            return .billing
        } else if subject.contains("account") || subject.contains("login") || description.contains("password") {
            return .account
        } else if subject.contains("crisis") || subject.contains("emergency") || description.contains("suicide") {
            return .crisis
        } else if subject.contains("bug") || subject.contains("crash") || description.contains("error") {
            return .technical
        } else {
            return .general
        }
    }
    
    private func notifyAgent(agentId: String, ticket: SupportTicket) {
        // Send notification to agent
        print("🔔 Notifying agent \(agentId) about ticket \(ticket.id)")
    }
    
    // MARK: - Knowledge Base
    
    func searchKnowledgeBase(_ query: String) async -> [KnowledgeBaseArticle] {
        return await supportAPI.searchKnowledgeBase(query: query)
    }
    
    func getArticle(_ articleId: String) async -> KnowledgeBaseArticle? {
        return await supportAPI.getArticle(articleId: articleId)
    }
    
    // MARK: - Crisis Support
    
    func handleCrisisSupport(userId: String, message: String) async -> CrisisResponse {
        // Immediate crisis detection
        if isCrisisMessage(message) {
            return CrisisResponse(
                isCrisis: true,
                message: "I understand you're going through a difficult time. Please know that you're not alone and help is available.",
                resources: getCrisisResources(),
                escalationRequired: true
            )
        }
        
        return CrisisResponse(
            isCrisis: false,
            message: "I'm here to help. Can you tell me more about what you're experiencing?",
            resources: [],
            escalationRequired: false
        )
    }
    
    private func isCrisisMessage(_ message: String) -> Bool {
        let crisisKeywords = [
            "suicide", "kill myself", "end it all", "not worth living",
            "hurt myself", "self harm", "cutting", "overdose"
        ]
        
        let lowercasedMessage = message.lowercased()
        return crisisKeywords.contains { lowercasedMessage.contains($0) }
    }
    
    private func getCrisisResources() -> [CrisisResource] {
        return [
            CrisisResource(
                id: "crisis_us_001",
                title: "National Suicide Prevention Lifeline",
                description: "Free and confidential emotional support to people in suicidal crisis or emotional distress 24 hours a day, 7 days a week. Text HOME to 741741",
                phoneNumber: "988",
                website: "https://suicidepreventionlifeline.org",
                location: "US",
                availability: "24/7",
                priority: 1
            ),
            CrisisResource(
                id: "crisis_us_002",
                title: "Crisis Text Line",
                description: "Free, 24/7 support for those in crisis. Text HOME to 741741 from anywhere in the US.",
                phoneNumber: "741741",
                website: "https://www.crisistextline.org",
                location: "US",
                availability: "24/7",
                priority: 1
            ),
            CrisisResource(
                id: "crisis_us_003",
                title: "Emergency Services",
                description: "Emergency services for immediate life-threatening situations. Call 911 for immediate help",
                phoneNumber: "911",
                website: nil,
                location: "US",
                availability: "24/7",
                priority: 1
            )
        ]
    }
    
    // MARK: - Feedback System
    
    func submitFeedback(_ feedback: SupportFeedback) async {
        await supportAPI.submitFeedback(feedback)
    }
    
    func getFeedbackStats() async -> FeedbackStats {
        return await supportAPI.getFeedbackStats()
    }
    
    // MARK: - Analytics
    
    func getSupportMetrics() async -> SupportMetrics {
        return SupportMetrics(
            totalTickets: activeTickets.count,
            openTickets: activeTickets.filter { $0.status == .open }.count,
            resolvedTickets: activeTickets.filter { $0.status == .resolved }.count,
            averageResponseTime: calculateAverageResponseTime(),
            customerSatisfaction: await getCustomerSatisfaction()
        )
    }
    
    private func calculateAverageResponseTime() -> TimeInterval {
        // Calculate average response time for resolved tickets
        let resolvedTickets = activeTickets.filter { $0.status == .resolved }
        let totalTime = resolvedTickets.reduce(0) { total, ticket in
            total + (ticket.updatedAt?.timeIntervalSince(ticket.createdAt) ?? 0)
        }
        return totalTime / Double(resolvedTickets.count)
    }
    
    private func getCustomerSatisfaction() async -> Double {
        return await supportAPI.getCustomerSatisfaction()
    }
}

// MARK: - Support Chatbot

class SupportChatbot {
    private let knowledgeBase = KnowledgeBase()
    
    func canHandle(message: String) -> Bool {
        let simpleQueries = [
            "how to", "what is", "where is", "when does", "why can't",
            "help", "support", "problem", "issue", "question"
        ]
        
        let lowercasedMessage = message.lowercased()
        return simpleQueries.contains { lowercasedMessage.contains($0) }
    }
    
    func processMessage(message: String, userId: String) async -> ChatResponse {
        // Search knowledge base for relevant articles
        let articles = await knowledgeBase.search(message)
        
        if let bestArticle = articles.first {
            return ChatResponse(
                message: bestArticle.content,
                isFromBot: true,
                agentId: nil,
                timestamp: Date()
            )
        }
        
        // Provide generic helpful response
        return ChatResponse(
            message: "I understand you need help. Let me connect you with one of our support specialists who can assist you better.",
            isFromBot: true,
            agentId: nil,
            timestamp: Date()
        )
    }
}

// MARK: - Knowledge Base

class KnowledgeBase {
    private let articles = [
        KnowledgeBaseArticle(
            id: "kb_001",
            title: "How to reset your password",
            content: "To reset your password, go to Settings > Account > Change Password. Enter your current password and new password twice.",
            category: .account,
            tags: ["password", "account", "security"]
        ),
        KnowledgeBaseArticle(
            id: "kb_002",
            title: "How to cancel your subscription",
            content: "To cancel your subscription, go to Settings > Subscription > Cancel Subscription. You'll continue to have access until the end of your billing period.",
            category: .billing,
            tags: ["subscription", "billing", "cancel"]
        ),
        KnowledgeBaseArticle(
            id: "kb_003",
            title: "App keeps crashing",
            content: "If the app keeps crashing, try these steps: 1) Close and reopen the app, 2) Restart your device, 3) Update to the latest version, 4) Contact support if the issue persists.",
            category: .technical,
            tags: ["crash", "technical", "troubleshooting"]
        ),
        KnowledgeBaseArticle(
            id: "kb_004",
            title: "How to export your data",
            content: "To export your data, go to Settings > Privacy > Export Data. Your data will be sent to your registered email address within 24 hours.",
            category: .privacy,
            tags: ["export", "data", "privacy"]
        )
    ]
    
    func search(_ query: String) async -> [KnowledgeBaseArticle] {
        let lowercasedQuery = query.lowercased()
        
        return articles.filter { article in
            article.title.lowercased().contains(lowercasedQuery) ||
            article.content.lowercased().contains(lowercasedQuery) ||
            article.tags.contains { $0.lowercased().contains(lowercasedQuery) }
        }.sorted { $0.title.count < $1.title.count }
    }
}

// MARK: - Support API

class SupportAPI {
    func searchKnowledgeBase(query: String) async -> [KnowledgeBaseArticle] {
        // Simulate API call
        return []
    }
    
    func getArticle(articleId: String) async -> KnowledgeBaseArticle? {
        // Simulate API call
        return nil
    }
    
    func submitFeedback(_ feedback: SupportFeedback) async {
        // Simulate API call
        print("📝 Feedback submitted: \(feedback.rating) stars")
    }
    
    func getFeedbackStats() async -> FeedbackStats {
        // Simulate API call
        return FeedbackStats(
            totalFeedback: 150,
            averageRating: 4.7,
            ratingDistribution: [1: 2, 2: 5, 3: 15, 4: 45, 5: 83]
        )
    }
    
    func getCustomerSatisfaction() async -> Double {
        // Simulate API call
        return 4.7
    }
}

// MARK: - Supporting Types

struct SupportAgent {
    let id: String
    let name: String
    let status: AgentStatus
    let specialties: [SupportSpecialty]
}

enum AgentStatus: String, CaseIterable {
    case online = "online"
    case away = "away"
    case offline = "offline"
}

enum SupportSpecialty: String, CaseIterable {
    case technical = "technical"
    case billing = "billing"
    case account = "account"
    case crisis = "crisis"
    case general = "general"
}

struct SupportTicket {
    let id: String
    let userId: String
    let subject: String
    let description: String
    let priority: TicketPriority
    var status: TicketStatus
    var assignedAgent: String?
    let createdAt: Date
    var updatedAt: Date?
    var updates: [TicketUpdate] = []
}

struct SupportTicketRequest {
    let userId: String
    let subject: String
    let description: String
    let priority: TicketPriority
}

enum TicketPriority: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
}

enum TicketStatus: String, CaseIterable {
    case open = "open"
    case inProgress = "in_progress"
    case resolved = "resolved"
    case closed = "closed"
}

struct TicketUpdate {
    let id: String
    let ticketId: String
    let message: String
    let author: String
    let timestamp: Date
}

struct ChatResponse {
    let message: String
    let isFromBot: Bool
    let agentId: String?
    let timestamp: Date
}

struct KnowledgeBaseArticle {
    let id: String
    let title: String
    let content: String
    let category: ArticleCategory
    let tags: [String]
}

enum ArticleCategory: String, CaseIterable {
    case account = "account"
    case billing = "billing"
    case technical = "technical"
    case privacy = "privacy"
    case general = "general"
}

struct CrisisResponse {
    let isCrisis: Bool
    let message: String
    let resources: [CrisisResource]
    let escalationRequired: Bool
}

// Note: CrisisResource is defined in CrisisDetectionService.swift

struct SupportFeedback {
    let userId: String
    let ticketId: String?
    let rating: Int
    let message: String
    let timestamp: Date
}

struct FeedbackStats {
    let totalFeedback: Int
    let averageRating: Double
    let ratingDistribution: [Int: Int]
}

struct SupportMetrics {
    let totalTickets: Int
    let openTickets: Int
    let resolvedTickets: Int
    let averageResponseTime: TimeInterval
    let customerSatisfaction: Double
}
