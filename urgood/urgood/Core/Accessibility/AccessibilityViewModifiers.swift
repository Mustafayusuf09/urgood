import SwiftUI
import UIKit

// MARK: - Accessibility View Modifiers for UrGood

/// Comprehensive accessibility modifier for mental health app components
struct AccessibilityEnhanced: ViewModifier {
    let label: String
    let hint: String?
    let traits: SwiftUI.AccessibilityTraits
    let value: String?
    let isButton: Bool
    let priority: AccessibilityPriority
    
    @EnvironmentObject private var accessibilityService: AccessibilityService
    
    init(
        label: String,
        hint: String? = nil,
        traits: SwiftUI.AccessibilityTraits = [],
        value: String? = nil,
        isButton: Bool = false,
        priority: AccessibilityPriority = .normal
    ) {
        self.label = label
        self.hint = hint
        self.traits = traits
        self.value = value
        self.isButton = isButton
        self.priority = priority
    }
    
    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(traits)
            .accessibilityAction(.default) {
                if isButton {
                    accessibilityService.hapticService.playSelection()
                }
            }
            .onAppear {
                if priority == .high {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        accessibilityService.announceToVoiceOver(
                            "New content: \(label)",
                            priority: .medium
                        )
                    }
                }
            }
    }
}

/// Mental health specific accessibility modifier
struct MentalHealthAccessible: ViewModifier {
    let contentType: MentalHealthContentType
    let content: String
    let isInteractive: Bool
    
    @EnvironmentObject private var accessibilityService: AccessibilityService
    
    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel(formatLabel())
            .accessibilityHint(getHint())
            .accessibilityAddTraits(getTraits())
            .onAppear {
                if contentType.requiresImmediate {
                    accessibilityService.announceMentalHealthContent(
                        self.content,
                        type: contentType
                    )
                }
            }
    }
    
    private func formatLabel() -> String {
        switch contentType {
        case .moodEntry:
            return "Mood entry: \(content)"
        case .therapyResponse:
            return "Therapist response: \(content)"
        case .crisisAlert:
            return "Important alert: \(content)"
        case .encouragement:
            return "Encouragement: \(content)"
        case .reminder:
            return "Reminder: \(content)"
        case .progress:
            return "Progress update: \(content)"
        }
    }
    
    private func getHint() -> String {
        if isInteractive {
            return "Double tap to interact"
        }
        
        switch contentType {
        case .crisisAlert:
            return "Important information for your safety"
        case .therapyResponse:
            return "Response from your AI therapist"
        case .moodEntry:
            return "Your mood tracking entry"
        default:
            return ""
        }
    }
    
    private func getTraits() -> SwiftUI.AccessibilityTraits {
        var traits: SwiftUI.AccessibilityTraits = []
        
        if isInteractive {
            _ = traits.insert(.isButton)
        }
        
        if contentType == .crisisAlert {
            _ = traits.insert(.playsSound)
        }
        
        return traits
    }
}

/// Dynamic Type support modifier
struct DynamicTypeSupport: ViewModifier {
    let textStyle: Font.TextStyle
    let maxSize: DynamicTypeSize?
    
    @EnvironmentObject private var accessibilityService: AccessibilityService
    
    func body(content: Content) -> some View {
        let upperBound = maxSize ?? .accessibility5
        
        return content
            .font(.system(textStyle, design: .default))
            .lineLimit(accessibilityService.isAccessibilityTextSize ? nil : 3)
            .minimumScaleFactor(0.8)
            .allowsTightening(true)
            .dynamicTypeSize(.xSmall...upperBound)
    }
}

/// High contrast support modifier
struct HighContrastSupport: ViewModifier {
    let foregroundColor: Color
    let backgroundColor: Color
    
    @EnvironmentObject private var accessibilityService: AccessibilityService
    @Environment(\.colorScheme) private var colorScheme
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(getAccessibleForegroundColor())
            .background(getAccessibleBackgroundColor())
    }
    
    private func getAccessibleForegroundColor() -> Color {
        if accessibilityService.accessibilitySettings.isDarkerSystemColorsEnabled {
            return colorScheme == .dark ? .white : .black
        }
        
        if accessibilityService.accessibilitySettings.isInvertColorsEnabled {
            return foregroundColor == .black ? .white : .black
        }
        
        return foregroundColor
    }
    
    private func getAccessibleBackgroundColor() -> Color {
        if accessibilityService.accessibilitySettings.isDarkerSystemColorsEnabled {
            return colorScheme == .dark ? .black : .white
        }
        
        if accessibilityService.accessibilitySettings.isInvertColorsEnabled {
            return backgroundColor == .white ? .black : .white
        }
        
        return backgroundColor
    }
}

/// Reduce motion support modifier
struct ReduceMotionSupport: ViewModifier {
    let animation: Animation?
    let fallbackAnimation: Animation?
    
    @EnvironmentObject private var accessibilityService: AccessibilityService
    
    func body(content: Content) -> some View {
        content
            .animation(
                accessibilityService.accessibilitySettings.isReduceMotionEnabled 
                    ? (fallbackAnimation ?? .none)
                    : animation,
                value: UUID()
            )
    }
}

/// Voice chat accessibility modifier
struct VoiceChatAccessible: ViewModifier {
    let state: VoiceChatState
    let isListening: Bool
    let transcript: String?
    
    @EnvironmentObject private var accessibilityService: AccessibilityService
    
    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel(getVoiceChatLabel())
            .accessibilityHint(getVoiceChatHint())
            .accessibilityAddTraits(getVoiceChatTraits())
            .accessibilityAction(.default) {
                accessibilityService.hapticService.playImpact(.medium)
            }
            .onChange(of: state) { newState in
                announceStateChange(newState)
            }
            .onChange(of: isListening) { listening in
                if listening {
                    accessibilityService.announceVoiceChatEvent(
                        VoiceChatEvent(
                            type: .listening,
                            timestamp: Date(),
                            context: nil
                        )
                    )
                }
            }
    }
    
    private func getVoiceChatLabel() -> String {
        switch state {
        case .idle:
            return "Voice chat ready. Tap to start conversation."
        case .listening:
            return "Listening for your voice. Speak now."
        case .processing:
            return "Processing your message. Please wait."
        case .responding:
            return "AI therapist is responding."
        case .error:
            return "Voice chat error. Tap to try again."
        }
    }
    
    private func getVoiceChatHint() -> String {
        switch state {
        case .idle:
            return "Double tap to start voice conversation with your AI therapist"
        case .listening:
            return "Speak naturally about your feelings or concerns"
        case .processing:
            return "Your message is being processed"
        case .responding:
            return "Listen to the AI therapist's response"
        case .error:
            return "Double tap to retry voice chat"
        }
    }
    
    private func getVoiceChatTraits() -> SwiftUI.AccessibilityTraits {
        var traits: SwiftUI.AccessibilityTraits = [.isButton]
        
        if isListening {
            _ = traits.insert(.startsMediaSession)
        }
        
        if state == .responding {
            _ = traits.insert(.playsSound)
        }
        
        return traits
    }
    
    private func announceStateChange(_ newState: VoiceChatState) {
        let event = VoiceChatEvent(
            type: newState.eventType,
            timestamp: Date(),
            context: transcript
        )
        
        accessibilityService.announceVoiceChatEvent(event)
    }
}

/// Mood tracking accessibility modifier
struct MoodTrackingAccessible: ViewModifier {
    let moodLevel: Int
    let isInteractive: Bool
    
    @EnvironmentObject private var accessibilityService: AccessibilityService
    
    func body(content: Content) -> some View {
        content
            .accessibilityLabel(getMoodLabel())
            .accessibilityHint(getMoodHint())
            .accessibilityValue(getMoodValue())
            .accessibilityAddTraits(getMoodTraits())
            .accessibilityAdjustableAction { direction in
                handleMoodAdjustment(direction)
            }
    }
    
    private func getMoodLabel() -> String {
        let moodDescription = getMoodDescription(moodLevel)
        return "Mood level \(moodLevel) out of 10, \(moodDescription)"
    }
    
    private func getMoodHint() -> String {
        if isInteractive {
            return "Swipe up to increase or down to decrease mood level"
        }
        return "Your current mood entry"
    }
    
    private func getMoodValue() -> String {
        return "\(moodLevel) out of 10"
    }
    
    private func getMoodTraits() -> SwiftUI.AccessibilityTraits {
        if isInteractive {
            return [.isButton]
        }
        return []
    }
    
    private func handleMoodAdjustment(_ direction: AccessibilityAdjustmentDirection) {
        let newLevel: Int
        switch direction {
        case .increment:
            newLevel = min(moodLevel + 1, 10)
        case .decrement:
            newLevel = max(moodLevel - 1, 1)
        @unknown default:
            return
        }
        
        let moodDescription = getMoodDescription(newLevel)
        accessibilityService.announceToVoiceOver(
            "Mood level \(newLevel), \(moodDescription)",
            priority: .medium
        )
        
        accessibilityService.hapticService.playSelection()
    }
    
    private func getMoodDescription(_ level: Int) -> String {
        switch level {
        case 1...2: return "very low"
        case 3...4: return "low"
        case 5...6: return "moderate"
        case 7...8: return "good"
        case 9...10: return "excellent"
        default: return "neutral"
        }
    }
}

enum AccessibilityPriority {
    case low
    case normal
    case high
    case critical
}

enum VoiceChatState {
    case idle
    case listening
    case processing
    case responding
    case error
    
    var eventType: VoiceChatEventType {
        switch self {
        case .idle:
            return .sessionEnded
        case .listening:
            return .listening
        case .processing:
            return .processing
        case .responding:
            return .responding
        case .error:
            return .error
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Apply comprehensive accessibility enhancements
    func accessibilityEnhanced(
        label: String,
        hint: String? = nil,
        traits: SwiftUI.AccessibilityTraits = [],
        value: String? = nil,
        isButton: Bool = false,
        priority: AccessibilityPriority = .normal
    ) -> some View {
        modifier(AccessibilityEnhanced(
            label: label,
            hint: hint,
            traits: traits,
            value: value,
            isButton: isButton,
            priority: priority
        ))
    }
    
    /// Apply mental health specific accessibility
    func mentalHealthAccessible(
        contentType: MentalHealthContentType,
        content: String,
        isInteractive: Bool = false
    ) -> some View {
        modifier(MentalHealthAccessible(
            contentType: contentType,
            content: content,
            isInteractive: isInteractive
        ))
    }
    
    /// Apply Dynamic Type support
    func dynamicTypeSupport(
        textStyle: Font.TextStyle = .body,
        maxSize: DynamicTypeSize? = nil
    ) -> some View {
        modifier(DynamicTypeSupport(
            textStyle: textStyle,
            maxSize: maxSize
        ))
    }
    
    /// Apply high contrast support
    func highContrastSupport(
        foregroundColor: Color = .primary,
        backgroundColor: Color = .clear
    ) -> some View {
        modifier(HighContrastSupport(
            foregroundColor: foregroundColor,
            backgroundColor: backgroundColor
        ))
    }
    
    /// Apply reduce motion support
    func reduceMotionSupport(
        animation: Animation? = .default,
        fallbackAnimation: Animation? = nil
    ) -> some View {
        modifier(ReduceMotionSupport(
            animation: animation,
            fallbackAnimation: fallbackAnimation
        ))
    }
    
    /// Apply voice chat accessibility
    func voiceChatAccessible(
        state: VoiceChatState,
        isListening: Bool = false,
        transcript: String? = nil
    ) -> some View {
        modifier(VoiceChatAccessible(
            state: state,
            isListening: isListening,
            transcript: transcript
        ))
    }
    
    /// Apply mood tracking accessibility
    func moodTrackingAccessible(
        moodLevel: Int,
        isInteractive: Bool = false
    ) -> some View {
        modifier(MoodTrackingAccessible(
            moodLevel: moodLevel,
            isInteractive: isInteractive
        ))
    }
}
