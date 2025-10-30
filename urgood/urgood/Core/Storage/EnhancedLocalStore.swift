import Foundation
import CoreData
import UIKit

class EnhancedLocalStore: LocalStore {
    static let shared = EnhancedLocalStore()
    
    private let coreDataStack: CoreDataStack
    private let userDefaults = UserDefaults.standard
    
    // Development mode - set to true to bypass onboarding flows
    private let developmentMode = DevelopmentConfig.bypassOnboarding
    
    // Memory management
    private let maxMessagesInMemory = 200
    private let messagePageSize = 50
    private var isLoadingMessages = false
    private var hasMoreMessages = true
    
    // Performance monitoring
    private var lastMemoryWarning: Date?
    private let memoryWarningCooldown: TimeInterval = 30.0
    
    private override init() {
        self.coreDataStack = CoreDataStack.shared
        
        super.init()
        
        loadData()
        setupMemoryWarningObserver()
        
        if developmentMode {
            // Bypass onboarding flows in development mode
            self.hasCompletedOnboarding = true
            self.hasCompletedFirstRun = true
            print("🔧 Development mode: Onboarding flows bypassed")
        }
    }
    
    // MARK: - Chat Messages
    
    override func addMessage(_ message: ChatMessage) {
        // Add to Core Data
        let coreDataMessage = ChatMessageEntity(context: coreDataStack.viewContext)
        coreDataMessage.id = message.id
        coreDataMessage.role = message.role.rawValue
        coreDataMessage.text = message.text
        coreDataMessage.timestamp = message.date
        coreDataMessage.isFromUser = message.role == .user
        
        // Update local array
        chatMessages.append(message)
        
        // Memory management - keep only recent messages in memory
        if chatMessages.count > maxMessagesInMemory {
            let excessCount = chatMessages.count - maxMessagesInMemory
            chatMessages.removeFirst(excessCount)
            print("🧹 Trimmed \(excessCount) old messages from memory")
        }
        
        // Update user stats
        if message.role == .user {
            user.messagesThisWeek += 1
        }
        updateUser()
        
        // Save to Core Data
        coreDataStack.save()
        
        print("✅ Message saved to Core Data")
    }
    
    override func addChatMessage(_ message: ChatMessage) {
        addMessage(message)
    }
    
    private func loadChatMessages() {
        let request: NSFetchRequest<ChatMessageEntity> = ChatMessageEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ChatMessageEntity.timestamp, ascending: false)]
        request.fetchLimit = maxMessagesInMemory // Only load recent messages
        
        do {
            let coreDataMessages = try coreDataStack.viewContext.fetch(request)
            chatMessages = coreDataMessages.reversed().compactMap { entity in
                guard entity.id != nil,
                      let roleString = entity.role,
                      let role = Role(rawValue: roleString),
                      let text = entity.text,
                      entity.timestamp != nil else {
                    return ChatMessage(role: .user, text: "")
                }
                
                return ChatMessage(role: role, text: text)
            }
            
            hasMoreMessages = coreDataMessages.count == maxMessagesInMemory
            print("📱 Loaded \(chatMessages.count) recent messages into memory")
        } catch {
            print("❌ Failed to load chat messages: \(error)")
            chatMessages = []
        }
    }
    
    func loadMoreMessages() async {
        guard !isLoadingMessages && hasMoreMessages else { return }
        
        isLoadingMessages = true
        defer { isLoadingMessages = false }
        
        do {
            let additionalMessages = try await coreDataStack.performBackgroundTask { context in
                let request: NSFetchRequest<ChatMessageEntity> = ChatMessageEntity.fetchRequest()
                request.sortDescriptors = [NSSortDescriptor(keyPath: \ChatMessageEntity.timestamp, ascending: false)]
                request.fetchOffset = self.chatMessages.count
                request.fetchLimit = self.messagePageSize
                
                let entities = try context.fetch(request)
                return entities.compactMap { entity in
                    guard entity.id != nil,
                          let roleString = entity.role,
                          let role = Role(rawValue: roleString),
                          let text = entity.text,
                          entity.timestamp != nil else {
                        return ChatMessage(role: .user, text: "")
                    }
                    
                    return ChatMessage(role: role, text: text)
                }
            }
            
            // Update UI on main thread
            Task { @MainActor in
                self.chatMessages.insert(contentsOf: additionalMessages.reversed(), at: 0)
                self.hasMoreMessages = additionalMessages.count == self.messagePageSize
                print("📱 Loaded \(additionalMessages.count) additional messages")
            }
        } catch {
            print("❌ Failed to load more messages: \(error)")
        }
    }
    
    // MARK: - Mood Entries
    
    override func addMoodEntry(_ entry: MoodEntry) {
        // Add to Core Data
        let coreDataEntry = MoodEntryEntity(context: coreDataStack.viewContext)
        coreDataEntry.id = entry.id
        coreDataEntry.mood = Int16(entry.mood)
        coreDataEntry.timestamp = entry.date
        coreDataEntry.tags = entry.tags.map { $0.name }.joined(separator: ",")
        coreDataEntry.notes = "" // MoodEntry doesn't have a description field
        
        // Update local array
        moodEntries.append(entry)
        
        // Update user stats
        user.totalCheckins += 1
        updateStreak()
        updateUser()
        
        // Save to Core Data
        coreDataStack.save()
        
        print("✅ Mood entry saved to Core Data")
    }
    
    private func loadMoodEntries() {
        let request: NSFetchRequest<MoodEntryEntity> = MoodEntryEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MoodEntryEntity.timestamp, ascending: true)]
        
        do {
            let coreDataEntries = try coreDataStack.viewContext.fetch(request)
            moodEntries = coreDataEntries.compactMap { entity in
                guard entity.id != nil,
                      entity.timestamp != nil else {
                    return MoodEntry(mood: 5, tags: [])
                }
                
                let tagStrings = entity.tags?.components(separatedBy: ",").filter { !$0.isEmpty } ?? []
                let tags = tagStrings.map { MoodTag(name: $0) }
                
                return MoodEntry(mood: Int(entity.mood), tags: tags)
            }
        } catch {
            print("❌ Failed to load mood entries: \(error)")
            moodEntries = []
        }
    }
    
    // MARK: - User Management
    
    private func updateUser() {
        // Update Core Data user
        let request: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
        
        do {
            let users = try coreDataStack.viewContext.fetch(request)
            let coreDataUser: UserEntity
            
            if let existingUser = users.first {
                coreDataUser = existingUser
            } else {
                coreDataUser = UserEntity(context: coreDataStack.viewContext)
                coreDataUser.createdAt = Date()
            }
            
            coreDataUser.subscriptionStatus = user.subscriptionStatus.rawValue
            coreDataUser.streakCount = Int16(user.streakCount)
            coreDataUser.totalCheckins = Int16(user.totalCheckins)
            coreDataUser.messagesThisWeek = Int16(user.messagesThisWeek)
            coreDataUser.lastUpdated = Date()
            
            coreDataStack.save()
        } catch {
            print("❌ Failed to update user: \(error)")
        }
    }
    
    private func loadUser() {
        let request: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
        
        do {
            let users = try coreDataStack.viewContext.fetch(request)
            if let coreDataUser = users.first {
                user.subscriptionStatus = SubscriptionStatus(rawValue: coreDataUser.subscriptionStatus ?? "free") ?? .free
                user.streakCount = Int(coreDataUser.streakCount)
                user.totalCheckins = Int(coreDataUser.totalCheckins)
                user.messagesThisWeek = Int(coreDataUser.messagesThisWeek)
            }
        } catch {
            print("❌ Failed to load user: \(error)")
        }
    }
    
    // MARK: - Streak Management
    
    private func updateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Get all mood entries sorted by date
        let sortedEntries = moodEntries.sorted { $0.date < $1.date }
        
        var streak = 0
        var currentDate = today
        
        // Count consecutive days with mood entries
        for entry in sortedEntries.reversed() {
            let entryDate = calendar.startOfDay(for: entry.date)
            
            if calendar.isDate(entryDate, inSameDayAs: currentDate) {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else if entryDate < currentDate {
                break
            }
        }
        
        user.streakCount = streak
    }
    
    // MARK: - Daily Message Count
    
    override func getDailyMessageCount() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return chatMessages.filter { message in
            message.role == .user && calendar.isDate(message.date, inSameDayAs: today)
        }.count
    }
    
    override func resetDailyMessageCount() {
        // This would typically be called at midnight or when starting a new day
        // For now, we'll just update the last message date
        userDefaults.set(Date(), forKey: "lastMessageDate")
    }
    
    // MARK: - Data Loading
    
    private func loadData() {
        loadUser()
        loadChatMessages()
        loadMoodEntries()
        
        // Load onboarding status from UserDefaults (not migrated to Core Data)
        hasCompletedOnboarding = userDefaults.bool(forKey: "hasCompletedOnboarding")
        hasCompletedFirstRun = userDefaults.bool(forKey: "hasCompletedFirstRun")
    }
    
    // MARK: - Data Clearing
    
    override func clearAllData() {
        // Clear Core Data
        let entities = ["ChatMessageEntity", "MoodEntryEntity", "UserEntity", "SessionEntity", "CrisisEventEntity"]
        
        for entityName in entities {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            
            do {
                try coreDataStack.viewContext.execute(deleteRequest)
            } catch {
                print("❌ Failed to clear \(entityName): \(error)")
            }
        }
        
        // Clear UserDefaults
        userDefaults.removeObject(forKey: "hasCompletedOnboarding")
        userDefaults.removeObject(forKey: "hasCompletedFirstRun")
        userDefaults.removeObject(forKey: "lastMessageDate")
        
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
        
        coreDataStack.save()
        print("🧹 All data cleared - ready for fresh demo")
    }
    
    // MARK: - Data Export
    
    func exportAllData() -> [String: Any] {
        return coreDataStack.exportData()
    }
    
    // MARK: - Data Backup
    
    func createBackup() -> URL? {
        return coreDataStack.createBackup()
    }
    
    func restoreBackup(from url: URL) -> Bool {
        let success = coreDataStack.restoreBackup(from: url)
        if success {
            loadData() // Reload data after restore
        }
        return success
    }
    
    // MARK: - Analytics Data
    
    func getAnalyticsData() -> [String: Any] {
        var analytics: [String: Any] = [:]
        
        // Message analytics
        analytics["totalMessages"] = chatMessages.count
        analytics["messagesThisWeek"] = user.messagesThisWeek
        analytics["dailyMessageCount"] = getDailyMessageCount()
        
        // Mood analytics
        analytics["totalCheckins"] = user.totalCheckins
        analytics["currentStreak"] = user.streakCount
        analytics["moodEntriesCount"] = moodEntries.count
        
        // User analytics
        analytics["subscriptionStatus"] = user.subscriptionStatus.rawValue
        analytics["hasCompletedOnboarding"] = hasCompletedOnboarding
        analytics["hasCompletedFirstRun"] = hasCompletedFirstRun
        
        // Recent activity
        let lastMessage = chatMessages.last
        analytics["lastMessageTime"] = lastMessage?.date.timeIntervalSince1970
        analytics["lastMoodEntryTime"] = moodEntries.last?.date.timeIntervalSince1970
        
        return analytics
    }
    
    // MARK: - Memory Management
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    private func handleMemoryWarning() {
        let now = Date()
        
        // Throttle memory warning handling
        if let lastWarning = lastMemoryWarning,
           now.timeIntervalSince(lastWarning) < memoryWarningCooldown {
            return
        }
        
        lastMemoryWarning = now
        print("⚠️ Memory warning received - cleaning up...")
        
        // Clear excess messages from memory
        if chatMessages.count > messagePageSize {
            let excessCount = chatMessages.count - messagePageSize
            chatMessages.removeFirst(excessCount)
            print("🧹 Removed \(excessCount) old messages from memory")
        }
        
        // Clear Core Data memory cache
        coreDataStack.clearMemoryCache()
        
        // Force garbage collection
        DispatchQueue.global(qos: .utility).async {
            autoreleasepool {
                // Trigger memory cleanup
                self.coreDataStack.refreshAllObjects()
            }
        }
    }
    
    func performMemoryCleanup() {
        print("🧹 Performing manual memory cleanup...")
        
        // Keep only recent messages in memory
        if chatMessages.count > maxMessagesInMemory {
            let excessCount = chatMessages.count - maxMessagesInMemory
            chatMessages.removeFirst(excessCount)
            print("🧹 Trimmed \(excessCount) messages from memory")
        }
        
        // Clear Core Data caches
        coreDataStack.clearMemoryCache()
        coreDataStack.refreshAllObjects()
        
        // Log performance stats
        coreDataStack.logPerformanceStats()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
