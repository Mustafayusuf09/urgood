//
//  DataMigrationService.swift
//  urgood
//
//  Migrates data from legacy global collections to namespaced user collections
//

import Foundation
import FirebaseFirestore
import os.log

private let log = Logger(subsystem: "com.urgood.urgood", category: "Migration")

@MainActor
class DataMigrationService {
    private let db = Firestore.firestore()
    
    // MARK: - Migration Status
    enum MigrationStatus {
        case notStarted
        case inProgress
        case completed
        case failed(Error)
    }
    
    // MARK: - Main Migration
    func migrateUserData(uid: String) async throws {
        log.info("🔄 Starting data migration for user: \(uid)")
        
        do {
            // Migrate in order: sessions, moods, insights, chat messages
            try await migrateSessions(uid: uid)
            try await migrateMoods(uid: uid)
            try await migrateInsights(uid: uid)
            try await migrateChatMessages(uid: uid)
            
            // Mark migration as complete
            try await markMigrationComplete(uid: uid)
            
            log.info("✅ Data migration completed for user: \(uid)")
        } catch {
            log.error("❌ Migration failed for user \(uid): \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Check Migration Status
    func needsMigration(uid: String) async throws -> Bool {
        // Check if migration marker exists
        let doc = try await db.collection("users").document(uid)
            .collection("settings").document("migration")
            .getDocument()
        
        if let data = doc.data(),
           let completed = data["migrationCompleted"] as? Bool,
           completed {
            return false
        }
        
        // Check if any legacy data exists for this user
        let hasLegacyData = try await checkForLegacyData(uid: uid)
        return hasLegacyData
    }
    
    private func checkForLegacyData(uid: String) async throws -> Bool {
        // Check legacy sessions
        let sessionsSnapshot = try await db.collection("sessions")
            .whereField("userId", isEqualTo: uid)
            .limit(to: 1)
            .getDocuments()
        
        if !sessionsSnapshot.documents.isEmpty {
            return true
        }
        
        // Check legacy moods
        let moodsSnapshot = try await db.collection("mood_entries")
            .whereField("userId", isEqualTo: uid)
            .limit(to: 1)
            .getDocuments()
        
        if !moodsSnapshot.documents.isEmpty {
            return true
        }
        
        // Check legacy insights
        let insightsSnapshot = try await db.collection("insights")
            .whereField("userId", isEqualTo: uid)
            .limit(to: 1)
            .getDocuments()
        
        if !insightsSnapshot.documents.isEmpty {
            return true
        }
        
        // Check legacy chat messages
        let messagesSnapshot = try await db.collection("chat_messages")
            .whereField("userId", isEqualTo: uid)
            .limit(to: 1)
            .getDocuments()
        
        return !messagesSnapshot.documents.isEmpty
    }
    
    // MARK: - Migrate Sessions
    private func migrateSessions(uid: String) async throws {
        log.info("🔄 Migrating sessions for user: \(uid)")
        
        // Fetch all legacy sessions for this user
        let snapshot = try await db.collection("sessions")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()
        
        guard !snapshot.documents.isEmpty else {
            log.info("ℹ️ No sessions to migrate for user: \(uid)")
            return
        }
        
        // Batch write to new location
        let batchSize = 500 // Firestore batch limit
        var currentBatch = db.batch()
        var operationCount = 0
        
        for document in snapshot.documents {
            var data = document.data()
            
            // Remove userId field (no longer needed in namespaced structure)
            data.removeValue(forKey: "userId")
            
            // Write to new location
            let newRef = db.collection("users").document(uid)
                .collection("sessions").document(document.documentID)
            currentBatch.setData(data, forDocument: newRef)
            
            operationCount += 1
            
            // Commit batch if we hit the limit
            if operationCount >= batchSize {
                try await currentBatch.commit()
                currentBatch = db.batch()
                operationCount = 0
            }
            
            // Delete from old location (in same batch)
            currentBatch.deleteDocument(document.reference)
            operationCount += 1
            
            if operationCount >= batchSize {
                try await currentBatch.commit()
                currentBatch = db.batch()
                operationCount = 0
            }
        }
        
        // Commit remaining operations
        if operationCount > 0 {
            try await currentBatch.commit()
        }
        
        log.info("✅ Migrated \(snapshot.documents.count) sessions for user: \(uid)")
    }
    
    // MARK: - Migrate Moods
    private func migrateMoods(uid: String) async throws {
        log.info("🔄 Migrating moods for user: \(uid)")
        
        let snapshot = try await db.collection("mood_entries")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()
        
        guard !snapshot.documents.isEmpty else {
            log.info("ℹ️ No moods to migrate for user: \(uid)")
            return
        }
        
        let batchSize = 500
        var currentBatch = db.batch()
        var operationCount = 0
        
        for document in snapshot.documents {
            var data = document.data()
            data.removeValue(forKey: "userId")
            
            // Rename timestamp to date if needed
            if let timestamp = data["timestamp"] as? Timestamp {
                data["date"] = timestamp
                data.removeValue(forKey: "timestamp")
            }
            
            let newRef = db.collection("users").document(uid)
                .collection("moods").document(document.documentID)
            currentBatch.setData(data, forDocument: newRef)
            operationCount += 1
            
            if operationCount >= batchSize {
                try await currentBatch.commit()
                currentBatch = db.batch()
                operationCount = 0
            }
            
            currentBatch.deleteDocument(document.reference)
            operationCount += 1
            
            if operationCount >= batchSize {
                try await currentBatch.commit()
                currentBatch = db.batch()
                operationCount = 0
            }
        }
        
        if operationCount > 0 {
            try await currentBatch.commit()
        }
        
        log.info("✅ Migrated \(snapshot.documents.count) moods for user: \(uid)")
    }
    
    // MARK: - Migrate Insights
    private func migrateInsights(uid: String) async throws {
        log.info("🔄 Migrating insights for user: \(uid)")
        
        let snapshot = try await db.collection("insights")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()
        
        guard !snapshot.documents.isEmpty else {
            log.info("ℹ️ No insights to migrate for user: \(uid)")
            return
        }
        
        let batchSize = 500
        var currentBatch = db.batch()
        var operationCount = 0
        
        for document in snapshot.documents {
            var data = document.data()
            data.removeValue(forKey: "userId")
            
            let newRef = db.collection("users").document(uid)
                .collection("insights").document(document.documentID)
            currentBatch.setData(data, forDocument: newRef)
            operationCount += 1
            
            if operationCount >= batchSize {
                try await currentBatch.commit()
                currentBatch = db.batch()
                operationCount = 0
            }
            
            currentBatch.deleteDocument(document.reference)
            operationCount += 1
            
            if operationCount >= batchSize {
                try await currentBatch.commit()
                currentBatch = db.batch()
                operationCount = 0
            }
        }
        
        if operationCount > 0 {
            try await currentBatch.commit()
        }
        
        log.info("✅ Migrated \(snapshot.documents.count) insights for user: \(uid)")
    }
    
    // MARK: - Migrate Chat Messages
    private func migrateChatMessages(uid: String) async throws {
        log.info("🔄 Migrating chat messages for user: \(uid)")
        
        let snapshot = try await db.collection("chat_messages")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()
        
        guard !snapshot.documents.isEmpty else {
            log.info("ℹ️ No chat messages to migrate for user: \(uid)")
            return
        }
        
        let batchSize = 500
        var currentBatch = db.batch()
        var operationCount = 0
        
        for document in snapshot.documents {
            var data = document.data()
            data.removeValue(forKey: "userId")
            
            let newRef = db.collection("users").document(uid)
                .collection("chat_messages").document(document.documentID)
            currentBatch.setData(data, forDocument: newRef)
            operationCount += 1
            
            if operationCount >= batchSize {
                try await currentBatch.commit()
                currentBatch = db.batch()
                operationCount = 0
            }
            
            currentBatch.deleteDocument(document.reference)
            operationCount += 1
            
            if operationCount >= batchSize {
                try await currentBatch.commit()
                currentBatch = db.batch()
                operationCount = 0
            }
        }
        
        if operationCount > 0 {
            try await currentBatch.commit()
        }
        
        log.info("✅ Migrated \(snapshot.documents.count) chat messages for user: \(uid)")
    }
    
    // MARK: - Mark Complete
    private func markMigrationComplete(uid: String) async throws {
        let data: [String: Any] = [
            "migrationCompleted": true,
            "migratedAt": Timestamp(date: Date()),
            "migrationVersion": "1.0"
        ]
        
        try await db.collection("users").document(uid)
            .collection("settings").document("migration")
            .setData(data)
        
        log.info("✅ Marked migration complete for user: \(uid)")
    }
    
    // MARK: - Rollback (Emergency Use Only)
    func rollbackMigration(uid: String) async throws {
        log.warning("⚠️ Rolling back migration for user: \(uid)")
        
        // This is for emergency use only - it doesn't restore deleted data
        // It only clears the migration marker
        
        try await db.collection("users").document(uid)
            .collection("settings").document("migration")
            .delete()
        
        log.info("✅ Migration marker cleared for user: \(uid)")
    }
}

// MARK: - Migration Errors
enum MigrationError: LocalizedError {
    case migrationFailed(String)
    case alreadyMigrated
    case noDataToMigrate
    
    var errorDescription: String? {
        switch self {
        case .migrationFailed(let reason):
            return "Migration failed: \(reason)"
        case .alreadyMigrated:
            return "Data already migrated"
        case .noDataToMigrate:
            return "No data to migrate"
        }
    }
}

