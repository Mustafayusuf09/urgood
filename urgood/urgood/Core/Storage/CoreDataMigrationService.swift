import Foundation
import CoreData

class CoreDataMigrationService {
    static let shared = CoreDataMigrationService()
    
    private init() {}
    
    // MARK: - Migration Status
    
    func hasMigratedToCoreData() -> Bool {
        return UserDefaults.standard.bool(forKey: "hasMigratedToCoreData")
    }
    
    func markMigrationComplete() {
        UserDefaults.standard.set(true, forKey: "hasMigratedToCoreData")
        print("✅ Migration marked as complete")
    }
    
    // MARK: - Migration Process
    
    func migrateIfNeeded() {
        guard !hasMigratedToCoreData() else {
            print("✅ Data already migrated to Core Data")
            return
        }
        
        print("🔄 Starting migration from UserDefaults to Core Data...")
        
        let coreDataStack = CoreDataStack.shared
        
        // Migrate chat messages
        migrateChatMessages(to: coreDataStack)
        
        // Migrate mood entries
        migrateMoodEntries(to: coreDataStack)
        
        // Migrate user data
        migrateUserData(to: coreDataStack)
        
        // Save all changes
        coreDataStack.save()
        
        // Mark migration as complete
        markMigrationComplete()
        
        print("✅ Migration completed successfully")
    }
    
    // MARK: - Individual Migration Methods
    
    private func migrateChatMessages(to coreDataStack: CoreDataStack) {
        let userDefaults = UserDefaults.standard
        
        guard let chatData = userDefaults.data(forKey: "chatMessages"),
              let chatMessages = try? JSONDecoder().decode([ChatMessage].self, from: chatData) else {
            print("ℹ️ No chat messages to migrate")
            return
        }
        
        print("🔄 Migrating \(chatMessages.count) chat messages...")
        
        for message in chatMessages {
            let coreDataMessage = ChatMessageEntity(context: coreDataStack.viewContext)
            coreDataMessage.id = message.id
            coreDataMessage.role = message.role.rawValue
            coreDataMessage.text = message.text
            coreDataMessage.timestamp = message.date
            coreDataMessage.isFromUser = message.role == .user
        }
        
        print("✅ Chat messages migrated")
    }
    
    private func migrateMoodEntries(to coreDataStack: CoreDataStack) {
        let userDefaults = UserDefaults.standard
        
        guard let moodData = userDefaults.data(forKey: "moodEntries"),
              let moodEntries = try? JSONDecoder().decode([MoodEntry].self, from: moodData) else {
            print("ℹ️ No mood entries to migrate")
            return
        }
        
        print("🔄 Migrating \(moodEntries.count) mood entries...")
        
        for entry in moodEntries {
            let coreDataEntry = MoodEntryEntity(context: coreDataStack.viewContext)
            coreDataEntry.id = entry.id
            coreDataEntry.mood = Int16(entry.mood)
            coreDataEntry.timestamp = entry.date
            coreDataEntry.tags = entry.tags.map { $0.name }.joined(separator: ",")
            coreDataEntry.notes = "" // MoodEntry doesn't have a description field
        }
        
        print("✅ Mood entries migrated")
    }
    
    private func migrateUserData(to coreDataStack: CoreDataStack) {
        let userDefaults = UserDefaults.standard
        
        guard let userData = userDefaults.data(forKey: "user"),
              let user = try? JSONDecoder().decode(User.self, from: userData) else {
            print("ℹ️ No user data to migrate")
            return
        }
        
        print("🔄 Migrating user data...")
        
        let coreDataUser = UserEntity(context: coreDataStack.viewContext)
        coreDataUser.subscriptionStatus = user.subscriptionStatus.rawValue
        coreDataUser.streakCount = Int16(user.streakCount)
        coreDataUser.totalCheckins = Int16(user.totalCheckins)
        coreDataUser.messagesThisWeek = Int16(user.messagesThisWeek)
        coreDataUser.createdAt = Date()
        coreDataUser.lastUpdated = Date()
        
        print("✅ User data migrated")
    }
    
    // MARK: - Cleanup Old Data
    
    func cleanupOldUserDefaultsData() {
        guard hasMigratedToCoreData() else {
            print("⚠️ Migration not complete - skipping cleanup")
            return
        }
        
        print("🧹 Cleaning up old UserDefaults data...")
        
        let userDefaults = UserDefaults.standard
        let keysToRemove = [
            "chatMessages",
            "moodEntries", 
            "user",
            "lastMessageDate"
        ]
        
        for key in keysToRemove {
            userDefaults.removeObject(forKey: key)
        }
        
        print("✅ Old UserDefaults data cleaned up")
    }
    
    // MARK: - Verification
    
    func verifyMigration() -> Bool {
        let coreDataStack = CoreDataStack.shared
        
        // Check if we have data in Core Data
        let chatRequest: NSFetchRequest<ChatMessageEntity> = ChatMessageEntity.fetchRequest()
        let moodRequest: NSFetchRequest<MoodEntryEntity> = MoodEntryEntity.fetchRequest()
        let userRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
        
        do {
            let chatCount = try coreDataStack.viewContext.count(for: chatRequest)
            let moodCount = try coreDataStack.viewContext.count(for: moodRequest)
            let userCount = try coreDataStack.viewContext.count(for: userRequest)
            
            print("📊 Migration verification:")
            print("  Chat messages: \(chatCount)")
            print("  Mood entries: \(moodCount)")
            print("  User records: \(userCount)")
            
            return chatCount > 0 || moodCount > 0 || userCount > 0
        } catch {
            print("❌ Migration verification failed: \(error)")
            return false
        }
    }
    
    // MARK: - Rollback
    
    func rollbackMigration() {
        print("🔄 Rolling back migration...")
        
        // Clear Core Data
        let entities = ["ChatMessageEntity", "MoodEntryEntity", "UserEntity"]
        
        for entityName in entities {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            
            do {
                try CoreDataStack.shared.viewContext.execute(deleteRequest)
            } catch {
                print("❌ Failed to rollback \(entityName): \(error)")
            }
        }
        
        // Reset migration flag
        UserDefaults.standard.removeObject(forKey: "hasMigratedToCoreData")
        
        print("✅ Migration rolled back")
    }
}
