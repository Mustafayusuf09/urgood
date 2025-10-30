import Foundation

struct APIConfig {
    // MARK: - Backend Configuration (PRODUCTION - Most Secure)
    
    /// Backend API URL - now uses EnvironmentConfig for dynamic configuration
    static var backendURL: String {
        return EnvironmentConfig.backendURL
    }
    
    // MARK: - OpenAI Configuration
    
    /// OpenAI API Key Strategy:
    /// - Development: Environment variable in Xcode for fast testing
    /// - Production: Backend proxy (when ready for production)
    static var openAIAPIKey: String {
        if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        return SecretsResolver.value(for: "OPENAI_API_KEY") ?? ""
    }
    
    /// OpenAI model to use for chat completions
    /// Options: gpt-4o-mini (cost-effective), gpt-4o, gpt-4-turbo
    static let openAIModel = "gpt-4o-mini"  // Optimized for conversational speed and cost
    
    /// Maximum tokens for AI responses
    static let maxTokens = 1500  // Increased for more engaging responses
    
    /// Temperature for response creativity (0.0 = focused, 1.0 = creative)
    static let temperature = 0.8  // Increased for more personality and creativity
    
    // MARK: - Voice Configuration (OpenAI for Transcription Only)
    
    /// Transcription model - OpenAI Whisper for speech-to-text
    /// NOTE: Text-to-speech uses ElevenLabs ONLY (configured below)
    static let transcriptionModel = "whisper-1"
    
    // MARK: - ElevenLabs Configuration
    
    /// ElevenLabs API Key Strategy:
    /// - Development: Load from environment variable ELEVENLABS_API_KEY
    /// - Production: Secured in Firebase Functions (no key needed in app)
    static var elevenLabsAPIKey: String? {
        #if DEBUG
        if let envKey = ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        return SecretsResolver.value(for: "ELEVENLABS_API_KEY")
        #else
        return SecretsResolver.value(for: "ELEVENLABS_API_KEY")
        #endif
    }
    
    /// ElevenLabs voice ID - uses user's selected voice
    static var elevenLabsVoiceId: String {
        return UserDefaults.standard.selectedVoice.rawValue
    }
    
    /// ElevenLabs model to use
    static let elevenLabsModel = "eleven_multilingual_v2"
    
    /// ElevenLabs voice settings
    static let elevenLabsStability = 0.35
    static let elevenLabsSimilarityBoost = 0.85
    
    /// Whether to use ElevenLabs for voice output
    /// Development: Checks for API key in environment
    /// Production: Always true (uses Firebase Functions)
    static var useElevenLabs: Bool {
        #if DEBUG
        if let key = elevenLabsAPIKey, !key.isEmpty {
            return true
        }
        return false
        #else
        return elevenLabsAPIKey != nil && !(elevenLabsAPIKey?.isEmpty ?? true)
        #endif
    }
    
    /// Firebase Function endpoints
    static let synthesizeSpeechFunction = "synthesizeSpeech"
    
    // MARK: - Rate Limiting & Cost Controls
    
    /// Maximum messages per day for free users
    static let dailyMessageLimit = 10
    
    /// Cooldown between messages (seconds)
    static let messageCooldown = 1.0
    
    /// Rate limiting configuration
    static let freeUserRequestsPerMinute = 10
    static let premiumUserRequestsPerMinute = 60
    static let rateLimitWindow: TimeInterval = 60.0 // 1 minute
    
    /// Request timeout configuration
    static let requestTimeout: TimeInterval = 30.0
    static let retryAttempts = 3
    static let baseRetryDelay: TimeInterval = 1.0
    
    /// Response caching
    static let responseCacheDuration: TimeInterval = 300.0 // 5 minutes
    static let maxCacheSize = 100 // Maximum cached responses
    
    /// Maximum tokens for summaries (cost-effective)
    static let summaryMaxTokens = 500
    
    /// Temperature for summaries (more focused)
    static let summaryTemperature = 0.3
    
    /// Model for summaries (cost-effective)
    static let summaryModel = "gpt-4o-mini"
    
    // MARK: - Error Messages
    
    static let apiKeyNotConfiguredMessage = """
    OpenAI API key not configured.
    
    To use AI features:
    1. Get an API key from https://platform.openai.com/api-keys
    2. Add OPENAI_API_KEY to your backend .env file
    3. Restart the backend server
    
    Note: OpenAI charges per usage. Monitor your usage at https://platform.openai.com/usage
    """
    
    static let networkErrorMessage = "Network error. Please check your internet connection and try again."
    
    static let rateLimitMessage = "Rate limit exceeded. Please wait a moment before trying again."
    
    // MARK: - Validation
    
    static var isConfigured: Bool {
        if !isProduction {
            // Development mode: check local environment variable
            return !openAIAPIKey.isEmpty && openAIAPIKey.hasPrefix("sk-")
        }
        
        // Production mode: backend handles authentication
        // App doesn't need direct access to OpenAI key
        return true
    }
    
    static var isProduction: Bool {
        return EnvironmentConfig.isProduction
    }
    
    // MARK: - Backend API Endpoints (now using EnvironmentConfig)
    
    /// Voice chat authorization endpoint
    static var voiceAuthEndpoint: String {
        return EnvironmentConfig.Endpoints.voiceAuthorize
    }
    
    /// Chat completion endpoint (if using backend proxy)
    static var chatEndpoint: String {
        return EnvironmentConfig.Endpoints.chatCompletions
    }
    
    /// User authentication endpoint
    static var authEndpoint: String {
        return EnvironmentConfig.Endpoints.authVerify
    }
}
