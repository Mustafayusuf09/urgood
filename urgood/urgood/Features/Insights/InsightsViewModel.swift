import SwiftUI
import Combine

class InsightsViewModel: ObservableObject {
    @Published var hasCheckedInToday = false
    @Published var weeklyMoods: [InsightsViewDailyMood] = []
    @Published var recentSessions: [InsightsChatSession] = []
    @Published var trends: [TrendPoint] = []
    @Published var averageMood: Double = 0.0
    @Published var totalSessions: Int = 0
    @Published var hasData = false
    @Published var toast: ToastData?
    @Published var weeklyRecap: WeeklyRecap?
    @Published var showPremiumUpgrade = false
    
    private let checkinService: CheckinService
    private let chatService: ChatService
    private let localStore: LocalStore
    private let billingService: any BillingServiceProtocol
    private let weeklyRecapService: WeeklyRecapService
    private var cancellables = Set<AnyCancellable>()
    
    init(
        checkinService: CheckinService,
        chatService: ChatService,
        localStore: LocalStore,
        billingService: any BillingServiceProtocol
    ) {
        self.checkinService = checkinService
        self.chatService = chatService
        self.localStore = localStore
        self.billingService = billingService
        self.weeklyRecapService = WeeklyRecapService(
            localStore: localStore,
            checkinService: checkinService,
            chatService: chatService
        )
        
        loadData()
    }
    
    func refreshData() {
        loadData()
    }
    
    func saveQuickCheckin(mood: Int, tags: [String]) {
        // Save the check-in
        let moodTags = tags.map { MoodTag(name: $0) }
        let moodEntry = MoodEntry(
            mood: mood,
            tags: moodTags
        )
        
        checkinService.saveMoodEntry(moodEntry)
        
        // Update local state
        hasCheckedInToday = true
        
        // Show motivational toast
        let motivationalMessage = getMotivationalMessage()
        toast = ToastData(
            message: motivationalMessage,
            type: .success
        )
        
        // Refresh data
        loadData()
    }
    
    private func loadData() {
        loadCheckinStatus()
        loadWeeklyMoods()
        loadRecentSessions()
        loadTrends()
        loadWeeklyRecap()
        updateHasData()
    }
    
    private func loadCheckinStatus() {
        hasCheckedInToday = checkinService.hasCheckedInToday()
    }
    
    private func loadWeeklyMoods() {
        let calendar = Calendar.current
        let today = Date()
        
        var moods: [InsightsViewDailyMood] = []
        
        for i in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            
            // Check if there's a mood entry for this date
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date
            
            let entriesForDay = localStore.moodEntries.filter { entry in
                entry.date >= dayStart && entry.date < dayEnd
            }
            
            let moodValue = entriesForDay.isEmpty ? 3.0 : Double(entriesForDay.map { $0.mood }.reduce(0, +)) / Double(entriesForDay.count)
            
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "E"
            
            let mood = InsightsViewDailyMood(
                date: date,
                value: moodValue,
                dayOfWeek: dayFormatter.string(from: date)
            )
            
            moods.append(mood)
        }
        
        weeklyMoods = moods.reversed() // Show oldest to newest
    }
    
    private func loadRecentSessions() {
        // Get recent chat messages and group them into sessions
        let messages = localStore.chatMessages
        let groupedMessages = Dictionary(grouping: messages) { message in
            Calendar.current.startOfDay(for: message.date)
        }
        
        recentSessions = groupedMessages.compactMap { (date, messages) in
            guard !messages.isEmpty else { return nil }
            
            let userMessages = messages.filter { $0.role == .user }
            let aiMessages = messages.filter { $0.role == .assistant }
            
            // Try to generate AI-powered summary if we have enough messages
            if messages.count >= 4 { // At least 2 exchanges
                Task {
                    if let summary = await chatService.generateSessionSummary(for: messages) {
                        _ = await MainActor.run {
                            // Update the session with AI-generated insights
                            if let index = recentSessions.firstIndex(where: { 
                                Calendar.current.isDate($0.date, inSameDayAs: date) 
                            }) {
                                recentSessions[index] = InsightsChatSession(
                                    title: summary.title,
                                    preview: userMessages.first?.text ?? "",
                                    date: date,
                                    messageCount: messages.count,
                                    moodRating: summary.moodRating,
                                    insights: summary.insights,
                                    breakthrough: generateBreakthrough(from: userMessages, aiMessages: aiMessages),
                                    progressLevel: summary.progressLevel
                                )
                            }
                        }
                    }
                }
            }
            
            // Fallback to rule-based generation
            let title = generateSessionTitle(from: userMessages, aiMessages: aiMessages)
            let preview = userMessages.first?.text ?? ""
            let moodRating = calculateMoodRating(from: messages)
            let insights = generateSessionInsights(from: userMessages, aiMessages: aiMessages)
            let breakthrough = generateBreakthrough(from: userMessages, aiMessages: aiMessages)
            let progressLevel = calculateProgressLevel(from: messages)
            
            return InsightsChatSession(
                title: title,
                preview: preview,
                date: date,
                messageCount: messages.count,
                moodRating: moodRating,
                insights: insights,
                breakthrough: breakthrough,
                progressLevel: progressLevel
            )
        }.sorted { $0.date > $1.date }.prefix(10).map { $0 }
    }
    
    private func loadTrends() {
        // Get trend data from checkin service
        trends = checkinService.getRecentTrends(days: 7)
        
        // Calculate average mood from recent trends
        if !trends.isEmpty {
            averageMood = trends.map(\.value).reduce(0, +) / Double(trends.count)
        }
    }
    
    private func loadWeeklyRecap() {
        weeklyRecap = weeklyRecapService.generateWeeklyRecap()
    }
    
    func upgradeToPremium() {
        showPremiumUpgrade = true
    }
    
    private func updateHasData() {
        hasData = !weeklyMoods.isEmpty || !recentSessions.isEmpty || !trends.isEmpty
    }
    
    private func calculateMoodRating(from messages: [ChatMessage]) -> Double {
        // Simple mood calculation based on message content
        // This would typically use sentiment analysis
        return 3.0 // Default neutral mood
    }
    
    private func generateSessionTitle(from userMessages: [ChatMessage], aiMessages: [ChatMessage]) -> String {
        guard let firstUserMessage = userMessages.first else { return "Conversation" }
        
        let content = firstUserMessage.text.lowercased()
        
        // Generate contextual titles based on content
        if content.contains("anxiety") || content.contains("worried") || content.contains("nervous") {
            return "Managing Anxiety"
        } else if content.contains("sad") || content.contains("depressed") || content.contains("down") {
            return "Working Through Sadness"
        } else if content.contains("stress") || content.contains("overwhelmed") || content.contains("pressure") {
            return "Stress Relief Session"
        } else if content.contains("relationship") || content.contains("friend") || content.contains("family") {
            return "Relationship Support"
        } else if content.contains("work") || content.contains("career") || content.contains("job") {
            return "Career Guidance"
        } else if content.contains("sleep") || content.contains("tired") || content.contains("rest") {
            return "Sleep & Wellness"
        } else if content.contains("goal") || content.contains("plan") || content.contains("future") {
            return "Goal Setting & Planning"
        } else {
            return String(firstUserMessage.text.prefix(30))
        }
    }
    
    private func generateSessionInsights(from userMessages: [ChatMessage], aiMessages: [ChatMessage]) -> String? {
        guard !userMessages.isEmpty && !aiMessages.isEmpty else { return nil }
        
        let userContent = userMessages.map { $0.text }.joined(separator: " ").lowercased()
        let aiContent = aiMessages.map { $0.text }.joined(separator: " ").lowercased()
        
        // Generate insights based on conversation patterns
        if userContent.contains("realize") || userContent.contains("understand") || userContent.contains("see") {
            return "Gained new perspective on your situation"
        } else if aiContent.contains("technique") || aiContent.contains("strategy") || aiContent.contains("exercise") {
            return "Learned practical coping strategies"
        } else if userContent.contains("feel better") || userContent.contains("improved") || userContent.contains("progress") {
            return "Made positive progress in your mental wellness"
        } else if aiContent.contains("strength") || aiContent.contains("resilient") || aiContent.contains("capable") {
            return "Recognized your inner strength and resilience"
        } else if userContent.contains("pattern") || userContent.contains("habit") || userContent.contains("behavior") {
            return "Identified patterns in your thoughts and behaviors"
        } else {
            return "Had a meaningful conversation about your wellbeing"
        }
    }
    
    private func generateBreakthrough(from userMessages: [ChatMessage], aiMessages: [ChatMessage]) -> String? {
        guard !userMessages.isEmpty else { return nil }
        
        let userContent = userMessages.map { $0.text }.joined(separator: " ").lowercased()
        
        // Identify potential breakthroughs
        if userContent.contains("breakthrough") || userContent.contains("epiphany") || userContent.contains("realization") {
            return "Had a major realization about yourself"
        } else if userContent.contains("fear") && userContent.contains("face") {
            return "Faced a fear that was holding you back"
        } else if userContent.contains("forgive") || userContent.contains("let go") {
            return "Let go of past hurt and found forgiveness"
        } else if userContent.contains("boundary") || userContent.contains("say no") {
            return "Set healthy boundaries for yourself"
        } else if userContent.contains("grateful") || userContent.contains("appreciate") {
            return "Found gratitude in difficult circumstances"
        } else if userContent.contains("confident") || userContent.contains("believe") {
            return "Built confidence in your abilities"
        } else {
            return nil
        }
    }
    
    private func calculateProgressLevel(from messages: [ChatMessage]) -> Int {
        let userMessages = messages.filter { $0.role == .user }
        let messageCount = userMessages.count
        
        // Calculate progress based on conversation depth and length
        if messageCount >= 10 {
            return 5 // Deep conversation
        } else if messageCount >= 6 {
            return 4 // Good conversation
        } else if messageCount >= 3 {
            return 3 // Moderate conversation
        } else if messageCount >= 2 {
            return 2 // Brief conversation
        } else {
            return 1 // Very brief
        }
    }
    
    private func getMotivationalMessage() -> String {
        let checkinStreak = calculateCheckinStreak()
        let mood = localStore.moodEntries.last?.mood ?? 3
        
        // Streak-based messages
        if checkinStreak >= 7 {
            return "Amazing! 7+ day streak! You're building incredible habits 🌟"
        } else if checkinStreak >= 3 {
            return "Great job! \(checkinStreak) days in a row, keep it up! 💪"
        } else if checkinStreak == 2 {
            return "Nice! 2 days in a row, you're on a roll! 🚀"
        }
        
        // Mood-based messages
        switch mood {
        case 5:
            return "Fantastic! You're feeling great today! ✨"
        case 4:
            return "Wonderful! Great job checking in with yourself 🌱"
        case 3:
            return "Thanks for taking care of yourself today 💚"
        case 2:
            return "You're doing great by checking in, even when it's tough 🌿"
        case 1:
            return "You're so strong for checking in today. Take care of yourself 💙"
        default:
            return "Great job reflecting today 🌱"
        }
    }
    
    private func calculateCheckinStreak() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var currentDate = today
        
        while true {
            let dayStart = currentDate
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? currentDate
            
            let hasCheckin = localStore.moodEntries.contains { entry in
                entry.date >= dayStart && entry.date < dayEnd
            }
            
            if hasCheckin {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else {
                break
            }
        }
        
        return streak
    }
}


