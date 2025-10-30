import Foundation

class CheckinService: ObservableObject {
    private let localStore: EnhancedLocalStore
    private let notificationService: NotificationService
    
    init(localStore: EnhancedLocalStore, notificationService: NotificationService? = nil) {
        self.localStore = localStore
        self.notificationService = notificationService ?? NotificationService(localStore: localStore)
    }
    
    func saveMoodEntry(_ entry: MoodEntry) {
        localStore.addMoodEntry(entry)
        
        // Check if this is the user's first check-in and request notification permission
        if localStore.moodEntries.count == 1 {
            Task {
                let granted = await notificationService.requestPermission()
                if granted {
                    notificationService.scheduleSmartNotifications()
                }
            }
        } else {
            // Update notifications for existing users
            notificationService.scheduleSmartNotifications()
        }
        
        // Track mood check-in
        FirebaseConfig.logEvent("mood_checkin", parameters: [
            "mood_value": entry.mood,
            "tags_count": entry.tags.count,
            "streak_count": localStore.user.streakCount,
            "has_tags": !entry.tags.isEmpty
        ])
        
        // Set user properties for analytics
        FirebaseConfig.setUserProperty("\(entry.mood)", forName: "last_mood")
        FirebaseConfig.setUserProperty("\(localStore.user.streakCount)", forName: "current_streak")
    }
    
    func getRecentTrends(days: Int = 7) -> [TrendPoint] {
        let calendar = Calendar.current
        let today = Date()
        let _ = calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today
        
        var trends: [TrendPoint] = []
        
        for i in 0..<days {
            let date = calendar.date(byAdding: .day, value: -i, to: today) ?? today
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date
            
            let entriesForDay = localStore.moodEntries.filter { entry in
                entry.date >= dayStart && entry.date < dayEnd
            }
            
            let averageMood = entriesForDay.isEmpty ? 0.0 : Double(entriesForDay.map { $0.mood }.reduce(0, +)) / Double(entriesForDay.count)
            
            trends.append(TrendPoint(date: date, value: averageMood))
        }
        
        return trends.reversed()
    }
    
    func getCurrentStreak() -> Int {
        return localStore.user.streakCount
    }
    
    func hasCheckedInToday() -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return localStore.moodEntries.contains { entry in
            calendar.isDate(entry.date, inSameDayAs: today)
        }
    }
    
    func getAvailableTags() -> [MoodTag] {
        return [
            MoodTag(name: "Exams"),
            MoodTag(name: "Sleep"),
            MoodTag(name: "Friends"),
            MoodTag(name: "Work"),
            MoodTag(name: "Family"),
            MoodTag(name: "Health"),
            MoodTag(name: "Money"),
            MoodTag(name: "Social Media"),
            MoodTag(name: "Exercise"),
            MoodTag(name: "Creativity")
        ]
    }
}
