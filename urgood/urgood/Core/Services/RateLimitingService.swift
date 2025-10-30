import Foundation
import Combine

class RateLimitingService: ObservableObject {
    static let shared = RateLimitingService()
    
    // MARK: - Rate Limiting State
    
    private struct UserRateLimit {
        var requestCount: Int
        var windowStart: Date
        var isBlocked: Bool
        var blockUntil: Date?
    }
    
    private var userLimits: [String: UserRateLimit] = [:]
    private let queue = DispatchQueue(label: "rate-limiting", attributes: .concurrent)
    
    // MARK: - Request Queue
    
    private struct QueuedRequest {
        let id: UUID
        let userId: String
        let priority: RequestPriority
        let timestamp: Date
        let completion: (Result<Void, RateLimitError>) -> Void
    }
    
    enum RequestPriority: Int, CaseIterable {
        case low = 0
        case normal = 1
        case high = 2
        case critical = 3
    }
    
    private var requestQueue: [QueuedRequest] = []
    private var isProcessingQueue = false
    
    private init() {
        startQueueProcessor()
    }
    
    // MARK: - Rate Limiting
    
    func canMakeRequest(userId: String, isPremium: Bool) -> Bool {
        return queue.sync {
            let limit = isPremium ? APIConfig.premiumUserRequestsPerMinute : APIConfig.freeUserRequestsPerMinute
            let now = Date()
            
            var userLimit = userLimits[userId] ?? UserRateLimit(
                requestCount: 0,
                windowStart: now,
                isBlocked: false,
                blockUntil: nil
            )
            
            // Check if user is currently blocked
            if userLimit.isBlocked, let blockUntil = userLimit.blockUntil, now < blockUntil {
                return false
            }
            
            // Reset window if needed
            if now.timeIntervalSince(userLimit.windowStart) >= APIConfig.rateLimitWindow {
                userLimit.requestCount = 0
                userLimit.windowStart = now
                userLimit.isBlocked = false
                userLimit.blockUntil = nil
            }
            
            // Check if within limit
            if userLimit.requestCount >= limit {
                // Block user for exponential backoff
                let blockDuration = min(pow(2.0, Double(userLimit.requestCount - limit)), 300.0) // Max 5 minutes
                userLimit.isBlocked = true
                userLimit.blockUntil = now.addingTimeInterval(blockDuration)
                userLimits[userId] = userLimit
                return false
            }
            
            return true
        }
    }
    
    func recordRequest(userId: String, isPremium: Bool) {
        queue.async(flags: .barrier) {
            let now = Date()
            var userLimit = self.userLimits[userId] ?? UserRateLimit(
                requestCount: 0,
                windowStart: now,
                isBlocked: false,
                blockUntil: nil
            )
            
            userLimit.requestCount += 1
            self.userLimits[userId] = userLimit
        }
    }
    
    func getRemainingRequests(userId: String, isPremium: Bool) -> Int {
        return queue.sync {
            let limit = isPremium ? APIConfig.premiumUserRequestsPerMinute : APIConfig.freeUserRequestsPerMinute
            let userLimit = userLimits[userId] ?? UserRateLimit(
                requestCount: 0,
                windowStart: Date(),
                isBlocked: false,
                blockUntil: nil
            )
            
            return max(0, limit - userLimit.requestCount)
        }
    }
    
    func getTimeUntilReset(userId: String) -> TimeInterval {
        return queue.sync {
            guard let userLimit = userLimits[userId] else { return 0 }
            
            if userLimit.isBlocked, let blockUntil = userLimit.blockUntil {
                return max(0, blockUntil.timeIntervalSinceNow)
            }
            
            let windowEnd = userLimit.windowStart.addingTimeInterval(APIConfig.rateLimitWindow)
            return max(0, windowEnd.timeIntervalSinceNow)
        }
    }
    
    // MARK: - Request Queuing
    
    func queueRequest(
        userId: String,
        priority: RequestPriority = .normal,
        completion: @escaping (Result<Void, RateLimitError>) -> Void
    ) -> UUID {
        let requestId = UUID()
        let queuedRequest = QueuedRequest(
            id: requestId,
            userId: userId,
            priority: priority,
            timestamp: Date(),
            completion: completion
        )
        
        queue.async(flags: .barrier) {
            self.requestQueue.append(queuedRequest)
            self.requestQueue.sort { $0.priority.rawValue > $1.priority.rawValue }
        }
        
        return requestId
    }
    
    func cancelRequest(_ requestId: UUID) {
        queue.async(flags: .barrier) {
            self.requestQueue.removeAll { $0.id == requestId }
        }
    }
    
    private func startQueueProcessor() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.processQueue()
        }
    }
    
    private func processQueue() {
        guard !isProcessingQueue else { return }
        
        queue.async(flags: .barrier) {
            guard !self.requestQueue.isEmpty else { return }
            
            self.isProcessingQueue = true
            defer { self.isProcessingQueue = false }
            
            var processedRequests: [UUID] = []
            
            for request in self.requestQueue {
                // Check if request has expired (older than 5 minutes)
                if Date().timeIntervalSince(request.timestamp) > 300 {
                    request.completion(.failure(.requestExpired))
                    processedRequests.append(request.id)
                    continue
                }
                
                // Try to process request
                if self.canMakeRequest(userId: request.userId, isPremium: false) { // TODO: Get actual premium status
                    self.recordRequest(userId: request.userId, isPremium: false)
                    request.completion(.success(()))
                    processedRequests.append(request.id)
                }
            }
            
            // Remove processed requests
            self.requestQueue.removeAll { processedRequests.contains($0.id) }
        }
    }
}

// MARK: - Response Caching Service

class ResponseCacheService: ObservableObject {
    static let shared = ResponseCacheService()
    
    private struct CachedResponse {
        let response: String
        let timestamp: Date
        let expiresAt: Date
    }
    
    private var cache: [String: CachedResponse] = [:]
    private let queue = DispatchQueue(label: "response-cache", attributes: .concurrent)
    
    private init() {
        startCacheCleanup()
    }
    
    func getCachedResponse(for key: String) -> String? {
        return queue.sync {
            guard let cached = cache[key],
                  Date() < cached.expiresAt else {
                return nil
            }
            return cached.response
        }
    }
    
    func cacheResponse(_ response: String, for key: String) {
        queue.async(flags: .barrier) {
            let expiresAt = Date().addingTimeInterval(APIConfig.responseCacheDuration)
            self.cache[key] = CachedResponse(
                response: response,
                timestamp: Date(),
                expiresAt: expiresAt
            )
            
            // Enforce cache size limit
            if self.cache.count > APIConfig.maxCacheSize {
                let sortedEntries = self.cache.sorted { $0.value.timestamp < $1.value.timestamp }
                let entriesToRemove = sortedEntries.prefix(self.cache.count - APIConfig.maxCacheSize)
                for (key, _) in entriesToRemove {
                    self.cache.removeValue(forKey: key)
                }
            }
        }
    }
    
    func generateCacheKey(message: String, conversationHistory: [ChatMessage]) -> String {
        let historyContext = conversationHistory.suffix(3).map { "\($0.role.rawValue):\($0.text)" }.joined(separator: "|")
        let combined = "\(message)|\(historyContext)"
        return combined.sha256
    }
    
    private func startCacheCleanup() {
        Timer.scheduledTimer(withTimeInterval: 300.0, repeats: true) { _ in // Every 5 minutes
            self.cleanupExpiredEntries()
        }
    }
    
    private func cleanupExpiredEntries() {
        queue.async(flags: .barrier) {
            let now = Date()
            self.cache = self.cache.filter { $0.value.expiresAt > now }
        }
    }
}

// MARK: - Circuit Breaker Service

class CircuitBreakerService: ObservableObject {
    static let shared = CircuitBreakerService()
    
    enum CircuitState {
        case closed    // Normal operation
        case open      // Failing, reject requests
        case halfOpen  // Testing if service recovered
    }
    
    private struct CircuitBreaker {
        var state: CircuitState = .closed
        var failureCount: Int = 0
        var lastFailureTime: Date?
        var nextAttemptTime: Date?
    }
    
    private var circuits: [String: CircuitBreaker] = [:]
    private let queue = DispatchQueue(label: "circuit-breaker", attributes: .concurrent)
    
    private let failureThreshold = 5
    private let recoveryTimeout: TimeInterval = 60.0 // 1 minute
    private let halfOpenTimeout: TimeInterval = 30.0 // 30 seconds
    
    private init() {}
    
    func canExecuteRequest(for service: String) -> Bool {
        return queue.sync {
            var circuit = circuits[service] ?? CircuitBreaker()
            let now = Date()
            
            switch circuit.state {
            case .closed:
                return true
                
            case .open:
                guard let nextAttempt = circuit.nextAttemptTime, now >= nextAttempt else {
                    return false
                }
                // Transition to half-open
                circuit.state = .halfOpen
                circuit.nextAttemptTime = now.addingTimeInterval(halfOpenTimeout)
                circuits[service] = circuit
                return true
                
            case .halfOpen:
                return true
            }
        }
    }
    
    func recordSuccess(for service: String) {
        queue.async(flags: .barrier) {
            var circuit = self.circuits[service] ?? CircuitBreaker()
            
            if circuit.state == .halfOpen {
                // Recovery successful, close circuit
                circuit.state = .closed
                circuit.failureCount = 0
                circuit.lastFailureTime = nil
                circuit.nextAttemptTime = nil
            }
            
            self.circuits[service] = circuit
        }
    }
    
    func recordFailure(for service: String) {
        queue.async(flags: .barrier) {
            var circuit = self.circuits[service] ?? CircuitBreaker()
            let now = Date()
            
            circuit.failureCount += 1
            circuit.lastFailureTime = now
            
            if circuit.failureCount >= self.failureThreshold {
                circuit.state = .open
                circuit.nextAttemptTime = now.addingTimeInterval(self.recoveryTimeout)
            }
            
            self.circuits[service] = circuit
        }
    }
    
    func getCircuitState(for service: String) -> CircuitState {
        return queue.sync {
            return circuits[service]?.state ?? .closed
        }
    }
}

// MARK: - Error Types

enum RateLimitError: LocalizedError {
    case rateLimitExceeded(resetTime: TimeInterval)
    case requestExpired
    case queueFull
    
    var errorDescription: String? {
        switch self {
        case .rateLimitExceeded(let resetTime):
            let minutes = Int(resetTime / 60)
            let seconds = Int(resetTime.truncatingRemainder(dividingBy: 60))
            return "Rate limit exceeded. Try again in \(minutes)m \(seconds)s."
        case .requestExpired:
            return "Request expired while waiting in queue."
        case .queueFull:
            return "Request queue is full. Please try again later."
        }
    }
}

// MARK: - String Extension for Hashing

extension String {
    var sha256: String {
        let data = Data(self.utf8)
        let hash = data.withUnsafeBytes { bytes in
            return bytes.bindMemory(to: UInt8.self)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
