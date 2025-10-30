//
//  UserScopedRepositories.swift
//  urgood
//
//  User-scoped data repositories for proper multi-user isolation
//

import Foundation
import FirebaseFirestore
import Combine
import os.log

private let log = Logger(subsystem: "com.urgood.urgood", category: "Repositories")

// MARK: - Base Repository Protocol
protocol UserScopedRepository: AnyObject {
    var uid: String { get }
    nonisolated func cancelAllListeners()
}

// MARK: - Sessions Repository
@MainActor
class SessionsRepository: ObservableObject, UserScopedRepository {
    let uid: String
    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    
    @Published var sessions: [ChatSession] = []
    
    init(uid: String) {
        self.uid = uid
        log.info("📁 SessionsRepository initialized for user: \(uid)")
    }
    
    deinit {
        cancelAllListeners()
    }
    
    nonisolated func cancelAllListeners() {
        Task { @MainActor in
            listeners.forEach { $0.remove() }
            listeners.removeAll()
            log.info("🛑 Cancelled all listeners for SessionsRepository")
        }
    }
    
    // MARK: - CRUD Operations
    func createSession(session: ChatSession) async throws {
        let data: [String: Any] = [
            "id": session.id.uuidString,
            "startTime": Timestamp(date: session.startTime),
            "endTime": session.endTime.map { Timestamp(date: $0) } as Any,
            "messageCount": session.messageCount,
            "moodBefore": session.moodBefore ?? 0,
            "moodAfter": session.moodAfter ?? 0,
            "summary": session.summary ?? "",
            "insights": session.insights ?? "",
            "createdAt": Timestamp(date: Date())
        ]
        
        try await db.collection("users").document(uid)
            .collection("sessions").document(session.id.uuidString)
            .setData(data)
        
        log.info("✅ Created session: \(session.id)")
    }
    
    func fetchSessions(limit: Int = 50) async throws -> [ChatSession] {
        let snapshot = try await db.collection("users").document(uid)
            .collection("sessions")
            .order(by: "startTime", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { try? parseChatSession(from: $0.data()) }
    }
    
    func fetchSession(id: UUID) async throws -> ChatSession? {
        let doc = try await db.collection("users").document(uid)
            .collection("sessions").document(id.uuidString)
            .getDocument()
        
        guard let data = doc.data() else { return nil }
        return try? parseChatSession(from: data)
    }
    
    func updateSession(id: UUID, updates: [String: Any]) async throws {
        try await db.collection("users").document(uid)
            .collection("sessions").document(id.uuidString)
            .updateData(updates)
    }
    
    func deleteSession(id: UUID) async throws {
        try await db.collection("users").document(uid)
            .collection("sessions").document(id.uuidString)
            .delete()
        
        log.info("🗑️ Deleted session: \(id)")
    }
    
    // MARK: - Real-time Listener
    func listenToSessions() {
        let listener = db.collection("users").document(self.uid)
            .collection("sessions")
            .order(by: "startTime", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    log.error("❌ Error listening to sessions: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                Task { @MainActor in
                    self.sessions = documents.compactMap { try? self.parseChatSession(from: $0.data()) }
                }
            }
        
        listeners.append(listener)
    }
    
    private func parseChatSession(from data: [String: Any]) throws -> ChatSession {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let startTimestamp = data["startTime"] as? Timestamp else {
            throw RepositoryError.invalidData
        }
        
        let startTime = startTimestamp.dateValue()
        let endTime = (data["endTime"] as? Timestamp)?.dateValue()
        let messageCount = data["messageCount"] as? Int ?? 0
        let moodBefore = data["moodBefore"] as? Int
        let moodAfter = data["moodAfter"] as? Int
        let summary = data["summary"] as? String
        let insights = data["insights"] as? String
        
        return ChatSession(
            id: id,
            startTime: startTime,
            endTime: endTime,
            messageCount: messageCount,
            moodBefore: moodBefore,
            moodAfter: moodAfter,
            summary: summary,
            insights: insights
        )
    }
}

// MARK: - Moods Repository
@MainActor
class MoodsRepository: ObservableObject, UserScopedRepository {
    let uid: String
    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    
    @Published var moods: [MoodEntry] = []
    
    init(uid: String) {
        self.uid = uid
        log.info("📁 MoodsRepository initialized for user: \(uid)")
    }
    
    deinit {
        cancelAllListeners()
    }
    
    nonisolated func cancelAllListeners() {
        Task { @MainActor in
            listeners.forEach { $0.remove() }
            listeners.removeAll()
            log.info("🛑 Cancelled all listeners for MoodsRepository")
        }
    }
    
    // MARK: - CRUD Operations
    func saveMoodEntry(entry: MoodEntry) async throws {
        let data: [String: Any] = [
            "id": entry.id.uuidString,
            "mood": entry.mood,
            "tags": entry.tags.map { ["id": $0.id.uuidString, "name": $0.name] },
            "date": Timestamp(date: entry.date),
            "createdAt": Timestamp(date: Date())
        ]
        
        try await db.collection("users").document(uid)
            .collection("moods").document(entry.id.uuidString)
            .setData(data)
        
        log.info("✅ Saved mood entry: \(entry.id)")
    }
    
    func fetchMoods(limit: Int = 100) async throws -> [MoodEntry] {
        let snapshot = try await db.collection("users").document(uid)
            .collection("moods")
            .order(by: "date", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { try? parseMoodEntry(from: $0.data()) }
    }
    
    func fetchMood(id: UUID) async throws -> MoodEntry? {
        let doc = try await db.collection("users").document(uid)
            .collection("moods").document(id.uuidString)
            .getDocument()
        
        guard let data = doc.data() else { return nil }
        return try? parseMoodEntry(from: data)
    }
    
    func deleteMood(id: UUID) async throws {
        try await db.collection("users").document(uid)
            .collection("moods").document(id.uuidString)
            .delete()
        
        log.info("🗑️ Deleted mood: \(id)")
    }
    
    // MARK: - Real-time Listener
    func listenToMoods() {
        let listener = db.collection("users").document(self.uid)
            .collection("moods")
            .order(by: "date", descending: true)
            .limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    log.error("❌ Error listening to moods: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                Task { @MainActor in
                    self.moods = documents.compactMap { try? self.parseMoodEntry(from: $0.data()) }
                }
            }
        
        listeners.append(listener)
    }
    
    private func parseMoodEntry(from data: [String: Any]) throws -> MoodEntry {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let mood = data["mood"] as? Int,
              let dateTimestamp = data["date"] as? Timestamp else {
            throw RepositoryError.invalidData
        }
        
        let date = dateTimestamp.dateValue()
        let tagsData = data["tags"] as? [[String: Any]] ?? []
        let tags = tagsData.compactMap { tagData -> MoodTag? in
            guard let name = tagData["name"] as? String else { return nil }
            return MoodTag(name: name)
        }
        
        return MoodEntry(id: id, date: date, mood: mood, tags: tags)
    }
}

// MARK: - Insights Repository
@MainActor
class InsightsRepository: ObservableObject, UserScopedRepository {
    let uid: String
    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    
    @Published var insights: [Insight] = []
    
    init(uid: String) {
        self.uid = uid
        log.info("📁 InsightsRepository initialized for user: \(uid)")
    }
    
    deinit {
        cancelAllListeners()
    }
    
    nonisolated func cancelAllListeners() {
        Task { @MainActor in
            listeners.forEach { $0.remove() }
            listeners.removeAll()
            log.info("🛑 Cancelled all listeners for InsightsRepository")
        }
    }
    
    // MARK: - CRUD Operations
    func saveInsight(insight: Insight) async throws {
        let data: [String: Any] = [
            "id": insight.id.uuidString,
            "title": insight.title,
            "content": insight.content,
            "category": insight.category,
            "date": Timestamp(date: insight.date),
            "createdAt": Timestamp(date: Date())
        ]
        
        try await db.collection("users").document(uid)
            .collection("insights").document(insight.id.uuidString)
            .setData(data)
        
        log.info("✅ Saved insight: \(insight.id)")
    }
    
    func fetchInsights(limit: Int = 50) async throws -> [Insight] {
        let snapshot = try await db.collection("users").document(uid)
            .collection("insights")
            .order(by: "date", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { try? parseInsight(from: $0.data()) }
    }
    
    func deleteInsight(id: UUID) async throws {
        try await db.collection("users").document(uid)
            .collection("insights").document(id.uuidString)
            .delete()
        
        log.info("🗑️ Deleted insight: \(id)")
    }
    
    // MARK: - Real-time Listener
    func listenToInsights() {
        let listener = db.collection("users").document(self.uid)
            .collection("insights")
            .order(by: "date", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    log.error("❌ Error listening to insights: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                Task { @MainActor in
                    self.insights = documents.compactMap { try? self.parseInsight(from: $0.data()) }
                }
            }
        
        listeners.append(listener)
    }
    
    private func parseInsight(from data: [String: Any]) throws -> Insight {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let title = data["title"] as? String,
              let content = data["content"] as? String,
              let category = data["category"] as? String,
              let dateTimestamp = data["date"] as? Timestamp else {
            throw RepositoryError.invalidData
        }
        
        let date = dateTimestamp.dateValue()
        
        return Insight(id: id, title: title, content: content, category: category, date: date)
    }
}

// MARK: - Settings Repository
@MainActor
class SettingsRepository: UserScopedRepository {
    let uid: String
    private let db = Firestore.firestore()
    
    init(uid: String) {
        self.uid = uid
        log.info("📁 SettingsRepository initialized for user: \(uid)")
    }
    
    nonisolated func cancelAllListeners() {
        // Settings don't use listeners
    }
    
    // MARK: - Operations
    func saveSettings(settings: UserPreferences) async throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        
        var mutableDict = dict
        mutableDict["updatedAt"] = Timestamp(date: Date())
        
        try await db.collection("users").document(uid)
            .collection("settings").document("app")
            .setData(mutableDict, merge: true)
        
        log.info("✅ Saved settings for user: \(self.uid)")
    }
    
    func fetchSettings() async throws -> UserPreferences? {
        let doc = try await db.collection("users").document(uid)
            .collection("settings").document("app")
            .getDocument()
        
        guard let data = doc.data() else {
            return nil // Return nil if no settings exist
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: data)
        let decoder = JSONDecoder()
        return try? decoder.decode(UserPreferences.self, from: jsonData)
    }
    
    func saveBillingInfo(plan: SubscriptionPlan, productId: String?, expiresAt: Date?) async throws {
        var data: [String: Any] = [
            "isPro": plan == .premium,
            "plan": plan.rawValue,
            "updatedAt": Timestamp(date: Date())
        ]
        
        if let productId = productId {
            data["productId"] = productId
        }
        
        if let expiresAt = expiresAt {
            data["expiresAt"] = Timestamp(date: expiresAt)
        }
        
        try await db.collection("users").document(uid)
            .collection("settings").document("billing")
            .setData(data, merge: true)
        
        log.info("✅ Saved billing info for user: \(self.uid)")
    }
}

// MARK: - Supporting Models
struct ChatSession: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    var messageCount: Int
    var moodBefore: Int?
    var moodAfter: Int?
    var summary: String?
    var insights: String?
    
    init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        endTime: Date? = nil,
        messageCount: Int = 0,
        moodBefore: Int? = nil,
        moodAfter: Int? = nil,
        summary: String? = nil,
        insights: String? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.messageCount = messageCount
        self.moodBefore = moodBefore
        self.moodAfter = moodAfter
        self.summary = summary
        self.insights = insights
    }
}

struct Insight: Identifiable, Codable {
    let id: UUID
    let title: String
    let content: String
    let category: String
    let date: Date
    
    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        category: String,
        date: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.category = category
        self.date = date
    }
}

// MARK: - Repository Errors
enum RepositoryError: LocalizedError {
    case invalidData
    case notFound
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid data format"
        case .notFound:
            return "Resource not found"
        case .unauthorized:
            return "Unauthorized access"
        }
    }
}

