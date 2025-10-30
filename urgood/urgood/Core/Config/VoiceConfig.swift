import Foundation

/// Configuration for voice chat features and quality settings
/// NOTE: All voice synthesis uses ElevenLabs only - NO OpenAI voices
struct VoiceConfig {
    
    // MARK: - ElevenLabs Voice Quality Settings
    
    /// Enhanced voice quality settings for more natural speech using ElevenLabs
    static let enhancedVoiceSettings = ElevenLabsVoiceSettings(
        model: "eleven_multilingual_v2",
        voiceId: UserDefaults.standard.selectedVoice.rawValue,
        stability: 0.35,
        similarityBoost: 0.85,
        responseFormat: "mp3_44100_128"
    )
    
    /// Alternative ElevenLabs voice options for different moods/contexts
    static let voiceOptions: [String: ElevenLabsVoiceSettings] = [
        "friendly": ElevenLabsVoiceSettings(model: "eleven_multilingual_v2", voiceId: ElevenLabsVoice.nova.rawValue, stability: 0.35, similarityBoost: 0.85, responseFormat: "mp3_44100_128"),
        "calm": ElevenLabsVoiceSettings(model: "eleven_multilingual_v2", voiceId: ElevenLabsVoice.lyra.rawValue, stability: 0.45, similarityBoost: 0.80, responseFormat: "mp3_44100_128"),
        "energetic": ElevenLabsVoiceSettings(model: "eleven_multilingual_v2", voiceId: ElevenLabsVoice.kai.rawValue, stability: 0.30, similarityBoost: 0.90, responseFormat: "mp3_44100_128"),
        "supportive": ElevenLabsVoiceSettings(model: "eleven_multilingual_v2", voiceId: ElevenLabsVoice.mira.rawValue, stability: 0.40, similarityBoost: 0.85, responseFormat: "mp3_44100_128"),
        "lateNight": ElevenLabsVoiceSettings(model: "eleven_multilingual_v2", voiceId: ElevenLabsVoice.zen.rawValue, stability: 0.50, similarityBoost: 0.78, responseFormat: "mp3_44100_128"),
        "confidence": ElevenLabsVoiceSettings(model: "eleven_multilingual_v2", voiceId: ElevenLabsVoice.atlas.rawValue, stability: 0.32, similarityBoost: 0.88, responseFormat: "mp3_44100_128")
    ]
    
    // MARK: - Conversation Settings
    
    /// Maximum response length for voice mode (shorter for better flow)
    static let maxVoiceResponseLength = 150
    
    /// Pause duration between sentences for natural speech flow
    static let naturalPauseDuration: TimeInterval = 0.3
    
    /// Audio processing settings for better quality
    static let audioProcessingSettings = AudioProcessingSettings(
        sampleRate: 24000,      // Higher quality audio
        bitRate: 128,           // Good balance of quality and size
        enableNoiseReduction: true,
        enableEcho: false,
        compressionLevel: 0.7
    )
    
    // MARK: - UI Animation Settings
    
    /// Animation durations for voice UI elements
    static let animationSettings = VoiceAnimationSettings(
        pulseSpeed: 1.2,
        breathingSpeed: 2.0,
        rotationSpeed: 8.0,
        glowIntensity: 0.8,
        responseToAudioLevel: 0.3
    )
    
    // MARK: - Conversation Flow Settings
    
    /// Settings for natural conversation flow
    static let conversationSettings = ConversationFlowSettings(
        autoListenAfterResponse: true,
        silenceTimeoutDuration: 3.0,
        maxContinuousListeningTime: 30.0,
        enableConversationalFillers: true,
        useNaturalPauses: true
    )
}

// MARK: - Supporting Structures

// DEPRECATED: Use ElevenLabsVoiceSettings instead
struct VoiceQualitySettings {
    let model: String
    let voice: String
    let speed: Double
    let responseFormat: String
}

struct ElevenLabsVoiceSettings {
    let model: String
    let voiceId: String
    let stability: Double
    let similarityBoost: Double
    let responseFormat: String
}

struct AudioProcessingSettings {
    let sampleRate: Int
    let bitRate: Int
    let enableNoiseReduction: Bool
    let enableEcho: Bool
    let compressionLevel: Double
}

struct VoiceAnimationSettings {
    let pulseSpeed: Double
    let breathingSpeed: Double
    let rotationSpeed: Double
    let glowIntensity: Double
    let responseToAudioLevel: Double
}

struct ConversationFlowSettings {
    let autoListenAfterResponse: Bool
    let silenceTimeoutDuration: TimeInterval
    let maxContinuousListeningTime: TimeInterval
    let enableConversationalFillers: Bool
    let useNaturalPauses: Bool
}

// MARK: - Voice Mode Extensions

extension APIConfig {
    /// Get current ElevenLabs voice settings based on context
    static func getElevenLabsVoiceSettings(for mood: String? = nil) -> ElevenLabsVoiceSettings {
        if let mood = mood, let settings = VoiceConfig.voiceOptions[mood] {
            return settings
        }
        return VoiceConfig.enhancedVoiceSettings
    }
    
    /// Check if ElevenLabs voice features are available
    static var supportsElevenLabsVoice: Bool {
        return useElevenLabs
    }
}
