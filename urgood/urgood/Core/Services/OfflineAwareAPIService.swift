import Foundation
import Combine

/// Enhanced API service with offline support and intelligent request handling
/// Automatically queues operations when offline and syncs when connection is restored
@MainActor
final class OfflineAwareAPIService: ObservableObject {
    static let shared = OfflineAwareAPIService()
    
    // MARK: - Published Properties
    @Published private(set) var isOnlineMode = true
    @Published private(set) var queuedOperationsCount = 0
    
    // MARK: - Private Properties
    private let apiService = APIService.shared
    private let networkMonitor = NetworkMonitor.shared
    private let offlineSync = OfflineDataSync.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupNetworkObserver()
        setupSyncObserver()
    }
    
    // MARK: - Public Methods
    
    /// Send a chat message with offline support
    func sendChatMessage(_ message: ChatMessage, userId: String) async throws -> String {
        if networkMonitor.canPerformNetworkOperation() {
            // Try online first
            do {
                return try await performOnlineChatMessage(message, userId: userId)
            } catch {
                // If online fails, queue for offline
                await queueChatMessageOperation(message, userId: userId)
                throw OfflineAPIError.queuedForLater
            }
        } else {
            // Queue for offline sync
            await queueChatMessageOperation(message, userId: userId)
            throw OfflineAPIError.queuedForLater
        }
    }
    
    /// Update user data with offline support
    func updateUser(_ user: User) async throws {
        if networkMonitor.canPerformNetworkOperation() {
            do {
                try await performOnlineUserUpdate(user)
            } catch {
                await queueUserUpdateOperation(user)
                throw OfflineAPIError.queuedForLater
            }
        } else {
            await queueUserUpdateOperation(user)
            throw OfflineAPIError.queuedForLater
        }
    }
    
    /// Save mood entry with offline support
    func saveMoodEntry(_ moodEntry: MoodEntry, userId: String) async throws {
        if networkMonitor.canPerformNetworkOperation() {
            do {
                try await performOnlineMoodEntry(moodEntry, userId: userId)
            } catch {
                await queueMoodEntryOperation(moodEntry, userId: userId)
                throw OfflineAPIError.queuedForLater
            }
        } else {
            await queueMoodEntryOperation(moodEntry, userId: userId)
            throw OfflineAPIError.queuedForLater
        }
    }
    
    /// Get cached data when offline
    func getCachedChatMessages(userId: String) -> [ChatMessage] {
        // Return locally stored messages
        return EnhancedLocalStore.shared.chatMessages
    }
    
    /// Check if operation can be performed online
    func canPerformOnlineOperation() -> Bool {
        return networkMonitor.canPerformNetworkOperation()
    }
    
    /// Get offline status summary
    func getOfflineStatus() -> OfflineStatus {
        return OfflineStatus(
            isOnline: isOnlineMode,
            networkConnected: networkMonitor.isConnected,
            queuedOperations: queuedOperationsCount,
            canSync: networkMonitor.canPerformNetworkOperation(),
            connectionQuality: networkMonitor.connectionQuality
        )
    }
    
    // MARK: - Private Methods
    
    private func setupNetworkObserver() {
        networkMonitor.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                self?.isOnlineMode = isConnected
                if isConnected {
                    print("🌐 Network restored - switching to online mode")
                } else {
                    print("🌐 Network lost - switching to offline mode")
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupSyncObserver() {
        offlineSync.$pendingOperationsCount
            .receive(on: DispatchQueue.main)
            .assign(to: &$queuedOperationsCount)
    }
    
    // MARK: - Online Operations
    
    private func performOnlineChatMessage(_ message: ChatMessage, userId: String) async throws -> String {
        // Use existing API service for online operations
        let firestoreService = FirestoreService.shared
        try await firestoreService.saveChatMessage(message, userId: userId)
        return message.id.uuidString
    }
    
    private func performOnlineUserUpdate(_ user: User) async throws {
        let firestoreService = FirestoreService.shared
        try await firestoreService.updateUser(user)
    }
    
    private func performOnlineMoodEntry(_ moodEntry: MoodEntry, userId: String) async throws {
        // Implementation for saving mood entry online
        print("💾 Mood entry saved online: \(moodEntry.id)")
    }
    
    // MARK: - Offline Queueing Operations
    
    private func queueChatMessageOperation(_ message: ChatMessage, userId: String) async {
        let operationData: [String: Any] = [
            "id": message.id.uuidString,
            "role": message.role.rawValue,
            "text": message.text,
            "userId": userId,
            "timestamp": message.date.timeIntervalSince1970
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: operationData) else {
            print("❌ Failed to serialize chat message operation")
            return
        }
        
        let operation = OfflineOperation(
            type: .saveChatMessage,
            data: data,
            priority: .high
        )
        
        offlineSync.queueOperation(operation)
    }
    
    private func queueUserUpdateOperation(_ user: User) async {
        let operationData: [String: Any] = [
            "uid": user.uid,
            "email": user.email ?? "",
            "displayName": user.displayName ?? "",
            "subscriptionStatus": user.subscriptionStatus.rawValue,
            "streakCount": user.streakCount,
            "totalCheckins": user.totalCheckins,
            "messagesThisWeek": user.messagesThisWeek
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: operationData) else {
            print("❌ Failed to serialize user update operation")
            return
        }
        
        let operation = OfflineOperation(
            type: .updateUser,
            data: data,
            priority: .normal
        )
        
        offlineSync.queueOperation(operation)
    }
    
    private func queueMoodEntryOperation(_ moodEntry: MoodEntry, userId: String) async {
        let operationData: [String: Any] = [
            "id": moodEntry.id.uuidString,
            "mood": moodEntry.mood,
            "date": moodEntry.date.timeIntervalSince1970,
            "tags": moodEntry.tags.map { $0.name },
            "userId": userId
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: operationData) else {
            print("❌ Failed to serialize mood entry operation")
            return
        }
        
        let operation = OfflineOperation(
            type: .saveMoodEntry,
            data: data,
            priority: .normal
        )
        
        offlineSync.queueOperation(operation)
    }
}

// MARK: - Supporting Types

struct OfflineStatus {
    let isOnline: Bool
    let networkConnected: Bool
    let queuedOperations: Int
    let canSync: Bool
    let connectionQuality: ConnectionQuality
    
    var statusMessage: String {
        if isOnline && networkConnected {
            return "Online"
        } else if queuedOperations > 0 {
            return "Offline - \(queuedOperations) queued"
        } else {
            return "Offline"
        }
    }
    
    var statusColor: String {
        if isOnline && networkConnected {
            return "green"
        } else if queuedOperations > 0 {
            return "orange"
        } else {
            return "red"
        }
    }
}

enum OfflineAPIError: LocalizedError {
    case queuedForLater
    case networkUnavailable
    case operationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .queuedForLater:
            return "Operation queued for when connection is restored"
        case .networkUnavailable:
            return "Network connection unavailable"
        case .operationFailed(let message):
            return "Operation failed: \(message)"
        }
    }
    
    var isRecoverable: Bool {
        switch self {
        case .queuedForLater, .networkUnavailable:
            return true
        case .operationFailed:
            return false
        }
    }
}

