import Foundation
import OSLog

enum SecretsResolver {
    static func value(for key: String, placeholders: [String] = ["your-", "YOUR_"]) -> String? {
        if let envValue = sanitize(ProcessInfo.processInfo.environment[key], placeholders: placeholders) {
            return envValue
        }
        
        if let infoValue = sanitize(Bundle.main.object(forInfoDictionaryKey: key) as? String, placeholders: placeholders) {
            return infoValue
        }
        
        // Search resources with exact extension first
        for path in Bundle.main.paths(forResourcesOfType: "xcconfig", inDirectory: nil) {
            if let value = parseKey(key, in: path, placeholders: placeholders) {
                return value
            }
        }
        
        // Fallback: scan all bundle resources for filenames that end with ".xcconfig"
        if let bundleURL = Bundle.main.resourceURL,
           let fallback = try? scanAdditionalSecrets(in: bundleURL, key: key, placeholders: placeholders) {
            return fallback
        }
        
        return nil
    }
    
    static func logMissing(_ key: String) {
        print("⚠️ ProductionConfig: Missing configuration for \(key). Falling back to safe defaults.")
        MissingSecretReporter.recordMissing(key, feature: "Configuration fallback")
    }
    
    private static func sanitize(_ raw: String?, placeholders: [String]) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              placeholders.allSatisfy({ !trimmed.contains($0) }) else { return nil }
        return trimmed
    }
    
    private static func parseKey(_ key: String, in path: String, placeholders: [String]) -> String? {
        guard let contents = try? String(contentsOfFile: path) else { return nil }
        let lines = contents.split(whereSeparator: \.isNewline)
        let match = lines.first { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("\(key) ") || trimmed.hasPrefix("\(key)=")
        }
        
        if let match {
            let components = match.split(separator: "=", maxSplits: 1)
            if components.count == 2 {
                let value = String(components[1]).trimmingCharacters(in: .whitespaces)
                return sanitize(value, placeholders: placeholders)
            }
        }
        return nil
    }
    
    private static func scanAdditionalSecrets(in folder: URL, key: String, placeholders: [String]) throws -> String? {
        let resources = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        for resource in resources {
            let fileName = resource.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
            guard fileName.lowercased().hasSuffix(".xcconfig") else { continue }
            
            if let value = parseKey(key, in: resource.path, placeholders: placeholders) {
                return value
            }
        }
        return nil
    }
}

// MARK: - Missing Secret Reporting

enum MissingSecretReporter {
    private static let log = Logger(subsystem: "com.urgood.urgood", category: "ProductionConfig")
    private static let crashlytics = CrashlyticsService.shared
    
    static func recordMissing(_ key: String, feature: String) {
        log.error("⚠️ Missing secret \(key, privacy: .public) for feature \(feature, privacy: .public)")
        crashlytics.log("Missing secret \(key) for \(feature)", level: .error)
        NotificationCenter.default.post(
            name: .missingSecretDetected,
            object: nil,
            userInfo: ["key": key, "feature": feature]
        )
    }
}

extension Notification.Name {
    static let missingSecretDetected = Notification.Name("ProductionConfigMissingSecret")
}

struct ProductionConfig {
    
    // MARK: - RevenueCat Configuration
    static let revenueCatAPIKey: String = {
        if let key = SecretsResolver.value(for: "REVENUECAT_API_KEY") {
            return key
        }
#if DEBUG
        SecretsResolver.logMissing("REVENUECAT_API_KEY")
        return ""
#else
        MissingSecretReporter.recordMissing("REVENUECAT_API_KEY", feature: "RevenueCat subscriptions")
        return ""
#endif
    }()
    static let revenueCatEntitlementId = "premium"
    
    // MARK: - OpenAI Configuration
    static let openAIAPIKey: String = {
        if let key = SecretsResolver.value(for: "OPENAI_API_KEY", placeholders: ["your-", "YOUR_", "placeholder"]) {
            return key
        }
#if DEBUG
        SecretsResolver.logMissing("OPENAI_API_KEY")
        return ""
#else
        MissingSecretReporter.recordMissing("OPENAI_API_KEY", feature: "OpenAI requests")
        return ""
#endif
    }()
    static let openAIModel = "gpt-4o-mini"
    static let openAIMaxTokens = 1000
    
    // MARK: - Firebase Configuration
    static let firebaseProjectID = "urgood-dc7f0"
    
    // MARK: - App Store Configuration
    static let bundleIdentifier = "com.urgood.urgood"
    static let teamID = "JK7B7MXHZU"
    
    // MARK: - Subscription Products
    static let coreProductId = "urgood_core_monthly"
    
    // MARK: - Apple Sign In Configuration
    static let appleSignInServiceId = "com.urgood.urgood.signin"
    static let appleSignInDomain = "urgood-dc7f0.firebaseapp.com"
    
    // MARK: - Push Notifications
    static let pushNotificationKeyId: String = {
        if let keyId = SecretsResolver.value(for: "PUSH_KEY_ID", placeholders: ["YOUR_", "your-"]) {
            return keyId
        }
#if DEBUG
        SecretsResolver.logMissing("PUSH_KEY_ID")
        return ""
#else
        MissingSecretReporter.recordMissing("PUSH_KEY_ID", feature: "Push notifications")
        return ""
#endif
    }()
    static let pushNotificationTeamId = "JK7B7MXHZU"
    
    // MARK: - Environment Detection
    static var isProduction: Bool {
        #if DEBUG
        return false
        #else
        return true
        #endif
    }
    
    static var isDevelopment: Bool {
        return !isProduction
    }
    
    // MARK: - Validation
    static func validateConfiguration() -> [String] {
        var issues: [String] = []
        
        // Check if environment variables are properly configured
        if SecretsResolver.value(for: "REVENUECAT_API_KEY") == nil {
            issues.append("REVENUECAT_API_KEY not set in environment")
        }
        
        let openAIKey = SecretsResolver.value(for: "OPENAI_API_KEY", placeholders: ["your-openai-api-key-here", "YOUR_OPENAI"])
        if openAIKey?.isEmpty ?? true {
            issues.append("OPENAI_API_KEY not properly configured in environment")
        }
        
        let pushKey = SecretsResolver.value(for: "PUSH_KEY_ID", placeholders: ["YOUR_PUSH_KEY_ID"])
        if pushKey?.isEmpty ?? true {
            issues.append("PUSH_KEY_ID not properly configured in environment")
        }
        
        return issues
    }
    
    // MARK: - Logging
    static func logConfigurationStatus() {
        let issues = validateConfiguration()
        
        if issues.isEmpty {
            print("✅ Production configuration is valid")
        } else {
            print("⚠️ Production configuration issues:")
            for issue in issues {
                print("  - \(issue)")
            }
        }
    }
}
