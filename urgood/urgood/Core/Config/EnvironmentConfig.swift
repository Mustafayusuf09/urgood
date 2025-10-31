import Foundation

/// Comprehensive environment configuration for UrGood app
/// Handles all URLs, API endpoints, and environment-specific settings
struct EnvironmentConfig {
    
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
    
    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    // MARK: - Backend Configuration
    
    /// Main backend API URL
    static var backendURL: String {
        if let customURL = ProcessInfo.processInfo.environment["URGOOD_BACKEND_URL"],
           !customURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return customURL
        }

        if let secretsURL = SecretsResolver.value(for: "BACKEND_BASE_URL", placeholders: ["your-", "YOUR_", "placeholder"]),
           !secretsURL.isEmpty {
            return secretsURL
        }

        if isProduction {
            return "https://api.urgood.app"
        }

        // When running a debug build on a physical device, "localhost" resolves to the device itself.
        // Fall back to the production API unless a custom override is supplied so end users stay connected.
        if !isSimulator {
            return "https://api.urgood.app"
        }

        return "http://localhost:3001"
    }
    
    /// WebSocket URL for real-time features
    static var websocketURL: String {
        let baseURL = backendURL.replacingOccurrences(of: "http://", with: "ws://")
                                .replacingOccurrences(of: "https://", with: "wss://")
        return "\(baseURL)/ws"
    }
    
    // MARK: - Firebase Configuration
    
    /// Firebase project configuration
    static var firebaseProjectId: String {
        return "urgood-dc7f0"
    }
    
    /// Firebase Functions region
    static var firebaseFunctionsRegion: String {
        return "us-central1"
    }
    
    /// Firebase Functions base URL
    static var firebaseFunctionsURL: String {
        if let customURL = ProcessInfo.processInfo.environment["FIREBASE_FUNCTIONS_URL"] {
            return customURL
        }
        
        return isProduction
            ? "https://\(firebaseFunctionsRegion)-\(firebaseProjectId).cloudfunctions.net"
            : "http://localhost:5001/\(firebaseProjectId)/\(firebaseFunctionsRegion)"
    }
    
    // MARK: - API Endpoints
    
    struct Endpoints {
        // Authentication
        static var auth: String { "\(backendURL)/api/auth" }
        static var authVerify: String { "\(auth)/verify" }
        static var authApple: String { "\(auth)/apple" }
        static var authRefresh: String { "\(auth)/refresh" }
        static var authLogout: String { "\(auth)/logout" }
        
        // Voice Chat
        static var voice: String { "\(backendURL)/api/v1/voice" }
        static var voiceAuthorize: String { "\(voice)/authorize" }
        static var voiceSessionStart: String { "\(voice)/session/start" }
        static var voiceSessionEnd: String { "\(voice)/session/end" }
        static var voiceStatus: String { "\(voice)/status" }
        
        // Chat
        static var chat: String { "\(backendURL)/api/chat" }
        static var chatCompletions: String { "\(chat)/completions" }
        static var chatHistory: String { "\(chat)/history" }
        static var chatSummary: String { "\(chat)/summary" }
        
        // User Management
        static var users: String { "\(backendURL)/api/users" }
        static var userProfile: String { "\(users)/profile" }
        static var userPreferences: String { "\(users)/preferences" }
        static var userSubscription: String { "\(users)/subscription" }
        
        // Mood Tracking
        static var mood: String { "\(backendURL)/api/mood" }
        static var moodEntries: String { "\(mood)/entries" }
        static var moodTrends: String { "\(mood)/trends" }
        static var moodInsights: String { "\(mood)/insights" }
        
        // Crisis Detection
        static var crisis: String { "\(backendURL)/api/crisis" }
        static var crisisDetect: String { "\(crisis)/detect" }
        static var crisisReport: String { "\(crisis)/report" }
        static var crisisResources: String { "\(crisis)/resources" }
        
        // Analytics
        static var analytics: String { "\(backendURL)/api/analytics" }
        static var analyticsEvents: String { "\(analytics)/events" }
        static var analyticsDashboard: String { "\(analytics)/dashboard" }
        
        // Billing
        static var billing: String { "\(backendURL)/api/billing" }
        static var billingSubscribe: String { "\(billing)/subscribe" }
        static var billingCancel: String { "\(billing)/cancel" }
        static var billingWebhook: String { "\(billing)/webhook" }
        
        // Health Check
        static var health: String { "\(backendURL)/health" }
        static var healthReady: String { "\(backendURL)/ready" }
        static var healthLive: String { "\(backendURL)/live" }
    }
    
    // MARK: - Firebase Functions Endpoints
    
    struct FirebaseFunctions {
        static var authorizeVoiceChat: String { "\(firebaseFunctionsURL)/authorizeVoiceChat" }
        static var synthesizeSpeech: String { "\(firebaseFunctionsURL)/synthesizeSpeech" }
        static var processAudioTranscription: String { "\(firebaseFunctionsURL)/processAudioTranscription" }
        static var detectCrisis: String { "\(firebaseFunctionsURL)/detectCrisis" }
        static var sendNotification: String { "\(firebaseFunctionsURL)/sendNotification" }
        static var processPayment: String { "\(firebaseFunctionsURL)/processPayment" }
        static var generateInsights: String { "\(firebaseFunctionsURL)/generateInsights" }
    }
    
    // MARK: - External Services
    
    struct ExternalServices {
        // OpenAI
        static var openAIBaseURL: String {
            return ProcessInfo.processInfo.environment["OPENAI_BASE_URL"] ?? "https://api.openai.com/v1"
        }
        
        // ElevenLabs
        static var elevenLabsBaseURL: String {
            return ProcessInfo.processInfo.environment["ELEVENLABS_BASE_URL"] ?? "https://api.elevenlabs.io/v1"
        }
        
        // Stripe
        static var stripeBaseURL: String {
            return isProduction 
                ? "https://api.stripe.com/v1"
                : "https://api.stripe.com/v1" // Stripe doesn't have a sandbox URL
        }
    }
    
    // MARK: - App Configuration
    
    struct App {
        static var bundleId: String {
            return Bundle.main.bundleIdentifier ?? "com.urgood.urgood"
        }
        
        static var version: String {
            return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        }
        
        static var buildNumber: String {
            return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        }
        
        static var displayName: String {
            return Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "UrGood"
        }
        
        // Deep linking
        static var urlScheme: String {
            return "urgood"
        }
        
        static var universalLinkDomain: String {
            return isProduction ? "urgood.app" : "dev.urgood.app"
        }
    }
    
    // MARK: - Network Configuration
    
    struct Network {
        static var requestTimeout: TimeInterval {
            return isDevelopment ? 60.0 : 30.0 // Longer timeout in development
        }
        
        static var retryAttempts: Int {
            return 3
        }
        
        static var retryDelay: TimeInterval {
            return 1.0
        }
        
        static var maxConcurrentRequests: Int {
            return isProduction ? 10 : 5
        }
        
        // Rate limiting
        static var rateLimitWindow: TimeInterval {
            return 60.0 // 1 minute
        }
        
        static var freeUserRequestsPerMinute: Int {
            return 10
        }
        
        static var premiumUserRequestsPerMinute: Int {
            return 60
        }
    }
    
    // MARK: - Feature Flags
    
    struct Features {
        static var voiceChatEnabled: Bool {
            return ProcessInfo.processInfo.environment["FEATURE_VOICE_CHAT"] != "false"
        }
        
        static var crisisDetectionEnabled: Bool {
            return ProcessInfo.processInfo.environment["FEATURE_CRISIS_DETECTION"] != "false"
        }
        
        static var analyticsEnabled: Bool {
            return ProcessInfo.processInfo.environment["FEATURE_ANALYTICS"] != "false"
        }
        
        static var debugModeEnabled: Bool {
            return isDevelopment || ProcessInfo.processInfo.environment["DEBUG_MODE"] == "true"
        }
        
        static var betaFeaturesEnabled: Bool {
            return ProcessInfo.processInfo.environment["BETA_FEATURES"] == "true"
        }
        
        static var offlineModeEnabled: Bool {
            return ProcessInfo.processInfo.environment["OFFLINE_MODE"] == "true"
        }
    }
    
    // MARK: - Security Configuration
    
    struct Security {
        static var certificatePinningEnabled: Bool {
            return isProduction
        }
        
        static var allowSelfSignedCertificates: Bool {
            return isDevelopment
        }
        
        static var requireHTTPS: Bool {
            return isProduction
        }
        
        static var sessionTimeout: TimeInterval {
            return 24 * 60 * 60 // 24 hours
        }
        
        static var refreshTokenLifetime: TimeInterval {
            return 30 * 24 * 60 * 60 // 30 days
        }
    }
    
    // MARK: - Logging Configuration
    
    struct Logging {
        static var logLevel: LogLevel {
            if let level = ProcessInfo.processInfo.environment["LOG_LEVEL"] {
                return LogLevel(rawValue: level) ?? (isDevelopment ? .debug : .info)
            }
            return isDevelopment ? .debug : .info
        }
        
        static var enableRemoteLogging: Bool {
            return isProduction
        }
        
        static var enableCrashlytics: Bool {
            return true
        }
        
        static var enableAnalytics: Bool {
            return Features.analyticsEnabled
        }
    }
    
    // MARK: - Performance Configuration
    
    struct Performance {
        static var cacheSize: Int {
            return isProduction ? 100 : 50
        }
        
        static var cacheDuration: TimeInterval {
            return 300.0 // 5 minutes
        }
        
        static var imageCompressionQuality: CGFloat {
            return isProduction ? 0.8 : 0.9
        }
        
        static var maxConcurrentDownloads: Int {
            return 5
        }
    }
    
    // MARK: - Development Tools
    
    struct Development {
        static var enableNetworkLogging: Bool {
            return isDevelopment || ProcessInfo.processInfo.environment["NETWORK_LOGGING"] == "true"
        }
        
        static var enableUITesting: Bool {
            return ProcessInfo.processInfo.environment["UI_TESTING"] == "true"
        }
        
        static var mockAPIResponses: Bool {
            return ProcessInfo.processInfo.environment["MOCK_API"] == "true"
        }
        
        static var skipOnboarding: Bool {
            return ProcessInfo.processInfo.environment["SKIP_ONBOARDING"] == "true"
        }
    }
    
    // MARK: - Validation
    
    static func validateConfiguration() -> [String] {
        var issues: [String] = []
        
        // Validate backend URL
        if !isValidURL(backendURL) {
            issues.append("Invalid backend URL: \(backendURL)")
        }
        
        // Validate Firebase configuration
        if firebaseProjectId.isEmpty {
            issues.append("Firebase project ID is empty")
        }
        
        // Production-specific validations
        if isProduction {
            if backendURL.contains("localhost") {
                issues.append("Production build should not use localhost URLs")
            }
            
            if !backendURL.hasPrefix("https://") {
                issues.append("Production backend URL must use HTTPS")
            }
        }
        
        return issues
    }
    
    private static func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme != nil && url.host != nil
    }
    
    // MARK: - Debug Information
    
    static func printConfiguration() {
        guard Features.debugModeEnabled else { return }
        
        print("🔧 [EnvironmentConfig] Configuration:")
        print("   Environment: \(isProduction ? "Production" : "Development")")
        print("   Backend URL: \(backendURL)")
        print("   Firebase Functions: \(firebaseFunctionsURL)")
        print("   Bundle ID: \(App.bundleId)")
        print("   Version: \(App.version) (\(App.buildNumber))")
        print("   Features:")
        print("     - Voice Chat: \(Features.voiceChatEnabled)")
        print("     - Crisis Detection: \(Features.crisisDetectionEnabled)")
        print("     - Analytics: \(Features.analyticsEnabled)")
        print("     - Debug Mode: \(Features.debugModeEnabled)")
        
        let issues = validateConfiguration()
        if !issues.isEmpty {
            print("⚠️ [EnvironmentConfig] Configuration Issues:")
            for issue in issues {
                print("   - \(issue)")
            }
        }
    }
}

// MARK: - Supporting Types

enum LogLevel: String, CaseIterable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"
}

// MARK: - Environment Variables Helper

extension ProcessInfo {
    func environmentBool(_ key: String, default defaultValue: Bool = false) -> Bool {
        guard let value = environment[key] else { return defaultValue }
        return ["true", "1", "yes", "on"].contains(value.lowercased())
    }
    
    func environmentInt(_ key: String, default defaultValue: Int = 0) -> Int {
        guard let value = environment[key], let intValue = Int(value) else { return defaultValue }
        return intValue
    }
    
    func environmentDouble(_ key: String, default defaultValue: Double = 0.0) -> Double {
        guard let value = environment[key], let doubleValue = Double(value) else { return defaultValue }
        return doubleValue
    }
}
