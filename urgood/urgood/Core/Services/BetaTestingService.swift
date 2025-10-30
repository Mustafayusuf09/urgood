import Foundation
import Combine

class BetaTestingService: ObservableObject {
    static let shared = BetaTestingService()
    
    @Published var betaPrograms: [BetaProgram] = []
    @Published var activeTesters: [BetaTester] = []
    @Published var feedbackItems: [BetaFeedback] = []
    @Published var testBuilds: [TestBuild] = []
    
    private let feedbackAPI = BetaFeedbackAPI()
    private let buildManager = BetaBuildManager()
    private let analyticsService = RealAnalyticsService.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadBetaPrograms()
        loadActiveTesters()
    }
    
    // MARK: - Beta Program Management
    
    func createBetaProgram(_ program: BetaProgram) async {
        // Validate program
        guard validateBetaProgram(program) else {
            print("❌ Invalid beta program: \(program.id)")
            return
        }
        
        // Add to programs
        _ = await MainActor.run {
            betaPrograms.append(program)
        }
        
        // Save to storage
        await saveBetaProgram(program)
        
        // Log program creation
        analyticsService.logEvent("beta_program_created", parameters: [
            "program_id": program.id,
            "name": program.name,
            "target_audience": program.targetAudience.rawValue
        ])
    }
    
    func updateBetaProgram(_ program: BetaProgram) async {
        guard let index = betaPrograms.firstIndex(where: { $0.id == program.id }) else {
            print("❌ Beta program not found: \(program.id)")
            return
        }
        
        _ = await MainActor.run {
            betaPrograms[index] = program
        }
        
        await saveBetaProgram(program)
        
        analyticsService.logEvent("beta_program_updated", parameters: [
            "program_id": program.id,
            "name": program.name
        ])
    }
    
    func endBetaProgram(_ programId: String) async {
        guard let index = betaPrograms.firstIndex(where: { $0.id == programId }) else {
            print("❌ Beta program not found: \(programId)")
            return
        }
        
        let program = betaPrograms[index]
        
        _ = await MainActor.run {
            betaPrograms.remove(at: index)
        }
        
        await deleteBetaProgram(programId)
        
        analyticsService.logEvent("beta_program_ended", parameters: [
            "program_id": programId,
            "name": program.name
        ])
    }
    
    // MARK: - Beta Tester Management
    
    func addBetaTester(_ tester: BetaTester) async {
        // Check if tester already exists
        if activeTesters.contains(where: { $0.id == tester.id }) {
            print("⚠️ Beta tester already exists: \(tester.id)")
            return
        }
        
        // Add tester
        _ = await MainActor.run {
            activeTesters.append(tester)
        }
        
        // Save to storage
        await saveBetaTester(tester)
        
        // Send welcome email
        await sendWelcomeEmail(to: tester)
        
        analyticsService.logEvent("beta_tester_added", parameters: [
            "tester_id": tester.id,
            "email": tester.email,
            "program_id": tester.programId
        ])
    }
    
    func removeBetaTester(_ testerId: String) async {
        guard let index = activeTesters.firstIndex(where: { $0.id == testerId }) else {
            print("❌ Beta tester not found: \(testerId)")
            return
        }
        
        let tester = activeTesters[index]
        
        _ = await MainActor.run {
            activeTesters.remove(at: index)
        }
        
        await deleteBetaTester(testerId)
        
        analyticsService.logEvent("beta_tester_removed", parameters: [
            "tester_id": testerId,
            "email": tester.email
        ])
    }
    
    func updateTesterStatus(_ testerId: String, status: BetaTesterStatus) async {
        guard let index = activeTesters.firstIndex(where: { $0.id == testerId }) else {
            print("❌ Beta tester not found: \(testerId)")
            return
        }
        
        activeTesters[index].status = status
        activeTesters[index].lastUpdated = Date()
        
        await saveBetaTester(activeTesters[index])
        
        analyticsService.logEvent("beta_tester_status_updated", parameters: [
            "tester_id": testerId,
            "status": status.rawValue
        ])
    }
    
    // MARK: - Test Build Management
    
    func createTestBuild(_ build: TestBuild) async {
        // Validate build
        guard validateTestBuild(build) else {
            print("❌ Invalid test build: \(build.id)")
            return
        }
        
        // Add to builds
        _ = await MainActor.run {
            testBuilds.append(build)
        }
        
        // Save to storage
        await saveTestBuild(build)
        
        // Notify testers
        await notifyTestersAboutNewBuild(build)
        
        analyticsService.logEvent("test_build_created", parameters: [
            "build_id": build.id,
            "version": build.version,
            "program_id": build.programId
        ])
    }
    
    func distributeBuild(_ buildId: String, to testers: [String]) async {
        guard let build = testBuilds.first(where: { $0.id == buildId }) else {
            print("❌ Test build not found: \(buildId)")
            return
        }
        
        // Update build distribution (create new build with updated properties)
        let updatedBuild = TestBuild(
            id: build.id,
            version: build.version,
            programId: build.programId,
            createdAt: build.createdAt,
            buildNumber: build.buildNumber,
            releaseNotes: build.releaseNotes,
            downloadUrl: build.downloadUrl,
            distributedTo: testers,
            distributionDate: Date(),
            rating: build.rating,
            features: build.features,
            knownIssues: build.knownIssues
        )
        
        // Notify testers
        for testerId in testers {
            await notifyTesterAboutBuild(testerId: testerId, build: updatedBuild)
        }
        
        analyticsService.logEvent("test_build_distributed", parameters: [
            "build_id": buildId,
            "tester_count": testers.count
        ])
    }
    
    // MARK: - Feedback Management
    
    func submitFeedback(_ feedback: BetaFeedback) async {
        // Validate feedback
        guard validateFeedback(feedback) else {
            print("❌ Invalid feedback: \(feedback.id)")
            return
        }
        
        // Add to feedback
        _ = await MainActor.run {
            feedbackItems.append(feedback)
        }
        
        // Save to storage
        await saveFeedback(feedback)
        
        // Notify program managers
        await notifyProgramManagers(feedback)
        
        analyticsService.logEvent("beta_feedback_submitted", parameters: [
            "feedback_id": feedback.id,
            "tester_id": feedback.testerId,
            "program_id": feedback.programId,
            "type": feedback.type.rawValue,
            "priority": feedback.priority.rawValue
        ])
    }
    
    func updateFeedbackStatus(_ feedbackId: String, status: FeedbackStatus) async {
        guard let index = feedbackItems.firstIndex(where: { $0.id == feedbackId }) else {
            print("❌ Feedback not found: \(feedbackId)")
            return
        }
        
        feedbackItems[index].status = status
        feedbackItems[index].lastUpdated = Date()
        
        await saveFeedback(feedbackItems[index])
        
        analyticsService.logEvent("beta_feedback_status_updated", parameters: [
            "feedback_id": feedbackId,
            "status": status.rawValue
        ])
    }
    
    func getFeedbackForProgram(_ programId: String) -> [BetaFeedback] {
        return feedbackItems.filter { $0.programId == programId }
    }
    
    func getFeedbackForTester(_ testerId: String) -> [BetaFeedback] {
        return feedbackItems.filter { $0.testerId == testerId }
    }
    
    // MARK: - Analytics and Reporting
    
    func getBetaProgramMetrics(_ programId: String) async -> BetaProgramMetrics {
        let program = betaPrograms.first { $0.id == programId }
        let testers = activeTesters.filter { $0.programId == programId }
        let feedback = feedbackItems.filter { $0.programId == programId }
        let builds = testBuilds.filter { $0.programId == programId }
        
        return BetaProgramMetrics(
            programId: programId,
            programName: program?.name ?? "",
            totalTesters: testers.count,
            activeTesters: testers.filter { $0.status == .active }.count,
            totalFeedback: feedback.count,
            resolvedFeedback: feedback.filter { $0.status == .resolved }.count,
            totalBuilds: builds.count,
            averageFeedbackPerTester: testers.count > 0 ? Double(feedback.count) / Double(testers.count) : 0.0,
            averageBuildRating: calculateAverageBuildRating(builds),
            startDate: program?.startDate ?? Date(),
            endDate: program?.endDate
        )
    }
    
    func getTesterMetrics(_ testerId: String) async -> BetaTesterMetrics {
        let tester = activeTesters.first { $0.id == testerId }
        let feedback = feedbackItems.filter { $0.testerId == testerId }
        let builds = testBuilds.filter { $0.distributedTo?.contains(testerId) == true }
        
        return BetaTesterMetrics(
            testerId: testerId,
            testerName: tester?.name ?? "",
            programId: tester?.programId ?? "",
            status: tester?.status ?? .inactive,
            totalFeedback: feedback.count,
            resolvedFeedback: feedback.filter { $0.status == .resolved }.count,
            totalBuilds: builds.count,
            averageFeedbackPerBuild: builds.count > 0 ? Double(feedback.count) / Double(builds.count) : 0.0,
            joinDate: tester?.joinDate ?? Date(),
            lastActivity: feedback.max { $0.timestamp < $1.timestamp }?.timestamp ?? Date()
        )
    }
    
    func generateBetaReport(_ programId: String) async -> BetaReport {
        let metrics = await getBetaProgramMetrics(programId)
        let feedback = getFeedbackForProgram(programId)
        let builds = testBuilds.filter { $0.programId == programId }
        
        return BetaReport(
            programId: programId,
            programName: metrics.programName,
            metrics: metrics,
            topIssues: getTopIssues(feedback),
            topTesters: getTopTesters(programId),
            buildHistory: builds.sorted { $0.createdAt > $1.createdAt },
            recommendations: generateRecommendations(metrics, feedback: feedback),
            generatedAt: Date()
        )
    }
    
    // MARK: - Communication
    
    func sendMessageToTesters(_ message: BetaMessage, programId: String) async {
        let testers = activeTesters.filter { $0.programId == programId && $0.status == .active }
        
        for tester in testers {
            await sendMessageToTester(message, tester: tester)
        }
        
        analyticsService.logEvent("beta_message_sent", parameters: [
            "program_id": programId,
            "tester_count": testers.count,
            "message_type": message.type.rawValue
        ])
    }
    
    func sendMessageToTester(_ message: BetaMessage, tester: BetaTester) async {
        // Send message to specific tester
        print("📧 Sending message to \(tester.email): \(message.subject)")
    }
    
    // MARK: - Private Methods
    
    private func validateBetaProgram(_ program: BetaProgram) -> Bool {
        // Check if program has valid dates
        guard program.startDate < program.endDate else {
            return false
        }
        
        // Check if program has valid target audience
        guard !program.targetAudience.rawValue.isEmpty else {
            return false
        }
        
        return true
    }
    
    private func validateTestBuild(_ build: TestBuild) -> Bool {
        // Check if build has valid version
        guard !build.version.isEmpty else {
            return false
        }
        
        // Check if build has valid program ID
        guard !build.programId.isEmpty else {
            return false
        }
        
        return true
    }
    
    private func validateFeedback(_ feedback: BetaFeedback) -> Bool {
        // Check if feedback has valid content
        guard !feedback.content.isEmpty else {
            return false
        }
        
        // Check if feedback has valid tester ID
        guard !feedback.testerId.isEmpty else {
            return false
        }
        
        return true
    }
    
    private func calculateAverageBuildRating(_ builds: [TestBuild]) -> Double {
        let ratedBuilds = builds.filter { $0.rating != nil }
        guard !ratedBuilds.isEmpty else { return 0.0 }
        
        let totalRating = ratedBuilds.reduce(0.0) { $0 + ($1.rating ?? 0.0) }
        return totalRating / Double(ratedBuilds.count)
    }
    
    private func getTopIssues(_ feedback: [BetaFeedback]) -> [FeedbackIssue] {
        let issues = feedback.compactMap { $0.issue }
        let issueCounts = Dictionary(grouping: issues, by: { $0.type })
            .mapValues { $0.count }
        
        return issueCounts.sorted { $0.value > $1.value }
            .prefix(5)
            .map { FeedbackIssue(type: $0.key, count: $0.value) }
    }
    
    private func getTopTesters(_ programId: String) -> [BetaTester] {
        let testers = activeTesters.filter { $0.programId == programId }
        let feedbackCounts = Dictionary(grouping: feedbackItems.filter { $0.programId == programId }, by: { $0.testerId })
            .mapValues { $0.count }
        
        return testers.sorted { (tester1, tester2) in
            let count1 = feedbackCounts[tester1.id] ?? 0
            let count2 = feedbackCounts[tester2.id] ?? 0
            return count1 > count2
        }.prefix(5).map { $0 }
    }
    
    private func generateRecommendations(_ metrics: BetaProgramMetrics, feedback: [BetaFeedback]) -> [BetaRecommendation] {
        var recommendations: [BetaRecommendation] = []
        
        // Check feedback response rate
        if metrics.resolvedFeedback < Int(Double(metrics.totalFeedback) * 0.8) {
            recommendations.append(BetaRecommendation(
                type: .feedbackResponse,
                priority: .high,
                description: "Improve feedback response rate",
                implementation: "Review and respond to pending feedback items"
            ))
        }
        
        // Check tester engagement
        if metrics.activeTesters < Int(Double(metrics.totalTesters) * 0.7) {
            recommendations.append(BetaRecommendation(
                type: .testerEngagement,
                priority: .medium,
                description: "Improve tester engagement",
                implementation: "Send engagement messages and provide incentives"
            ))
        }
        
        // Check build quality
        if metrics.averageBuildRating < 3.0 {
            recommendations.append(BetaRecommendation(
                type: .buildQuality,
                priority: .high,
                description: "Improve build quality",
                implementation: "Address critical issues before next build"
            ))
        }
        
        return recommendations
    }
    
    private func loadBetaPrograms() {
        // Load from storage
        // Implementation would load from persistent storage
    }
    
    private func loadActiveTesters() {
        // Load from storage
        // Implementation would load from persistent storage
    }
    
    private func saveBetaProgram(_ program: BetaProgram) async {
        // Save to storage
        // Implementation would save to persistent storage
    }
    
    private func deleteBetaProgram(_ programId: String) async {
        // Delete from storage
        // Implementation would delete from persistent storage
    }
    
    private func saveBetaTester(_ tester: BetaTester) async {
        // Save to storage
        // Implementation would save to persistent storage
    }
    
    private func deleteBetaTester(_ testerId: String) async {
        // Delete from storage
        // Implementation would delete from persistent storage
    }
    
    private func saveTestBuild(_ build: TestBuild) async {
        // Save to storage
        // Implementation would save to persistent storage
    }
    
    private func saveFeedback(_ feedback: BetaFeedback) async {
        // Save to storage
        // Implementation would save to persistent storage
    }
    
    private func sendWelcomeEmail(to tester: BetaTester) async {
        // Send welcome email
        print("📧 Sending welcome email to \(tester.email)")
    }
    
    private func notifyTestersAboutNewBuild(_ build: TestBuild) async {
        // Notify testers about new build
        print("📱 Notifying testers about new build: \(build.version)")
    }
    
    private func notifyTesterAboutBuild(testerId: String, build: TestBuild) async {
        // Notify specific tester about build
        print("📱 Notifying tester \(testerId) about build: \(build.version)")
    }
    
    private func notifyProgramManagers(_ feedback: BetaFeedback) async {
        // Notify program managers about feedback
        print("📧 Notifying program managers about feedback: \(feedback.id)")
    }
}

// MARK: - Beta Feedback API

class BetaFeedbackAPI {
    func submitFeedback(_ feedback: BetaFeedback) async {
        // Submit feedback to API
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
    
    func getFeedback(_ programId: String) async -> [BetaFeedback] {
        // Get feedback from API
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        return []
    }
}

// MARK: - Beta Build Manager

class BetaBuildManager {
    func createBuild(_ build: TestBuild) async {
        // Create test build
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
    }
    
    func distributeBuild(_ build: TestBuild, to testers: [String]) async {
        // Distribute build to testers
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
    }
}

// MARK: - Supporting Types

struct BetaProgram {
    let id: String
    let name: String
    let description: String
    let targetAudience: TargetAudience
    let startDate: Date
    let endDate: Date
    let maxTesters: Int
    let requirements: [String]
    let status: ProgramStatus
}

enum TargetAudience: String, CaseIterable {
    case general = "general"
    case mentalHealth = "mental_health"
    case healthcare = "healthcare"
    case developers = "developers"
    case earlyAdopters = "early_adopters"
}

enum ProgramStatus: String, CaseIterable {
    case planning = "planning"
    case recruiting = "recruiting"
    case active = "active"
    case paused = "paused"
    case completed = "completed"
}

struct BetaTester {
    let id: String
    let name: String
    let email: String
    let programId: String
    let joinDate: Date
    var status: BetaTesterStatus
    var lastUpdated: Date
    let deviceInfo: DeviceInfo
    let preferences: TesterPreferences
}

enum BetaTesterStatus: String, CaseIterable {
    case pending = "pending"
    case active = "active"
    case inactive = "inactive"
    case suspended = "suspended"
}

struct DeviceInfo {
    let platform: String
    let version: String
    let model: String
    let screenSize: String
}

struct TesterPreferences {
    let feedbackFrequency: FeedbackFrequency
    let notificationSettings: NotificationSettings
    let preferredContactMethod: ContactMethod
}

enum FeedbackFrequency: String, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case biweekly = "biweekly"
    case monthly = "monthly"
}

struct NotificationSettings {
    let email: Bool
    let push: Bool
    let sms: Bool
}

enum ContactMethod: String, CaseIterable {
    case email = "email"
    case phone = "phone"
    case inApp = "in_app"
}

struct TestBuild {
    let id: String
    let version: String
    let programId: String
    let createdAt: Date
    let buildNumber: String
    let releaseNotes: String
    let downloadUrl: String
    var distributedTo: [String]?
    var distributionDate: Date?
    var rating: Double?
    let features: [String]
    let knownIssues: [String]
}

struct BetaFeedback {
    let id: String
    let testerId: String
    let programId: String
    let buildId: String?
    let type: FeedbackType
    let priority: FeedbackPriority
    let content: String
    let timestamp: Date
    var status: FeedbackStatus
    var lastUpdated: Date
    let attachments: [FeedbackAttachment]
    let issue: FeedbackIssue?
}

enum FeedbackType: String, CaseIterable {
    case bug = "bug"
    case feature = "feature"
    case improvement = "improvement"
    case question = "question"
    case general = "general"
}

enum FeedbackPriority: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

enum FeedbackStatus: String, CaseIterable {
    case open = "open"
    case inProgress = "in_progress"
    case resolved = "resolved"
    case closed = "closed"
}

struct FeedbackAttachment {
    let id: String
    let type: AttachmentType
    let url: String
    let filename: String
    let size: Int
}

enum AttachmentType: String, CaseIterable {
    case image = "image"
    case video = "video"
    case audio = "audio"
    case document = "document"
    case log = "log"
}

struct FeedbackIssue {
    let type: String
    let count: Int
}

struct BetaMessage {
    let id: String
    let subject: String
    let content: String
    let type: MessageType
    let createdAt: Date
    let attachments: [FeedbackAttachment]
}

enum MessageType: String, CaseIterable {
    case announcement = "announcement"
    case instruction = "instruction"
    case reminder = "reminder"
    case update = "update"
}

struct BetaProgramMetrics {
    let programId: String
    let programName: String
    let totalTesters: Int
    let activeTesters: Int
    let totalFeedback: Int
    let resolvedFeedback: Int
    let totalBuilds: Int
    let averageFeedbackPerTester: Double
    let averageBuildRating: Double
    let startDate: Date
    let endDate: Date?
}

struct BetaTesterMetrics {
    let testerId: String
    let testerName: String
    let programId: String
    let status: BetaTesterStatus
    let totalFeedback: Int
    let resolvedFeedback: Int
    let totalBuilds: Int
    let averageFeedbackPerBuild: Double
    let joinDate: Date
    let lastActivity: Date
}

struct BetaReport {
    let programId: String
    let programName: String
    let metrics: BetaProgramMetrics
    let topIssues: [FeedbackIssue]
    let topTesters: [BetaTester]
    let buildHistory: [TestBuild]
    let recommendations: [BetaRecommendation]
    let generatedAt: Date
}

struct BetaRecommendation {
    let type: BetaRecommendationType
    let priority: BetaRecommendationPriority
    let description: String
    let implementation: String
}

enum BetaRecommendationPriority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

enum BetaRecommendationType: String, CaseIterable {
    case feedbackResponse = "feedback_response"
    case testerEngagement = "tester_engagement"
    case buildQuality = "build_quality"
    case programExpansion = "program_expansion"
    case featureFocus = "feature_focus"
}

