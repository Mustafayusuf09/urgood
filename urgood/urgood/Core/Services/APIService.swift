import Foundation
import Combine

class APIService: ObservableObject {
    static let shared = APIService()
    
    private let baseURL = "https://api.urgood.app/v1"
    private let session = URLSession.shared
    private var cancellables = Set<AnyCancellable>()
    
    // API Configuration
    private let timeout: TimeInterval = 30.0
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 1.0
    
    // Rate limiting
    private var requestCounts: [String: (count: Int, resetTime: Date)] = [:]
    private let rateLimitWindow: TimeInterval = 60.0 // 1 minute
    
    private init() {
        setupNetworkMonitoring()
    }
    
    // MARK: - Authentication
    
    func authenticate(apiKey: String) -> AnyPublisher<AuthResponse, APIError> {
        let request = APIRequest(
            endpoint: "/auth",
            method: .POST,
            body: ["api_key": apiKey]
        )
        
        return performRequest(request)
            .map { (response: AuthResponse) in response }
            .eraseToAnyPublisher()
    }
    
    func refreshToken(refreshToken: String) -> AnyPublisher<AuthResponse, APIError> {
        let request = APIRequest(
            endpoint: "/auth/refresh",
            method: .POST,
            body: ["refresh_token": refreshToken]
        )
        
        return performRequest(request)
            .map { (response: AuthResponse) in response }
            .eraseToAnyPublisher()
    }
    
    // MARK: - User Management
    
    func createUser(_ user: UserCreateRequest) -> AnyPublisher<UserResponse, APIError> {
        let request = APIRequest(
            endpoint: "/users",
            method: .POST,
            body: (try? user.toDictionary()) ?? [:]
        )
        
        return performRequest(request)
            .map { (response: UserResponse) in response }
            .eraseToAnyPublisher()
    }
    
    func getUser(userId: String) -> AnyPublisher<UserResponse, APIError> {
        let request = APIRequest(
            endpoint: "/users/\(userId)",
            method: .GET
        )
        
        return performRequest(request)
            .map { (response: UserResponse) in response }
            .eraseToAnyPublisher()
    }
    
    func updateUser(userId: String, updates: UserUpdateRequest) -> AnyPublisher<UserResponse, APIError> {
        let request = APIRequest(
            endpoint: "/users/\(userId)",
            method: .PUT,
            body: (try? updates.toDictionary()) ?? [:]
        )
        
        return performRequest(request)
            .map { (response: UserResponse) in response }
            .eraseToAnyPublisher()
    }
    
    func deleteUser(userId: String) -> AnyPublisher<Void, APIError> {
        let request = APIRequest(
            endpoint: "/users/\(userId)",
            method: .DELETE
        )
        
        return performRequest(request)
            .map { (_: EmptyResponse) in () }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Chat Messages
    
    func sendMessage(_ message: ChatMessageRequest) -> AnyPublisher<ChatMessageResponse, APIError> {
        let request = APIRequest(
            endpoint: "/chat/messages",
            method: .POST,
            body: (try? message.toDictionary()) ?? [:]
        )
        
        return performRequest(request)
            .map { (response: ChatMessageResponse) in response }
            .eraseToAnyPublisher()
    }
    
    func getMessages(userId: String, limit: Int = 50, offset: Int = 0) -> AnyPublisher<[ChatMessageResponse], APIError> {
        let request = APIRequest(
            endpoint: "/chat/messages",
            method: .GET,
            queryParams: [
                "user_id": userId,
                "limit": "\(limit)",
                "offset": "\(offset)"
            ]
        )
        
        return performRequest(request)
            .map { (response: MessagesResponse) in response.messages }
            .eraseToAnyPublisher()
    }
    
    func deleteMessage(messageId: String) -> AnyPublisher<Void, APIError> {
        let request = APIRequest(
            endpoint: "/chat/messages/\(messageId)",
            method: .DELETE
        )
        
        return performRequest(request)
            .map { (_: EmptyResponse) in () }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Mood Entries
    
    func createMoodEntry(_ entry: MoodEntryRequest) -> AnyPublisher<MoodEntryResponse, APIError> {
        let request = APIRequest(
            endpoint: "/mood/entries",
            method: .POST,
            body: (try? entry.toDictionary()) ?? [:]
        )
        
        return performRequest(request)
            .map { (response: MoodEntryResponse) in response }
            .eraseToAnyPublisher()
    }
    
    func getMoodEntries(userId: String, startDate: Date, endDate: Date) -> AnyPublisher<[MoodEntryResponse], APIError> {
        let formatter = ISO8601DateFormatter()
        let request = APIRequest(
            endpoint: "/mood/entries",
            method: .GET,
            queryParams: [
                "user_id": userId,
                "start_date": formatter.string(from: startDate),
                "end_date": formatter.string(from: endDate)
            ]
        )
        
        return performRequest(request)
            .map { (response: MoodEntriesResponse) in response.entries }
            .eraseToAnyPublisher()
    }
    
    func getMoodTrends(userId: String, period: String = "7d") -> AnyPublisher<MoodTrendsResponse, APIError> {
        let request = APIRequest(
            endpoint: "/mood/trends",
            method: .GET,
            queryParams: [
                "user_id": userId,
                "period": period
            ]
        )
        
        return performRequest(request)
            .map { (response: MoodTrendsResponse) in response }
            .eraseToAnyPublisher()
    }
    
    
    // MARK: - Crisis Events
    
    func reportCrisisEvent(_ event: CrisisEventRequest) -> AnyPublisher<CrisisEventResponse, APIError> {
        let request = APIRequest(
            endpoint: "/crisis/events",
            method: .POST,
            body: (try? event.toDictionary()) ?? [:]
        )
        
        return performRequest(request)
            .map { (response: CrisisEventResponse) in response }
            .eraseToAnyPublisher()
    }
    
    func getCrisisEvents(userId: String, limit: Int = 20) -> AnyPublisher<[CrisisEventResponse], APIError> {
        let request = APIRequest(
            endpoint: "/crisis/events",
            method: .GET,
            queryParams: [
                "user_id": userId,
                "limit": "\(limit)"
            ]
        )
        
        return performRequest(request)
            .map { (response: CrisisEventsResponse) in response.events }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Analytics
    
    func getAnalytics(userId: String, period: String = "30d") -> AnyPublisher<AnalyticsResponse, APIError> {
        let request = APIRequest(
            endpoint: "/analytics",
            method: .GET,
            queryParams: [
                "user_id": userId,
                "period": period
            ]
        )
        
        return performRequest(request)
            .map { (response: AnalyticsResponse) in response }
            .eraseToAnyPublisher()
    }
    
    func trackEvent(_ event: AnalyticsEventRequest) -> AnyPublisher<Void, APIError> {
        let request = APIRequest(
            endpoint: "/analytics/events",
            method: .POST,
            body: (try? event.toDictionary()) ?? [:]
        )
        
        return performRequest(request)
            .map { (_: EmptyResponse) in () }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Core Request Handling
    
    private func performRequest<T: Codable>(_ apiRequest: APIRequest) -> AnyPublisher<T, APIError> {
        guard let urlRequest = buildURLRequest(from: apiRequest) else {
            return Fail(error: APIError.invalidRequest)
                .eraseToAnyPublisher()
        }
        
        // Check rate limiting
        if !checkRateLimit(for: apiRequest.endpoint) {
            return Fail(error: APIError.rateLimited)
                .eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: urlRequest)
            .map(\.data)
            .decode(type: APIResponse<T>.self, decoder: JSONDecoder())
            .map(\.data)
            .mapError { error in
                if error is DecodingError {
                    return APIError.decodingError(error)
                } else {
                    return APIError.networkError(error)
                }
            }
            .retry(maxRetries)
            .eraseToAnyPublisher()
    }
    
    private func buildURLRequest(from apiRequest: APIRequest) -> URLRequest? {
        guard let url = URL(string: baseURL + apiRequest.endpoint) else {
            return nil
        }
        
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        
        // Add query parameters
        if !apiRequest.queryParams.isEmpty {
            urlComponents?.queryItems = apiRequest.queryParams.map { key, value in
                URLQueryItem(name: key, value: value)
            }
        }
        
        guard let finalURL = urlComponents?.url else {
            return nil
        }
        
        var request = URLRequest(url: finalURL)
        request.httpMethod = apiRequest.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = timeout
        
        // Add authentication header if available
        if let token = getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add body for POST/PUT requests
        if let body = apiRequest.body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                return nil
            }
        }
        
        return request
    }
    
    // MARK: - Rate Limiting
    
    private func checkRateLimit(for endpoint: String) -> Bool {
        let now = Date()
        let key = endpoint.components(separatedBy: "/").first ?? "default"
        
        if let (count, resetTime) = requestCounts[key] {
            if now > resetTime {
                // Reset window
                requestCounts[key] = (1, now.addingTimeInterval(rateLimitWindow))
                return true
            } else if count < 100 { // 100 requests per minute
                requestCounts[key] = (count + 1, resetTime)
                return true
            } else {
                return false
            }
        } else {
            requestCounts[key] = (1, now.addingTimeInterval(rateLimitWindow))
            return true
        }
    }
    
    // MARK: - Authentication Token Management
    
    private func getAuthToken() -> String? {
        return UserDefaults.standard.string(forKey: "api_auth_token")
    }
    
    private func setAuthToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: "api_auth_token")
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        // Monitor network reachability
        // This would integrate with Network framework in a real implementation
    }
}

// MARK: - API Models

struct APIRequest {
    let endpoint: String
    let method: HTTPMethod
    let body: [String: Any]?
    let queryParams: [String: String]
    
    init(endpoint: String, method: HTTPMethod, body: [String: Any]? = nil, queryParams: [String: String] = [:]) {
        self.endpoint = endpoint
        self.method = method
        self.body = body
        self.queryParams = queryParams
    }
}

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

struct APIResponse<T: Codable>: Codable {
    let data: T
    let success: Bool
    let message: String?
    let timestamp: Date
}

struct EmptyResponse: Codable {}

// MARK: - Error Handling

enum APIError: Error, LocalizedError {
    case invalidRequest
    case networkError(Error)
    case decodingError(Error)
    case rateLimited
    case unauthorized
    case forbidden
    case notFound
    case serverError(Int)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Invalid request"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .rateLimited:
            return "Rate limit exceeded"
        case .unauthorized:
            return "Unauthorized"
        case .forbidden:
            return "Forbidden"
        case .notFound:
            return "Not found"
        case .serverError(let code):
            return "Server error: \(code)"
        case .unknown:
            return "Unknown error"
        }
    }
}
