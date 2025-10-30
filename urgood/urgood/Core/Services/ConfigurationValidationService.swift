import Foundation
import SwiftUI

/// Service to validate app configuration and environment setup
final class ConfigurationValidationService: ObservableObject {
    
    static let shared = ConfigurationValidationService()
    
    @Published private(set) var validationResults: ValidationResults?
    @Published private(set) var isValidating = false
    
    private init() {}
    
    // MARK: - Validation Results
    
    struct ValidationResults {
        let isValid: Bool
        let warnings: [ValidationIssue]
        let errors: [ValidationIssue]
        let timestamp: Date
        
        var hasIssues: Bool {
            return !warnings.isEmpty || !errors.isEmpty
        }
        
        var canProceed: Bool {
            return errors.isEmpty
        }
    }
    
    struct ValidationIssue {
        let category: Category
        let severity: Severity
        let message: String
        let suggestion: String?
        
        enum Category: String, CaseIterable {
            case network = "Network"
            case authentication = "Authentication"
            case configuration = "Configuration"
            case permissions = "Permissions"
            case services = "Services"
            case security = "Security"
        }
        
        enum Severity: String, CaseIterable {
            case error = "Error"
            case warning = "Warning"
            case info = "Info"
        }
    }
    
    // MARK: - Public Methods
    
    func validateConfiguration() async {
        await MainActor.run {
            isValidating = true
        }
        
        var warnings: [ValidationIssue] = []
        var errors: [ValidationIssue] = []
        
        // Validate environment configuration
        let envIssues = EnvironmentConfig.validateConfiguration()
        for issue in envIssues {
            errors.append(ValidationIssue(
                category: .configuration,
                severity: .error,
                message: issue,
                suggestion: "Check your environment configuration and build settings"
            ))
        }
        
        // Validate network connectivity
        await validateNetworkConnectivity(&warnings, &errors)
        
        // Validate API configuration
        validateAPIConfiguration(&warnings, &errors)
        
        // Validate Firebase configuration
        validateFirebaseConfiguration(&warnings, &errors)
        
        // Validate security settings
        validateSecurityConfiguration(&warnings, &errors)
        
        // Validate feature flags
        validateFeatureFlags(&warnings, &errors)
        
        // Validate development settings
        if EnvironmentConfig.isDevelopment {
            validateDevelopmentSettings(&warnings, &errors)
        }
        
        let results = ValidationResults(
            isValid: errors.isEmpty,
            warnings: warnings,
            errors: errors,
            timestamp: Date()
        )
        
        await MainActor.run {
            self.validationResults = results
            self.isValidating = false
        }
        
        // Log results
        logValidationResults(results)
        
        // Report to Crashlytics if there are issues
        if results.hasIssues {
            reportValidationIssues(results)
        }
    }
    
    // MARK: - Private Validation Methods
    
    private func validateNetworkConnectivity(_ warnings: inout [ValidationIssue], _ errors: inout [ValidationIssue]) async {
        // Test backend connectivity
        do {
            let url = URL(string: "\(EnvironmentConfig.Endpoints.health)")!
            let (_, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    warnings.append(ValidationIssue(
                        category: .network,
                        severity: .warning,
                        message: "Backend health check returned status \(httpResponse.statusCode)",
                        suggestion: "Check if the backend server is running and accessible"
                    ))
                }
            }
        } catch {
            if EnvironmentConfig.isProduction {
                errors.append(ValidationIssue(
                    category: .network,
                    severity: .error,
                    message: "Cannot connect to backend: \(error.localizedDescription)",
                    suggestion: "Check your internet connection and backend server status"
                ))
            } else {
                warnings.append(ValidationIssue(
                    category: .network,
                    severity: .warning,
                    message: "Cannot connect to local backend: \(error.localizedDescription)",
                    suggestion: "Make sure your local development server is running on the correct port"
                ))
            }
        }
    }
    
    private func validateAPIConfiguration(_ warnings: inout [ValidationIssue], _ errors: inout [ValidationIssue]) {
        // Validate OpenAI API key in development
        if EnvironmentConfig.isDevelopment {
            let apiKey = APIConfig.openAIAPIKey
            if apiKey.isEmpty {
                warnings.append(ValidationIssue(
                    category: .configuration,
                    severity: .warning,
                    message: "OpenAI API key not configured for development",
                    suggestion: "Set OPENAI_API_KEY environment variable in Xcode scheme"
                ))
            } else if !apiKey.hasPrefix("sk-") {
                errors.append(ValidationIssue(
                    category: .configuration,
                    severity: .error,
                    message: "Invalid OpenAI API key format",
                    suggestion: "OpenAI API keys should start with 'sk-'"
                ))
            }
        }
        
        // Validate ElevenLabs configuration
        if EnvironmentConfig.isDevelopment && APIConfig.useElevenLabs {
            if let elevenLabsKey = APIConfig.elevenLabsAPIKey, elevenLabsKey.isEmpty {
                warnings.append(ValidationIssue(
                    category: .configuration,
                    severity: .warning,
                    message: "ElevenLabs API key not configured",
                    suggestion: "Set ELEVENLABS_API_KEY environment variable for voice features"
                ))
            }
        }
    }
    
    private func validateFirebaseConfiguration(_ warnings: inout [ValidationIssue], _ errors: inout [ValidationIssue]) {
        // Check if GoogleService-Info.plist exists
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path) else {
            errors.append(ValidationIssue(
                category: .configuration,
                severity: .error,
                message: "GoogleService-Info.plist not found",
                suggestion: "Download GoogleService-Info.plist from Firebase Console and add it to your project"
            ))
            return
        }
        
        // Validate Firebase project ID
        guard let projectId = plist["PROJECT_ID"] as? String,
              projectId == EnvironmentConfig.firebaseProjectId else {
            errors.append(ValidationIssue(
                category: .configuration,
                severity: .error,
                message: "Firebase project ID mismatch",
                suggestion: "Ensure GoogleService-Info.plist matches the configured project ID"
            ))
            return
        }
        
        // Validate bundle ID
        if let bundleId = plist["BUNDLE_ID"] as? String,
           bundleId != EnvironmentConfig.App.bundleId {
            warnings.append(ValidationIssue(
                category: .configuration,
                severity: .warning,
                message: "Firebase bundle ID mismatch",
                suggestion: "Ensure GoogleService-Info.plist bundle ID matches your app's bundle ID"
            ))
        }
    }
    
    private func validateSecurityConfiguration(_ warnings: inout [ValidationIssue], _ errors: inout [ValidationIssue]) {
        // Check HTTPS requirement in production
        if EnvironmentConfig.isProduction {
            if !EnvironmentConfig.backendURL.hasPrefix("https://") {
                errors.append(ValidationIssue(
                    category: .security,
                    severity: .error,
                    message: "Production backend URL must use HTTPS",
                    suggestion: "Update backend URL to use HTTPS protocol"
                ))
            }
            
            if !EnvironmentConfig.Security.certificatePinningEnabled {
                warnings.append(ValidationIssue(
                    category: .security,
                    severity: .warning,
                    message: "Certificate pinning is disabled in production",
                    suggestion: "Enable certificate pinning for enhanced security"
                ))
            }
        }
        
        // Check for localhost URLs in production
        if EnvironmentConfig.isProduction && EnvironmentConfig.backendURL.contains("localhost") {
            errors.append(ValidationIssue(
                category: .security,
                severity: .error,
                message: "Production build contains localhost URLs",
                suggestion: "Update configuration to use production URLs"
            ))
        }
    }
    
    private func validateFeatureFlags(_ warnings: inout [ValidationIssue], _ errors: inout [ValidationIssue]) {
        // Validate feature dependencies
        if EnvironmentConfig.Features.voiceChatEnabled && !EnvironmentConfig.Features.analyticsEnabled {
            warnings.append(ValidationIssue(
                category: .configuration,
                severity: .warning,
                message: "Voice chat enabled without analytics",
                suggestion: "Consider enabling analytics for voice chat monitoring"
            ))
        }
        
        if EnvironmentConfig.Features.crisisDetectionEnabled && !EnvironmentConfig.Features.analyticsEnabled {
            warnings.append(ValidationIssue(
                category: .configuration,
                severity: .warning,
                message: "Crisis detection enabled without analytics",
                suggestion: "Enable analytics for crisis detection monitoring"
            ))
        }
    }
    
    private func validateDevelopmentSettings(_ warnings: inout [ValidationIssue], _ errors: inout [ValidationIssue]) {
        // Check for development-specific configurations
        if EnvironmentConfig.Development.mockAPIResponses {
            warnings.append(ValidationIssue(
                category: .configuration,
                severity: .info,
                message: "Mock API responses are enabled",
                suggestion: "Disable mock responses for real API testing"
            ))
        }
        
        if EnvironmentConfig.Development.skipOnboarding {
            warnings.append(ValidationIssue(
                category: .configuration,
                severity: .info,
                message: "Onboarding is skipped in development",
                suggestion: "Test onboarding flow before production release"
            ))
        }
        
        // Check for missing environment variables
        let requiredEnvVars = ["OPENAI_API_KEY"]
        for envVar in requiredEnvVars {
            if ProcessInfo.processInfo.environment[envVar]?.isEmpty != false {
                warnings.append(ValidationIssue(
                    category: .configuration,
                    severity: .warning,
                    message: "Environment variable \(envVar) not set",
                    suggestion: "Set \(envVar) in your Xcode scheme for development"
                ))
            }
        }
    }
    
    // MARK: - Logging and Reporting
    
    private func logValidationResults(_ results: ValidationResults) {
        print("🔍 [ConfigValidation] Validation completed:")
        print("   Status: \(results.isValid ? "✅ Valid" : "❌ Invalid")")
        print("   Errors: \(results.errors.count)")
        print("   Warnings: \(results.warnings.count)")
        
        if EnvironmentConfig.Features.debugModeEnabled {
            for error in results.errors {
                print("   ❌ [\(error.category.rawValue)] \(error.message)")
                if let suggestion = error.suggestion {
                    print("      💡 \(suggestion)")
                }
            }
            
            for warning in results.warnings {
                print("   ⚠️ [\(warning.category.rawValue)] \(warning.message)")
                if let suggestion = warning.suggestion {
                    print("      💡 \(suggestion)")
                }
            }
        }
    }
    
    private func reportValidationIssues(_ results: ValidationResults) {
        let crashlytics = CrashlyticsService.shared
        
        // Report configuration errors
        for error in results.errors {
            crashlytics.recordError(
                NSError(domain: "ConfigurationValidation", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: error.message
                ]),
                userInfo: [
                    "category": error.category.rawValue,
                    "severity": error.severity.rawValue,
                    "suggestion": error.suggestion ?? "",
                    "environment": EnvironmentConfig.isProduction ? "production" : "development"
                ]
            )
        }
        
        // Log validation summary
        crashlytics.log("Configuration validation: \(results.errors.count) errors, \(results.warnings.count) warnings", level: results.errors.isEmpty ? .warning : .error)
        
        // Set custom values for debugging
        crashlytics.setCustomValue(results.isValid, forKey: "config_valid")
        crashlytics.setCustomValue(results.errors.count, forKey: "config_errors")
        crashlytics.setCustomValue(results.warnings.count, forKey: "config_warnings")
    }
    
    // MARK: - Public Helpers
    
    func getIssuesByCategory() -> [ValidationIssue.Category: [ValidationIssue]] {
        guard let results = validationResults else { return [:] }
        
        let allIssues = results.errors + results.warnings
        return Dictionary(grouping: allIssues) { $0.category }
    }
    
    func hasErrorsInCategory(_ category: ValidationIssue.Category) -> Bool {
        guard let results = validationResults else { return false }
        return results.errors.contains { $0.category == category }
    }
    
    func canUseFeature(_ feature: String) -> Bool {
        guard let results = validationResults else { return false }
        
        // Feature-specific validation logic
        switch feature {
        case "voice_chat":
            return !hasErrorsInCategory(.network) && !hasErrorsInCategory(.authentication)
        case "crisis_detection":
            return !hasErrorsInCategory(.services) && !hasErrorsInCategory(.configuration)
        default:
            return results.canProceed
        }
    }
}
