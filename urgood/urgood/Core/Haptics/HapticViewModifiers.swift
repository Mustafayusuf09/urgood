import SwiftUI

// MARK: - Haptic View Modifiers for UrGood

/// Add haptic feedback to button interactions
@MainActor
struct HapticButton: ViewModifier {
    let hapticType: HapticButtonType
    let intensity: UIImpactFeedbackGenerator.FeedbackStyle
    
    @EnvironmentObject private var hapticService: HapticFeedbackService
    
    func body(content: Content) -> some View {
        content.buttonStyle(
            HapticButtonStyle(
                hapticType: hapticType,
                intensity: intensity,
                hapticService: hapticService
            )
        )
    }
}

/// Add mental health specific haptic feedback
struct MentalHealthHaptic: ViewModifier {
    let contentType: MentalHealthContentType
    let triggerOn: HapticTrigger
    
    @EnvironmentObject private var hapticService: HapticFeedbackService
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                guard triggerOn == .appear else { return }
                playMentalHealthHaptic()
            }
            .modifier(NonConsumingTapTrigger(isEnabled: triggerOn == .tap) {
                playMentalHealthHaptic()
            })
    }
    
    private func playMentalHealthHaptic() {
        switch contentType {
        case .encouragement:
            hapticService.playEncouraging()
        case .crisisAlert:
            hapticService.playCrisisAlert()
        case .progress:
            hapticService.playNotification(.success)
        case .therapyResponse:
            hapticService.playCalming()
        default:
            hapticService.playSelection()
        }
    }
}

/// Add mood-based haptic feedback
struct MoodHaptic: ViewModifier {
    let moodLevel: Int
    let triggerOn: HapticTrigger
    
    @EnvironmentObject private var hapticService: HapticFeedbackService
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                guard triggerOn == .appear else { return }
                hapticService.playMoodFeedback(for: moodLevel)
            }
            .modifier(NonConsumingTapTrigger(isEnabled: triggerOn == .tap) {
                hapticService.playMoodFeedback(for: moodLevel)
            })
    }
}

/// Add voice chat haptic feedback
struct VoiceChatHaptic: ViewModifier {
    let state: VoiceChatHapticState
    let triggerOn: HapticTrigger
    
    @EnvironmentObject private var hapticService: HapticFeedbackService
    @State private var previousState: VoiceChatHapticState?
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                guard triggerOn == .appear else { return }
                hapticService.playVoiceChatFeedback(for: state)
            }
            .modifier(NonConsumingTapTrigger(isEnabled: triggerOn == .tap) {
                hapticService.playVoiceChatFeedback(for: state)
            })
            .onChange(of: state) { newState in
                if triggerOn == .stateChange && previousState != newState {
                    hapticService.playVoiceChatFeedback(for: newState)
                    previousState = newState
                }
            }
    }
}

/// Add therapeutic haptic patterns
struct TherapeuticHaptic: ViewModifier {
    let pattern: TherapeuticPattern
    let triggerOn: HapticTrigger
    
   @EnvironmentObject private var hapticService: HapticFeedbackService
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                guard triggerOn == .appear else { return }
                playTherapeuticPattern()
            }
            .modifier(NonConsumingTapTrigger(isEnabled: triggerOn == .tap) {
                playTherapeuticPattern()
            })
    }
    
    private func playTherapeuticPattern() {
        switch pattern {
        case .calming:
            hapticService.playCalming()
        case .encouraging:
            hapticService.playEncouraging()
        case .grounding:
            playGroundingPattern()
        case .breathing:
            playBreathingPattern()
        }
    }
    
    private func playGroundingPattern() {
        // 5-4-3-2-1 grounding technique haptic pattern
        DispatchQueue.main.async {
            hapticService.playImpact(.light)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                hapticService.playImpact(.light)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    hapticService.playImpact(.light)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        hapticService.playImpact(.light)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            hapticService.playImpact(.medium)
                        }
                    }
                }
            }
        }
    }
    
    private func playBreathingPattern() {
        // 4-7-8 breathing technique haptic pattern
        DispatchQueue.main.async {
            // Inhale (4 seconds)
            hapticService.playImpact(.light)
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                // Hold (7 seconds) - gentle pulse
                hapticService.playSelection()
                DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) {
                    // Exhale (8 seconds)
                    hapticService.playImpact(.medium)
                }
            }
        }
    }
}

/// Add accessibility-aware haptic feedback
struct AccessibilityHaptic: ViewModifier {
    let hapticType: AccessibilityHapticType
    let triggerOn: HapticTrigger
    
    @EnvironmentObject private var hapticService: HapticFeedbackService
    @EnvironmentObject private var accessibilityService: AccessibilityService
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                guard triggerOn == .appear else { return }
                playAccessibilityHaptic()
            }
            .modifier(NonConsumingTapTrigger(isEnabled: triggerOn == .tap) {
                playAccessibilityHaptic()
            })
    }
    
    private func playAccessibilityHaptic() {
        // Enhanced haptics for accessibility users
        let enhancedIntensity: UIImpactFeedbackGenerator.FeedbackStyle = 
            accessibilityService.isAccessibilityEnabled ? .heavy : .medium
        
        switch hapticType {
        case .focus:
            hapticService.playImpact(enhancedIntensity)
        case .navigation:
            hapticService.playSelection()
        case .confirmation:
            hapticService.playNotification(.success)
        case .alert:
            hapticService.playNotification(.warning)
        case .error:
            hapticService.playNotification(.error)
        }
    }
}

// MARK: - Supporting Types

enum HapticButtonType {
    case impact
    case selection
    case success
    case warning
    case error
}

enum HapticTrigger {
    case tap
    case appear
    case stateChange
}

enum TherapeuticPattern {
    case calming
    case encouraging
    case grounding
    case breathing
}

enum AccessibilityHapticType {
    case focus
    case navigation
    case confirmation
    case alert
    case error
}

// MARK: - View Extensions

extension View {
    /// Add haptic feedback to button interactions
    func hapticButton(
        type: HapticButtonType = .impact,
        intensity: UIImpactFeedbackGenerator.FeedbackStyle = .medium
    ) -> some View {
        modifier(HapticButton(hapticType: type, intensity: intensity))
    }
    
    /// Add mental health specific haptic feedback
    func mentalHealthHaptic(
        contentType: MentalHealthContentType,
        triggerOn: HapticTrigger = .tap
    ) -> some View {
        modifier(MentalHealthHaptic(contentType: contentType, triggerOn: triggerOn))
    }
    
    /// Add mood-based haptic feedback
    func moodHaptic(
        moodLevel: Int,
        triggerOn: HapticTrigger = .tap
    ) -> some View {
        modifier(MoodHaptic(moodLevel: moodLevel, triggerOn: triggerOn))
    }
    
    /// Add voice chat haptic feedback
    func voiceChatHaptic(
        state: VoiceChatHapticState,
        triggerOn: HapticTrigger = .stateChange
    ) -> some View {
        modifier(VoiceChatHaptic(state: state, triggerOn: triggerOn))
    }
    
    /// Add therapeutic haptic patterns
    func therapeuticHaptic(
        pattern: TherapeuticPattern,
        triggerOn: HapticTrigger = .tap
    ) -> some View {
        modifier(TherapeuticHaptic(pattern: pattern, triggerOn: triggerOn))
    }
    
    /// Add accessibility-aware haptic feedback
    func accessibilityHaptic(
        type: AccessibilityHapticType,
        triggerOn: HapticTrigger = .tap
    ) -> some View {
        modifier(AccessibilityHaptic(hapticType: type, triggerOn: triggerOn))
    }
    
    /// Add simple tap haptic feedback
    func tapHaptic(
        intensity: UIImpactFeedbackGenerator.FeedbackStyle = .medium
    ) -> some View {
        hapticButton(type: .impact, intensity: intensity)
    }
    
    /// Add success haptic feedback
    func successHaptic(triggerOn: HapticTrigger = .tap) -> some View {
        hapticButton(type: .success)
    }
    
    /// Add error haptic feedback
    func errorHaptic(triggerOn: HapticTrigger = .tap) -> some View {
        hapticButton(type: .error)
    }
}

// MARK: - Supporting Modifiers & Styles

@MainActor
private struct NonConsumingTapTrigger: ViewModifier {
    let isEnabled: Bool
    let onTap: () -> Void
    
    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content.simultaneousGesture(
                TapGesture().onEnded {
                    onTap()
                },
                including: .subviews
            )
        } else {
            content
        }
    }
}

@MainActor
private struct HapticButtonStyle: ButtonStyle {
    let hapticType: HapticButtonType
    let intensity: UIImpactFeedbackGenerator.FeedbackStyle
    let hapticService: HapticFeedbackService
    
    func makeBody(configuration: Configuration) -> some View {
        HapticButtonStyleBody(
            configuration: configuration,
            hapticType: hapticType,
            intensity: intensity,
            hapticService: hapticService
        )
    }
}

@MainActor
private struct HapticButtonStyleBody: View {
    let configuration: ButtonStyle.Configuration
    let hapticType: HapticButtonType
    let intensity: UIImpactFeedbackGenerator.FeedbackStyle
    let hapticService: HapticFeedbackService
    
    @State private var didPress = false
    
    var body: some View {
        configuration.label
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed {
                    didPress = true
                } else if didPress {
                    didPress = false
                    triggerHaptic()
                }
            }
    }
    
    private func triggerHaptic() {
        switch hapticType {
        case .impact:
            hapticService.playImpact(intensity)
        case .selection:
            hapticService.playSelection()
        case .success:
            hapticService.playNotification(.success)
        case .warning:
            hapticService.playNotification(.warning)
        case .error:
            hapticService.playNotification(.error)
        }
    }
}
