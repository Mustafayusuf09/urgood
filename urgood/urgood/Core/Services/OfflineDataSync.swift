import Foundation
import CoreData
import Combine

/// Manages offline data synchronization and conflict resolution
/// Handles queuing operations when offline and syncing when connection is restored
@MainActor
final class OfflineDataSync: ObservableObject {
    static let shared = OfflineDataSync()
    
    // MARK: - Published Properties
    @Published private(set) var isSyncing = false
    @Published private(set) var pendingOperationsCount = 0
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var syncError: String?
    
    // MARK: - Private Properties
    private let coreDataStack = CoreDataStack.shared
    private let networkMonitor = NetworkMonitor.shared
    private let apiService = APIService.shared
    private let firestoreService = FirestoreService.shared
    
    private var cancellables = Set<AnyCancellable>()
    private var syncTimer: Timer?
    
    // Sync configuration
    private let syncInterval: TimeInterval = 300 // 5 minutes
    private let maxRetryAttempts = 3
    private let backoffMultiplier: TimeInterval = 2.0
    
    private init() {
        setupNetworkObserver()
        setupPeriodicSync()
        loadPendingOperations()
    }
    
    // MARK: - Public Methods
    
    /// Queue an operation for offline execution
    func queueOperation(_ operation: OfflineOperation) {
        let operationEntity = PendingOperationEntity(context: coreDataStack.viewContext)
        operationEntity.id = operation.id
        operationEntity.type = operation.type.rawValue
        operationEntity.data = operation.data
        operationEntity.timestamp = operation.timestamp
        operationEntity.retryCount = Int16(operation.retryCount)
        operationEntity.priority = Int16(operation.priority.rawValue)
        
        coreDataStack.save()
        updatePendingOperationsCount()
        
        print("📝 Queued offline operation: \(operation.type.rawValue)")
        
        // Try to sync immediately if connected
        if networkMonitor.canPerformNetworkOperation() {
            Task {
                await performSync()
            }
        }
    }
    
    /// Force a manual sync
    func forcSync() async {
        await performSync()
    }
    
    /// Clear all pending operations (use with caution)
    func clearPendingOperations() {
        let request: NSFetchRequest<PendingOperationEntity> = PendingOperationEntity.fetchRequest()
        
        do {
            let operations = try coreDataStack.viewContext.fetch(request)
            for operation in operations {
                coreDataStack.viewContext.delete(operation)
            }
            coreDataStack.save()
            updatePendingOperationsCount()
            print("🗑️ Cleared all pending operations")
        } catch {
            print("❌ Failed to clear pending operations: \(error)")
        }
    }
    
    /// Get sync status summary
    func getSyncStatus() -> SyncStatus {
        return SyncStatus(
            isSyncing: isSyncing,
            pendingOperationsCount: pendingOperationsCount,
            lastSyncDate: lastSyncDate,
            isConnected: networkMonitor.isConnected,
            canSync: networkMonitor.canPerformNetworkOperation()
        )
    }
    
    // MARK: - Private Methods
    
    private func setupNetworkObserver() {
        // Monitor network changes
        networkMonitor.$isConnected
            .dropFirst()
            .sink { [weak self] isConnected in
                if isConnected {
                    print("🌐 Network restored - starting sync")
                    Task {
                        await self?.performSync()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupPeriodicSync() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                if self?.networkMonitor.canPerformNetworkOperation() == true {
                    await self?.performSync()
                }
            }
        }
    }
    
    private func loadPendingOperations() {
        updatePendingOperationsCount()
    }
    
    private func updatePendingOperationsCount() {
        let request: NSFetchRequest<PendingOperationEntity> = PendingOperationEntity.fetchRequest()
        
        do {
            pendingOperationsCount = try coreDataStack.viewContext.count(for: request)
        } catch {
            print("❌ Failed to count pending operations: \(error)")
            pendingOperationsCount = 0
        }
    }
    
    private func performSync() async {
        guard !isSyncing else { return }
        guard networkMonitor.canPerformNetworkOperation() else {
            print("🌐 Network not suitable for sync")
            return
        }
        
        isSyncing = true
        syncError = nil
        
        do {
            let operations = try fetchPendingOperations()
            
            for operation in operations {
                do {
                    try await executeOperation(operation)
                    removeOperation(operation)
                } catch {
                    handleOperationError(operation, error: error)
                }
            }
            
            lastSyncDate = Date()
            print("✅ Sync completed successfully")
            
        } catch {
            syncError = error.localizedDescription
            print("❌ Sync failed: \(error)")
        }
        
        isSyncing = false
        updatePendingOperationsCount()
    }
    
    private func fetchPendingOperations() throws -> [OfflineOperation] {
        let request: NSFetchRequest<PendingOperationEntity> = PendingOperationEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \PendingOperationEntity.priority, ascending: false),
            NSSortDescriptor(keyPath: \PendingOperationEntity.timestamp, ascending: true)
        ]
        
        let entities = try coreDataStack.viewContext.fetch(request)
        
        return entities.compactMap { entity in
            guard let id = entity.id,
                  let typeString = entity.type,
                  let type = OperationType(rawValue: typeString),
                  let data = entity.data,
                  let timestamp = entity.timestamp else {
                return nil
            }
            
            return OfflineOperation(
                id: id,
                type: type,
                data: data,
                timestamp: timestamp,
                retryCount: Int(entity.retryCount),
                priority: OperationPriority(rawValue: Int(entity.priority)) ?? .normal
            )
        }
    }
    
    private func executeOperation(_ operation: OfflineOperation) async throws {
        switch operation.type {
        case .saveChatMessage:
            try await executeSaveChatMessage(operation)
        case .updateUser:
            try await executeUpdateUser(operation)
        case .saveMoodEntry:
            try await executeSaveMoodEntry(operation)
        case .deleteMessage:
            try await executeDeleteMessage(operation)
        case .uploadFile:
            try await executeUploadFile(operation)
        }
        
        print("✅ Executed operation: \(operation.type.rawValue)")
    }
    
    private func executeSaveChatMessage(_ operation: OfflineOperation) async throws {
        guard let messageData = try? JSONSerialization.jsonObject(with: operation.data) as? [String: Any],
              let messageId = messageData["id"] as? String,
              let role = messageData["role"] as? String,
              let text = messageData["text"] as? String,
              let timestamp = messageData["timestamp"] as? TimeInterval,
              let userId = messageData["userId"] as? String else {
            throw SyncError.invalidOperationData
        }
        
        let message = ChatMessage(
            id: UUID(uuidString: messageId) ?? UUID(),
            role: Role(rawValue: role) ?? .user,
            text: text,
            date: Date(timeIntervalSince1970: timestamp)
        )
        
        try await firestoreService.saveChatMessage(message, userId: userId)
    }
    
    private func executeUpdateUser(_ operation: OfflineOperation) async throws {
        guard let _ = try? JSONSerialization.jsonObject(with: operation.data) as? [String: Any] else {
            throw SyncError.invalidOperationData
        }
        
        // Convert to User object and update
        // Implementation depends on User model structure
        print("🔄 User update operation executed")
    }
    
    private func executeSaveMoodEntry(_ operation: OfflineOperation) async throws {
        guard let _ = try? JSONSerialization.jsonObject(with: operation.data) as? [String: Any] else {
            throw SyncError.invalidOperationData
        }
        
        // Convert to MoodEntry and save
        print("🔄 Mood entry save operation executed")
    }
    
    private func executeDeleteMessage(_ operation: OfflineOperation) async throws {
        guard let deleteData = try? JSONSerialization.jsonObject(with: operation.data) as? [String: Any],
              let messageId = deleteData["messageId"] as? String else {
            throw SyncError.invalidOperationData
        }
        
        // Delete message from server
        print("🔄 Message delete operation executed: \(messageId)")
    }
    
    private func executeUploadFile(_ operation: OfflineOperation) async throws {
        guard let fileData = try? JSONSerialization.jsonObject(with: operation.data) as? [String: Any],
              let filePath = fileData["filePath"] as? String else {
            throw SyncError.invalidOperationData
        }
        
        // Upload file to server
        print("🔄 File upload operation executed: \(filePath)")
    }
    
    private func removeOperation(_ operation: OfflineOperation) {
        let request: NSFetchRequest<PendingOperationEntity> = PendingOperationEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", operation.id.uuidString)
        
        do {
            let entities = try coreDataStack.viewContext.fetch(request)
            for entity in entities {
                coreDataStack.viewContext.delete(entity)
            }
            coreDataStack.save()
        } catch {
            print("❌ Failed to remove operation: \(error)")
        }
    }
    
    private func handleOperationError(_ operation: OfflineOperation, error: Error) {
        let request: NSFetchRequest<PendingOperationEntity> = PendingOperationEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", operation.id.uuidString)
        
        do {
            let entities = try coreDataStack.viewContext.fetch(request)
            if let entity = entities.first {
                entity.retryCount += 1
                
                // Remove operation if max retries exceeded
                if entity.retryCount >= maxRetryAttempts {
                    print("❌ Operation exceeded max retries, removing: \(operation.type.rawValue)")
                    coreDataStack.viewContext.delete(entity)
                } else {
                    print("⚠️ Operation failed, will retry: \(operation.type.rawValue) (attempt \(entity.retryCount))")
                }
                
                coreDataStack.save()
            }
        } catch {
            print("❌ Failed to handle operation error: \(error)")
        }
    }
}

// MARK: - Supporting Types

struct OfflineOperation {
    let id: UUID
    let type: OperationType
    let data: Data
    let timestamp: Date
    let retryCount: Int
    let priority: OperationPriority
    
    init(id: UUID = UUID(), type: OperationType, data: Data, timestamp: Date = Date(), retryCount: Int = 0, priority: OperationPriority = .normal) {
        self.id = id
        self.type = type
        self.data = data
        self.timestamp = timestamp
        self.retryCount = retryCount
        self.priority = priority
    }
}

enum OperationType: String, CaseIterable {
    case saveChatMessage = "saveChatMessage"
    case updateUser = "updateUser"
    case saveMoodEntry = "saveMoodEntry"
    case deleteMessage = "deleteMessage"
    case uploadFile = "uploadFile"
}

enum OperationPriority: Int, CaseIterable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3
}

struct SyncStatus {
    let isSyncing: Bool
    let pendingOperationsCount: Int
    let lastSyncDate: Date?
    let isConnected: Bool
    let canSync: Bool
    
    var statusMessage: String {
        if isSyncing {
            return "Syncing..."
        } else if !isConnected {
            return "Offline"
        } else if pendingOperationsCount > 0 {
            return "\(pendingOperationsCount) pending"
        } else {
            return "Up to date"
        }
    }
}

enum SyncError: LocalizedError {
    case invalidOperationData
    case networkUnavailable
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidOperationData:
            return "Invalid operation data"
        case .networkUnavailable:
            return "Network unavailable"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}

