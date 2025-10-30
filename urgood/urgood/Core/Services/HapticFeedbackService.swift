import UIKit
import CoreHaptics

/// Comprehensive haptic feedback service for UrGood mental health app
/// Provides therapeutic haptic patterns and accessibility-aware feedback
@MainActor
class HapticFeedbackService: ObservableObject {
    static let shared = HapticFeedbackService()
    
    // MARK: - Published Properties
    @Published var isHapticsEnabled: Bool = true
    @Published var hapticIntensity: HapticIntensity = .medium
    @Published var therapeuticHapticsEnabled: Bool = true
    
    // MARK: - Private Properties
    private var hapticEngine: CHHapticEngine?
    private let crashlytics = CrashlyticsService.shared
    private let userDefaults = UserDefaults.standard
    private var accessibilityService: AccessibilityService?
    
    // MARK: - Haptic Generators
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()
    
    // MARK: - UserDefaults Keys
    private enum Keys {
        static let hapticsEnabled = "haptics_enabled"
        static let hapticIntensity = "haptic_intensity"
        static let therapeuticHapticsEnabled = "therapeutic_haptics_enabled"
    }
    
    private init() {
        setupHapticEngine()
        loadSettings()
        prepareGenerators()
        
        // Set accessibility service reference after initialization
        DispatchQueue.main.async {
            self.accessibilityService = AccessibilityService.shared
        }
        
        crashlytics.log("Haptic feedback service initialized", level: .info)
    }
    
    // MARK: - Basic Haptic Feedback
    
    /// Play impact feedback with specified intensity
    func playImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isHapticsEnabled && CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        let generator: UIImpactFeedbackGenerator
        switch style {
        case .light:
            generator = impactLight
        case .medium:
            generator = impactMedium
        case .heavy:
            generator = impactHeavy
        case .soft:
            generator = impactLight // Use light for soft
        case .rigid:
            generator = impactHeavy // Use heavy for rigid
        @unknown default:
            generator = impactMedium
        }
        
        generator.impactOccurred(intensity: CGFloat(hapticIntensity.rawValue))
        
        crashlytics.recordFeatureUsage("haptic_impact", success: true, metadata: [
            "style": style.rawValue,
            "intensity": hapticIntensity.rawValue
        ])
    }
    
    /// Play notification feedback
    func playNotification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isHapticsEnabled && CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        notificationGenerator.notificationOccurred(type)
        
        crashlytics.recordFeatureUsage("haptic_notification", success: true, metadata: [
            "type": type.rawValue
        ])
    }
    
    /// Play selection feedback
    func playSelection() {
        guard isHapticsEnabled && CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        selectionGenerator.selectionChanged()
        
        crashlytics.recordFeatureUsage("haptic_selection", success: true)
    }
    
    // MARK: - Mental Health Specific Haptics
    
    /// Play calming haptic pattern for relaxation
    func playCalming() {
        guard therapeuticHapticsEnabled else { return }
        
        playCustomPattern([
            HapticEvent(intensity: 0.3, sharpness: 0.2, duration: 0.5),
            HapticEvent(intensity: 0.0, sharpness: 0.0, duration: 0.3),
            HapticEvent(intensity: 0.4, sharpness: 0.3, duration: 0.6),
            HapticEvent(intensity: 0.0, sharpness: 0.0, duration: 0.4),
            HapticEvent(intensity: 0.2, sharpness: 0.1, duration: 0.8)
        ])
    }
    
    /// Play encouraging haptic pattern for positive reinforcement
    func playEncouraging() {
        guard therapeuticHapticsEnabled else { return }
        
        playCustomPattern([
            HapticEvent(intensity: 0.5, sharpness: 0.5, duration: 0.2),
            HapticEvent(intensity: 0.7, sharpness: 0.7, duration: 0.2),
            HapticEvent(intensity: 0.9, sharpness: 0.8, duration: 0.3)
        ])
    }
    
    /// Play mood-based haptic feedback
    func playMoodFeedback(for moodLevel: Int) {
        guard therapeuticHapticsEnabled else { return }
        
        let intensity = Float(moodLevel) / 10.0
        let sharpness = min(intensity + 0.2, 1.0)
        
        playCustomPattern([
            HapticEvent(intensity: intensity, sharpness: sharpness, duration: 0.4)
        ])
    }
    
    /// Play crisis alert haptic pattern
    func playCrisisAlert() {
        guard isHapticsEnabled else { return }
        
        // Strong, attention-grabbing pattern
        playCustomPattern([
            HapticEvent(intensity: 1.0, sharpness: 1.0, duration: 0.2),
            HapticEvent(intensity: 0.0, sharpness: 0.0, duration: 0.1),
            HapticEvent(intensity: 1.0, sharpness: 1.0, duration: 0.2),
            HapticEvent(intensity: 0.0, sharpness: 0.0, duration: 0.1),
            HapticEvent(intensity: 1.0, sharpness: 1.0, duration: 0.3)
        ])
    }
    
    /// Play voice chat haptic feedback
    func playVoiceChatFeedback(for state: VoiceChatHapticState) {
        guard therapeuticHapticsEnabled else { return }
        
        switch state {
        case .sessionStart:
            playCustomPattern([
                HapticEvent(intensity: 0.6, sharpness: 0.5, duration: 0.3),
                HapticEvent(intensity: 0.4, sharpness: 0.3, duration: 0.2)
            ])
        case .listening:
            playCustomPattern([
                HapticEvent(intensity: 0.3, sharpness: 0.2, duration: 0.1)
            ])
        case .processing:
            playCustomPattern([
                HapticEvent(intensity: 0.2, sharpness: 0.1, duration: 0.1),
                HapticEvent(intensity: 0.0, sharpness: 0.0, duration: 0.1),
                HapticEvent(intensity: 0.2, sharpness: 0.1, duration: 0.1)
            ])
        case .responseReady:
            playCustomPattern([
                HapticEvent(intensity: 0.5, sharpness: 0.4, duration: 0.2),
                HapticEvent(intensity: 0.7, sharpness: 0.6, duration: 0.2)
            ])
        case .sessionEnd:
            playCustomPattern([
                HapticEvent(intensity: 0.4, sharpness: 0.3, duration: 0.2),
                HapticEvent(intensity: 0.6, sharpness: 0.5, duration: 0.3)
            ])
        case .error:
            playNotification(.error)
        }
    }
    
    // MARK: - Custom Haptic Patterns
    
    private func playCustomPattern(_ events: [HapticEvent]) {
        guard isHapticsEnabled,
              CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = hapticEngine else { return }
        
        do {
            let hapticEvents = events.enumerated().map { index, event in
                let startTime = events.prefix(index).reduce(0) { $0 + $1.duration }
                return CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: event.intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: event.sharpness)
                    ],
                    relativeTime: startTime,
                    duration: event.duration
                )
            }
            
            let pattern = try CHHapticPattern(events: hapticEvents, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
            
        } catch {
            crashlytics.recordError(error)
        }
    }
    
    // MARK: - Settings Management
    
    func setHapticsEnabled(_ enabled: Bool) {
        isHapticsEnabled = enabled
        userDefaults.set(enabled, forKey: Keys.hapticsEnabled)
        
        if enabled {
            prepareGenerators()
        }
        
        crashlytics.recordFeatureUsage("haptics_toggle", success: true, metadata: [
            "enabled": enabled
        ])
    }
    
    func setHapticIntensity(_ intensity: HapticIntensity) {
        hapticIntensity = intensity
        userDefaults.set(intensity.rawValue, forKey: Keys.hapticIntensity)
        
        crashlytics.recordFeatureUsage("haptic_intensity_change", success: true, metadata: [
            "intensity": intensity.rawValue
        ])
    }
    
    func setTherapeuticHapticsEnabled(_ enabled: Bool) {
        therapeuticHapticsEnabled = enabled
        userDefaults.set(enabled, forKey: Keys.therapeuticHapticsEnabled)
        
        crashlytics.recordFeatureUsage("therapeutic_haptics_toggle", success: true, metadata: [
            "enabled": enabled
        ])
    }
    
    // MARK: - Private Methods
    
    private func setupHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            crashlytics.log("Device does not support haptics")
            return
        }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
            
            hapticEngine?.stoppedHandler = { [weak self] reason in
                self?.crashlytics.log("Haptic engine stopped: \(reason)")
            }
            
            hapticEngine?.resetHandler = { [weak self] in
                self?.crashlytics.log("Haptic engine reset")
                do {
                    try self?.hapticEngine?.start()
                } catch {
                    self?.crashlytics.recordError(error)
                }
            }
            
        } catch {
            crashlytics.recordError(error)
        }
    }
    
    private func loadSettings() {
        isHapticsEnabled = userDefaults.object(forKey: Keys.hapticsEnabled) as? Bool ?? true
        
        if let intensityValue = userDefaults.object(forKey: Keys.hapticIntensity) as? Float,
           let intensity = HapticIntensity(rawValue: intensityValue) {
            hapticIntensity = intensity
        }
        
        therapeuticHapticsEnabled = userDefaults.object(forKey: Keys.therapeuticHapticsEnabled) as? Bool ?? true
    }
    
    private func prepareGenerators() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        notificationGenerator.prepare()
        selectionGenerator.prepare()
    }
}

// MARK: - Supporting Types

enum HapticIntensity: Float, CaseIterable {
    case light = 0.5
    case medium = 0.75
    case strong = 1.0
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .medium: return "Medium"
        case .strong: return "Strong"
        }
    }
}

enum VoiceChatHapticState {
    case sessionStart
    case listening
    case processing
    case responseReady
    case sessionEnd
    case error
}

struct HapticEvent {
    let intensity: Float
    let sharpness: Float
    let duration: TimeInterval
}

// MARK: - UIKit Extensions

extension UIImpactFeedbackGenerator.FeedbackStyle {
    var rawValue: String {
        switch self {
        case .light: return "light"
        case .medium: return "medium"
        case .heavy: return "heavy"
        case .soft: return "soft"
        case .rigid: return "rigid"
        @unknown default: return "unknown"
        }
    }
}

extension UINotificationFeedbackGenerator.FeedbackType {
    var rawValue: String {
        switch self {
        case .success: return "success"
        case .warning: return "warning"
        case .error: return "error"
        @unknown default: return "unknown"
        }
    }
}
