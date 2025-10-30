import Foundation
import Security
import OSLog

enum SecureNonceGenerator {
    private static let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    private static let log = Logger(subsystem: "com.urgood.urgood", category: "SecureNonceGenerator")
    
    static func randomNonce(length: Int = 32) throws -> String {
        precondition(length > 0)
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randomBytes = try randomBytes(count: 16)
            for random in randomBytes {
                guard remainingLength > 0 else { break }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private static func randomBytes(count: Int) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        guard status == errSecSuccess else {
            log.error("🔐 SecRandomCopyBytes failed with status \(status, privacy: .public)")
            throw SecureNonceError.randomGenerationFailed(status: status)
        }
        return bytes
    }
}

enum SecureNonceError: LocalizedError {
    case randomGenerationFailed(status: OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .randomGenerationFailed(let status):
            return "Unable to generate secure nonce (status \(status))"
        }
    }
}
