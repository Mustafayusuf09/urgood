import Foundation

// MARK: - Dictionary Conversion Extensions

extension Encodable {
    func toDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        guard let dictionary = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
            throw NSError(domain: "DictionaryConversion", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert to dictionary"])
        }
        return dictionary
    }
}

// MARK: - Authentication Requests

struct AuthRequest: Codable {
    let apiKey: String
    let deviceId: String
    let platform: String
    let version: String
}

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String
    let user: UserResponse
}

// MARK: - User Requests

struct UserCreateRequest: Codable {
    let email: String?
    let name: String?
    let authProvider: String
    let deviceId: String
    let platform: String
    let version: String
    let timezone: String
    let language: String
}

struct UserUpdateRequest: Codable {
    let name: String?
    let timezone: String?
    let language: String?
    let preferences: UserPreferences?
}

struct UserResponse: Codable {
    let id: String
    let email: String?
    let name: String?
    let authProvider: String
    let subscriptionStatus: String
    let createdAt: Date
    let lastUpdated: Date
    let preferences: UserPreferences?
}

struct UserPreferences: Codable {
    let notifications: Bool
    let darkMode: Bool
    let language: String
    let timezone: String
    let dailyReminderTime: String?
    let crisisDetectionEnabled: Bool
}

// MARK: - Chat Message Requests

struct ChatMessageRequest: Codable {
    let userId: String
    let role: String
    let text: String
    let timestamp: Date
    let sessionId: String?
    let metadata: ChatMessageMetadata?
}

struct ChatMessageResponse: Codable {
    let id: String
    let userId: String
    let role: String
    let text: String
    let timestamp: Date
    let sessionId: String?
    let metadata: ChatMessageMetadata?
    let createdAt: Date
}

struct ChatMessageMetadata: Codable {
    let messageType: String?
    let crisisLevel: Int?
    let sentiment: String?
    let topics: [String]?
    let responseTime: Double?
}

struct MessagesResponse: Codable {
    let messages: [ChatMessageResponse]
    let total: Int
    let hasMore: Bool
    let nextOffset: Int?
}

// MARK: - Mood Entry Requests

struct MoodEntryRequest: Codable {
    let userId: String
    let mood: Int
    let timestamp: Date
    let tags: [String]
    let notes: String?
    let context: MoodContext?
}

struct MoodEntryResponse: Codable {
    let id: String
    let userId: String
    let mood: Int
    let timestamp: Date
    let tags: [String]
    let notes: String?
    let context: MoodContext?
    let createdAt: Date
}

struct MoodContext: Codable {
    let location: String?
    let weather: String?
    let activity: String?
    let socialContext: String?
    let healthStatus: String?
}

struct MoodEntriesResponse: Codable {
    let entries: [MoodEntryResponse]
    let total: Int
    let averageMood: Double
    let trend: String
}

struct MoodTrendsResponse: Codable {
    let period: String
    let dataPoints: [MoodTrendPoint]
    let averageMood: Double
    let trend: String
    let insights: [String]
}

struct MoodTrendPoint: Codable {
    let date: Date
    let mood: Double
    let count: Int
}


// MARK: - Crisis Event Requests

struct CrisisEventRequest: Codable {
    let userId: String
    let level: Int
    let message: String
    let timestamp: Date
    let context: CrisisContext?
    let actionTaken: String?
}

struct CrisisEventResponse: Codable {
    let id: String
    let userId: String
    let level: Int
    let message: String
    let timestamp: Date
    let context: CrisisContext?
    let actionTaken: String?
    let resolved: Bool
    let resolvedAt: Date?
    let createdAt: Date
}

struct CrisisContext: Codable {
    let trigger: String?
    let location: String?
    let socialContext: String?
    let previousEvents: Int
    let supportContacted: Bool
}

struct CrisisEventsResponse: Codable {
    let events: [CrisisEventResponse]
    let total: Int
    let unresolvedCount: Int
    let averageLevel: Double
}

// MARK: - Analytics Requests

struct AnalyticsEventRequest: Codable {
    let userId: String
    let eventName: String
    let parameters: [String: AnyCodable]
    let timestamp: Date
    let sessionId: String?
}

struct AnalyticsResponse: Codable {
    let period: String
    let userId: String
    let metrics: AnalyticsMetrics
    let insights: [String]
    let recommendations: [String]
}

struct AnalyticsMetrics: Codable {
    let totalSessions: Int
    let averageSessionDuration: Double
    let totalMessages: Int
    let moodEntries: Int
    let voiceChatSessions: Int
    let crisisEvents: Int
    let engagementScore: Double
    let retentionRate: Double
    let churnRisk: Double
}

// MARK: - Session Requests

struct SessionRequest: Codable {
    let userId: String
    let sessionType: String
    let startTime: Date
    let metadata: SessionMetadata?
}

struct SessionResponse: Codable {
    let id: String
    let userId: String
    let sessionType: String
    let startTime: Date
    let endTime: Date?
    let duration: Double?
    let messageCount: Int
    let moodBefore: Int?
    let moodAfter: Int?
    let summary: String?
    let insights: [String]?
    let metadata: SessionMetadata?
    let createdAt: Date
}

struct SessionMetadata: Codable {
    let platform: String
    let version: String
    let deviceType: String
    let location: String?
    let networkType: String?
}

// MARK: - Health Check Requests

struct HealthCheckResponse: Codable {
    let status: String
    let timestamp: Date
    let version: String
    let uptime: Double
    let database: HealthStatus
    let redis: HealthStatus
    let externalServices: [String: HealthStatus]
}

struct HealthStatus: Codable {
    let status: String
    let responseTime: Double?
    let lastCheck: Date
    let error: String?
}

// MARK: - Utility Types

struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.typeMismatch(AnyCodable.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        if let string = value as? String {
            try container.encode(string)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else if let array = value as? [Any] {
            try container.encode(array.map { AnyCodable($0) })
        } else if let dictionary = value as? [String: Any] {
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        } else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
}
