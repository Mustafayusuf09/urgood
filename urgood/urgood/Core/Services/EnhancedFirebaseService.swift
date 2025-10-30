import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class EnhancedFirebaseService: ObservableObject {
    static let shared = EnhancedFirebaseService()
    
    private let db = Firestore.firestore()
    // Note: FirebaseFunctions not available, using stub implementation
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Enhanced User Management
    
    func createUserProfile(uid: String, email: String?, name: String?) async throws {
        let userData: [String: Any] = [
            "uid": uid,
            "email": email ?? "",
            "name": name ?? "",
            "subscriptionStatus": "FREE",
            "streakCount": 0,
            "totalCheckins": 0,
            "messagesThisWeek": 0,
            "createdAt": FieldValue.serverTimestamp(),
            "lastActiveAt": FieldValue.serverTimestamp(),
            "preferences": [
                "notifications": true,
                "darkMode": false,
                "crisisDetectionEnabled": true,
                "dailyReminderTime": "09:00"
            ]
        ]
        
        try await db.collection("users").document(uid).setData(userData)
        print("✅ User profile created: \(uid)")
    }
    
    func updateUserActivity(uid: String) async throws {
        try await db.collection("users").document(uid).updateData([
            "lastActiveAt": FieldValue.serverTimestamp()
        ])
    }
    
    // MARK: - Enhanced Chat System with AI Integration
    
    func saveChatMessage(uid: String, message: ChatMessage, sessionId: String? = nil) async throws -> String {
        let messageData: [String: Any] = [
            "id": message.id.uuidString,
            "userId": uid,
            "role": message.role.rawValue,
            "content": message.text,
            "sessionId": sessionId ?? UUID().uuidString,
            "timestamp": FieldValue.serverTimestamp(),
            "metadata": [
                "platform": "ios",
                "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            ]
        ]
        
        let docRef = try await db.collection("chat_messages").addDocument(data: messageData)
        
        // Update user message count
        try await db.collection("users").document(uid).updateData([
            "messagesThisWeek": FieldValue.increment(Int64(1)),
            "lastActiveAt": FieldValue.serverTimestamp()
        ])
        
        return docRef.documentID
    }
    
    func getChatHistory(uid: String, limit: Int = 50) async throws -> [ChatMessage] {
        let snapshot = try await db.collection("chat_messages")
            .whereField("userId", isEqualTo: uid)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard let role = data["role"] as? String,
                  let content = data["content"] as? String,
                  let roleEnum = Role(rawValue: role) else {
                return nil
            }
            
            return ChatMessage(role: roleEnum, text: content)
        }
    }
    
    // MARK: - Crisis Detection and Response
    
    func reportCrisisEvent(uid: String, message: String, level: CrisisLevel) async throws {
        let crisisData: [String: Any] = [
            "userId": uid,
            "message": String(message.prefix(500)), // Truncate for privacy
            "level": level.rawValue,
            "timestamp": FieldValue.serverTimestamp(),
            "resolved": false,
            "actionTaken": NSNull(),
            "emergencyContacted": false
        ]
        
        let docRef = try await db.collection("crisis_events").addDocument(data: crisisData)
        
        // Trigger crisis response cloud function
        try await triggerCrisisResponse(crisisId: docRef.documentID, level: level, uid: uid)
        
        print("🚨 Crisis event reported: \(level.rawValue)")
    }
    
    private func triggerCrisisResponse(crisisId: String, level: CrisisLevel, uid: String) async throws {
        let data: [String: Any] = [
            "crisisId": crisisId,
            "level": level.rawValue,
            "userId": uid,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // TODO: Firebase Cloud Function for crisis response (FirebaseFunctions not available)
        // _ = try await functions.httpsCallable("handleCrisisEvent").call(data)
        print("Crisis event logged: \(data)")
    }
    
    // MARK: - Enhanced Mood Tracking
    
    func saveMoodEntry(uid: String, mood: Int, tags: [String], notes: String?) async throws {
        let moodData: [String: Any] = [
            "userId": uid,
            "mood": mood,
            "tags": tags,
            "notes": notes ?? "",
            "timestamp": FieldValue.serverTimestamp(),
            "date": Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        ]
        
        try await db.collection("mood_entries").addDocument(data: moodData)
        
        // Update user checkin count
        try await db.collection("users").document(uid).updateData([
            "totalCheckins": FieldValue.increment(Int64(1)),
            "lastActiveAt": FieldValue.serverTimestamp()
        ])
        
        // Update streak
        try await updateUserStreak(uid: uid)
    }
    
    func getMoodTrends(uid: String, days: Int = 30) async throws -> [MoodTrendPoint] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        let snapshot = try await db.collection("mood_entries")
            .whereField("userId", isEqualTo: uid)
            .whereField("timestamp", isGreaterThan: Timestamp(date: startDate))
            .order(by: "timestamp")
            .getDocuments()
        
        var trends: [MoodTrendPoint] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // Group by date and calculate averages
        var dailyMoods: [String: [Int]] = [:]
        
        for doc in snapshot.documents {
            let data = doc.data()
            if let timestamp = data["timestamp"] as? Timestamp,
               let mood = data["mood"] as? Int {
                let dateKey = dateFormatter.string(from: timestamp.dateValue())
                dailyMoods[dateKey, default: []].append(mood)
            }
        }
        
        for (dateString, moods) in dailyMoods {
            if let date = dateFormatter.date(from: dateString) {
                let average = Double(moods.reduce(0, +)) / Double(moods.count)
                trends.append(MoodTrendPoint(date: date, mood: average, count: moods.count))
            }
        }
        
        return trends.sorted { $0.date < $1.date }
    }
    
    private func updateUserStreak(uid: String) async throws {
        // Get user's last checkin date
        let userDoc = try await db.collection("users").document(uid).getDocument()
        
        // Calculate streak logic
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
        
        // Check if user checked in yesterday or today
        let recentSnapshot = try await db.collection("mood_entries")
            .whereField("userId", isEqualTo: uid)
            .whereField("date", isGreaterThanOrEqualTo: yesterday.timeIntervalSince1970)
            .getDocuments()
        
        let checkinDates = Set(recentSnapshot.documents.compactMap { doc -> Date? in
            guard let dateTimestamp = doc.data()["date"] as? Double else { return nil }
            return Date(timeIntervalSince1970: dateTimestamp)
        })
        
        var newStreak = 1
        if let userData = userDoc.data(),
           let currentStreak = userData["streakCount"] as? Int {
            
            if checkinDates.contains(yesterday) {
                newStreak = currentStreak + 1
            } else if checkinDates.contains(today) {
                newStreak = currentStreak // Maintain streak if already checked in today
            }
        }
        
        try await db.collection("users").document(uid).updateData([
            "streakCount": newStreak
        ])
    }
    
    // MARK: - Analytics and Insights
    
    func trackEvent(uid: String, eventName: String, parameters: [String: Any] = [:]) async throws {
        let eventData: [String: Any] = [
            "userId": uid,
            "eventName": eventName,
            "parameters": parameters,
            "timestamp": FieldValue.serverTimestamp(),
            "platform": "ios",
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        ]
        
        try await db.collection("analytics_events").addDocument(data: eventData)
    }
    
    func getUserInsights(uid: String) async throws -> UserInsights {
        // Get user data
        let userDoc = try await db.collection("users").document(uid).getDocument()
        guard let userData = userDoc.data() else {
            throw FirestoreError.invalidData
        }
        
        // Get mood trends for last 30 days
        let moodTrends = try await getMoodTrends(uid: uid, days: 30)
        
        // Calculate insights
        let averageMood = moodTrends.isEmpty ? 0 : moodTrends.map { $0.mood }.reduce(0, +) / Double(moodTrends.count)
        let totalCheckins = userData["totalCheckins"] as? Int ?? 0
        let streakCount = userData["streakCount"] as? Int ?? 0
        
        return UserInsights(
            averageMood: averageMood,
            totalCheckins: totalCheckins,
            currentStreak: streakCount,
            moodTrends: moodTrends,
            insights: generateInsightMessages(averageMood: averageMood, streak: streakCount)
        )
    }
    
    private func generateInsightMessages(averageMood: Double, streak: Int) -> [String] {
        var insights: [String] = []
        
        if averageMood >= 4.0 {
            insights.append("You're maintaining excellent mental wellness! 🌟")
        } else if averageMood >= 3.0 {
            insights.append("You're doing well overall. Keep up the good work! 💪")
        } else if averageMood >= 2.0 {
            insights.append("Consider reaching out for support if you need it. 🤗")
        } else {
            insights.append("Your wellbeing is important. Please consider professional support. 💙")
        }
        
        if streak >= 7 {
            insights.append("Amazing \(streak)-day streak! Consistency is key to wellness. 🔥")
        } else if streak >= 3 {
            insights.append("Great \(streak)-day streak! You're building a healthy habit. ✨")
        }
        
        return insights
    }
    
    // MARK: - Subscription Management
    
    func updateSubscriptionStatus(uid: String, status: SubscriptionStatus, expiresAt: Date? = nil) async throws {
        var updateData: [String: Any] = [
            "subscriptionStatus": status.rawValue,
            "subscriptionUpdatedAt": FieldValue.serverTimestamp()
        ]
        
        if let expiresAt = expiresAt {
            updateData["subscriptionExpiresAt"] = Timestamp(date: expiresAt)
        }
        
        try await db.collection("users").document(uid).updateData(updateData)
        
        // Track subscription event
        try await trackEvent(uid: uid, eventName: "subscription_updated", parameters: [
            "status": status.rawValue,
            "expires_at": expiresAt?.timeIntervalSince1970 ?? 0
        ])
    }
    
    // MARK: - Data Export (GDPR Compliance)
    
    func exportUserData(uid: String) async throws -> [String: Any] {
        // Get all user data
        let userDoc = try await db.collection("users").document(uid).getDocument()
        let chatMessages = try await getChatHistory(uid: uid, limit: 1000)
        let moodEntries = try await getMoodEntries(uid: uid)
        let crisisEvents = try await getCrisisEvents(uid: uid)
        
        return [
            "user": userDoc.data() ?? [:],
            "chatMessages": chatMessages.map { ["role": $0.role.rawValue, "text": $0.text, "date": $0.date.timeIntervalSince1970] },
            "moodEntries": moodEntries,
            "crisisEvents": crisisEvents,
            "exportedAt": Date().timeIntervalSince1970
        ]
    }
    
    private func getMoodEntries(uid: String) async throws -> [[String: Any]] {
        let snapshot = try await db.collection("mood_entries")
            .whereField("userId", isEqualTo: uid)
            .order(by: "timestamp", descending: true)
            .getDocuments()
        
        return snapshot.documents.map { $0.data() }
    }
    
    private func getCrisisEvents(uid: String) async throws -> [[String: Any]] {
        let snapshot = try await db.collection("crisis_events")
            .whereField("userId", isEqualTo: uid)
            .order(by: "timestamp", descending: true)
            .getDocuments()
        
        return snapshot.documents.map { $0.data() }
    }
    
    // MARK: - Data Deletion (GDPR Compliance)
    
    func deleteAllUserData(uid: String) async throws {
        let batch = db.batch()
        
        // Delete user document
        batch.deleteDocument(db.collection("users").document(uid))
        
        // Delete chat messages
        let chatSnapshot = try await db.collection("chat_messages")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()
        
        for doc in chatSnapshot.documents {
            batch.deleteDocument(doc.reference)
        }
        
        // Delete mood entries
        let moodSnapshot = try await db.collection("mood_entries")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()
        
        for doc in moodSnapshot.documents {
            batch.deleteDocument(doc.reference)
        }
        
        // Delete crisis events
        let crisisSnapshot = try await db.collection("crisis_events")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()
        
        for doc in crisisSnapshot.documents {
            batch.deleteDocument(doc.reference)
        }
        
        // Delete analytics events
        let analyticsSnapshot = try await db.collection("analytics_events")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()
        
        for doc in analyticsSnapshot.documents {
            batch.deleteDocument(doc.reference)
        }
        
        try await batch.commit()
        
        // Delete Firebase Auth user
        if let currentUser = Auth.auth().currentUser, currentUser.uid == uid {
            try await currentUser.delete()
        }
        
        print("✅ All user data deleted for: \(uid)")
    }
}

// MARK: - Supporting Types
// Note: CrisisLevel and MoodTrendPoint are defined in Models.swift and APIRequests.swift

struct UserInsights {
    let averageMood: Double
    let totalCheckins: Int
    let currentStreak: Int
    let moodTrends: [MoodTrendPoint]
    let insights: [String]
}
