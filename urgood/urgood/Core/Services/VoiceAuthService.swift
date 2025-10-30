import Foundation
import FirebaseAuth

/// Service to handle voice chat authorization with backend API
@MainActor
final class VoiceAuthService: ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var isAuthorized = false
    @Published private(set) var currentSessionId: String?
    @Published private(set) var error: String?
    @Published private(set) var softCapReached = false
    
    // MARK: - Private Properties
    private var sessionStartTime: Date?
    private var messageCount: Int = 0
    
    // MARK: - Public Methods
    
    /// Get OpenAI API key from backend authorization endpoint
    func getVoiceChatAPIKey() async throws -> String {
        print("🔑 [VoiceAuth] Getting API key for voice chat...")
        
        // Check if user is authenticated
        guard let user = Auth.auth().currentUser else {
            print("❌ [VoiceAuth] No authenticated user found")
            throw VoiceAuthError.notAuthenticated
        }
        
        // Get Firebase ID token
        let idToken = try await user.getIDToken()
        
        // Call backend authorize endpoint
        guard let url = URL(string: EnvironmentConfig.Endpoints.voiceAuthorize) else {
            throw VoiceAuthError.serviceUnavailable
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let sessionId = UUID().uuidString
        let body: [String: Any] = [
            "sessionId": sessionId,
            "userId": user.uid
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoiceAuthError.networkError("Invalid response")
        }
        
        if httpResponse.statusCode == 403 {
            print("❌ [VoiceAuth] Premium subscription required")
            throw VoiceAuthError.premiumRequired
        }
        
        guard httpResponse.statusCode == 200 else {
            throw VoiceAuthError.networkError("Server returned status \(httpResponse.statusCode)")
        }
        
        // Parse response
        let responseData = try JSONDecoder().decode(VoiceAuthResponse.self, from: data)
        
        guard responseData.authorized else {
            throw VoiceAuthError.unauthorized
        }
        
        // Check for soft cap
        self.softCapReached = responseData.dailySessions?.status == "soft_cap_reached"
        
        // Update local state
        self.isAuthorized = true
        self.currentSessionId = sessionId
        self.error = nil
        
        print("✅ [VoiceAuth] Successfully authorized for voice chat")
        if softCapReached {
            print("⚠️ [VoiceAuth] Soft cap reached - sessions may be limited")
        }
        
        // Return API key from secure configuration (backend validates access)
        return ProductionConfig.openAIAPIKey
    }
    
    /// Legacy method for backward compatibility
    func authorizeVoiceChat() async throws -> Bool {
        do {
            _ = try await getVoiceChatAPIKey()
            return true
        } catch {
            return false
        }
    }
    
    /// Start a voice chat session and track on backend
    func startSession() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw VoiceAuthError.notAuthenticated
        }
        
        let sessionId = UUID().uuidString
        self.currentSessionId = sessionId
        self.sessionStartTime = Date()
        self.messageCount = 0
        
        // Call backend session/start endpoint
        guard let url = URL(string: EnvironmentConfig.Endpoints.voiceSessionStart) else {
            throw VoiceAuthError.serviceUnavailable
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(try await user.getIDToken())", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoiceAuthError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw VoiceAuthError.networkError("Server returned status \(httpResponse.statusCode)")
        }
        
        // Parse response
        let responseData = try JSONDecoder().decode(VoiceSessionStartResponse.self, from: data)
        
        // Update soft cap status
        self.softCapReached = responseData.dailySessions?.status == "soft_cap_reached"
        
        print("🎙️ [VoiceAuth] Session started: \(sessionId)")
        return sessionId
    }
    
    /// End a voice chat session and track usage on backend
    func endSession(duration: TimeInterval, messageCount: Int) async {
        guard let sessionId = currentSessionId,
              let user = Auth.auth().currentUser else {
            return
        }
        
        self.messageCount = messageCount
        
        // Call backend session/end endpoint
        guard let url = URL(string: EnvironmentConfig.Endpoints.voiceSessionEnd) else {
            print("❌ [VoiceAuth] Invalid session end URL")
            return
        }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(try await user.getIDToken())", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = [
                "sessionId": sessionId,
                "duration": duration,
                "messageCount": messageCount
            ]
            
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [VoiceAuth] Invalid response")
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                print("❌ [VoiceAuth] Server returned status \(httpResponse.statusCode)")
                return
            }
            
            // Parse response
            let responseData = try JSONDecoder().decode(VoiceSessionEndResponse.self, from: data)
            
            // Update soft cap status
            self.softCapReached = responseData.dailySessions?.status == "soft_cap_reached"
            
            print("🎙️ [VoiceAuth] Session ended: \(sessionId), duration: \(duration)s, messages: \(messageCount)")
            
        } catch {
            print("❌ [VoiceAuth] Failed to end session: \(error)")
        }
        
        self.currentSessionId = nil
        self.isAuthorized = false
        self.sessionStartTime = nil
    }
    
    /// Check voice chat service status
    func checkServiceStatus() async -> Bool {
        guard let url = URL(string: EnvironmentConfig.Endpoints.voiceStatus) else {
            return false
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return false
            }
            
            let statusData = try JSONDecoder().decode(VoiceStatusResponse.self, from: data)
            return statusData.status == "online" && statusData.openaiConfigured
        } catch {
            print("❌ [VoiceAuth] Failed to check service status: \(error)")
            return false
        }
    }
}

// MARK: - Response Models

struct VoiceAuthResponse: Codable {
    let authorized: Bool
    let userId: String?
    let sessionId: String?
    let rateLimits: RateLimits?
    let dailySessions: DailySessionStatus?
    let message: String?
}

struct RateLimits: Codable {
    let requestsPerMinute: Int
    let dailyLimit: Int
}

struct DailySessionStatus: Codable {
    let status: String
    let softCapReached: Bool
    let sessionsStartedThisMonth: Int?
    let sessionsCompletedThisMonth: Int?
}

struct VoiceSessionStartResponse: Codable {
    let sessionId: String
    let startedAt: String
    let status: String
    let dailySessions: DailySessionStatus?
}

struct VoiceSessionEndResponse: Codable {
    let sessionId: String
    let endedAt: String
    let status: String
    let dailySessions: DailySessionStatus?
}

struct VoiceStatusResponse: Codable {
    let status: String
    let openaiConfigured: Bool
    let model: String?
    let timestamp: String?
}

// MARK: - Error Types

enum VoiceAuthError: LocalizedError {
    case notAuthenticated
    case unauthorized
    case premiumRequired
    case serviceUnavailable
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to use voice chat"
        case .unauthorized:
            return "Voice chat access denied"
        case .premiumRequired:
            return "Voice chat requires premium subscription. Upgrade to continue."
        case .serviceUnavailable:
            return "Voice chat service is temporarily unavailable"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}