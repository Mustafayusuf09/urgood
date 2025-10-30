import Foundation
import FirebaseAuth
import FirebaseFirestore
import CryptoKit

class FirebaseSecurityService: ObservableObject {
    static let shared = FirebaseSecurityService()
    
    private let db = Firestore.firestore()
    private var rateLimitCache: [String: RateLimitInfo] = [:]
    
    private init() {}
    
    // MARK: - Input Validation and Sanitization
    
    func validateAndSanitizeMessage(_ message: String) throws -> String {
        // Length validation
        guard message.count >= 1 && message.count <= 4000 else {
            throw ValidationError.invalidLength
        }
        
        // Content sanitization
        var sanitized = message
        
        // Remove potential XSS
        sanitized = sanitized.replacingOccurrences(of: "<script", with: "&lt;script", options: .caseInsensitive)
        sanitized = sanitized.replacingOccurrences(of: "</script>", with: "&lt;/script&gt;", options: .caseInsensitive)
        
        // Filter sensitive information
        sanitized = filterSensitiveData(sanitized)
        
        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func validateMoodEntry(mood: Int, tags: [String], notes: String?) throws -> (Int, [String], String?) {
        // Mood validation
        guard mood >= 1 && mood <= 5 else {
            throw ValidationError.invalidMoodRange
        }
        
        // Tags validation
        guard tags.count <= 10 else {
            throw ValidationError.tooManyTags
        }
        
        let validatedTags = tags.compactMap { tag -> String? in
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.count <= 50 ? trimmed : nil
        }
        
        // Notes validation
        let validatedNotes = notes?.count ?? 0 <= 1000 ? notes : String(notes?.prefix(1000) ?? "")
        
        return (mood, validatedTags, validatedNotes)
    }
    
    private func filterSensitiveData(_ text: String) -> String {
        var filtered = text
        
        // SSN pattern
        let ssnPattern = #"\b\d{3}-\d{2}-\d{4}\b"#
        filtered = filtered.replacingOccurrences(of: ssnPattern, with: "[REDACTED-SSN]", options: .regularExpression)
        
        // Credit card pattern
        let ccPattern = #"\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b"#
        filtered = filtered.replacingOccurrences(of: ccPattern, with: "[REDACTED-CC]", options: .regularExpression)
        
        // Email pattern (partial redaction)
        let emailPattern = #"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b"#
        filtered = filtered.replacingOccurrences(of: emailPattern, with: "[REDACTED-EMAIL]", options: .regularExpression)
        
        // Phone number pattern
        let phonePattern = #"\b\d{3}[\s-]?\d{3}[\s-]?\d{4}\b"#
        filtered = filtered.replacingOccurrences(of: phonePattern, with: "[REDACTED-PHONE]", options: .regularExpression)
        
        return filtered
    }
    
    // MARK: - Rate Limiting
    
    func checkRateLimit(for userId: String, action: String, limit: Int = 10, windowMinutes: Int = 1) async throws {
        let key = "\(userId):\(action)"
        let now = Date()
        let windowStart = now.addingTimeInterval(-TimeInterval(windowMinutes * 60))
        
        // Clean old entries
        rateLimitCache = rateLimitCache.filter { $0.value.lastReset > windowStart }
        
        if var info = rateLimitCache[key] {
            if info.lastReset < windowStart {
                // Reset window
                info.count = 1
                info.lastReset = now
            } else {
                info.count += 1
            }
            
            rateLimitCache[key] = info
            
            if info.count > limit {
                throw SecurityError.rateLimitExceeded(resetTime: info.lastReset.addingTimeInterval(TimeInterval(windowMinutes * 60)))
            }
        } else {
            rateLimitCache[key] = RateLimitInfo(count: 1, lastReset: now)
        }
    }
    
    // MARK: - Crisis Content Detection
    
    func detectCrisisContent(_ message: String) -> CrisisDetectionResult {
        let lowercaseMessage = message.lowercased()
        
        // Critical keywords
        let criticalKeywords = [
            "suicide", "kill myself", "end my life", "want to die",
            "planning to hurt", "going to hurt myself", "end it all"
        ]
        
        // High risk keywords
        let highKeywords = [
            "hurt myself", "self harm", "cutting", "overdose",
            "jump off", "can't go on", "no point living"
        ]
        
        // Medium risk keywords
        let mediumKeywords = [
            "hopeless", "worthless", "giving up", "can't take it",
            "everything is pointless", "nobody cares"
        ]
        
        // Low risk keywords
        let lowKeywords = [
            "depressed", "sad", "down", "upset", "anxious", "worried"
        ]
        
        for keyword in criticalKeywords {
            if lowercaseMessage.contains(keyword) {
                return CrisisDetectionResult(isCrisis: true, level: .high, matchedKeywords: [keyword])
            }
        }
        
        for keyword in highKeywords {
            if lowercaseMessage.contains(keyword) {
                return CrisisDetectionResult(isCrisis: true, level: .high, matchedKeywords: [keyword])
            }
        }
        
        for keyword in mediumKeywords {
            if lowercaseMessage.contains(keyword) {
                return CrisisDetectionResult(isCrisis: true, level: .medium, matchedKeywords: [keyword])
            }
        }
        
        for keyword in lowKeywords {
            if lowercaseMessage.contains(keyword) {
                return CrisisDetectionResult(isCrisis: false, level: .low, matchedKeywords: [keyword])
            }
        }
        
        return CrisisDetectionResult(isCrisis: false, level: .low, matchedKeywords: [])
    }
    
    // MARK: - Authentication Security
    
    func validateAuthenticationAttempt(email: String, from ipAddress: String? = nil) async throws {
        // Check for too many failed attempts
        try await checkRateLimit(for: email, action: "auth_attempt", limit: 5, windowMinutes: 15)
        
        // Log authentication attempt
        await logSecurityEvent(
            type: "auth_attempt",
            userId: nil,
            details: [
                "email": email,
                "ip_address": ipAddress ?? "unknown",
                "timestamp": Date().timeIntervalSince1970
            ]
        )
    }
    
    func logFailedAuthentication(email: String, reason: String, ipAddress: String? = nil) async {
        await logSecurityEvent(
            type: "auth_failed",
            userId: nil,
            details: [
                "email": email,
                "reason": reason,
                "ip_address": ipAddress ?? "unknown",
                "timestamp": Date().timeIntervalSince1970
            ]
        )
    }
    
    func logSuccessfulAuthentication(userId: String, email: String, ipAddress: String? = nil) async {
        await logSecurityEvent(
            type: "auth_success",
            userId: userId,
            details: [
                "email": email,
                "ip_address": ipAddress ?? "unknown",
                "timestamp": Date().timeIntervalSince1970
            ]
        )
    }
    
    // MARK: - Data Access Logging
    
    func logDataAccess(userId: String, resource: String, action: String) async {
        await logSecurityEvent(
            type: "data_access",
            userId: userId,
            details: [
                "resource": resource,
                "action": action,
                "timestamp": Date().timeIntervalSince1970
            ]
        )
    }
    
    func logSensitiveDataAccess(userId: String, dataType: String, reason: String) async {
        await logSecurityEvent(
            type: "sensitive_data_access",
            userId: userId,
            details: [
                "data_type": dataType,
                "reason": reason,
                "timestamp": Date().timeIntervalSince1970
            ]
        )
    }
    
    // MARK: - Security Event Logging
    
    private func logSecurityEvent(type: String, userId: String?, details: [String: Any]) async {
        let eventData: [String: Any] = [
            "type": type,
            "userId": userId ?? "",
            "details": details,
            "timestamp": FieldValue.serverTimestamp(),
            "platform": "ios",
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        ]
        
        do {
            try await db.collection("security_events").addDocument(data: eventData)
        } catch {
            print("Failed to log security event: \(error)")
        }
    }
    
    // MARK: - Data Encryption Helpers
    
    func encryptSensitiveData(_ data: String) throws -> String {
        guard let keyData = "UrGoodEncryptionKey2024!".data(using: .utf8) else {
            throw SecurityError.encryptionFailed
        }
        
        let key = SHA256.hash(data: keyData)
        let keyData32 = Data(key.prefix(32))
        
        guard let dataToEncrypt = data.data(using: .utf8) else {
            throw SecurityError.encryptionFailed
        }
        
        let sealedBox = try AES.GCM.seal(dataToEncrypt, using: SymmetricKey(data: keyData32))
        return sealedBox.combined?.base64EncodedString() ?? ""
    }
    
    func decryptSensitiveData(_ encryptedData: String) throws -> String {
        guard let keyData = "UrGoodEncryptionKey2024!".data(using: .utf8),
              let combinedData = Data(base64Encoded: encryptedData) else {
            throw SecurityError.decryptionFailed
        }
        
        let key = SHA256.hash(data: keyData)
        let keyData32 = Data(key.prefix(32))
        
        let sealedBox = try AES.GCM.SealedBox(combined: combinedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: SymmetricKey(data: keyData32))
        
        return String(data: decryptedData, encoding: .utf8) ?? ""
    }
    
    // MARK: - Compliance Helpers
    
    func generateDataProcessingLog(userId: String, action: String, dataTypes: [String], legalBasis: String) async {
        let logData: [String: Any] = [
            "userId": userId,
            "action": action,
            "dataTypes": dataTypes,
            "legalBasis": legalBasis,
            "timestamp": FieldValue.serverTimestamp(),
            "processor": "UrGood iOS App"
        ]
        
        do {
            try await db.collection("data_processing_logs").addDocument(data: logData)
        } catch {
            print("Failed to log data processing: \(error)")
        }
    }
}

// MARK: - Supporting Types

struct RateLimitInfo {
    var count: Int
    var lastReset: Date
}

struct CrisisDetectionResult {
    let isCrisis: Bool
    let level: CrisisLevel
    let matchedKeywords: [String]
}

enum ValidationError: LocalizedError {
    case invalidLength
    case invalidMoodRange
    case tooManyTags
    case invalidCharacters
    
    var errorDescription: String? {
        switch self {
        case .invalidLength:
            return "Content length is invalid"
        case .invalidMoodRange:
            return "Mood must be between 1 and 5"
        case .tooManyTags:
            return "Too many tags (maximum 10)"
        case .invalidCharacters:
            return "Contains invalid characters"
        }
    }
}

enum SecurityError: LocalizedError {
    case rateLimitExceeded(resetTime: Date)
    case encryptionFailed
    case decryptionFailed
    case unauthorizedAccess
    
    var errorDescription: String? {
        switch self {
        case .rateLimitExceeded(let resetTime):
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Rate limit exceeded. Try again after \(formatter.string(from: resetTime))"
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        case .unauthorizedAccess:
            return "Unauthorized access attempt"
        }
    }
}
