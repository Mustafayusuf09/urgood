import Foundation

class LocalStore: ObservableObject {
    @Published var chatMessages: [ChatMessage] = []
    @Published var moodEntries: [MoodEntry] = []
    @Published var user: User
    @Published var hasCompletedOnboarding: Bool = false
    @Published var hasCompletedFirstRun: Bool = false
    
    // Development mode - set to true to bypass onboarding flows
    private let developmentMode = DevelopmentConfig.bypassOnboarding
    
    private let userDefaults = UserDefaults.standard
    private let chatMessagesKey = "chatMessages"
    private let moodEntriesKey = "moodEntries"
    private let userKey = "user"
    private let lastMessageDateKey = "lastMessageDate"
    private let hasCompletedOnboardingKey = "hasCompletedOnboarding"
    private let hasCompletedFirstRunKey = "hasCompletedFirstRun"
    
    init() {
        self.user = User()
        loadData()
        
        if developmentMode {
            // Bypass onboarding flows in development mode
            self.hasCompletedOnboarding = true
            self.hasCompletedFirstRun = true
            print("🔧 Development mode: Onboarding flows bypassed")
        }
    }
    
    // MARK: - Chat Messages
    
    func addMessage(_ message: ChatMessage) {
        chatMessages.append(message)
        saveChatMessages()
        updateLastMessageDate()
        if message.role == .user {
            user.messagesThisWeek += 1
        }
        saveUser()
    }
    
    func addChatMessage(_ message: ChatMessage) {
        addMessage(message)
    }
    
    private func saveChatMessages() {
        if let encoded = try? JSONEncoder().encode(chatMessages) {
            userDefaults.set(encoded, forKey: chatMessagesKey)
        }
    }
    
    private func loadChatMessages() {
        if let data = userDefaults.data(forKey: chatMessagesKey),
           let decoded = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            chatMessages = decoded
        }
    }
    

    
    // MARK: - Daily Message Count
    
    func getDailyMessageCount() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return chatMessages.filter { message in
            message.role == .user && calendar.isDate(message.date, inSameDayAs: today)
        }.count
    }
    
    func resetDailyMessageCount() {
        // This would typically be called at midnight or when starting a new day
        // For now, we'll just update the last message date
        updateLastMessageDate()
    }
    
    private func updateLastMessageDate() {
        userDefaults.set(Date(), forKey: lastMessageDateKey)
    }
    
    // MARK: - Mood Entries (Checkins)
    
    func addMoodEntry(_ entry: MoodEntry) {
        moodEntries.append(entry)
        user.totalCheckins += 1
        updateStreak()
        saveMoodEntries()
        saveUser()
    }
    
    private func saveMoodEntries() {
        if let encoded = try? JSONEncoder().encode(moodEntries) {
            userDefaults.set(encoded, forKey: moodEntriesKey)
        }
    }
    
    private func loadMoodEntries() {
        if let data = userDefaults.data(forKey: moodEntriesKey),
           let decoded = try? JSONDecoder().decode([MoodEntry].self, from: data) {
            moodEntries = decoded
        }
    }
    
    // MARK: - User Management
    
    private func saveUser() {
        if let encoded = try? JSONEncoder().encode(user) {
            userDefaults.set(encoded, forKey: userKey)
        }
    }
    
    private func loadUser() {
        if let data = userDefaults.data(forKey: userKey),
           let decoded = try? JSONDecoder().decode(User.self, from: data) {
            user = decoded
        }
    }
    
    // MARK: - Streak Management
    
    private func updateStreak() {
        let calendar = Calendar.current
        let today = Date()
        
        var streak = 0
        var currentDate = today
        
        while true {
            let hasEntryForDate = moodEntries.contains { entry in
                calendar.isDate(entry.date, inSameDayAs: currentDate)
            }
            
            if hasEntryForDate {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else {
                break
            }
        }
        
        user.streakCount = streak
    }
    
    // MARK: - Onboarding State
    
    func markOnboardingComplete() {
        hasCompletedOnboarding = true
        userDefaults.set(true, forKey: hasCompletedOnboardingKey)
    }
    
    func markFirstRunComplete() {
        hasCompletedFirstRun = true
        userDefaults.set(true, forKey: hasCompletedFirstRunKey)
    }
    
    private func loadOnboardingState() {
        hasCompletedOnboarding = userDefaults.bool(forKey: hasCompletedOnboardingKey)
    }
    
    private func loadFirstRunState() {
        hasCompletedFirstRun = userDefaults.bool(forKey: hasCompletedFirstRunKey)
    }
    
    // MARK: - Data Loading
    
    private func loadData() {
        loadChatMessages()
        loadMoodEntries()
        loadUser()
        loadOnboardingState()
        loadFirstRunState()
    }
    
    // MARK: - Data Clearing (for demo purposes)
    
    func clearAllData() {
        // Clear all stored data
        userDefaults.removeObject(forKey: chatMessagesKey)
        userDefaults.removeObject(forKey: moodEntriesKey)
        userDefaults.removeObject(forKey: userKey)
        userDefaults.removeObject(forKey: lastMessageDateKey)
        userDefaults.removeObject(forKey: hasCompletedOnboardingKey)
        userDefaults.removeObject(forKey: hasCompletedFirstRunKey)
        
        // Reset to initial state
        chatMessages = []
        moodEntries = []
        user = User()
        hasCompletedOnboarding = false
        hasCompletedFirstRun = false
        
        // Apply development mode settings if enabled
        if developmentMode {
            hasCompletedOnboarding = true
            hasCompletedFirstRun = true
            print("🔧 Development mode: Onboarding flows bypassed after data clear")
        }
        
        print("🧹 All user data cleared - ready for fresh demo")
    }
}
