import SwiftUI
import UIKit
import Combine

/// Comprehensive theme service for UrGood mental health app
/// Provides dark mode, system preference detection, and mental health-specific theming
@MainActor
class ThemeService: ObservableObject {
    static let shared = ThemeService()
    
    // MARK: - Published Properties
    @Published var currentTheme: AppTheme = .system
    @Published var colorScheme: ColorScheme = .light
    @Published var isDarkMode: Bool = false
    @Published var isSystemTheme: Bool = true
    @Published var mentalHealthTheme: MentalHealthTheme = .energizing
    @Published var accessibilityEnhanced: Bool = false
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let crashlytics = CrashlyticsService.shared
    private let accessibilityService = AccessibilityService.shared
    private var cancellables = Set<AnyCancellable>()
    private var systemColorSchemeObserver: NSObjectProtocol?
    
    // MARK: - Theme Keys
    private enum UserDefaultsKeys {
        static let selectedTheme = "selected_theme"
        static let mentalHealthTheme = "mental_health_theme"
        static let accessibilityEnhanced = "accessibility_enhanced_theme"
    }
    
    private init() {
        setupSystemColorSchemeObserver()
        loadSavedTheme()
        setupAccessibilityObserver()
        
        // Log theme initialization
        crashlytics.log("Theme service initialized")
    }
    
    // MARK: - Theme Management
    
    /// Set the app theme with system preference detection
    func setTheme(_ theme: AppTheme) {
        let previousTheme = currentTheme
        currentTheme = theme
        isSystemTheme = theme == .system
        
        updateColorScheme()
        saveTheme()
        
        // Announce theme change to accessibility users
        if accessibilityService.isAccessibilityEnabled {
            let themeDescription = getThemeDescription(theme)
            accessibilityService.announceToVoiceOver(
                "Theme changed to \(themeDescription)",
                priority: .medium
            )
        }
        
        // Log theme change
        crashlytics.recordFeatureUsage("theme_change", success: true, metadata: [
            "previous_theme": previousTheme.rawValue,
            "new_theme": theme.rawValue,
            "is_system": isSystemTheme
        ])
    }
    
    /// Set mental health specific theme
    func setMentalHealthTheme(_ theme: MentalHealthTheme) {
        let previousTheme = mentalHealthTheme
        mentalHealthTheme = theme
        
        saveMentalHealthTheme()
        
        // Announce mental health theme change
        if accessibilityService.isAccessibilityEnabled {
            let themeDescription = getMentalHealthThemeDescription(theme)
            accessibilityService.announceToVoiceOver(
                "Mental health theme changed to \(themeDescription)",
                priority: .medium
            )
        }
        
        // Log mental health theme change
        crashlytics.recordFeatureUsage("mental_health_theme_change", success: true, metadata: [
            "previous_theme": previousTheme.rawValue,
            "new_theme": theme.rawValue
        ])
    }
    
    /// Toggle accessibility enhanced theme
    func toggleAccessibilityEnhanced() {
        accessibilityEnhanced.toggle()
        saveAccessibilityEnhanced()
        
        // Announce accessibility enhancement change
        if accessibilityService.isAccessibilityEnabled {
            let status = accessibilityEnhanced ? "enabled" : "disabled"
            accessibilityService.announceToVoiceOver(
                "Accessibility enhanced theme \(status)",
                priority: .medium
            )
        }
        
        // Log accessibility enhancement change
        crashlytics.recordFeatureUsage("accessibility_enhanced_theme_toggle", success: true, metadata: [
            "enabled": accessibilityEnhanced
        ])
    }
    
    // MARK: - Color Providers
    
    /// Get primary colors for current theme
    var primaryColors: PrimaryColors {
        switch currentTheme {
        case .light:
            return getLightPrimaryColors()
        case .dark:
            return getDarkPrimaryColors()
        case .system:
            return isDarkMode ? getDarkPrimaryColors() : getLightPrimaryColors()
        }
    }
    
    /// Get mental health specific colors
    var mentalHealthColors: MentalHealthColors {
        switch mentalHealthTheme {
        case .calming:
            return getCalmingColors()
        case .energizing:
            return getEnergizingColors()
        case .neutral:
            return getNeutralColors()
        case .therapeutic:
            return getTherapeuticColors()
        }
    }
    
    /// Get accessibility enhanced colors if needed
    var accessibilityColors: AccessibilityColors {
        if accessibilityEnhanced || accessibilityService.accessibilitySettings.isDarkerSystemColorsEnabled {
            return getAccessibilityEnhancedColors()
        }
        return getStandardAccessibilityColors()
    }
    
    // MARK: - Dynamic Colors
    
    /// Get background color with mental health theming
    var backgroundColor: Color {
        let baseColor = primaryColors.background
        let mentalHealthTint = mentalHealthColors.backgroundTint
        
        if accessibilityEnhanced {
            return accessibilityColors.background
        }
        
        return Color(
            red: baseColor.red * 0.9 + mentalHealthTint.red * 0.1,
            green: baseColor.green * 0.9 + mentalHealthTint.green * 0.1,
            blue: baseColor.blue * 0.9 + mentalHealthTint.blue * 0.1
        )
    }
    
    /// Get text color with accessibility considerations
    var textColor: Color {
        if accessibilityEnhanced {
            return accessibilityColors.text
        }
        
        let textComponents = primaryColors.text
        return Color(red: textComponents.red, green: textComponents.green, blue: textComponents.blue)
    }
    
    /// Get accent color for mental health app
    var accentColor: Color {
        return mentalHealthColors.accent
    }
    
    /// Get mood colors for mood tracking
    func getMoodColor(for level: Int) -> Color {
        let colors = mentalHealthColors.moodGradient
        let index = min(max(level - 1, 0), colors.count - 1)
        return colors[index]
    }
    
    /// Get crisis alert color
    var crisisColor: Color {
        return mentalHealthColors.crisis
    }
    
    /// Get success color for positive interactions
    var successColor: Color {
        return mentalHealthColors.success
    }
    
    /// Get warning color for important notices
    var warningColor: Color {
        return mentalHealthColors.warning
    }
    
    // MARK: - System Integration
    
    private func setupSystemColorSchemeObserver() {
        systemColorSchemeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateColorScheme()
            }
        }
    }
    
    private func setupAccessibilityObserver() {
        accessibilityService.$accessibilitySettings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] settings in
                self?.handleAccessibilityChange(settings)
            }
            .store(in: &cancellables)
    }
    
    private func updateColorScheme() {
        let systemColorScheme = UITraitCollection.current.userInterfaceStyle
        
        switch currentTheme {
        case .light:
            colorScheme = .light
            isDarkMode = false
        case .dark:
            colorScheme = .dark
            isDarkMode = true
        case .system:
            colorScheme = systemColorScheme == .dark ? .dark : .light
            isDarkMode = systemColorScheme == .dark
        }

        applyColorSchemeToWindows()
    }
    
    private func handleAccessibilityChange(_ settings: AccessibilitySettings) {
        if settings.isDarkerSystemColorsEnabled && !accessibilityEnhanced {
            accessibilityEnhanced = true
            saveAccessibilityEnhanced()
        }
    }
    
    // MARK: - Persistence
    
    private func loadSavedTheme() {
        if let savedThemeRaw = userDefaults.string(forKey: UserDefaultsKeys.selectedTheme),
           let savedTheme = AppTheme(rawValue: savedThemeRaw) {
            currentTheme = savedTheme
        }
        
        if let savedMentalHealthThemeRaw = userDefaults.string(forKey: UserDefaultsKeys.mentalHealthTheme),
           let savedMentalHealthTheme = MentalHealthTheme(rawValue: savedMentalHealthThemeRaw) {
            mentalHealthTheme = savedMentalHealthTheme
        }
        
        accessibilityEnhanced = userDefaults.bool(forKey: UserDefaultsKeys.accessibilityEnhanced)
        
        updateColorScheme()
    }
    
    private func saveTheme() {
        userDefaults.set(currentTheme.rawValue, forKey: UserDefaultsKeys.selectedTheme)
    }
    
    private func saveMentalHealthTheme() {
        userDefaults.set(mentalHealthTheme.rawValue, forKey: UserDefaultsKeys.mentalHealthTheme)
    }
    
    private func saveAccessibilityEnhanced() {
        userDefaults.set(accessibilityEnhanced, forKey: UserDefaultsKeys.accessibilityEnhanced)
    }

    private func applyColorSchemeToWindows() {
        let interfaceStyle: UIUserInterfaceStyle
        switch currentTheme {
        case .light:
            interfaceStyle = .light
        case .dark:
            interfaceStyle = .dark
        case .system:
            interfaceStyle = .unspecified
        }

        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = interfaceStyle
            }
        }
    }
    
    // MARK: - Color Definitions
    
    private func getLightPrimaryColors() -> PrimaryColors {
        return PrimaryColors(
            background: ColorComponents(red: 1.0, green: 1.0, blue: 1.0),
            text: ColorComponents(red: 0.0, green: 0.0, blue: 0.0),
            secondary: ColorComponents(red: 0.95, green: 0.95, blue: 0.97),
            tertiary: ColorComponents(red: 0.9, green: 0.9, blue: 0.92)
        )
    }
    
    private func getDarkPrimaryColors() -> PrimaryColors {
        return PrimaryColors(
            background: ColorComponents(red: 0.0, green: 0.0, blue: 0.0),
            text: ColorComponents(red: 1.0, green: 1.0, blue: 1.0),
            secondary: ColorComponents(red: 0.1, green: 0.1, blue: 0.1),
            tertiary: ColorComponents(red: 0.15, green: 0.15, blue: 0.15)
        )
    }
    
    private func getCalmingColors() -> MentalHealthColors {
        return MentalHealthColors(
            accent: Color(red: 0.4, green: 0.7, blue: 0.9),
            backgroundTint: ColorComponents(red: 0.95, green: 0.97, blue: 1.0),
            success: Color(red: 0.3, green: 0.8, blue: 0.5),
            warning: Color(red: 1.0, green: 0.8, blue: 0.4),
            crisis: Color(red: 0.9, green: 0.3, blue: 0.3),
            moodGradient: [
                Color(red: 0.8, green: 0.2, blue: 0.2), // Very low
                Color(red: 0.9, green: 0.4, blue: 0.2), // Low
                Color(red: 1.0, green: 0.6, blue: 0.2), // Below average
                Color(red: 1.0, green: 0.8, blue: 0.2), // Average
                Color(red: 0.8, green: 0.9, blue: 0.3), // Above average
                Color(red: 0.6, green: 0.9, blue: 0.4), // Good
                Color(red: 0.4, green: 0.9, blue: 0.5), // Very good
                Color(red: 0.3, green: 0.8, blue: 0.6), // Great
                Color(red: 0.2, green: 0.7, blue: 0.7), // Excellent
                Color(red: 0.2, green: 0.6, blue: 0.8)  // Outstanding
            ]
        )
    }
    
    private func getEnergizingColors() -> MentalHealthColors {
        return MentalHealthColors(
            accent: Color(red: 1.0, green: 0.73, blue: 0.59),
            backgroundTint: ColorComponents(red: 1.0, green: 0.98, blue: 0.95),
            success: Color(red: 0.2, green: 0.8, blue: 0.2),
            warning: Color(red: 1.0, green: 0.7, blue: 0.0),
            crisis: Color(red: 1.0, green: 0.2, blue: 0.2),
            moodGradient: [
                Color(red: 0.7, green: 0.1, blue: 0.1),
                Color(red: 0.8, green: 0.3, blue: 0.1),
                Color(red: 0.9, green: 0.5, blue: 0.1),
                Color(red: 1.0, green: 0.7, blue: 0.1),
                Color(red: 0.9, green: 0.8, blue: 0.2),
                Color(red: 0.7, green: 0.9, blue: 0.3),
                Color(red: 0.5, green: 0.9, blue: 0.4),
                Color(red: 0.3, green: 0.9, blue: 0.5),
                Color(red: 0.2, green: 0.8, blue: 0.6),
                Color(red: 0.1, green: 0.7, blue: 0.7)
            ]
        )
    }
    
    private func getNeutralColors() -> MentalHealthColors {
        return MentalHealthColors(
            accent: Color(red: 0.5, green: 0.5, blue: 0.5),
            backgroundTint: ColorComponents(red: 0.98, green: 0.98, blue: 0.98),
            success: Color(red: 0.4, green: 0.7, blue: 0.4),
            warning: Color(red: 0.8, green: 0.6, blue: 0.2),
            crisis: Color(red: 0.8, green: 0.2, blue: 0.2),
            moodGradient: Array(0..<10).map { i in
                let intensity = Double(i) / 9.0
                return Color(red: 0.3 + intensity * 0.4, green: 0.3 + intensity * 0.4, blue: 0.3 + intensity * 0.4)
            }
        )
    }
    
    private func getTherapeuticColors() -> MentalHealthColors {
        return MentalHealthColors(
            accent: Color(red: 0.6, green: 0.4, blue: 0.8),
            backgroundTint: ColorComponents(red: 0.98, green: 0.96, blue: 1.0),
            success: Color(red: 0.4, green: 0.6, blue: 0.8),
            warning: Color(red: 0.8, green: 0.6, blue: 0.4),
            crisis: Color(red: 0.8, green: 0.4, blue: 0.4),
            moodGradient: [
                Color(red: 0.6, green: 0.2, blue: 0.4),
                Color(red: 0.7, green: 0.3, blue: 0.4),
                Color(red: 0.8, green: 0.4, blue: 0.4),
                Color(red: 0.8, green: 0.5, blue: 0.5),
                Color(red: 0.7, green: 0.6, blue: 0.6),
                Color(red: 0.6, green: 0.7, blue: 0.7),
                Color(red: 0.5, green: 0.7, blue: 0.8),
                Color(red: 0.4, green: 0.6, blue: 0.8),
                Color(red: 0.3, green: 0.5, blue: 0.8),
                Color(red: 0.2, green: 0.4, blue: 0.8)
            ]
        )
    }
    
    private func getAccessibilityEnhancedColors() -> AccessibilityColors {
        return AccessibilityColors(
            background: isDarkMode ? Color.black : Color.white,
            text: isDarkMode ? Color.white : Color.black,
            highContrast: true
        )
    }
    
    private func getStandardAccessibilityColors() -> AccessibilityColors {
        return AccessibilityColors(
            background: backgroundColor,
            text: textColor,
            highContrast: false
        )
    }
    
    // MARK: - Helper Methods
    
    private func getThemeDescription(_ theme: AppTheme) -> String {
        switch theme {
        case .light:
            return "light mode"
        case .dark:
            return "dark mode"
        case .system:
            return "system preference"
        }
    }
    
    private func getMentalHealthThemeDescription(_ theme: MentalHealthTheme) -> String {
        switch theme {
        case .calming:
            return "calming blue theme"
        case .energizing:
            return "energizing orange theme"
        case .neutral:
            return "neutral gray theme"
        case .therapeutic:
            return "therapeutic purple theme"
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        if let observer = systemColorSchemeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

// MARK: - Supporting Types

enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        case .system:
            return "System"
        }
    }
    
    var icon: String {
        switch self {
        case .light:
            return "sun.max"
        case .dark:
            return "moon"
        case .system:
            return "gear"
        }
    }
}

enum MentalHealthTheme: String, CaseIterable {
    case calming = "calming"
    case energizing = "energizing"
    case neutral = "neutral"
    case therapeutic = "therapeutic"
    
    var displayName: String {
        switch self {
        case .calming:
            return "Calming"
        case .energizing:
            return "Energizing"
        case .neutral:
            return "Neutral"
        case .therapeutic:
            return "Therapeutic"
        }
    }
    
    var description: String {
        switch self {
        case .calming:
            return "Soothing blues for relaxation"
        case .energizing:
            return "Warm oranges for motivation"
        case .neutral:
            return "Balanced grays for focus"
        case .therapeutic:
            return "Gentle purples for healing"
        }
    }
    
    var icon: String {
        switch self {
        case .calming:
            return "water.waves"
        case .energizing:
            return "flame"
        case .neutral:
            return "circle"
        case .therapeutic:
            return "heart"
        }
    }
}

struct ColorComponents {
    let red: Double
    let green: Double
    let blue: Double
}

struct PrimaryColors {
    let background: ColorComponents
    let text: ColorComponents
    let secondary: ColorComponents
    let tertiary: ColorComponents
}

struct MentalHealthColors {
    let accent: Color
    let backgroundTint: ColorComponents
    let success: Color
    let warning: Color
    let crisis: Color
    let moodGradient: [Color]
}

struct AccessibilityColors {
    let background: Color
    let text: Color
    let highContrast: Bool
}
