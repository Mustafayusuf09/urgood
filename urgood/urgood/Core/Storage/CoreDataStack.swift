import Foundation
import CoreData

class CoreDataStack: ObservableObject {
    static let shared = CoreDataStack()
    
    // MARK: - Core Data Stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "UrGoodModel")
        
        // Performance optimizations
        if let storeDescription = container.persistentStoreDescriptions.first {
            // Enable CloudKit if needed (optional)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            
            // Performance optimizations
            storeDescription.setOption("WAL" as NSString, forKey: "journal_mode")
            storeDescription.setOption("1" as NSString, forKey: "synchronous")
            storeDescription.setOption("10000" as NSString, forKey: "cache_size")
            storeDescription.setOption("MEMORY" as NSString, forKey: "temp_store")
            
            // Enable automatic lightweight migration
            storeDescription.shouldMigrateStoreAutomatically = true
            storeDescription.shouldInferMappingModelAutomatically = true
        }
        
        container.loadPersistentStores { [weak self] _, error in
            if let error = error as NSError? {
                print("❌ Core Data error: \(error), \(error.userInfo)")
                // Try to recover by deleting and recreating the store
                self?.handleCoreDataError(error)
            }
        }
        
        // Performance optimizations for view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.undoManager = nil // Disable undo for better performance
        
        return container
    }()
    
    // MARK: - Core Data Contexts
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    var backgroundContext: NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.undoManager = nil
        return context
    }
    
    // MARK: - Performance Optimized Contexts
    
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            persistentContainer.performBackgroundTask { context in
                context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
                context.undoManager = nil
                
                do {
                    let result = try block(context)
                    if context.hasChanges {
                        try context.save()
                    }
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func batchInsert(
        entityName: String,
        objects: [[String: Any]],
        batchSize: Int = 1000
    ) async throws {
        try await performBackgroundTask { context in
            let batches = objects.chunked(into: batchSize)
            
            for batch in batches {
                let batchInsertRequest = NSBatchInsertRequest(entityName: entityName, objects: batch)
                batchInsertRequest.resultType = .statusOnly
                
                try context.execute(batchInsertRequest)
            }
        }
    }
    
    func batchDelete<T: NSManagedObject>(
        entity: T.Type,
        predicate: NSPredicate? = nil
    ) async throws {
        try await performBackgroundTask { context in
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: entity))
            if let predicate = predicate {
                fetchRequest.predicate = predicate
            }
            
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            batchDeleteRequest.resultType = .resultTypeStatusOnly
            
            try context.execute(batchDeleteRequest)
        }
    }
    
    // MARK: - Core Data Operations
    
    func save() {
        let context = persistentContainer.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
                print("✅ Core Data saved successfully")
            } catch {
                print("❌ Core Data save error: \(error)")
            }
        }
    }
    
    func saveBackground() {
        let context = backgroundContext
        
        if context.hasChanges {
            do {
                try context.save()
                print("✅ Core Data background save successful")
            } catch {
                print("❌ Core Data background save error: \(error)")
            }
        }
    }
    
    // MARK: - Data Migration
    
    func migrateData() {
        // Migrate existing UserDefaults data to Core Data
        migrateUserDefaultsToCoreData()
    }
    
    private func migrateUserDefaultsToCoreData() {
        let userDefaults = UserDefaults.standard
        
        // Migrate chat messages
        if let chatData = userDefaults.data(forKey: "chatMessages"),
           let chatMessages = try? JSONDecoder().decode([ChatMessage].self, from: chatData) {
            
            for message in chatMessages {
                let coreDataMessage = ChatMessageEntity(context: viewContext)
                coreDataMessage.id = message.id
                coreDataMessage.role = message.role.rawValue
                coreDataMessage.text = message.text
                coreDataMessage.timestamp = message.date
                coreDataMessage.isFromUser = message.role == .user
            }
        }
        
        // Migrate mood entries
        if let moodData = userDefaults.data(forKey: "moodEntries"),
           let moodEntries = try? JSONDecoder().decode([MoodEntry].self, from: moodData) {
            
            for entry in moodEntries {
                let coreDataEntry = MoodEntryEntity(context: viewContext)
                coreDataEntry.id = entry.id
                coreDataEntry.mood = Int16(entry.mood)
                coreDataEntry.timestamp = entry.date
                coreDataEntry.tags = entry.tags.map { $0.name }.joined(separator: ",")
                coreDataEntry.notes = "" // MoodEntry doesn't have a description field
            }
        }
        
        // Migrate user data
        if let userData = userDefaults.data(forKey: "user"),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            
            let coreDataUser = UserEntity(context: viewContext)
            coreDataUser.subscriptionStatus = user.subscriptionStatus.rawValue
            coreDataUser.streakCount = Int16(user.streakCount)
            coreDataUser.totalCheckins = Int16(user.totalCheckins)
            coreDataUser.messagesThisWeek = Int16(user.messagesThisWeek)
            coreDataUser.createdAt = Date()
            coreDataUser.lastUpdated = Date()
        }
        
        save()
        print("✅ Data migration completed")
    }
    
    // MARK: - Data Backup
    
    func createBackup() -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let backupURL = documentsPath.appendingPathComponent("UrGoodBackup_\(Date().timeIntervalSince1970).sqlite")
        
        do {
            let storeURL = persistentContainer.persistentStoreDescriptions.first?.url
            if let storeURL = storeURL {
                try FileManager.default.copyItem(at: storeURL, to: backupURL)
                print("✅ Backup created at: \(backupURL)")
                return backupURL
            }
        } catch {
            print("❌ Backup failed: \(error)")
        }
        
        return nil
    }
    
    func restoreBackup(from url: URL) -> Bool {
        do {
            let storeURL = persistentContainer.persistentStoreDescriptions.first?.url
            if let storeURL = storeURL {
                try FileManager.default.removeItem(at: storeURL)
                try FileManager.default.copyItem(at: url, to: storeURL)
                print("✅ Backup restored from: \(url)")
                return true
            }
        } catch {
            print("❌ Restore failed: \(error)")
        }
        
        return false
    }
    
    // MARK: - Data Export
    
    func exportData() -> [String: Any] {
        var exportData: [String: Any] = [:]
        
        // Export chat messages
        let chatRequest: NSFetchRequest<ChatMessageEntity> = ChatMessageEntity.fetchRequest()
        chatRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ChatMessageEntity.timestamp, ascending: true)]
        
        if let chatMessages = try? viewContext.fetch(chatRequest) {
            exportData["chatMessages"] = chatMessages.map { message in
                [
                    "id": message.id?.uuidString ?? "" as Any,
                    "role": message.role ?? "",
                    "text": message.text ?? "",
                    "timestamp": (message.timestamp?.timeIntervalSince1970 ?? 0) as Any,
                    "isFromUser": message.isFromUser
                ]
            }
        }
        
        // Export mood entries
        let moodRequest: NSFetchRequest<MoodEntryEntity> = MoodEntryEntity.fetchRequest()
        moodRequest.sortDescriptors = [NSSortDescriptor(keyPath: \MoodEntryEntity.timestamp, ascending: true)]
        
        if let moodEntries = try? viewContext.fetch(moodRequest) {
            exportData["moodEntries"] = moodEntries.map { entry in
                [
                    "id": entry.id?.uuidString ?? "",
                    "mood": entry.mood,
                    "timestamp": entry.timestamp?.timeIntervalSince1970 ?? 0,
                    "tags": entry.tags?.components(separatedBy: ",") ?? [],
                    "notes": entry.notes ?? ""
                ]
            }
        }
        
        // Export user data
        let userRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
        if let user = try? viewContext.fetch(userRequest).first {
            exportData["user"] = [
                "subscriptionStatus": user.subscriptionStatus ?? "",
                "streakCount": user.streakCount,
                "totalCheckins": user.totalCheckins,
                "messagesThisWeek": user.messagesThisWeek,
                "createdAt": user.createdAt?.timeIntervalSince1970 ?? 0,
                "lastUpdated": user.lastUpdated?.timeIntervalSince1970 ?? 0
            ]
        }
        
        return exportData
    }
    
    // MARK: - Error Handling & Recovery
    
    private func handleCoreDataError(_ error: NSError) {
        print("🚨 Core Data error occurred: \(error)")
        
        // Check if it's a migration error
        if error.code == NSPersistentStoreIncompatibleVersionHashError ||
           error.code == NSMigrationMissingSourceModelError {
            print("🔄 Attempting to recover from migration error...")
            recreateStore()
        }
        
        // Check for corruption
        if error.code == NSSQLiteError {
            print("🔄 Attempting to recover from corruption...")
            recreateStore()
        }
    }
    
    private func recreateStore() {
        guard let storeURL = persistentContainer.persistentStoreDescriptions.first?.url else {
            print("❌ Could not find store URL")
            return
        }
        
        do {
            // Create backup before deleting
            let backupURL = storeURL.appendingPathExtension("backup")
            if FileManager.default.fileExists(atPath: storeURL.path) {
                try FileManager.default.copyItem(at: storeURL, to: backupURL)
                print("📦 Created backup at: \(backupURL)")
            }
            
            // Remove corrupted store files
            if FileManager.default.fileExists(atPath: storeURL.path) {
                try FileManager.default.removeItem(at: storeURL)
            }
            let walURL = storeURL.appendingPathExtension("wal")
            if FileManager.default.fileExists(atPath: walURL.path) {
                try FileManager.default.removeItem(at: walURL)
            }
            let shmURL = storeURL.appendingPathExtension("shm")
            if FileManager.default.fileExists(atPath: shmURL.path) {
                try FileManager.default.removeItem(at: shmURL)
            }
            
            print("✅ Store recreated successfully")
        } catch {
            print("❌ Failed to recreate store: \(error)")
        }
    }
    
    // MARK: - Memory Management
    
    func refreshAllObjects() {
        viewContext.refreshAllObjects()
        print("🔄 Refreshed all Core Data objects")
    }
    
    func clearMemoryCache() {
        viewContext.reset()
        print("🧹 Cleared Core Data memory cache")
    }
    
    // MARK: - Performance Monitoring
    
    func logPerformanceStats() {
        let registeredObjects = viewContext.registeredObjects.count
        let insertedObjects = viewContext.insertedObjects.count
        let updatedObjects = viewContext.updatedObjects.count
        let deletedObjects = viewContext.deletedObjects.count
        
        print("""
        📊 Core Data Performance Stats:
        - Registered Objects: \(registeredObjects)
        - Inserted Objects: \(insertedObjects)
        - Updated Objects: \(updatedObjects)
        - Deleted Objects: \(deletedObjects)
        - Has Changes: \(viewContext.hasChanges)
        """)
    }
}

// MARK: - Array Extension for Chunking

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
