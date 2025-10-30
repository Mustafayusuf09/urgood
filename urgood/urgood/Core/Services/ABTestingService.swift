import Foundation
import Combine
import OSLog

class ABTestingService: ObservableObject {
    static let shared = ABTestingService()
    
    @Published var activeExperiments: [RemoteExperiment] = [] {
        didSet {
            Task { await saveActiveExperiments() }
        }
    }
    @Published var userVariants: [String: String] = [:]
    
    private let analyticsService = RealAnalyticsService.shared
    private let remoteFeatureFlags = RemoteFeatureFlags.shared
    private let experimentStorage = ExperimentStorage()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadActiveExperiments()
        loadUserVariants()
    }
    
    // MARK: - Experiment Management
    
    func createExperiment(_ experiment: RemoteExperiment) async {
        // Validate experiment
        guard validateExperiment(experiment) else {
            print("❌ Invalid experiment: \(experiment.id)")
            return
        }
        
        // Add to active experiments
        _ = await MainActor.run {
            activeExperiments.append(experiment)
        }
        
        // Log experiment creation
        analyticsService.logEvent("experiment_created", parameters: [
            "experiment_id": experiment.id,
            "name": experiment.name,
            "variants": experiment.variants.keys.joined(separator: ",")
        ])
    }
    
    func updateExperiment(_ experiment: RemoteExperiment) async {
        guard let index = activeExperiments.firstIndex(where: { $0.id == experiment.id }) else {
            print("❌ Experiment not found: \(experiment.id)")
            return
        }
        
        _ = await MainActor.run {
            activeExperiments[index] = experiment
        }
        
        analyticsService.logEvent("experiment_updated", parameters: [
            "experiment_id": experiment.id,
            "name": experiment.name
        ])
    }
    
    func endExperiment(_ experimentId: String) async {
        guard let index = activeExperiments.firstIndex(where: { $0.id == experimentId }) else {
            print("❌ Experiment not found: \(experimentId)")
            return
        }
        
        let experiment = activeExperiments[index]
        
        _ = await MainActor.run {
            activeExperiments.remove(at: index)
        }
        
        analyticsService.logEvent("experiment_ended", parameters: [
            "experiment_id": experimentId,
            "name": experiment.name
        ])
    }
    
    // MARK: - Variant Assignment
    
    func getVariant(for experimentId: String, userId: String) -> String? {
        // Check if user already has a variant assigned
        if let existingVariant = userVariants[experimentId] {
            return existingVariant
        }
        
        // Find the experiment
        guard let experiment = activeExperiments.first(where: { $0.id == experimentId }) else {
            return nil
        }
        
        // Check if user is eligible
        guard isUserEligible(userId: userId, experiment: experiment) else {
            return nil
        }
        
        // Assign variant based on experiment configuration (simplified)
        let variant = Array(experiment.variants.keys).randomElement() ?? "control"
        
        // Store variant assignment
        userVariants[experimentId] = variant
        
        // Log variant assignment
        analyticsService.logEvent("variant_assigned", parameters: [
            "experiment_id": experimentId,
            "variant": variant,
            "user_id": userId
        ])
        
        return variant
    }
    
    func getVariantValue(for experimentId: String, userId: String) -> String? {
        guard let variant = getVariant(for: experimentId, userId: userId) else {
            return nil
        }
        
        guard let experiment = activeExperiments.first(where: { $0.id == experimentId }) else {
            return nil
        }
        
        return experiment.variants[variant]
    }
    
    func getVariantValue<T>(for experimentId: String, userId: String, type: T.Type) -> T? {
        guard let value = getVariantValue(for: experimentId, userId: userId) else {
            return nil
        }
        
        return value as? T
    }
    
    // MARK: - Feature Flags
    
    func isFeatureEnabled(_ featureName: String, userId: String) -> Bool {
        // Check remote feature flags
        return remoteFeatureFlags.getFeatureFlag(featureName)
    }
    
    func getFeatureValue(_ featureName: String, userId: String) -> Any? {
        // Check remote feature flags
        return remoteFeatureFlags.getFeatureFlag(featureName)
    }
    
    // MARK: - Event Tracking
    
    func trackEvent(_ eventName: String, experimentId: String, userId: String, properties: [String: Any] = [:]) {
        guard let variant = userVariants[experimentId] else {
            return
        }
        
        var eventProperties = properties
        eventProperties["experiment_id"] = experimentId
        eventProperties["variant"] = variant
        eventProperties["user_id"] = userId
        
        analyticsService.logEvent(eventName, parameters: eventProperties)
    }
    
    func trackConversion(_ experimentId: String, userId: String, conversionValue: Double? = nil) {
        guard let variant = userVariants[experimentId] else {
            return
        }
        
        var parameters: [String: Any] = [
            "experiment_id": experimentId,
            "variant": variant,
            "user_id": userId
        ]
        
        if let conversionValue = conversionValue {
            parameters["conversion_value"] = conversionValue
        }
        
        analyticsService.logEvent("conversion", parameters: parameters)
    }
    
    // MARK: - Experiment Analysis
    
    func getExperimentResults(_ experimentId: String) async -> ExperimentResults? {
        guard let experiment = activeExperiments.first(where: { $0.id == experimentId }) else {
            return nil
        }
        
        // Get analytics data for the experiment
        let analyticsData = await getAnalyticsData(for: experimentId)
        
        // Calculate statistical significance
        let significance = calculateStatisticalSignificance(analyticsData)
        
        // Determine winning variant
        let winningVariant = determineWinningVariant(analyticsData)
        
        return ExperimentResults(
            experimentId: experimentId,
            experimentName: experiment.name,
            variants: Array(experiment.variants.keys).map { variant in
                VariantResults(
                    variant: variant,
                    participants: analyticsData[variant]?.participants ?? 0,
                    conversions: analyticsData[variant]?.conversions ?? 0,
                    conversionRate: analyticsData[variant]?.conversionRate ?? 0.0,
                    confidence: significance[variant] ?? 0.0
                )
            },
            winningVariant: winningVariant,
            isStatisticallySignificant: significance.values.contains { $0 > 0.95 },
            startDate: Date(), // RemoteExperiment doesn't have startDate
            endDate: Date().addingTimeInterval(86400 * 30) // Default 30 days
        )
    }
    
    func getExperimentMetrics(_ experimentId: String) async -> ExperimentMetrics {
        let analyticsData = await getAnalyticsData(for: experimentId)
        
        let totalParticipants = analyticsData.values.reduce(0) { $0 + $1.participants }
        let totalConversions = analyticsData.values.reduce(0) { $0 + $1.conversions }
        let overallConversionRate = totalParticipants > 0 ? Double(totalConversions) / Double(totalParticipants) : 0.0
        
        return ExperimentMetrics(
            experimentId: experimentId,
            totalParticipants: totalParticipants,
            totalConversions: totalConversions,
            overallConversionRate: overallConversionRate,
            startDate: Date(), // RemoteExperiment doesn't have startDate
            endDate: Date().addingTimeInterval(86400 * 30) // Default 30 days
        )
    }
    
    // MARK: - Multivariate Testing
    
    func createMultivariateExperiment(_ experiment: MultivariateExperiment) async {
        // Convert multivariate experiment to multiple A/B tests (simplified)
        let abExperiment = RemoteExperiment(
            id: experiment.id,
            name: experiment.name,
            variants: ["control": "default", "treatment": "variant"],
            trafficAllocation: ["control": 0.5, "treatment": 0.5],
            isActive: true
        )
        
        await createExperiment(abExperiment)
    }
    
    func getMultivariateVariant(for experimentId: String, userId: String) -> [String: String] {
        var variants: [String: String] = [:]
        
        // Get variants for each factor
        for factor in getExperimentFactors(experimentId) {
            if let variant = getVariant(for: "\(experimentId)_\(factor)", userId: userId) {
                variants[factor] = variant
            }
        }
        
        return variants
    }
    
    // MARK: - Private Methods
    
    private func validateExperiment(_ experiment: RemoteExperiment) -> Bool {
        // Check if experiment has at least 2 variants
        guard experiment.variants.count >= 2 else {
            return false
        }
        
        // Check if experiment has valid traffic allocation
        let totalAllocation = experiment.trafficAllocation.values.reduce(0, +)
        guard totalAllocation <= 1.0 else {
            return false
        }
        
        return true
    }
    
    private func isUserEligible(userId: String, experiment: RemoteExperiment) -> Bool {
        // Simplified eligibility check - always eligible for now
        return true
    }
    
    private func evaluateCriteria(_ criteria: EligibilityCriteria, userId: String) -> Bool {
        switch criteria {
        case .userProperty(let property, let value):
            // Check user property
            return checkUserProperty(property, value: value, userId: userId)
        case .userSegment(let segment):
            // Check user segment
            return checkUserSegment(segment, userId: userId)
        case .dateRange(let startDate, let endDate):
            // Check date range
            let now = Date()
            return now >= startDate && now <= endDate
        case .trafficPercentage(let percentage):
            // Check traffic percentage
            return Double.random(in: 0...1) < percentage
        }
    }
    
    private func checkUserProperty(_ property: String, value: Any, userId: String) -> Bool {
        // Implement user property checking
        return true // Placeholder
    }
    
    private func checkUserSegment(_ segment: String, userId: String) -> Bool {
        // Implement user segment checking
        return true // Placeholder
    }
    
    private func assignVariant(userId: String, experiment: RemoteExperiment) -> String {
        // Use consistent hashing to ensure same user gets same variant
        let hash = userId.hashValue
        let normalizedHash = abs(hash) % 100
        
        var cumulativePercentage = 0.0
        for (variant, _) in experiment.variants {
            let allocation = experiment.trafficAllocation[variant] ?? 0.0
            cumulativePercentage += allocation * 100
            
            if Double(normalizedHash) < cumulativePercentage {
                return variant
            }
        }
        
        // Fallback to first variant
        return experiment.variants.keys.first ?? "control"
    }
    
    private func loadActiveExperiments() {
        Task {
            let experiments = await experimentStorage.loadActiveExperiments()
            _ = await MainActor.run {
                self.activeExperiments = experiments
            }
        }
    }
    
    private func saveActiveExperiments() async {
        for experiment in activeExperiments {
            await experimentStorage.saveExperiment(experiment)
        }
    }
    
    private func loadUserVariants() {
        // Load user variants from storage
        userVariants = UserDefaults.standard.dictionary(forKey: "user_variants") as? [String: String] ?? [:]
    }
    
    private func getAnalyticsData(for experimentId: String) async -> [String: VariantAnalytics] {
        // Simulate analytics data retrieval
        return [
            "control": VariantAnalytics(participants: 1000, conversions: 50, conversionRate: 0.05),
            "variant_a": VariantAnalytics(participants: 1000, conversions: 60, conversionRate: 0.06),
            "variant_b": VariantAnalytics(participants: 1000, conversions: 55, conversionRate: 0.055)
        ]
    }
    
    private func calculateStatisticalSignificance(_ analyticsData: [String: VariantAnalytics]) -> [String: Double] {
        // Implement statistical significance calculation
        return analyticsData.mapValues { _ in Double.random(in: 0.8...0.99) }
    }
    
    private func determineWinningVariant(_ analyticsData: [String: VariantAnalytics]) -> String? {
        return analyticsData.max { $0.value.conversionRate < $1.value.conversionRate }?.key
    }
    
    private func convertToABExperiments(_ experiment: MultivariateExperiment) -> [Experiment] {
        // Convert multivariate experiment to multiple A/B tests
        return []
    }
    
    private func getExperimentFactors(_ experimentId: String) -> [String] {
        // Get factors for multivariate experiment
        return []
    }
}

// MARK: - Experiment Storage

class ExperimentStorage {
    private let crashlytics = CrashlyticsService.shared
    private let log = Logger(subsystem: "com.urgood.urgood", category: "ExperimentStorage")
    
    func saveExperiment(_ experiment: RemoteExperiment) async {
        // Save experiment to persistent storage
        do {
            let data = try JSONEncoder().encode(experiment)
            UserDefaults.standard.set(data, forKey: "experiment_\(experiment.id)")
        } catch {
            log.error("🧪 Failed to encode experiment \(experiment.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
    
    func loadActiveExperiments() async -> [RemoteExperiment] {
        // Load active experiments from storage
        let defaults = UserDefaults.standard
        let keys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("experiment_") }
        var experiments: [RemoteExperiment] = []
        for key in keys {
            if let data = defaults.data(forKey: key),
               let experiment = try? JSONDecoder().decode(RemoteExperiment.self, from: data) {
                experiments.append(experiment)
            }
        }
        return experiments.filter { $0.isActive }
    }
    
    func deleteExperiment(_ experimentId: String) async {
        UserDefaults.standard.removeObject(forKey: "experiment_\(experimentId)")
    }
}

// MARK: - Supporting Types


enum ExperimentStatus: String, CaseIterable {
    case draft = "draft"
    case running = "running"
    case paused = "paused"
    case completed = "completed"
}

enum EligibilityCriteria {
    case userProperty(String, Any)
    case userSegment(String)
    case dateRange(Date, Date)
    case trafficPercentage(Double)
}

struct MultivariateExperiment {
    let id: String
    let name: String
    let factors: [ExperimentFactor]
    let startDate: Date
    let endDate: Date
}

struct ExperimentFactor {
    let name: String
    let variants: [String]
    let trafficAllocation: [String: Double]
}

struct ExperimentResults {
    let experimentId: String
    let experimentName: String
    let variants: [VariantResults]
    let winningVariant: String?
    let isStatisticallySignificant: Bool
    let startDate: Date
    let endDate: Date?
}

struct VariantResults {
    let variant: String
    let participants: Int
    let conversions: Int
    let conversionRate: Double
    let confidence: Double
}

struct ExperimentMetrics {
    let experimentId: String
    let totalParticipants: Int
    let totalConversions: Int
    let overallConversionRate: Double
    let startDate: Date
    let endDate: Date?
}

struct VariantAnalytics {
    let participants: Int
    let conversions: Int
    let conversionRate: Double
}
