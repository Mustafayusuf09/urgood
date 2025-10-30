import Foundation
import CryptoKit
import Security

class EncryptionService: ObservableObject {
    static let shared = EncryptionService()
    
    private let keychain = KeychainService()
    private var encryptionKey: SymmetricKey?
    
    private init() {
        loadOrCreateEncryptionKey()
    }
    
    // MARK: - Key Management
    
    private func loadOrCreateEncryptionKey() {
        if let keyData = keychain.getData(forKey: "encryption_key") {
            encryptionKey = SymmetricKey(data: keyData)
        } else {
            // Generate new encryption key
            encryptionKey = SymmetricKey(size: .bits256)
            if let keyData = encryptionKey?.data {
                keychain.setData(keyData, forKey: "encryption_key")
            }
        }
    }
    
    // MARK: - String Encryption/Decryption
    
    func encryptString(_ string: String) throws -> String {
        guard let key = encryptionKey else {
            throw EncryptionError.noKeyAvailable
        }
        
        guard let data = string.data(using: .utf8) else {
            throw EncryptionError.invalidData
        }
        
        let sealedBox = try AES.GCM.seal(data, using: key)
        let encryptedData = sealedBox.combined
        
        guard let encryptedData = encryptedData else {
            throw EncryptionError.encryptionFailed
        }
        
        return encryptedData.base64EncodedString()
    }
    
    func decryptString(_ encryptedString: String) throws -> String {
        guard let key = encryptionKey else {
            throw EncryptionError.noKeyAvailable
        }
        
        guard let encryptedData = Data(base64Encoded: encryptedString) else {
            throw EncryptionError.invalidData
        }
        
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        
        guard let decryptedString = String(data: decryptedData, encoding: .utf8) else {
            throw EncryptionError.decryptionFailed
        }
        
        return decryptedString
    }
    
    // MARK: - Data Encryption/Decryption
    
    func encryptData(_ data: Data) throws -> Data {
        guard let key = encryptionKey else {
            throw EncryptionError.noKeyAvailable
        }
        
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let encryptedData = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }
        
        return encryptedData
    }
    
    func decryptData(_ encryptedData: Data) throws -> Data {
        guard let key = encryptionKey else {
            throw EncryptionError.noKeyAvailable
        }
        
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: key)
    }
    
    // MARK: - Chat Message Encryption
    
    func encryptChatMessage(_ message: ChatMessage) throws -> EncryptedChatMessage {
        let messageData = try JSONEncoder().encode(message)
        let encryptedData = try encryptData(messageData)
        
        return EncryptedChatMessage(
            id: message.id,
            encryptedData: encryptedData,
            timestamp: message.date
        )
    }
    
    func decryptChatMessage(_ encryptedMessage: EncryptedChatMessage) throws -> ChatMessage {
        let decryptedData = try decryptData(encryptedMessage.encryptedData)
        return try JSONDecoder().decode(ChatMessage.self, from: decryptedData)
    }
    
    // MARK: - Mood Entry Encryption
    
    func encryptMoodEntry(_ entry: MoodEntry) throws -> EncryptedMoodEntry {
        let entryData = try JSONEncoder().encode(entry)
        let encryptedData = try encryptData(entryData)
        
        return EncryptedMoodEntry(
            id: entry.id,
            encryptedData: encryptedData,
            timestamp: entry.date
        )
    }
    
    func decryptMoodEntry(_ encryptedEntry: EncryptedMoodEntry) throws -> MoodEntry {
        let decryptedData = try decryptData(encryptedEntry.encryptedData)
        return try JSONDecoder().decode(MoodEntry.self, from: decryptedData)
    }
    
    // MARK: - User Data Encryption
    
    func encryptUserData(_ user: User) throws -> EncryptedUserData {
        let userData = try JSONEncoder().encode(user)
        let encryptedData = try encryptData(userData)
        
        return EncryptedUserData(
            id: user.uid,
            encryptedData: encryptedData,
            timestamp: Date()
        )
    }
    
    func decryptUserData(_ encryptedUser: EncryptedUserData) throws -> User {
        let decryptedData = try decryptData(encryptedUser.encryptedData)
        return try JSONDecoder().decode(User.self, from: decryptedData)
    }
    
    // MARK: - File Encryption
    
    func encryptFile(at sourceURL: URL, to destinationURL: URL) throws {
        let data = try Data(contentsOf: sourceURL)
        let encryptedData = try encryptData(data)
        try encryptedData.write(to: destinationURL)
    }
    
    func decryptFile(at sourceURL: URL, to destinationURL: URL) throws {
        let encryptedData = try Data(contentsOf: sourceURL)
        let decryptedData = try decryptData(encryptedData)
        try decryptedData.write(to: destinationURL)
    }
    
    // MARK: - Key Rotation
    
    func rotateEncryptionKey() throws {
        // Generate new key
        let newKey = SymmetricKey(size: .bits256)
        
        // Store new key
        let keyData = newKey.withUnsafeBytes { Data($0) }
        if !keyData.isEmpty {
            keychain.setData(keyData, forKey: "encryption_key")
        }
        
        // Update current key
        encryptionKey = newKey
    }
    
    // MARK: - Key Export/Import
    
    func exportEncryptionKey() throws -> Data {
        guard let key = encryptionKey else {
            throw EncryptionError.noKeyAvailable
        }
        
        return key.data
    }
    
    func importEncryptionKey(_ keyData: Data) throws {
        let key = SymmetricKey(data: keyData)
        keychain.setData(keyData, forKey: "encryption_key")
        encryptionKey = key
    }
    
    // MARK: - Security Utilities
    
    func generateSecureRandomString(length: Int) -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
        var result = ""
        
        for _ in 0..<length {
            let randomIndex = Int.random(in: 0..<characters.count)
            let character = characters[characters.index(characters.startIndex, offsetBy: randomIndex)]
            result.append(character)
        }
        
        return result
    }
    
    func generateSecureRandomData(length: Int) -> Data {
        var data = Data(count: length)
        let result = data.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, length, bytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        
        guard result == errSecSuccess else {
            // Fallback to random generation
            return Data((0..<length).map { _ in UInt8.random(in: 0...255) })
        }
        
        return data
    }
    
    // MARK: - Hash Functions
    
    func hashString(_ string: String) -> String {
        let data = string.data(using: .utf8) ?? Data()
        let hashed = SHA256.hash(data: data)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    func hashData(_ data: Data) -> String {
        let hashed = SHA256.hash(data: data)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Data Integrity
    
    func createHMAC(for data: Data) throws -> String {
        guard let key = encryptionKey else {
            throw EncryptionError.noKeyAvailable
        }
        
        let hmac = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return Data(hmac).base64EncodedString()
    }
    
    func verifyHMAC(_ hmac: String, for data: Data) throws -> Bool {
        guard let key = encryptionKey else {
            throw EncryptionError.noKeyAvailable
        }
        
        guard let hmacData = Data(base64Encoded: hmac) else {
            return false
        }
        
        let expectedHMAC = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return hmacData == Data(expectedHMAC)
    }
}

// MARK: - Supporting Types

enum EncryptionError: Error, LocalizedError {
    case noKeyAvailable
    case invalidData
    case encryptionFailed
    case decryptionFailed
    case keyGenerationFailed
    
    var errorDescription: String? {
        switch self {
        case .noKeyAvailable:
            return "No encryption key available"
        case .invalidData:
            return "Invalid data provided"
        case .encryptionFailed:
            return "Encryption failed"
        case .decryptionFailed:
            return "Decryption failed"
        case .keyGenerationFailed:
            return "Key generation failed"
        }
    }
}

struct EncryptedChatMessage: Codable {
    let id: UUID
    let encryptedData: Data
    let timestamp: Date
}

struct EncryptedMoodEntry: Codable {
    let id: UUID
    let encryptedData: Data
    let timestamp: Date
}

struct EncryptedUserData: Codable {
    let id: String
    let encryptedData: Data
    let timestamp: Date
}

// MARK: - Keychain Service

class KeychainService {
    private let service = "com.urgood.encryption"
    
    func setData(_ data: Data, forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func getData(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            return nil
        }
        
        return result as? Data
    }
    
    func deleteData(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - SymmetricKey Extension

extension SymmetricKey {
    var data: Data {
        return withUnsafeBytes { Data($0) }
    }
}
