import Foundation
import Combine

class RemoteFeatureFlags: ObservableObject {
    static let shared = RemoteFeatureFlags()
    
    // Feature flag storage
    private var featureFlags: [String: FeatureFlag] = [:]
    private var userOverrides: [String: Bool] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    // A/B Testing
    private var experiments: [String: RemoteExperiment] = [:]
    private var userAssignments: [String: String] = [:]
    
    // Configuration
    private let apiService = APIService.shared
    private let localStore = EnhancedLocalStore.shared
    private let refreshInterval: TimeInterval = 300 // 5 minutes
    
    private init() {
        loadLocalFlags()
        startPeriodicRefresh()
    }
    
    // MARK: - Feature Flag Management
    
    func getFeatureFlag(_ name: String) -> Bool {
        // Check user override first
        if let override = userOverrides[name] {
            return override
        }
        
        // Check feature flag
        if let flag = featureFlags[name] {
            return evaluateFeatureFlag(flag)
        }
        
        // Default to false
        return false
    }
    
    func setFeatureFlag(_ name: String, enabled: Bool) {
        featureFlags[name] = FeatureFlag(
            name: name,
            enabled: enabled,
            rolloutPercentage: enabled ? 100 : 0,
            conditions: [],
            experimentId: nil
        )
        
        saveLocalFlags()
        print("✅ Set feature flag: \(name) = \(enabled)")
    }
    
    func setUserOverride(_ name: String, enabled: Bool) {
        userOverrides[name] = enabled
        saveLocalFlags()
        print("✅ Set user override: \(name) = \(enabled)")
    }
    
    func clearUserOverride(_ name: String) {
        userOverrides.removeValue(forKey: name)
        saveLocalFlags()
        print("❌ Cleared user override: \(name)")
    }
    
    func getAllFeatureFlags() -> [String: Bool] {
        var flags: [String: Bool] = [:]
        
        for (name, _) in featureFlags {
            flags[name] = getFeatureFlag(name)
        }
        
        return flags
    }
    
    // MARK: - A/B Testing
    
    func getExperimentVariant(_ experimentId: String) -> String? {
        // Check if user is already assigned
        if let variant = userAssignments[experimentId] {
            return variant
        }
        
        // Check if experiment exists
        guard let experiment = experiments[experimentId] else {
            return nil
        }
        
        // Assign user to variant
        let variant = assignUserToVariant(experiment)
        userAssignments[experimentId] = variant
        
        // Save assignment
        saveUserAssignments()
        
        print("🧪 Assigned user to experiment \(experimentId): \(variant)")
        return variant
    }
    
    func getExperimentValue(_ experimentId: String, key: String) -> Any? {
        guard let variant = getExperimentVariant(experimentId),
              let experiment = experiments[experimentId] else {
            return nil
        }
        
        return experiment.variants[variant]
    }
    
    func trackExperimentEvent(_ experimentId: String, event: String, properties: [String: Any] = [:]) {
        guard let variant = userAssignments[experimentId] else {
            return
        }
        
        let eventData: [String: Any] = [
            "experiment_id": experimentId,
            "variant": variant,
            "event": event,
            "properties": properties,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // Track in analytics
        let analyticsService = RealAnalyticsService.shared
        analyticsService.logEvent("experiment_event", parameters: eventData)
        
        print("📊 Tracked experiment event: \(experimentId) - \(event) - \(variant)")
    }
    
    // MARK: - Remote Configuration
    
    func refreshFeatureFlags() {
        // In a real implementation, this would fetch from API
        // For now, we'll simulate with local data
        
        let mockFlags = [
            "voice_chat_enabled": FeatureFlag(
                name: "voice_chat_enabled",
                enabled: true,
                rolloutPercentage: 100,
                conditions: [],
                experimentId: nil
            ),
            "ai_insights_enabled": FeatureFlag(
                name: "ai_insights_enabled",
                enabled: true,
                rolloutPercentage: 50,
                conditions: [],
                experimentId: "ai_insights_experiment"
            ),
            "crisis_detection_enabled": FeatureFlag(
                name: "crisis_detection_enabled",
                enabled: true,
                rolloutPercentage: 100,
                conditions: [],
                experimentId: nil
            ),
            "analytics_enabled": FeatureFlag(
                name: "analytics_enabled",
                enabled: true,
                rolloutPercentage: 100,
                conditions: [],
                experimentId: nil
            ),
            "premium_features_enabled": FeatureFlag(
                name: "premium_features_enabled",
                enabled: false,
                rolloutPercentage: 0,
                conditions: [],
                experimentId: nil
            )
        ]
        
        for (name, flag) in mockFlags {
            featureFlags[name] = flag
        }
        
        // Setup experiments
        setupExperiments()
        
        saveLocalFlags()
        print("🔄 Refreshed feature flags from remote")
    }
    
    private func setupExperiments() {
        experiments["ai_insights_experiment"] = RemoteExperiment(
            id: "ai_insights_experiment",
            name: "AI Insights Experiment",
            variants: [
                "control": "basic",
                "treatment_a": "detailed", 
                "treatment_b": "minimal"
            ],
            trafficAllocation: [
                "control": 0.33,
                "treatment_a": 0.33,
                "treatment_b": 0.34
            ],
            isActive: true,
            startDate: Date().addingTimeInterval(-86400 * 3),
            endDate: nil
        )
    }
    
    // MARK: - Feature Flag Evaluation
    
    private func evaluateFeatureFlag(_ flag: FeatureFlag) -> Bool {
        // Check if flag is enabled
        guard flag.enabled else { return false }
        
        // Check rollout percentage
        let userId = getUserId()
        let hash = hashUserId(userId)
        let percentage = (hash % 100) + 1
        
        if percentage > flag.rolloutPercentage {
            return false
        }
        
        // Check conditions
        for condition in flag.conditions {
            if !evaluateCondition(condition) {
                return false
            }
        }
        
        // Check experiment assignment
        if let experimentId = flag.experimentId {
            guard let variant = getExperimentVariant(experimentId) else {
                return false
            }
            
            // Check if variant enables the feature
            return variant != "control"
        }
        
        return true
    }
    
    private func evaluateCondition(_ condition: FeatureFlagCondition) -> Bool {
        switch condition.type {
        case .userProperty:
            return evaluateUserPropertyCondition(condition)
        case .deviceProperty:
            return evaluateDevicePropertyCondition(condition)
        case .timeBased:
            return evaluateTimeBasedCondition(condition)
        case .locationBased:
            return evaluateLocationBasedCondition(condition)
        }
    }
    
    private func evaluateUserPropertyCondition(_ condition: FeatureFlagCondition) -> Bool {
        // This would check user properties in a real implementation
        return true
    }
    
    private func evaluateDevicePropertyCondition(_ condition: FeatureFlagCondition) -> Bool {
        // This would check device properties in a real implementation
        return true
    }
    
    private func evaluateTimeBasedCondition(_ condition: FeatureFlagCondition) -> Bool {
        // This would check time-based conditions in a real implementation
        return true
    }
    
    private func evaluateLocationBasedCondition(_ condition: FeatureFlagCondition) -> Bool {
        // This would check location-based conditions in a real implementation
        return true
    }
    
    // MARK: - A/B Testing Logic
    
    private func assignUserToVariant(_ experiment: RemoteExperiment) -> String {
        let userId = getUserId()
        let hash = hashUserId(userId + experiment.id)
        let percentage = (hash % 100) + 1
        
        var cumulativePercentage = 0.0
        for (variant, allocation) in experiment.trafficAllocation {
            cumulativePercentage += allocation * 100
            if Double(percentage) <= cumulativePercentage {
                return variant
            }
        }
        
        return "control"
    }
    
    private func hashUserId(_ userId: String) -> Int {
        var hash = 0
        for char in userId.utf8 {
            hash = ((hash << 5) - hash) + Int(char)
            hash = hash & hash // Convert to 32-bit integer
        }
        return abs(hash)
    }
    
    private func getUserId() -> String {
        return "user_\(localStore.user.subscriptionStatus.rawValue)_\(localStore.user.streakCount)"
    }
    
    // MARK: - Local Storage
    
    private func loadLocalFlags() {
        if let data = UserDefaults.standard.data(forKey: "feature_flags"),
           let flags = try? JSONDecoder().decode([String: FeatureFlag].self, from: data) {
            featureFlags = flags
        }
        
        if let data = UserDefaults.standard.data(forKey: "user_overrides"),
           let overrides = try? JSONDecoder().decode([String: Bool].self, from: data) {
            userOverrides = overrides
        }
        
        if let data = UserDefaults.standard.data(forKey: "user_assignments"),
           let assignments = try? JSONDecoder().decode([String: String].self, from: data) {
            userAssignments = assignments
        }
    }
    
    private func saveLocalFlags() {
        if let data = try? JSONEncoder().encode(featureFlags) {
            UserDefaults.standard.set(data, forKey: "feature_flags")
        }
        
        if let data = try? JSONEncoder().encode(userOverrides) {
            UserDefaults.standard.set(data, forKey: "user_overrides")
        }
        
        if let data = try? JSONEncoder().encode(userAssignments) {
            UserDefaults.standard.set(data, forKey: "user_assignments")
        }
    }
    
    private func saveUserAssignments() {
        if let data = try? JSONEncoder().encode(userAssignments) {
            UserDefaults.standard.set(data, forKey: "user_assignments")
        }
    }
    
    // MARK: - Periodic Refresh
    
    private func startPeriodicRefresh() {
        Timer.publish(every: refreshInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshFeatureFlags()
            }
            .store(in: &cancellables)
        
        // Initial refresh
        refreshFeatureFlags()
    }
}

// MARK: - Feature Flag Models

struct FeatureFlag: Codable {
    let name: String
    let enabled: Bool
    let rolloutPercentage: Int
    let conditions: [FeatureFlagCondition]
    let experimentId: String?
}

struct FeatureFlagCondition: Codable {
    let type: ConditionType
    let property: String
    let `operator`: ConditionOperator
    let value: String
    
    enum ConditionType: String, Codable {
        case userProperty = "user_property"
        case deviceProperty = "device_property"
        case timeBased = "time_based"
        case locationBased = "location_based"
    }
    
    enum ConditionOperator: String, Codable {
        case equals = "equals"
        case notEquals = "not_equals"
        case contains = "contains"
        case notContains = "not_contains"
        case greaterThan = "greater_than"
        case lessThan = "less_than"
    }
}

struct RemoteExperiment: Codable {
    let id: String
    let name: String
    let variants: [String: String] // Simplified to String values
    let trafficAllocation: [String: Double]
    let isActive: Bool
    let startDate: Date?
    let endDate: Date?

    init(
        id: String,
        name: String,
        variants: [String: String],
        trafficAllocation: [String: Double],
        isActive: Bool,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.variants = variants
        self.trafficAllocation = trafficAllocation
        self.isActive = isActive
        self.startDate = startDate
        self.endDate = endDate
    }
}

// MARK: - Feature Flag Extensions

extension RemoteFeatureFlags {
    // Convenience methods for common feature flags
    
    var isVoiceChatEnabled: Bool {
        return getFeatureFlag("voice_chat_enabled")
    }
    
    var isAIInsightsEnabled: Bool {
        return getFeatureFlag("ai_insights_enabled")
    }
    
    var isCrisisDetectionEnabled: Bool {
        return getFeatureFlag("crisis_detection_enabled")
    }
    
    var isAnalyticsEnabled: Bool {
        return getFeatureFlag("analytics_enabled")
    }
    
    var isPremiumFeaturesEnabled: Bool {
        return getFeatureFlag("premium_features_enabled")
    }
}
