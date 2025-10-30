import Foundation
import FirebaseFirestore
import FirebaseCore
import Combine

class FirestoreService: ObservableObject {
    static let shared = FirestoreService()
    
    private let db = Firestore.firestore()
    private var isInitialized = false
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Collections
    private let usersCollection = "users"
    private let chatMessagesCollection = "chat_messages"
    private let moodEntriesCollection = "mood_entries"
    private let insightsCollection = "insights"
    private let sessionsCollection = "sessions"
    
    private init() {
        initializeFirestore()
    }
    
    // MARK: - Initialization
    
    private func initializeFirestore() {
        // Configure Firestore settings
        let settings = FirestoreSettings()
        let cacheSettings = PersistentCacheSettings()
        settings.cacheSettings = cacheSettings
        db.settings = settings
        
        isInitialized = true
        print("🔥 Firestore initialized successfully")
    }
    
    // MARK: - User Management
    
    func createUser(_ user: User) async throws {
        guard isInitialized else { throw FirestoreError.notInitialized }
        
        let userData: [String: Any] = [
            "uid": user.uid,
            "email": user.email ?? "",
            "displayName": user.displayName ?? "",
            "subscriptionStatus": user.subscriptionStatus.rawValue,
            "streakCount": user.streakCount,
            "totalCheckins": user.totalCheckins,
            "messagesThisWeek": user.messagesThisWeek,
            "isEmailVerified": user.isEmailVerified,
            "createdAt": Timestamp(date: Date()),
            "lastActiveAt": Timestamp(date: Date())
        ]
        
        try await db.collection(usersCollection).document(user.uid).setData(userData)
        print("🔥 User created in Firestore: \(user.uid)")
    }
    
    func updateUser(_ user: User) async throws {
        guard isInitialized else { throw FirestoreError.notInitialized }
        
        let userData: [String: Any] = [
            "email": user.email ?? "",
            "displayName": user.displayName ?? "",
            "subscriptionStatus": user.subscriptionStatus.rawValue,
            "streakCount": user.streakCount,
            "totalCheckins": user.totalCheckins,
            "messagesThisWeek": user.messagesThisWeek,
            "isEmailVerified": user.isEmailVerified,
            "lastActiveAt": Timestamp(date: Date())
        ]
        
        try await db.collection(usersCollection).document(user.uid).updateData(userData)
        print("🔥 User updated in Firestore: \(user.uid)")
    }
    
    func getUser(_ userId: String) async throws -> User? {
        guard isInitialized else { throw FirestoreError.notInitialized }
        
        let document = try await db.collection(usersCollection).document(userId).getDocument()
        
        guard document.exists,
              let data = document.data() else {
            return nil
        }
        
        return try User.fromFirestore(data)
    }
    
    // MARK: - Chat Messages
    
    func saveChatMessage(_ message: ChatMessage, userId: String) async throws {
        guard isInitialized else { throw FirestoreError.notInitialized }
        
        let messageData: [String: Any] = [
            "id": message.id.uuidString,
            "role": message.role.rawValue,
            "text": message.text,
            "timestamp": Timestamp(date: message.date),
            "userId": userId
        ]
        
        try await db.collection(chatMessagesCollection).document(message.id.uuidString).setData(messageData)
        print("🔥 Chat message saved to Firestore: \(message.id)")
    }
    
    func getChatMessages(for userId: String) async throws -> [ChatMessage] {
        guard isInitialized else { throw FirestoreError.notInitialized }
        
        let snapshot = try await db.collection(chatMessagesCollection)
            .whereField("userId", isEqualTo: userId)
            .order(by: "timestamp")
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? ChatMessage.fromFirestore(document.data())
        }
    }
    
    func deleteChatMessage(_ messageId: String) async throws {
        guard isInitialized else { throw FirestoreError.notInitialized }
        
        try await db.collection(chatMessagesCollection).document(messageId).delete()
        print("🔥 Chat message deleted from Firestore: \(messageId)")
    }
    
    // MARK: - Mood Entries
    
    func saveMoodEntry(_ entry: MoodEntry, userId: String) async throws {
        guard isInitialized else { throw FirestoreError.notInitialized }
        
        let entryData: [String: Any] = [
            "id": entry.id.uuidString,
            "mood": entry.mood,
            "tags": entry.tags.map { $0.name },
            "timestamp": Timestamp(date: entry.date),
            "userId": userId
        ]
        
        try await db.collection(moodEntriesCollection).document(entry.id.uuidString).setData(entryData)
        print("🔥 Mood entry saved to Firestore: \(entry.id)")
    }
    
    func getMoodEntries(for userId: String) async throws -> [MoodEntry] {
        guard isInitialized else { throw FirestoreError.notInitialized }
        
        let snapshot = try await db.collection(moodEntriesCollection)
            .whereField("userId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? MoodEntry.fromFirestore(document.data())
        }
    }
    
    func deleteMoodEntry(_ entryId: String) async throws {
        guard isInitialized else { throw FirestoreError.notInitialized }
        
        try await db.collection(moodEntriesCollection).document(entryId).delete()
        print("🔥 Mood entry deleted from Firestore: \(entryId)")
    }
    
    // MARK: - Real-time Listeners
    
    func listenToChatMessages(for userId: String, completion: @escaping ([ChatMessage]) -> Void) -> ListenerRegistration {
        return db.collection(chatMessagesCollection)
            .whereField("userId", isEqualTo: userId)
            .order(by: "timestamp")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("🔥 Error listening to chat messages: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                let messages = documents.compactMap { document in
                    try? ChatMessage.fromFirestore(document.data())
                }
                
                completion(messages)
            }
    }
    
    func listenToMoodEntries(for userId: String, completion: @escaping ([MoodEntry]) -> Void) -> ListenerRegistration {
        return db.collection(moodEntriesCollection)
            .whereField("userId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("🔥 Error listening to mood entries: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                let entries = documents.compactMap { document in
                    try? MoodEntry.fromFirestore(document.data())
                }
                
                completion(entries)
            }
    }
    
    // MARK: - Data Sync
    
    func syncUserData(_ user: User) async throws {
        guard isInitialized else { throw FirestoreError.notInitialized }
        
        // Update user document
        try await updateUser(user)
        
        // Sync chat messages
        // This would typically be called from the local store
        print("🔥 User data synced to Firestore: user_\(user.subscriptionStatus.rawValue)_\(user.streakCount)")
    }
    
    func syncChatMessages(_ messages: [ChatMessage], userId: String) async throws {
        guard isInitialized else { throw FirestoreError.notInitialized }
        
        let batch = db.batch()
        
        for message in messages {
            let messageData: [String: Any] = [
                "id": message.id.uuidString,
                "role": message.role.rawValue,
                "text": message.text,
                "timestamp": Timestamp(date: message.date),
                "userId": userId
            ]
            
            let docRef = db.collection(chatMessagesCollection).document(message.id.uuidString)
            batch.setData(messageData, forDocument: docRef)
        }
        
        try await batch.commit()
        print("🔥 \(messages.count) chat messages synced to Firestore")
    }
    
    func syncMoodEntries(_ entries: [MoodEntry], userId: String) async throws {
        guard isInitialized else { throw FirestoreError.notInitialized }
        
        let batch = db.batch()
        
        for entry in entries {
            let entryData: [String: Any] = [
                "id": entry.id.uuidString,
                "mood": entry.mood,
                "tags": entry.tags.map { $0.name },
                "timestamp": Timestamp(date: entry.date),
                "userId": userId
            ]
            
            let docRef = db.collection(moodEntriesCollection).document(entry.id.uuidString)
            batch.setData(entryData, forDocument: docRef)
        }
        
        try await batch.commit()
        print("🔥 \(entries.count) mood entries synced to Firestore")
    }
    
    // MARK: - Offline Support
    
    func enableOfflinePersistence() {
        // Firestore automatically handles offline persistence
        // when isPersistenceEnabled is true
        print("🔥 Offline persistence enabled")
    }
    
    func clearOfflineCache() async {
        try? await db.clearPersistence()
        print("🔥 Offline cache cleared")
    }
    
    // MARK: - Data Export
    
    func exportUserData(_ userId: String) async throws -> [String: Any] {
        guard isInitialized else { throw FirestoreError.notInitialized }
        
        let user = try await getUser(userId)
        let chatMessages = try await getChatMessages(for: userId)
        let moodEntries = try await getMoodEntries(for: userId)
        
        return [
            "user": user?.toDictionary() ?? [:],
            "chatMessages": chatMessages.map { $0.toDictionary() },
            "moodEntries": moodEntries.map { $0.toDictionary() },
            "exportedAt": Date().timeIntervalSince1970
        ]
    }
    
    // MARK: - Cleanup
    
    func deleteAllUserData(_ userId: String) async throws {
        guard isInitialized else { throw FirestoreError.notInitialized }
        
        // Delete user document
        try await db.collection(usersCollection).document(userId).delete()
        
        // Delete all chat messages
        let chatSnapshot = try await db.collection(chatMessagesCollection)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        let batch = db.batch()
        for document in chatSnapshot.documents {
            batch.deleteDocument(document.reference)
        }
        
        // Delete all mood entries
        let moodSnapshot = try await db.collection(moodEntriesCollection)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        for document in moodSnapshot.documents {
            batch.deleteDocument(document.reference)
        }
        
        try await batch.commit()
        print("🔥 All user data deleted from Firestore: \(userId)")
    }
}

// MARK: - Supporting Types

enum FirestoreError: Error, LocalizedError {
    case notInitialized
    case invalidData
    case networkError
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Firestore service not initialized"
        case .invalidData:
            return "Invalid data format"
        case .networkError:
            return "Network error occurred"
        case .permissionDenied:
            return "Permission denied"
        }
    }
}

// MARK: - Model Extensions

extension User {
    func toDictionary() -> [String: Any] {
        return [
            "uid": uid,
            "email": email ?? "",
            "displayName": displayName ?? "",
            "subscriptionStatus": subscriptionStatus.rawValue,
            "streakCount": streakCount,
            "totalCheckins": totalCheckins,
            "messagesThisWeek": messagesThisWeek,
            "isEmailVerified": isEmailVerified
        ]
    }
    
    static func fromFirestore(_ data: [String: Any]) throws -> User {
        guard let uid = data["uid"] as? String,
              let subscriptionStatusString = data["subscriptionStatus"] as? String,
              let subscriptionStatus = SubscriptionStatus(rawValue: subscriptionStatusString),
              let streakCount = data["streakCount"] as? Int,
              let totalCheckins = data["totalCheckins"] as? Int,
              let messagesThisWeek = data["messagesThisWeek"] as? Int else {
            throw FirestoreError.invalidData
        }
        
        let email = data["email"] as? String
        let displayName = data["displayName"] as? String
        let isEmailVerified = data["isEmailVerified"] as? Bool ?? false
        
        return User(
            uid: uid,
            email: email,
            displayName: displayName,
            subscriptionStatus: subscriptionStatus,
            streakCount: streakCount,
            totalCheckins: totalCheckins,
            messagesThisWeek: messagesThisWeek,
            isEmailVerified: isEmailVerified
        )
    }
}

extension ChatMessage {
    func toDictionary() -> [String: Any] {
        return [
            "id": id.uuidString,
            "role": role.rawValue,
            "text": text,
            "timestamp": date.timeIntervalSince1970
        ]
    }
    
    static func fromFirestore(_ data: [String: Any]) throws -> ChatMessage {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let roleString = data["role"] as? String,
              let role = Role(rawValue: roleString),
              let text = data["text"] as? String,
              let timestamp = data["timestamp"] as? Timestamp else {
            throw FirestoreError.invalidData
        }
        
        return ChatMessage(
            id: id,
            role: role,
            text: text,
            date: timestamp.dateValue()
        )
    }
}

extension MoodEntry {
    func toDictionary() -> [String: Any] {
        return [
            "id": id.uuidString,
            "mood": mood,
            "tags": tags.map { $0.name },
            "timestamp": date.timeIntervalSince1970
        ]
    }
    
    static func fromFirestore(_ data: [String: Any]) throws -> MoodEntry {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let mood = data["mood"] as? Int,
              let tagsArray = data["tags"] as? [String],
              let timestamp = data["timestamp"] as? Timestamp else {
            throw FirestoreError.invalidData
        }
        
        let tags = tagsArray.compactMap { tagName in
            MoodTag(name: tagName)
        }
        
        return MoodEntry(
            id: id,
            date: timestamp.dateValue(),
            mood: mood,
            tags: tags
        )
    }
}
