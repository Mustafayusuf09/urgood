import SwiftUI

// MARK: - Theme View Modifiers for UrGood

/// Apply UrGood app theme with mental health considerations
struct UrGoodThemed: ViewModifier {
    @EnvironmentObject private var themeService: ThemeService
    
    func body(content: Content) -> some View {
        content
            .preferredColorScheme(themeService.colorScheme)
            .background(themeService.backgroundColor)
            .foregroundColor(themeService.textColor)
            .accentColor(themeService.accentColor)
    }
}

/// Apply mental health specific theming
struct MentalHealthThemed: ViewModifier {
    let contentType: MentalHealthContentType
    let intensity: ThemeIntensity
    
    @EnvironmentObject private var themeService: ThemeService
    
    func body(content: Content) -> some View {
        content
            .background(getBackgroundColor())
            .foregroundColor(getForegroundColor())
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(getAccentColor(), lineWidth: getStrokeWidth())
                    .opacity(intensity == .subtle ? 0.3 : 0.6)
            )
    }
    
    private func getBackgroundColor() -> Color {
        switch contentType {
        case .moodEntry:
            return themeService.backgroundColor.opacity(0.8)
        case .therapyResponse:
            return themeService.mentalHealthColors.accent.opacity(0.1)
        case .crisisAlert:
            return themeService.crisisColor.opacity(0.1)
        case .encouragement:
            return themeService.successColor.opacity(0.1)
        case .reminder:
            return themeService.warningColor.opacity(0.1)
        case .progress:
            return themeService.successColor.opacity(0.05)
        }
    }
    
    private func getForegroundColor() -> Color {
        switch contentType {
        case .crisisAlert:
            return themeService.crisisColor
        case .encouragement, .progress:
            return themeService.successColor
        case .reminder:
            return themeService.warningColor
        default:
            return themeService.textColor
        }
    }
    
    private func getAccentColor() -> Color {
        switch contentType {
        case .crisisAlert:
            return themeService.crisisColor
        case .encouragement, .progress:
            return themeService.successColor
        case .reminder:
            return themeService.warningColor
        default:
            return themeService.accentColor
        }
    }
    
    private func getStrokeWidth() -> CGFloat {
        switch intensity {
        case .subtle:
            return 1.0
        case .moderate:
            return 2.0
        case .strong:
            return 3.0
        }
    }
}

/// Apply mood-specific theming based on mood level
struct MoodThemed: ViewModifier {
    let moodLevel: Int
    let showGradient: Bool
    
    @EnvironmentObject private var themeService: ThemeService
    
    func body(content: Content) -> some View {
        content
            .background(getMoodBackground())
            .foregroundColor(getMoodForeground())
    }
    
    private func getMoodBackground() -> some View {
        let moodColor = themeService.getMoodColor(for: moodLevel)
        
        if showGradient {
            return AnyView(
                LinearGradient(
                    colors: [moodColor.opacity(0.3), moodColor.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        } else {
            return AnyView(moodColor.opacity(0.2))
        }
    }
    
    private func getMoodForeground() -> Color {
        let moodColor = themeService.getMoodColor(for: moodLevel)
        
        // Ensure good contrast with background
        if themeService.isDarkMode {
            return moodColor.opacity(0.9)
        } else {
            return moodColor.opacity(0.8)
        }
    }
}

/// Apply voice chat theming based on state
struct VoiceChatThemed: ViewModifier {
    let state: VoiceChatState
    let isActive: Bool
    
    @EnvironmentObject private var themeService: ThemeService
    
    func body(content: Content) -> some View {
        content
            .background(getStateBackground())
            .foregroundColor(getStateForeground())
            .overlay(
                Circle()
                    .stroke(getStateAccent(), lineWidth: isActive ? 3 : 1)
                    .scaleEffect(isActive ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: isActive)
            )
    }
    
    private func getStateBackground() -> Color {
        switch state {
        case .idle:
            return themeService.backgroundColor
        case .listening:
            return themeService.accentColor.opacity(0.2)
        case .processing:
            return themeService.warningColor.opacity(0.2)
        case .responding:
            return themeService.successColor.opacity(0.2)
        case .error:
            return themeService.crisisColor.opacity(0.2)
        }
    }
    
    private func getStateForeground() -> Color {
        switch state {
        case .idle:
            return themeService.textColor
        case .listening:
            return themeService.accentColor
        case .processing:
            return themeService.warningColor
        case .responding:
            return themeService.successColor
        case .error:
            return themeService.crisisColor
        }
    }
    
    private func getStateAccent() -> Color {
        return getStateForeground()
    }
}

/// Apply accessibility-enhanced theming
struct AccessibilityThemed: ViewModifier {
    let enhanceContrast: Bool
    let increaseTouchTargets: Bool
    
    @EnvironmentObject private var themeService: ThemeService
    @EnvironmentObject private var accessibilityService: AccessibilityService
    
    func body(content: Content) -> some View {
        content
            .background(getAccessibilityBackground())
            .foregroundColor(getAccessibilityForeground())
            .scaleEffect(getScaleFactor())
            .padding(getAccessibilityPadding())
    }
    
    private func getAccessibilityBackground() -> Color {
        if enhanceContrast || themeService.accessibilityEnhanced {
            return themeService.accessibilityColors.background
        }
        return themeService.backgroundColor
    }
    
    private func getAccessibilityForeground() -> Color {
        if enhanceContrast || themeService.accessibilityEnhanced {
            return themeService.accessibilityColors.text
        }
        return themeService.textColor
    }
    
    private func getScaleFactor() -> CGFloat {
        if increaseTouchTargets && accessibilityService.isAccessibilityTextSize {
            return 1.2
        }
        return 1.0
    }
    
    private func getAccessibilityPadding() -> EdgeInsets {
        if increaseTouchTargets && accessibilityService.isAccessibilityTextSize {
            return EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        }
        return EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
    }
}

/// Apply crisis-specific theming with urgency indicators
struct CrisisThemed: ViewModifier {
    let severity: CrisisSeverity
    let isPulsing: Bool
    
    @EnvironmentObject private var themeService: ThemeService
    @State private var pulseScale: CGFloat = 1.0
    
    func body(content: Content) -> some View {
        content
            .background(getCrisisBackground())
            .foregroundColor(getCrisisForeground())
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(getCrisisAccent(), lineWidth: 3)
                    .scaleEffect(pulseScale)
                    .animation(
                        isPulsing ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : .none,
                        value: pulseScale
                    )
            )
            .onAppear {
                if isPulsing {
                    pulseScale = 1.1
                }
            }
    }
    
    private func getCrisisBackground() -> Color {
        switch severity {
        case .low:
            return themeService.warningColor.opacity(0.1)
        case .medium:
            return themeService.warningColor.opacity(0.2)
        case .high:
            return themeService.crisisColor.opacity(0.2)
        case .critical:
            return themeService.crisisColor.opacity(0.3)
        }
    }
    
    private func getCrisisForeground() -> Color {
        switch severity {
        case .low, .medium:
            return themeService.warningColor
        case .high, .critical:
            return themeService.crisisColor
        }
    }
    
    private func getCrisisAccent() -> Color {
        return getCrisisForeground()
    }
}

/// Apply progress-specific theming with celebration elements
struct ProgressThemed: ViewModifier {
    let progressType: ProgressType
    let celebrationLevel: CelebrationLevel
    
    @EnvironmentObject private var themeService: ThemeService
    @State private var celebrationScale: CGFloat = 1.0
    
    func body(content: Content) -> some View {
        content
            .background(getProgressBackground())
            .foregroundColor(getProgressForeground())
            .scaleEffect(celebrationScale)
            .onAppear {
                if celebrationLevel != .none {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                        celebrationScale = 1.05
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            celebrationScale = 1.0
                        }
                    }
                }
            }
    }
    
    private func getProgressBackground() -> Color {
        switch progressType {
        case .moodImprovement:
            return themeService.successColor.opacity(0.15)
        case .streakAchievement:
            return themeService.accentColor.opacity(0.15)
        case .goalCompletion:
            return themeService.successColor.opacity(0.2)
        case .milestone:
            return themeService.accentColor.opacity(0.2)
        }
    }
    
    private func getProgressForeground() -> Color {
        switch progressType {
        case .moodImprovement, .goalCompletion:
            return themeService.successColor
        case .streakAchievement, .milestone:
            return themeService.accentColor
        }
    }
}

// MARK: - Supporting Types

enum ThemeIntensity {
    case subtle
    case moderate
    case strong
}

enum ProgressType {
    case moodImprovement
    case streakAchievement
    case goalCompletion
    case milestone
}

enum CelebrationLevel {
    case none
    case subtle
    case moderate
    case enthusiastic
}

// MARK: - View Extensions

extension View {
    /// Apply UrGood app theme
    func urGoodThemed() -> some View {
        modifier(UrGoodThemed())
    }
    
    /// Apply mental health specific theming
    func mentalHealthThemed(
        contentType: MentalHealthContentType,
        intensity: ThemeIntensity = .moderate
    ) -> some View {
        modifier(MentalHealthThemed(
            contentType: contentType,
            intensity: intensity
        ))
    }
    
    /// Apply mood-specific theming
    func moodThemed(
        moodLevel: Int,
        showGradient: Bool = false
    ) -> some View {
        modifier(MoodThemed(
            moodLevel: moodLevel,
            showGradient: showGradient
        ))
    }
    
    /// Apply voice chat theming
    func voiceChatThemed(
        state: VoiceChatState,
        isActive: Bool = false
    ) -> some View {
        modifier(VoiceChatThemed(
            state: state,
            isActive: isActive
        ))
    }
    
    /// Apply accessibility-enhanced theming
    func accessibilityThemed(
        enhanceContrast: Bool = false,
        increaseTouchTargets: Bool = false
    ) -> some View {
        modifier(AccessibilityThemed(
            enhanceContrast: enhanceContrast,
            increaseTouchTargets: increaseTouchTargets
        ))
    }
    
    /// Apply crisis-specific theming
    func crisisThemed(
        severity: CrisisSeverity,
        isPulsing: Bool = false
    ) -> some View {
        modifier(CrisisThemed(
            severity: severity,
            isPulsing: isPulsing
        ))
    }
    
    /// Apply progress-specific theming
    func progressThemed(
        progressType: ProgressType,
        celebrationLevel: CelebrationLevel = .none
    ) -> some View {
        modifier(ProgressThemed(
            progressType: progressType,
            celebrationLevel: celebrationLevel
        ))
    }
    
    /// Apply theme with system preference detection
    func systemAwareTheme() -> some View {
        self.modifier(UrGoodThemed())
    }
    
    /// Apply dark mode specific styling
    func darkModeAdaptive<Content: View>(
        light: @escaping () -> Content,
        dark: @escaping () -> Content
    ) -> some View {
        @EnvironmentObject var themeService: ThemeService
        
        return Group {
            if themeService.isDarkMode {
                dark()
            } else {
                light()
            }
        }
    }
}
