import Foundation

// MARK: - Weekly Recap Models
struct WeeklyRecap: Identifiable, Codable {
    let id: UUID
    let weekStartDate: Date
    let weekEndDate: Date
    let averageMood: Double
    let moodTrend: MoodTrend
    let topTags: [TagFrequency]
    let totalCheckins: Int
    let totalMessages: Int
    let insights: [String]
    let hasEnoughData: Bool
    
    init(
        weekStartDate: Date,
        weekEndDate: Date,
        averageMood: Double = 0.0,
        moodTrend: MoodTrend = .stable,
        topTags: [TagFrequency] = [],
        totalCheckins: Int = 0,
        totalMessages: Int = 0,
        insights: [String] = [],
        hasEnoughData: Bool = false
    ) {
        self.id = UUID()
        self.weekStartDate = weekStartDate
        self.weekEndDate = weekEndDate
        self.averageMood = averageMood
        self.moodTrend = moodTrend
        self.topTags = topTags
        self.totalCheckins = totalCheckins
        self.totalMessages = totalMessages
        self.insights = insights
        self.hasEnoughData = hasEnoughData
    }
}

enum MoodTrend: String, Codable, CaseIterable {
    case up = "up"
    case down = "down"
    case stable = "stable"
    
    var displayName: String {
        switch self {
        case .up: return "Improving"
        case .down: return "Declining"
        case .stable: return "Stable"
        }
    }
    
    var emoji: String {
        switch self {
        case .up: return "📈"
        case .down: return "📉"
        case .stable: return "➡️"
        }
    }
    
    var color: String {
        switch self {
        case .up: return "success"
        case .down: return "error"
        case .stable: return "textSecondary"
        }
    }
}

struct TagFrequency: Identifiable, Codable {
    let id: UUID
    let tag: String
    let frequency: Int
    let percentage: Double
    
    init(tag: String, frequency: Int, percentage: Double) {
        self.id = UUID()
        self.tag = tag
        self.frequency = frequency
        self.percentage = percentage
    }
}

// MARK: - Weekly Recap Service
class WeeklyRecapService: ObservableObject {
    private let localStore: LocalStore
    private let checkinService: CheckinService
    private let chatService: ChatService
    
    init(localStore: LocalStore, checkinService: CheckinService, chatService: ChatService) {
        self.localStore = localStore
        self.checkinService = checkinService
        self.chatService = chatService
    }
    
    func generateWeeklyRecap() -> WeeklyRecap {
        let calendar = Calendar.current
        let today = Date()
        
        // Get the start of this week (Monday)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? today
        
        // Get mood entries for this week
        let moodEntries = localStore.moodEntries.filter { entry in
            entry.date >= weekStart && entry.date <= weekEnd
        }
        
        // Get chat messages for this week
        let chatMessages = localStore.chatMessages.filter { message in
            message.date >= weekStart && message.date <= weekEnd
        }
        
        // Check if we have enough data (at least 3 days with data)
        let uniqueDays = Set(moodEntries.map { calendar.startOfDay(for: $0.date) })
        let hasEnoughData = uniqueDays.count >= 3
        
        guard hasEnoughData else {
            return WeeklyRecap(
                weekStartDate: weekStart,
                weekEndDate: weekEnd,
                hasEnoughData: false
            )
        }
        
        // Calculate average mood
        let averageMood = moodEntries.isEmpty ? 0.0 : 
            Double(moodEntries.map { $0.mood }.reduce(0, +)) / Double(moodEntries.count)
        
        // Calculate mood trend (compare with previous week)
        let moodTrend = calculateMoodTrend(currentWeekMoods: moodEntries, weekStart: weekStart)
        
        // Get top tags
        let topTags = getTopTags(from: moodEntries)
        
        // Generate insights
        let insights = generateInsights(
            averageMood: averageMood,
            moodTrend: moodTrend,
            topTags: topTags,
            totalCheckins: moodEntries.count,
            totalMessages: chatMessages.count
        )
        
        return WeeklyRecap(
            weekStartDate: weekStart,
            weekEndDate: weekEnd,
            averageMood: averageMood,
            moodTrend: moodTrend,
            topTags: topTags,
            totalCheckins: moodEntries.count,
            totalMessages: chatMessages.count,
            insights: insights,
            hasEnoughData: true
        )
    }
    
    private func calculateMoodTrend(currentWeekMoods: [MoodEntry], weekStart: Date) -> MoodTrend {
        let calendar = Calendar.current
        
        // Get previous week's moods
        let previousWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart) ?? weekStart
        let previousWeekEnd = calendar.date(byAdding: .day, value: 6, to: previousWeekStart) ?? weekStart
        
        let previousWeekMoods = localStore.moodEntries.filter { entry in
            entry.date >= previousWeekStart && entry.date <= previousWeekEnd
        }
        
        let currentWeekAverage = currentWeekMoods.isEmpty ? 0.0 : 
            Double(currentWeekMoods.map { $0.mood }.reduce(0, +)) / Double(currentWeekMoods.count)
        
        let previousWeekAverage = previousWeekMoods.isEmpty ? 0.0 : 
            Double(previousWeekMoods.map { $0.mood }.reduce(0, +)) / Double(previousWeekMoods.count)
        
        let difference = currentWeekAverage - previousWeekAverage
        
        if difference > 0.3 {
            return .up
        } else if difference < -0.3 {
            return .down
        } else {
            return .stable
        }
    }
    
    private func getTopTags(from moodEntries: [MoodEntry]) -> [TagFrequency] {
        var tagCounts: [String: Int] = [:]
        
        for entry in moodEntries {
            for tag in entry.tags {
                tagCounts[tag.name, default: 0] += 1
            }
        }
        
        let totalTags = tagCounts.values.reduce(0, +)
        
        return tagCounts.map { (tag, count) in
            TagFrequency(
                tag: tag,
                frequency: count,
                percentage: totalTags > 0 ? Double(count) / Double(totalTags) * 100 : 0
            )
        }
        .sorted { $0.frequency > $1.frequency }
        .prefix(3)
        .map { $0 }
    }
    
    private func generateInsights(
        averageMood: Double,
        moodTrend: MoodTrend,
        topTags: [TagFrequency],
        totalCheckins: Int,
        totalMessages: Int
    ) -> [String] {
        var insights: [String] = []
        
        // Mood-based insights
        if averageMood >= 4.0 {
            insights.append("You've been feeling great this week! 🌟")
        } else if averageMood >= 3.0 {
            insights.append("You're maintaining a positive outlook 💚")
        } else if averageMood >= 2.0 {
            insights.append("You're working through some challenges 💪")
        } else {
            insights.append("You're being so strong during a tough time 💙")
        }
        
        // Trend-based insights
        switch moodTrend {
        case .up:
            insights.append("Your mood is trending upward - keep it up! 📈")
        case .down:
            insights.append("It's okay to have ups and downs - you're still growing 🌱")
        case .stable:
            insights.append("You're maintaining emotional balance ⚖️")
        }
        
        // Activity-based insights
        if totalCheckins >= 5 {
            insights.append("Amazing consistency with \(totalCheckins) check-ins! 🎯")
        } else if totalCheckins >= 3 {
            insights.append("Great job checking in \(totalCheckins) times this week! ✨")
        }
        
        if totalMessages >= 20 {
            insights.append("You've had \(totalMessages) meaningful conversations 💬")
        }
        
        // Tag-based insights
        if let topTag = topTags.first {
            insights.append("'\(topTag.tag)' was your main focus this week 🏷️")
        }
        
        return insights
    }
}
