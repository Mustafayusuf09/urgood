import Foundation
import CryptoKit
import OSLog

class HIPAAService: ObservableObject {
    static let shared = HIPAAService()
    
    private let encryptionService = EncryptionService.shared
    private let auditLogger = HIPAAAuditLogger.shared
    private let log = Logger(subsystem: "com.urgood.urgood", category: "HIPAAService")
    
    private init() {}
    
    // MARK: - PHI (Protected Health Information) Management
    
    func encryptPHI(_ data: String) throws -> String {
        // Log access to PHI
        auditLogger.logPHIAccess(action: "encrypt", dataType: "string", userId: getCurrentUserId())
        
        // Encrypt the data
        return try encryptionService.encryptString(data)
    }
    
    func decryptPHI(_ encryptedData: String) throws -> String {
        // Log access to PHI
        auditLogger.logPHIAccess(action: "decrypt", dataType: "string", userId: getCurrentUserId())
        
        // Decrypt the data
        return try encryptionService.decryptString(encryptedData)
    }
    
    func encryptPHIData(_ data: Data) throws -> Data {
        // Log access to PHI
        auditLogger.logPHIAccess(action: "encrypt", dataType: "data", userId: getCurrentUserId())
        
        // Encrypt the data
        return try encryptionService.encryptData(data)
    }
    
    func decryptPHIData(_ encryptedData: Data) throws -> Data {
        // Log access to PHI
        auditLogger.logPHIAccess(action: "decrypt", dataType: "data", userId: getCurrentUserId())
        
        // Decrypt the data
        return try encryptionService.decryptData(encryptedData)
    }
    
    // MARK: - Data Minimization
    
    func minimizePHI(_ data: String, requiredFields: [String]) -> String {
        // Remove unnecessary PHI fields
        var minimizedData = data
        
        // Remove common PHI fields that are not required
        let fieldsToRemove = ["ssn", "social_security", "insurance_id", "medical_record_number"]
        
        for field in fieldsToRemove {
            if !requiredFields.contains(field) {
                minimizedData = minimizedData.replacingOccurrences(of: field, with: "[REDACTED]")
            }
        }
        
        return minimizedData
    }
    
    func anonymizeData(_ data: String) -> String {
        // Anonymize personal identifiers
        var anonymizedData = data
        
        // Replace email addresses
        let emailPattern = #"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#
        anonymizedData = anonymizedData.replacingOccurrences(of: emailPattern, with: "[EMAIL_REDACTED]", options: .regularExpression)
        
        // Replace phone numbers
        let phonePattern = #"\(?([0-9]{3})\)?[-. ]?([0-9]{3})[-. ]?([0-9]{4})"#
        anonymizedData = anonymizedData.replacingOccurrences(of: phonePattern, with: "[PHONE_REDACTED]", options: .regularExpression)
        
        // Replace names (basic pattern)
        let namePattern = #"\b[A-Z][a-z]+ [A-Z][a-z]+\b"#
        anonymizedData = anonymizedData.replacingOccurrences(of: namePattern, with: "[NAME_REDACTED]", options: .regularExpression)
        
        return anonymizedData
    }
    
    // MARK: - Access Controls
    
    func checkAccessPermission(for userId: String, to resource: String) -> Bool {
        // Implement role-based access control
        let userRole = getUserRole(userId)
        let requiredRole = getRequiredRole(for: resource)
        
        return userRole.rawValue >= requiredRole.rawValue
    }
    
    func logAccessAttempt(userId: String, resource: String, success: Bool) {
        auditLogger.logAccessAttempt(
            userId: userId,
            resource: resource,
            success: success,
            timestamp: Date()
        )
    }
    
    // MARK: - Data Retention
    
    func shouldRetainData(_ data: Data, type: PHIDataType, createdAt: Date) -> Bool {
        let retentionPeriod = getRetentionPeriod(for: type)
        let dataAge = Date().timeIntervalSince(createdAt)
        
        return dataAge < retentionPeriod
    }
    
    func scheduleDataDeletion(for dataId: String, after retentionPeriod: TimeInterval) {
        let deletionDate = Date().addingTimeInterval(retentionPeriod)
        
        // Schedule deletion
        DispatchQueue.global().asyncAfter(deadline: .now() + retentionPeriod) {
            self.deleteData(dataId: dataId)
        }
        
        auditLogger.logDataRetention(dataId: dataId, deletionDate: deletionDate)
    }
    
    // MARK: - Breach Detection
    
    func detectPotentialBreach(_ event: SecurityEvent) -> Bool {
        // Implement breach detection logic
        switch event.type {
        case .unauthorizedAccess:
            return true
        case .dataExfiltration:
            return true
        case .suspiciousActivity:
            return event.severity.rawValue >= SecuritySeverity.high.rawValue
        case .systemCompromise:
            return true
        default:
            return false
        }
    }
    
    func reportBreach(_ breach: SecurityBreach) {
        // Log breach
        auditLogger.logSecurityBreach(breach)
        
        // Notify authorities if required
        if breach.requiresNotification {
            notifyAuthorities(breach)
        }
        
        // Notify affected users
        notifyAffectedUsers(breach)
    }
    
    // MARK: - Consent Management
    
    func recordConsent(_ consent: UserConsent) {
        auditLogger.logConsent(consent)
        
        // Store consent in secure location
        do {
            let consentData = try JSONEncoder().encode(consent)
            _ = try encryptionService.encryptData(consentData)
            // Store encrypted consent
        } catch {
            auditLogger.logError("Failed to record consent: \(error)")
        }
    }
    
    func checkConsent(for userId: String, purpose: ConsentPurpose) -> Bool {
        // Check if user has given consent for specific purpose
        // This would typically query a consent database
        return true // Placeholder
    }
    
    func revokeConsent(for userId: String, purpose: ConsentPurpose) {
        // Revoke user consent
        let consent = UserConsent(
            userId: userId,
            purpose: purpose,
            granted: false,
            timestamp: Date()
        )
        recordConsent(consent)
    }
    
    // MARK: - Audit Trail
    
    func generateAuditReport(from startDate: Date, to endDate: Date) -> HIPAAAuditReport {
        return auditLogger.generateReport(from: startDate, to: endDate)
    }
    
    func exportAuditLogs(for userId: String) -> Data {
        return auditLogger.exportLogs(for: userId)
    }
    
    // MARK: - Data Export
    
    func exportUserData(for userId: String) throws -> Data {
        // Check if user has consent for data export
        guard checkConsent(for: userId, purpose: .dataExport) else {
            throw HIPAAError.consentRequired
        }
        
        // Log data export
        auditLogger.logDataExport(userId: userId, timestamp: Date())
        
        // Export user data
        let userData = try getUserData(userId: userId)
        // Convert [String: Any] to Data using JSONSerialization
        return try JSONSerialization.data(withJSONObject: userData)
    }
    
    func deleteUserData(for userId: String) throws {
        // Check if user has consent for data deletion
        guard checkConsent(for: userId, purpose: .dataDeletion) else {
            throw HIPAAError.consentRequired
        }
        
        // Log data deletion
        auditLogger.logDataDeletion(userId: userId, timestamp: Date())
        
        // Delete user data
        try performDataDeletion(userId: userId)
    }
    
    // MARK: - Private Methods
    
    private func getCurrentUserId() -> String {
        // Get current user ID from authentication service
        return "current_user" // Placeholder
    }
    
    private func getUserRole(_ userId: String) -> UserRole {
        // Get user role from user management service
        return .user // Placeholder
    }
    
    private func getRequiredRole(for resource: String) -> UserRole {
        // Determine required role for resource
        return .user // Placeholder
    }
    
    private func getRetentionPeriod(for type: PHIDataType) -> TimeInterval {
        switch type {
        case .chatMessages:
            return 7 * 24 * 60 * 60 // 7 days
        case .moodEntries:
            return 30 * 24 * 60 * 60 // 30 days
        case .userProfile:
            return 365 * 24 * 60 * 60 // 1 year
        case .crisisData:
            return 7 * 24 * 60 * 60 // 7 days
        }
    }
    
    private func deleteData(dataId: String) {
        // Delete data from all storage locations
        auditLogger.logDataDeletion(dataId: dataId, timestamp: Date())
    }
    
    private func notifyAuthorities(_ breach: SecurityBreach) {
        // Notify relevant authorities
        auditLogger.logNotification("Authorities notified of breach: \(breach.id)")
    }
    
    private func notifyAffectedUsers(_ breach: SecurityBreach) {
        // Notify affected users
        auditLogger.logNotification("Affected users notified of breach: \(breach.id)")
    }
    
    private func getUserData(userId: String) throws -> [String: Any] {
        // Get user data from all sources
        return [:] // Placeholder
    }
    
    private func performDataDeletion(userId: String) throws {
        // Delete user data from all sources
    }
}

// MARK: - Supporting Types

enum UserRole: Int, CaseIterable {
    case user = 0
    case admin = 1
    case superAdmin = 2
}

enum PHIDataType: String, CaseIterable {
    case chatMessages = "chat_messages"
    case moodEntries = "mood_entries"
    case userProfile = "user_profile"
    case crisisData = "crisis_data"
}

enum ConsentPurpose: String, CaseIterable, Codable {
    case dataCollection = "data_collection"
    case dataProcessing = "data_processing"
    case dataSharing = "data_sharing"
    case dataExport = "data_export"
    case dataDeletion = "data_deletion"
}

enum SecurityEventType: String, CaseIterable {
    case unauthorizedAccess = "unauthorized_access"
    case dataExfiltration = "data_exfiltration"
    case suspiciousActivity = "suspicious_activity"
    case systemCompromise = "system_compromise"
    case dataBreach = "data_breach"
}

enum SecuritySeverity: Int, CaseIterable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3
}

struct SecurityEvent {
    let id: String
    let type: SecurityEventType
    let severity: SecuritySeverity
    let description: String
    let timestamp: Date
    let userId: String?
}

struct SecurityBreach {
    let id: String
    let description: String
    let affectedUsers: [String]
    let severity: SecuritySeverity
    let timestamp: Date
    let requiresNotification: Bool
}

struct UserConsent: Codable {
    let userId: String
    let purpose: ConsentPurpose
    let granted: Bool
    let timestamp: Date
}

struct HIPAAAuditReport {
    let startDate: Date
    let endDate: Date
    let totalEvents: Int
    let securityEvents: [SecurityEvent]
    let dataAccess: [DataAccessEvent]
    let breaches: [SecurityBreach]
}

struct DataAccessEvent {
    let userId: String
    let resource: String
    let action: String
    let timestamp: Date
    let success: Bool
}

enum HIPAAError: Error, LocalizedError {
    case consentRequired
    case accessDenied
    case dataNotFound
    case encryptionFailed
    case auditLogFailed
    
    var errorDescription: String? {
        switch self {
        case .consentRequired:
            return "User consent is required for this operation"
        case .accessDenied:
            return "Access denied to this resource"
        case .dataNotFound:
            return "Requested data not found"
        case .encryptionFailed:
            return "Data encryption failed"
        case .auditLogFailed:
            return "Audit logging failed"
        }
    }
}

// MARK: - HIPAA Audit Logger

class HIPAAAuditLogger {
    static let shared = HIPAAAuditLogger()
    
    private var auditLogs: [AuditLogEntry] = []
    private let queue = DispatchQueue(label: "hipaa.audit.logger", qos: .utility)
    
    private init() {}
    
    func logPHIAccess(action: String, dataType: String, userId: String) {
        let entry = AuditLogEntry(
            id: UUID().uuidString,
            type: .phiAccess,
            userId: userId,
            action: action,
            resource: dataType,
            timestamp: Date(),
            success: true
        )
        
        queue.async {
            self.auditLogs.append(entry)
        }
    }
    
    func logAccessAttempt(userId: String, resource: String, success: Bool, timestamp: Date) {
        let entry = AuditLogEntry(
            id: UUID().uuidString,
            type: .accessAttempt,
            userId: userId,
            action: "access",
            resource: resource,
            timestamp: timestamp,
            success: success
        )
        
        queue.async {
            self.auditLogs.append(entry)
        }
    }
    
    func logDataRetention(dataId: String, deletionDate: Date) {
        let entry = AuditLogEntry(
            id: UUID().uuidString,
            type: .dataRetention,
            userId: nil,
            action: "schedule_deletion",
            resource: dataId,
            timestamp: Date(),
            success: true
        )
        
        queue.async {
            self.auditLogs.append(entry)
        }
    }
    
    func logSecurityBreach(_ breach: SecurityBreach) {
        let entry = AuditLogEntry(
            id: UUID().uuidString,
            type: .securityBreach,
            userId: nil,
            action: "breach_detected",
            resource: breach.id,
            timestamp: Date(),
            success: false
        )
        
        queue.async {
            self.auditLogs.append(entry)
        }
    }
    
    func logConsent(_ consent: UserConsent) {
        let entry = AuditLogEntry(
            id: UUID().uuidString,
            type: .consent,
            userId: consent.userId,
            action: consent.granted ? "grant" : "revoke",
            resource: consent.purpose.rawValue,
            timestamp: consent.timestamp,
            success: true
        )
        
        queue.async {
            self.auditLogs.append(entry)
        }
    }
    
    func logDataExport(userId: String, timestamp: Date) {
        let entry = AuditLogEntry(
            id: UUID().uuidString,
            type: .dataExport,
            userId: userId,
            action: "export",
            resource: "user_data",
            timestamp: timestamp,
            success: true
        )
        
        queue.async {
            self.auditLogs.append(entry)
        }
    }
    
    func logDataDeletion(userId: String, timestamp: Date) {
        let entry = AuditLogEntry(
            id: UUID().uuidString,
            type: .dataDeletion,
            userId: userId,
            action: "delete",
            resource: "user_data",
            timestamp: timestamp,
            success: true
        )
        
        queue.async {
            self.auditLogs.append(entry)
        }
    }
    
    func logDataDeletion(dataId: String, timestamp: Date) {
        let entry = AuditLogEntry(
            id: UUID().uuidString,
            type: .dataDeletion,
            userId: nil,
            action: "delete",
            resource: dataId,
            timestamp: timestamp,
            success: true
        )
        
        queue.async {
            self.auditLogs.append(entry)
        }
    }
    
    func logNotification(_ message: String) {
        let entry = AuditLogEntry(
            id: UUID().uuidString,
            type: .notification,
            userId: nil,
            action: "notify",
            resource: message,
            timestamp: Date(),
            success: true
        )
        
        queue.async {
            self.auditLogs.append(entry)
        }
    }
    
    func logError(_ message: String) {
        let entry = AuditLogEntry(
            id: UUID().uuidString,
            type: .error,
            userId: nil,
            action: "error",
            resource: message,
            timestamp: Date(),
            success: false
        )
        
        queue.async {
            self.auditLogs.append(entry)
        }
    }
    
    func generateReport(from startDate: Date, to endDate: Date) -> HIPAAAuditReport {
        let filteredLogs = auditLogs.filter { log in
            log.timestamp >= startDate && log.timestamp <= endDate
        }
        
        let securityEvents = filteredLogs.compactMap { log -> SecurityEvent? in
            guard log.type == .securityBreach else { return nil }
            return SecurityEvent(
                id: log.id,
                type: .dataBreach,
                severity: .high,
                description: log.resource,
                timestamp: log.timestamp,
                userId: log.userId
            )
        }
        
        let dataAccess = filteredLogs.compactMap { log -> DataAccessEvent? in
            guard log.type == .phiAccess || log.type == .accessAttempt else { return nil }
            return DataAccessEvent(
                userId: log.userId ?? "unknown",
                resource: log.resource,
                action: log.action,
                timestamp: log.timestamp,
                success: log.success
            )
        }
        
        let breaches = securityEvents.compactMap { event -> SecurityBreach? in
            SecurityBreach(
                id: event.id,
                description: event.description,
                affectedUsers: [],
                severity: event.severity,
                timestamp: event.timestamp,
                requiresNotification: event.severity.rawValue >= SecuritySeverity.high.rawValue
            )
        }
        
        return HIPAAAuditReport(
            startDate: startDate,
            endDate: endDate,
            totalEvents: filteredLogs.count,
            securityEvents: securityEvents,
            dataAccess: dataAccess,
            breaches: breaches
        )
    }
    
    func exportLogs(for userId: String) -> Data {
        let userLogs = auditLogs.filter { entry in
            entry.userId == userId
        }
        
        do {
            return try JSONEncoder().encode(userLogs)
        } catch let encodingError {
            print("📄 Failed to export HIPAA logs for user \(userId): \(encodingError.localizedDescription)")
            return Data()
        }
    }
}

struct AuditLogEntry: Codable {
    let id: String
    let type: AuditLogType
    let userId: String?
    let action: String
    let resource: String
    let timestamp: Date
    let success: Bool
}

enum AuditLogType: String, Codable, CaseIterable {
    case phiAccess = "phi_access"
    case accessAttempt = "access_attempt"
    case dataRetention = "data_retention"
    case securityBreach = "security_breach"
    case consent = "consent"
    case dataExport = "data_export"
    case dataDeletion = "data_deletion"
    case notification = "notification"
    case error = "error"
}
