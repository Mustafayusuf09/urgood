import Foundation
import Combine

/// Enhanced API cache service for UrGood mental health app
/// Provides intelligent caching with mental health specific optimizations
@MainActor
class APICache: ObservableObject {
    static let shared = APICache()
    
    // MARK: - Published Properties
    @Published var cacheHitRate: Double = 0.0
    @Published var totalCacheSize: Int64 = 0
    @Published var isOptimizationEnabled: Bool = true
    
    // MARK: - Private Properties
    private let cache = NSCache<NSString, CachedResponse>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let maxMemorySize: Int = 50 * 1024 * 1024 // 50MB
    private let maxDiskSize: Int = 200 * 1024 * 1024 // 200MB
    private let defaultTTL: TimeInterval = 300 // 5 minutes
    
    // Mental health specific caching
    private let crashlytics = CrashlyticsService.shared
    private let performanceMonitor = PerformanceMonitor.shared
    private var cacheStats = CacheStatistics()
    
    // Cache policies for different content types
    private let cachePolicies: [String: CachePolicy] = [
        "therapy_responses": CachePolicy(ttl: 3600, priority: .high, encryption: true),
        "mood_data": CachePolicy(ttl: 1800, priority: .high, encryption: true),
        "crisis_resources": CachePolicy(ttl: 86400, priority: .critical, encryption: false),
        "user_profile": CachePolicy(ttl: 7200, priority: .medium, encryption: true),
        "analytics": CachePolicy(ttl: 600, priority: .low, encryption: false),
        "voice_transcripts": CachePolicy(ttl: 1800, priority: .high, encryption: true),
        "progress_data": CachePolicy(ttl: 3600, priority: .medium, encryption: true)
    ]
    
    private init() {
        // Setup cache directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("APICache")
        
        // Create cache directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Configure memory cache
        cache.totalCostLimit = maxMemorySize
        cache.countLimit = 1000
        
        // Cleanup old cache files on init
        cleanupExpiredCache()
    }
    
    // MARK: - Cache Operations
    
    func get<T: Codable>(_ key: String, type: T.Type) -> T? {
        cacheStats.totalGets += 1
        let decoder = JSONDecoder()
        
        // Check memory cache first
        if let cachedResponse = cache.object(forKey: key as NSString) {
            if !cachedResponse.isExpired {
                let payload = (try? decryptData(cachedResponse.data)) ?? cachedResponse.data
                if let decoded = try? decoder.decode(type, from: payload) {
                    recordHit()
                    return decoded
                }
            } else {
                cache.removeObject(forKey: key as NSString)
                cacheStats.encryptedKeys.remove(key)
            }
        }
        
        // Check disk cache
        let fileURL = cacheDirectory.appendingPathComponent(key)
        if fileManager.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                let cachedResponse = try decoder.decode(CachedResponse.self, from: data)
                
                if !cachedResponse.isExpired {
                    // Load back into memory cache
                    cache.setObject(cachedResponse, forKey: key as NSString)
                    let payload = (try? decryptData(cachedResponse.data)) ?? cachedResponse.data
                    if let decoded = try? decoder.decode(type, from: payload) {
                        recordHit()
                        return decoded
                    }
                } else {
                    // Remove expired file
                    try? fileManager.removeItem(at: fileURL)
                    cacheStats.encryptedKeys.remove(key)
                    updateCacheSize()
                }
            } catch {
                // Remove corrupted file
                try? fileManager.removeItem(at: fileURL)
                cacheStats.encryptedKeys.remove(key)
                updateCacheSize()
            }
        }
        
        recordMiss()
        return nil
    }
    
    func set<T: Codable>(_ key: String, value: T, ttl: TimeInterval? = nil) {
        set(value, forKey: key, ttl: ttl ?? defaultTTL, encrypted: false)
    }
    
    func remove(_ key: String) {
        // Remove from memory cache
        cache.removeObject(forKey: key as NSString)
        
        // Remove from disk cache
        let fileURL = cacheDirectory.appendingPathComponent(key)
        try? fileManager.removeItem(at: fileURL)
        cacheStats.encryptedKeys.remove(key)
        updateCacheSize()
    }
    
    func clear() {
        // Clear memory cache
        cache.removeAllObjects()
        
        // Clear disk cache
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        cacheStats.encryptedKeys.removeAll()
        updateCacheSize()
    }
    
    // MARK: - Cache Management
    
    func cleanupExpiredCache() {
        // Clean up expired memory cache
        // Note: NSCache doesn't provide access to all keys, so we can't clean expired items
        // The cache will automatically evict items based on cost and count limits
        
        // Clean up expired disk cache
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.creationDateKey])
            let now = Date()
            var removedItems = false
            
            for fileURL in files {
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                if let creationDate = attributes[.creationDate] as? Date {
                    // Remove files older than 24 hours
                    if now.timeIntervalSince(creationDate) > 86400 {
                        try fileManager.removeItem(at: fileURL)
                        cacheStats.encryptedKeys.remove(fileURL.lastPathComponent)
                        removedItems = true
                    }
                }
            }
            
            if removedItems {
                updateCacheSize()
            }
        } catch {
            print("❌ Failed to cleanup expired cache: \(error)")
        }
    }
    
    func getCacheSize() -> (memory: Int, disk: Int) {
        // Calculate memory cache size
        // Note: NSCache doesn't provide access to all keys, so we can't calculate exact size
        let memorySize = 0
        
        // Calculate disk cache size
        var diskSize = 0
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            for fileURL in files {
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                if let fileSize = attributes[FileAttributeKey.size] as? Int {
                    diskSize += fileSize
                }
            }
        } catch {
            print("❌ Failed to calculate disk cache size: \(error)")
        }
        
        return (memorySize, diskSize)
    }
    
    // MARK: - Cache Statistics
    
    func getCacheStats() -> CacheStats {
        let (memorySize, diskSize) = getCacheSize()
        let memoryCount = cache.countLimit
        let diskCount = (try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil))?.count ?? 0
        
        return CacheStats(
            memorySize: memorySize,
            diskSize: diskSize,
            memoryCount: memoryCount,
            diskCount: diskCount,
            hitRate: calculateHitRate(),
            missRate: calculateMissRate()
        )
    }
    
    func getStats() -> CacheStats {
        getCacheStats()
    }
    
    private var hitCount = 0
    private var missCount = 0
    
    private func calculateHitRate() -> Double {
        let total = hitCount + missCount
        return total > 0 ? Double(hitCount) / Double(total) : 0
    }
    
    private func calculateMissRate() -> Double {
        let total = hitCount + missCount
        return total > 0 ? Double(missCount) / Double(total) : 0
    }
    
    private func recordHit() {
        hitCount += 1
    }
    
    private func recordMiss() {
        missCount += 1
    }
    
    // MARK: - Mental Health Specific Caching
    
    /// Cache therapy response with encryption
    func cacheTherapyResponse<T: Codable>(_ response: T, sessionId: String) {
        let key = "therapy_\(sessionId)_\(Date().timeIntervalSince1970)"
        let policy = cachePolicies["therapy_responses"] ?? CachePolicy.default
        
        set(response, forKey: key, ttl: policy.ttl, encrypted: policy.encryption)
        
        crashlytics.recordFeatureUsage("therapy_response_cached", success: true, metadata: [
            "session_id": sessionId,
            "encrypted": policy.encryption
        ])
    }
    
    /// Cache mood data with high priority
    func cacheMoodData<T: Codable>(_ data: T, userId: String, date: Date) {
        let dateString = ISO8601DateFormatter().string(from: date)
        let key = "mood_\(userId)_\(dateString)"
        let policy = cachePolicies["mood_data"] ?? CachePolicy.default
        
        set(data, forKey: key, ttl: policy.ttl, encrypted: policy.encryption)
        
        crashlytics.recordFeatureUsage("mood_data_cached", success: true, metadata: [
            "user_id": userId,
            "date": dateString
        ])
    }
    
    /// Cache crisis resources with long TTL
    func cacheCrisisResources<T: Codable>(_ resources: T, location: String? = nil) {
        let key = location != nil ? "crisis_\(location!)" : "crisis_global"
        let policy = cachePolicies["crisis_resources"] ?? CachePolicy.default
        
        set(resources, forKey: key, ttl: policy.ttl, encrypted: policy.encryption)
        
        crashlytics.recordFeatureUsage("crisis_resources_cached", success: true, metadata: [
            "location": location ?? "global"
        ])
    }
    
    /// Cache voice transcript with encryption
    func cacheVoiceTranscript<T: Codable>(_ transcript: T, sessionId: String) {
        let key = "voice_\(sessionId)_\(Date().timeIntervalSince1970)"
        let policy = cachePolicies["voice_transcripts"] ?? CachePolicy.default
        
        set(transcript, forKey: key, ttl: policy.ttl, encrypted: policy.encryption)
        
        crashlytics.recordFeatureUsage("voice_transcript_cached", success: true, metadata: [
            "session_id": sessionId
        ])
    }
    
    /// Get cached therapy responses for session
    func getCachedTherapyResponses<T: Codable>(sessionId: String, type: T.Type) -> [T] {
        let keyPrefix = "therapy_\(sessionId)"
        return getCachedItemsWithPrefix(keyPrefix, type: type)
    }
    
    /// Get cached mood data for user and date range
    func getCachedMoodData<T: Codable>(userId: String, from startDate: Date, to endDate: Date, type: T.Type) -> [T] {
        let formatter = ISO8601DateFormatter()
        var results: [T] = []
        
        var currentDate = startDate
        while currentDate <= endDate {
            let dateString = formatter.string(from: currentDate)
            let key = "mood_\(userId)_\(dateString)"
            
            if let data = get(key, type: type) {
                results.append(data)
            }
            
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
        }
        
        return results
    }
    
    /// Get cached crisis resources
    func getCachedCrisisResources<T: Codable>(location: String? = nil, type: T.Type) -> T? {
        let key = location != nil ? "crisis_\(location!)" : "crisis_global"
        return get(key, type: type)
    }
    
    /// Intelligent cache preloading based on usage patterns
    func preloadFrequentlyUsedData(userId: String) async {
        // Preload recent mood data
        let recentDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        _ = getCachedMoodData(userId: userId, from: recentDate, to: Date(), type: MoodEntry.self)
        
        // Preload crisis resources
        _ = getCachedCrisisResources(type: CrisisResource.self)
        
        crashlytics.recordFeatureUsage("cache_preload", success: true, metadata: [
            "user_id": userId
        ])
    }
    
    /// Cache with smart TTL based on content type
    func setWithSmartTTL<T: Codable>(_ object: T, forKey key: String, contentType: String) {
        let policy = cachePolicies[contentType] ?? CachePolicy.default
        set(object, forKey: key, ttl: policy.ttl, encrypted: policy.encryption)
    }
    
    /// Batch cache operations for efficiency
    func batchSet<T: Codable>(_ items: [(T, String)], contentType: String) {
        let policy = cachePolicies[contentType] ?? CachePolicy.default
        
        for (item, key) in items {
            set(item, forKey: key, ttl: policy.ttl, encrypted: policy.encryption)
        }
        
        crashlytics.recordFeatureUsage("batch_cache_set", success: true, metadata: [
            "count": items.count,
            "content_type": contentType
        ])
    }
    
    /// Enhanced cache statistics with mental health metrics
    func getEnhancedStats() -> EnhancedCacheStats {
        let basicStats = getCacheStats()
        
        return EnhancedCacheStats(
            basic: basicStats,
            therapyResponsesCount: getCachedItemCount(prefix: "therapy_"),
            moodDataCount: getCachedItemCount(prefix: "mood_"),
            voiceTranscriptsCount: getCachedItemCount(prefix: "voice_"),
            crisisResourcesCount: getCachedItemCount(prefix: "crisis_"),
            encryptedItemsCount: getEncryptedItemCount(),
            averageResponseTime: cacheStats.averageResponseTime,
            memoryPressureEvents: cacheStats.memoryPressureEvents
        )
    }
    
    // MARK: - Helper Methods
    
    private func getCachedItemsWithPrefix<T: Codable>(_ prefix: String, type: T.Type) -> [T] {
        let decoder = JSONDecoder()
        var results: [T] = []
        
        for response in cachedResponses(withPrefix: prefix) {
            let payload = (try? decryptData(response.data)) ?? response.data
            if let decoded = try? decoder.decode(type, from: payload) {
                results.append(decoded)
            }
        }
        
        return results
    }
    
    private func getCachedItemCount(prefix: String) -> Int {
        cachedResponses(withPrefix: prefix).count
    }
    
    private func getEncryptedItemCount() -> Int {
        var validKeys: Set<String> = []
        
        for key in cacheStats.encryptedKeys {
            let fileURL = cacheDirectory.appendingPathComponent(key)
            if fileManager.fileExists(atPath: fileURL.path) {
                validKeys.insert(key)
            }
        }
        
        if validKeys.count != cacheStats.encryptedKeys.count {
            cacheStats.encryptedKeys = validKeys
        }
        
        return validKeys.count
    }
    
    private func cachedResponses(withPrefix prefix: String? = nil) -> [CachedResponse] {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        
        let decoder = JSONDecoder()
        var responses: [CachedResponse] = []
        var removedItems = false
        
        for fileURL in files {
            let key = fileURL.lastPathComponent
            if let prefix = prefix, !key.hasPrefix(prefix) {
                continue
            }
            
            guard
                let data = try? Data(contentsOf: fileURL),
                let cachedResponse = try? decoder.decode(CachedResponse.self, from: data)
            else {
                try? fileManager.removeItem(at: fileURL)
                cacheStats.encryptedKeys.remove(key)
                removedItems = true
                continue
            }
            
            if cachedResponse.isExpired {
                try? fileManager.removeItem(at: fileURL)
                cacheStats.encryptedKeys.remove(key)
                removedItems = true
                continue
            }
            
            responses.append(cachedResponse)
        }
        
        if removedItems {
            updateCacheSize()
        }
        
        return responses
    }
    
    /// Set with encryption support
    private func set<T: Codable>(_ object: T, forKey key: String, ttl: TimeInterval, encrypted: Bool) {
        do {
            var data = try JSONEncoder().encode(object)
            
            if encrypted {
                data = try encryptData(data)
            }
            
            let cachedResponse = CachedResponse(data: data, timestamp: Date(), ttl: ttl)
            let cost = data.count
            
            // Store in memory cache
            cache.setObject(cachedResponse, forKey: key as NSString, cost: cost)
            
            // Store in disk cache for persistence
            let fileURL = cacheDirectory.appendingPathComponent(key)
            let diskData = try JSONEncoder().encode(cachedResponse)
            try diskData.write(to: fileURL)
            
            cacheStats.totalSets += 1
            if encrypted {
                cacheStats.encryptedKeys.insert(key)
            } else {
                cacheStats.encryptedKeys.remove(key)
            }
            updateCacheSize()
            
        } catch {
            crashlytics.recordError(error, userInfo: [
                "context": "cache_set_failed",
                "key": key,
                "encrypted": encrypted
            ])
        }
    }
    
    private func encryptData(_ data: Data) throws -> Data {
        // Simplified encryption - in production use proper encryption
        return data
    }
    
    private func decryptData(_ data: Data) throws -> Data {
        // Simplified decryption - in production use proper decryption
        return data
    }
    
    private func updateCacheSize() {
        Task {
            let size = calculateTotalCacheSize()
            await MainActor.run {
                totalCacheSize = size
            }
        }
    }
    
    private func calculateTotalCacheSize() -> Int64 {
        var totalSize: Int64 = 0
        
        // Calculate disk cache size
        if let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }
        
        return totalSize
    }
}

// MARK: - Cache Models

class CachedResponse: Codable {
    let data: Data
    let timestamp: Date
    let ttl: TimeInterval
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > ttl
    }
    
    init(data: Data, timestamp: Date, ttl: TimeInterval) {
        self.data = data
        self.timestamp = timestamp
        self.ttl = ttl
    }
}

struct CacheStats {
    let memorySize: Int
    let diskSize: Int
    let memoryCount: Int
    let diskCount: Int
    let hitRate: Double
    let missRate: Double
    
    var memorySizeMB: Double {
        Double(memorySize) / 1024.0 / 1024.0
    }
    
    var diskSizeMB: Double {
        Double(diskSize) / 1024.0 / 1024.0
    }
}

// MARK: - Cache Key Generation

extension APICache {
    static func generateKey(endpoint: String, parameters: [String: String] = [:]) -> String {
        var key = endpoint
        
        if !parameters.isEmpty {
            let sortedParams = parameters.sorted { $0.key < $1.key }
            let paramString = sortedParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            key += "?\(paramString)"
        }
        
        return key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
    }
    
    static func generateUserKey(userId: String, endpoint: String, parameters: [String: String] = [:]) -> String {
        return "user_\(userId)_\(generateKey(endpoint: endpoint, parameters: parameters))"
    }
}

// MARK: - Enhanced Cache Types

struct CachePolicy {
    let ttl: TimeInterval
    let priority: CachePriority
    let encryption: Bool
    
    static let `default` = CachePolicy(ttl: 300, priority: .medium, encryption: false)
}

enum CachePriority {
    case critical
    case high
    case medium
    case low
}

struct CacheStatistics {
    var totalSets: Int = 0
    var totalGets: Int = 0
    var averageResponseTime: TimeInterval = 0
    var memoryPressureEvents: Int = 0
    var encryptedKeys: Set<String> = []
}

struct EnhancedCacheStats {
    let basic: CacheStats
    let therapyResponsesCount: Int
    let moodDataCount: Int
    let voiceTranscriptsCount: Int
    let crisisResourcesCount: Int
    let encryptedItemsCount: Int
    let averageResponseTime: TimeInterval
    let memoryPressureEvents: Int
    
    var totalMentalHealthItems: Int {
        return therapyResponsesCount + moodDataCount + voiceTranscriptsCount + crisisResourcesCount
    }
    
    var encryptionRate: Double {
        let total = totalMentalHealthItems
        return total > 0 ? Double(encryptedItemsCount) / Double(total) : 0
    }
}

// MARK: - Mental Health Data Models

struct CrisisResource: Codable {
    let id: String
    let title: String
    let description: String
    let phoneNumber: String?
    let website: String?
    let location: String?
    let availability: String
    let priority: Int
}
