import Foundation
import SwiftUI

@MainActor
class StreaksViewModel: ObservableObject {
    @Published var user: User
    @Published var showPaywall = false
    
    private let localStore: LocalStore
    let billingService: any BillingServiceProtocol
    private let authService: any AuthServiceProtocol
    
    init(localStore: LocalStore, billingService: any BillingServiceProtocol, authService: any AuthServiceProtocol) {
        self.localStore = localStore
        self.billingService = billingService
        self.authService = authService
        self.user = localStore.user
    }
    
    var currentStreak: Int {
        user.streakCount
    }
    
    var totalCheckins: Int {
        user.totalCheckins
    }
    
    
    var messagesThisWeek: Int {
        user.messagesThisWeek
    }
    
    var totalSessions: Int {
        // Calculate total sessions from chat messages
        let messages = localStore.chatMessages
        let uniqueSessions = Set(messages.map { $0.id })
        return uniqueSessions.count
    }
    
    var weeklyMoodData: [ViewModelDailyMood] {
        // Get mood data for the last 7 days
        let moodEntries = localStore.moodEntries
        let calendar = Calendar.current
        let today = Date()
        
        var weeklyData: [ViewModelDailyMood] = []
        
        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -i, to: today) ?? today
            let dayMoods = moodEntries.filter { calendar.isDate($0.date, inSameDayAs: date) }
            
            if let firstMood = dayMoods.first {
                weeklyData.append(ViewModelDailyMood(
                    date: date,
                    mood: Double(firstMood.mood),
                    count: dayMoods.count
                ))
            } else {
                weeklyData.append(ViewModelDailyMood(
                    date: date,
                    mood: 0,
                    count: 0
                ))
            }
        }
        
        return weeklyData.reversed() // Return in chronological order
    }
    
    var recentSessions: [InsightsChatSession] {
        // Get recent chat sessions
        let messages = localStore.chatMessages
        let sessionGroups = Dictionary(grouping: messages) { $0.id }
        
        return sessionGroups.compactMap { (sessionId, messages) in
            guard let firstMessage = messages.first else { return nil }
            
            return InsightsChatSession(
                title: "Chat Session",
                preview: firstMessage.text,
                date: firstMessage.date,
                messageCount: messages.count,
                moodRating: 3.0, // Default mood rating
                insights: nil,
                breakthrough: nil,
                progressLevel: 1
            )
        }.sorted { ($0.date as Date) > ($1.date as Date) }
        .prefix(5)
        .map { $0 }
    }
    
    var subscriptionStatus: SubscriptionStatus {
        user.subscriptionStatus
    }
    
    var isPremium: Bool {
        subscriptionStatus == .premium
    }
    
    var streakMessage: String {
        if currentStreak == 0 {
            return "Day zero just means the streak is ready for you."
        } else if currentStreak == 1 {
            return "1 day in—you showed up and that’s major."
        } else if currentStreak < 7 {
            return "\(currentStreak) days in a row. That’s how habits get locked."
        } else if currentStreak < 30 {
            return "\(currentStreak) days! Your consistency is giving main character energy."
        } else {
            return "\(currentStreak) days. You built a legendary streak and it shows."
        }
    }
    
    var nextMilestone: String {
        let milestones = [1, 7, 30, 100, 365]
        let next = milestones.first { $0 > currentStreak } ?? 365
        
        if next == 1 {
            return "Tap in today to start earning streak energy"
        } else {
            return "Next badge unlocks at \(next) days"
        }
    }
    
    var progressToNextMilestone: Double {
        let milestones = [1, 7, 30, 100, 365]
        let next = milestones.first { $0 > currentStreak } ?? 365
        let previous = milestones.last { $0 <= currentStreak } ?? 0
        
        if next == previous {
            return 1.0
        }
        
        let range = next - previous
        let progress = currentStreak - previous
        return Double(progress) / Double(range)
    }
    
    func refreshStats() {
        user = localStore.user
    }
    
    func unlockPremium() {
        showPaywall = true
    }
    
    func dismissPaywall() {
        showPaywall = false
    }
    
    func toggleNotifications() {
        // In a real app, this would request notification permissions
        print("Toggle notifications")
    }
    
    func openDataPrivacy() {
        // In a real app, this would open a data privacy view
        print("Open data privacy")
    }
    
    func signOut() async {
        // Sign out the user using the authentication service
        try? await authService.signOut()
        print("User signed out successfully")
    }
}

#Preview {
    StreaksView(container: DIContainer.shared)
}
