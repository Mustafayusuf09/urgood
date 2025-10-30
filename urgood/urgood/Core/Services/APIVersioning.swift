import Foundation

class APIVersioning: ObservableObject {
    static let shared = APIVersioning()
    
    // Current API version
    let currentVersion = "1.0.0"
    
    // Supported versions
    private let supportedVersions = ["1.0.0", "1.1.0", "2.0.0"]
    
    // Version compatibility matrix
    private let compatibilityMatrix: [String: [String]] = [
        "1.0.0": ["1.0.0", "1.1.0"],
        "1.1.0": ["1.0.0", "1.1.0", "2.0.0"],
        "2.0.0": ["1.1.0", "2.0.0"]
    ]
    
    // Feature flags per version
    private let versionFeatures: [String: [String]] = [
        "1.0.0": ["basic_chat", "mood_tracking", "crisis_detection"],
        "1.1.0": ["basic_chat", "mood_tracking", "crisis_detection", "voice_chat", "analytics"],
        "2.0.0": ["basic_chat", "mood_tracking", "crisis_detection", "voice_chat", "analytics", "ai_insights", "real_time_sync"]
    ]
    
    private init() {}
    
    // MARK: - Version Management
    
    func getCurrentVersion() -> String {
        return currentVersion
    }
    
    func getSupportedVersions() -> [String] {
        return supportedVersions
    }
    
    func isVersionSupported(_ version: String) -> Bool {
        return supportedVersions.contains(version)
    }
    
    func isVersionCompatible(clientVersion: String, serverVersion: String) -> Bool {
        guard let compatibleVersions = compatibilityMatrix[serverVersion] else {
            return false
        }
        return compatibleVersions.contains(clientVersion)
    }
    
    // MARK: - Feature Flags
    
    func getFeatures(for version: String) -> [String] {
        return versionFeatures[version] ?? []
    }
    
    func isFeatureAvailable(_ feature: String, in version: String) -> Bool {
        let features = getFeatures(for: version)
        return features.contains(feature)
    }
    
    func getAvailableFeatures(for version: String) -> [String: Bool] {
        let allFeatures = Set(versionFeatures.values.flatMap { $0 })
        var result: [String: Bool] = [:]
        
        for feature in allFeatures {
            result[feature] = isFeatureAvailable(feature, in: version)
        }
        
        return result
    }
    
    // MARK: - Version Migration
    
    func getMigrationPath(from: String, to: String) -> [MigrationStep] {
        var steps: [MigrationStep] = []
        
        // Define migration steps based on version changes
        if from == "1.0.0" && to == "1.1.0" {
            steps.append(MigrationStep(
                version: "1.1.0",
                description: "Add voice chat support",
                required: false,
                breaking: false
            ))
            steps.append(MigrationStep(
                version: "1.1.0",
                description: "Add analytics tracking",
                required: false,
                breaking: false
            ))
        } else if from == "1.1.0" && to == "2.0.0" {
            steps.append(MigrationStep(
                version: "2.0.0",
                description: "Add AI insights",
                required: false,
                breaking: false
            ))
            steps.append(MigrationStep(
                version: "2.0.0",
                description: "Add real-time sync",
                required: false,
                breaking: false
            ))
            steps.append(MigrationStep(
                version: "2.0.0",
                description: "Update chat message format",
                required: true,
                breaking: true
            ))
        }
        
        return steps
    }
    
    // MARK: - API Endpoint Versioning
    
    func getVersionedEndpoint(_ endpoint: String, version: String? = nil) -> String {
        let apiVersion = version ?? currentVersion
        return "/v\(apiVersion.components(separatedBy: ".").first ?? "1")\(endpoint)"
    }
    
    func getBaseURL(for version: String) -> String {
        let majorVersion = version.components(separatedBy: ".").first ?? "1"
        return "https://api.urgood.app/v\(majorVersion)"
    }
    
    // MARK: - Deprecation Management
    
    func getDeprecatedEndpoints(for version: String) -> [DeprecatedEndpoint] {
        var deprecated: [DeprecatedEndpoint] = []
        
        if version == "2.0.0" {
            deprecated.append(DeprecatedEndpoint(
                endpoint: "/chat/messages/legacy",
                deprecatedIn: "1.1.0",
                removedIn: "2.0.0",
                replacement: "/chat/messages",
                migrationGuide: "https://docs.urgood.app/migration/chat-messages"
            ))
        }
        
        return deprecated
    }
    
    // MARK: - Client Version Validation
    
    func validateClientVersion(_ version: String) -> VersionValidationResult {
        if !isVersionSupported(version) {
            return .unsupported(version: version, supportedVersions: supportedVersions)
        }
        
        if !isVersionCompatible(clientVersion: version, serverVersion: currentVersion) {
            return .incompatible(clientVersion: version, serverVersion: currentVersion)
        }
        
        let features = getAvailableFeatures(for: version)
        let missingFeatures = features.filter { !$0.value }.map { $0.key }
        
        if !missingFeatures.isEmpty {
            return .featureLimited(version: version, missingFeatures: missingFeatures)
        }
        
        return .valid(version: version)
    }
    
    // MARK: - Version Headers
    
    func getVersionHeaders() -> [String: String] {
        return [
            "API-Version": currentVersion,
            "Client-Version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            "Supported-Versions": supportedVersions.joined(separator: ", "),
            "Accept-Version": currentVersion
        ]
    }
}

// MARK: - Version Models

struct MigrationStep {
    let version: String
    let description: String
    let required: Bool
    let breaking: Bool
}

struct DeprecatedEndpoint {
    let endpoint: String
    let deprecatedIn: String
    let removedIn: String
    let replacement: String
    let migrationGuide: String
}

enum VersionValidationResult {
    case valid(version: String)
    case unsupported(version: String, supportedVersions: [String])
    case incompatible(clientVersion: String, serverVersion: String)
    case featureLimited(version: String, missingFeatures: [String])
    
    var isValid: Bool {
        if case .valid = self {
            return true
        }
        return false
    }
    
    var errorMessage: String? {
        switch self {
        case .valid:
            return nil
        case .unsupported(let version, let supportedVersions):
            return "Version \(version) is not supported. Supported versions: \(supportedVersions.joined(separator: ", "))"
        case .incompatible(let clientVersion, let serverVersion):
            return "Client version \(clientVersion) is not compatible with server version \(serverVersion)"
        case .featureLimited(let version, let missingFeatures):
            return "Version \(version) is missing features: \(missingFeatures.joined(separator: ", "))"
        }
    }
}

// MARK: - Version Info

struct VersionInfo {
    let currentVersion: String
    let supportedVersions: [String]
    let features: [String: Bool]
    let deprecatedEndpoints: [DeprecatedEndpoint]
    let migrationSteps: [MigrationStep]
    let lastUpdated: Date
}

extension APIVersioning {
    func getVersionInfo() -> VersionInfo {
        return VersionInfo(
            currentVersion: currentVersion,
            supportedVersions: supportedVersions,
            features: getAvailableFeatures(for: currentVersion),
            deprecatedEndpoints: getDeprecatedEndpoints(for: currentVersion),
            migrationSteps: getMigrationPath(from: "1.0.0", to: currentVersion),
            lastUpdated: Date()
        )
    }
}
