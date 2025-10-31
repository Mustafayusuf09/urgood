import Foundation

/// ElevenLabs voice options for UrGood with enhanced metadata
enum ElevenLabsVoice: String, CaseIterable, Codable, Identifiable {
    var id: String { rawValue }
    case nova = "248nvfaZe8BXhKntjmpp"
    case lyra = "6u6JbqKdaQy89ENzLSju"
    case kai = "e79RFuEzhsq38bytJLIt"
    case mira = "RHRP17LnQ9rtwcwNw6Cm"
    case zen = "yM93hbw8Qtvdma2wCnJG"
    case atlas = "ySr9tfpEeN2Sp5JTEEW1"
    
    /// Display name for the voice
    var displayName: String {
        switch self {
        case .nova:
            return "Murph"
        case .lyra:
            return "Lyra"
        case .kai:
            return "Kai"
        case .mira:
            return "Mira"
        case .zen:
            return "Zen"
        case .atlas:
            return "Atlas"
        }
    }
    
    /// Description of the voice characteristics
    var description: String {
        switch self {
        case .nova:
            return "Bright, supportive, pronounced \"your good\""
        case .lyra:
            return "Calm, nurturing, therapeutic"
        case .kai:
            return "Upbeat, energetic, Gen Z vibe"
        case .mira:
            return "Grounded, mindful, reflective"
        case .zen:
            return "Soft-spoken, soothing, late-night"
        case .atlas:
            return "Confident, steady, encouraging"
        }
    }
    
    /// Emoji icon for the voice
    var icon: String {
        switch self {
        case .nova:
            return "🌟"
        case .lyra:
            return "🌸"
        case .kai:
            return "⚡️"
        case .mira:
            return "🌿"
        case .zen:
            return "🌙"
        case .atlas:
            return "🛡️"
        }
    }
    
    /// Whether the voice is female
    var isFemale: Bool {
        switch self {
        case .nova, .lyra, .mira, .zen:
            return true
        case .kai, .atlas:
            return false
        }
    }
    
    /// Voice category for filtering
    var category: VoiceCategory {
        switch self {
        case .nova:
            return .uplifting
        case .lyra:
            return .therapeutic
        case .kai:
            return .energetic
        case .mira:
            return .wise
        case .zen:
            return .professional
        case .atlas:
            return .confident
        }
    }
    
    /// Recommended use cases
    var useCases: [String] {
        switch self {
        case .nova:
            return ["Daily check-ins", "Goal planning", "General support"]
        case .lyra:
            return ["Anxiety relief", "Sleep preparation", "Grounding exercises"]
        case .kai:
            return ["Motivation boosts", "Social energy", "Morning routines"]
        case .mira:
            return ["Mindfulness sessions", "Deep reflection", "Life transitions"]
        case .zen:
            return ["Late-night support", "Calming reflections", "Stress release"]
        case .atlas:
            return ["Confidence building", "Decision support", "Accountability"]
        }
    }
}

/// Voice categories for organization
enum VoiceCategory: String, CaseIterable {
    case professional = "Professional"
    case therapeutic = "Therapeutic"
    case energetic = "Energetic"
    case confident = "Confident"
    case uplifting = "Uplifting"
    case wise = "Wise"
    
    var icon: String {
        switch self {
        case .professional: return "briefcase.fill"
        case .therapeutic: return "heart.fill"
        case .energetic: return "bolt.fill"
        case .confident: return "star.fill"
        case .uplifting: return "sun.max.fill"
        case .wise: return "book.fill"
        }
    }
}

/// Voice preferences model for comprehensive voice settings
struct VoicePreferences: Codable {
    let selectedVoice: ElevenLabsVoice
    let voiceSpeed: Double
    let voiceVolume: Double
    let lastUpdated: Date
    let syncedToCloud: Bool
    
    init(selectedVoice: ElevenLabsVoice = .nova, 
         voiceSpeed: Double = 1.0, 
         voiceVolume: Double = 0.8) {
        self.selectedVoice = selectedVoice
        self.voiceSpeed = voiceSpeed
        self.voiceVolume = voiceVolume
        self.lastUpdated = Date()
        self.syncedToCloud = false
    }
}

/// Enhanced user defaults extension for voice persistence
extension UserDefaults {
    private static let selectedVoiceKey = "selectedElevenLabsVoice"
    private static let voicePreferencesKey = "voicePreferences"
    private static let voiceSpeedKey = "voiceSpeed"
    private static let voiceVolumeKey = "voiceVolume"
    
    // MARK: - Legacy Voice Selection (Backward Compatible)
    var selectedVoice: ElevenLabsVoice {
        get {
            // First try to get from new preferences system
            if let preferences = voicePreferences {
                return preferences.selectedVoice
            }
            
            // Fallback to legacy system
            guard let rawValue = string(forKey: Self.selectedVoiceKey),
                  let voice = ElevenLabsVoice(rawValue: rawValue) else {
                return .nova // Default to UrGood voice
            }
            return voice
        }
        set {
            // Update both new and legacy systems for compatibility
            set(newValue.rawValue, forKey: Self.selectedVoiceKey)
            
            // Update comprehensive preferences
            var preferences = voicePreferences ?? VoicePreferences()
            preferences = VoicePreferences(
                selectedVoice: newValue,
                voiceSpeed: preferences.voiceSpeed,
                voiceVolume: preferences.voiceVolume
            )
            voicePreferences = preferences
            
            // Post notification for real-time updates
            NotificationCenter.default.post(
                name: .voiceSelectionChanged,
                object: newValue
            )
        }
    }
    
    // MARK: - Comprehensive Voice Preferences
    var voicePreferences: VoicePreferences? {
        get {
            guard let data = data(forKey: Self.voicePreferencesKey),
                  let preferences = try? JSONDecoder().decode(VoicePreferences.self, from: data) else {
                return nil
            }
            return preferences
        }
        set {
            if let preferences = newValue,
               let data = try? JSONEncoder().encode(preferences) {
                set(data, forKey: Self.voicePreferencesKey)
                
                // Also update individual keys for backward compatibility
                set(preferences.selectedVoice.rawValue, forKey: Self.selectedVoiceKey)
                set(preferences.voiceSpeed, forKey: Self.voiceSpeedKey)
                set(preferences.voiceVolume, forKey: Self.voiceVolumeKey)
            } else {
                removeObject(forKey: Self.voicePreferencesKey)
            }
        }
    }
    
    // MARK: - Individual Voice Settings
    var voiceSpeed: Double {
        get {
            let speed = double(forKey: Self.voiceSpeedKey)
            return speed > 0 ? speed : 1.0 // Default to 1.0x
        }
        set {
            set(newValue, forKey: Self.voiceSpeedKey)
            updateVoicePreferences()
        }
    }
    
    var voiceVolume: Double {
        get {
            let volume = double(forKey: Self.voiceVolumeKey)
            return volume > 0 ? volume : 0.8 // Default to 80%
        }
        set {
            set(newValue, forKey: Self.voiceVolumeKey)
            updateVoicePreferences()
        }
    }
    
    // MARK: - Helper Methods
    private func updateVoicePreferences() {
        let preferences = VoicePreferences(
            selectedVoice: selectedVoice,
            voiceSpeed: voiceSpeed,
            voiceVolume: voiceVolume
        )
        voicePreferences = preferences
    }
    
    /// Reset voice preferences to defaults
    func resetVoicePreferences() {
        removeObject(forKey: Self.selectedVoiceKey)
        removeObject(forKey: Self.voicePreferencesKey)
        removeObject(forKey: Self.voiceSpeedKey)
        removeObject(forKey: Self.voiceVolumeKey)
        
        // Set defaults
        let defaultPreferences = VoicePreferences()
        voicePreferences = defaultPreferences
    }
    
    /// Export voice preferences for backup/sync
    func exportVoicePreferences() -> Data? {
        return data(forKey: Self.voicePreferencesKey)
    }
    
    /// Import voice preferences from backup/sync
    func importVoicePreferences(from data: Data) -> Bool {
        guard let preferences = try? JSONDecoder().decode(VoicePreferences.self, from: data) else {
            return false
        }
        
        voicePreferences = preferences
        return true
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let voiceSelectionChanged = Notification.Name("voiceSelectionChanged")
    static let voicePreferencesChanged = Notification.Name("voicePreferencesChanged")
}
