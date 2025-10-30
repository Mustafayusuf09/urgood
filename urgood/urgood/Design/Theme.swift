import SwiftUI

// MARK: - Color Extensions
extension Color {
    // Helper to create adaptive colors for light/dark mode
    init(light: Color, dark: Color) {
        self.init(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
    }
}

// MARK: - Colors
extension Color {
    // New Sky Blue + Peach + Midnight Gray color scheme
    // Primary: Sky blue (#4DA6FF) - trust + calm
    static let brandPrimary = Color(red: 0.30, green: 0.65, blue: 1.0) // Sky blue #4DA6FF
    
    // Secondary: Soft peach (#FFB997) - warmth/friendliness  
    static let brandSecondary = Color(red: 1.0, green: 0.73, blue: 0.59) // Soft peach #FFB997
    
    // Accent colors using variations of the main palette
    static let brandAccent = Color(red: 0.85, green: 0.45, blue: 0.35) // Deeper peach
    static let brandElectric = Color(red: 0.20, green: 0.80, blue: 1.0) // Brighter sky blue
    static let brandGlow = Color(red: 1.0, green: 0.85, blue: 0.70) // Light peach glow
    
    // Neutral: Deep gray (#1C1C1E) - sophisticated base
    static let neutral = Color(red: 0.11, green: 0.11, blue: 0.12) // Deep gray #1C1C1E
    
    // Adaptive backgrounds that respond to color scheme
    static let background = Color(
        light: Color(red: 0.98, green: 0.98, blue: 0.99), // Off-white
        dark: Color(red: 0.11, green: 0.11, blue: 0.12)   // Deep gray #1C1C1E
    )
    
    static let surface = Color(
        light: Color(red: 1.0, green: 1.0, blue: 1.0),    // Pure white
        dark: Color(red: 0.15, green: 0.15, blue: 0.16)   // Slightly lighter gray
    )
    
    static let surfaceSecondary = Color(
        light: Color(red: 0.96, green: 0.97, blue: 0.98), // Light gray
        dark: Color(red: 0.20, green: 0.20, blue: 0.21)   // Medium gray
    )
    
    static let surfaceGlow = Color(
        light: Color(red: 0.30, green: 0.65, blue: 1.0).opacity(0.05), // Sky blue tint
        dark: Color(red: 0.30, green: 0.65, blue: 1.0).opacity(0.1)    // Sky blue glow
    )
    
    // Adaptive text colors that respond to color scheme
    static let textPrimary = Color(
        light: Color(red: 0.11, green: 0.11, blue: 0.12), // Deep gray
        dark: Color.white                                  // White
    )
    
    static let textSecondary = Color(
        light: Color(red: 0.11, green: 0.11, blue: 0.12).opacity(0.7), // Muted gray
        dark: Color.white.opacity(0.8)                                  // Slightly muted white
    )
    
    static let textTertiary = Color(
        light: Color(red: 0.11, green: 0.11, blue: 0.12).opacity(0.5), // Light gray
        dark: Color.white.opacity(0.6)                                  // More muted white
    )
    
    // Keep the individual variants for manual use if needed
    static let backgroundLight = Color(red: 0.98, green: 0.98, blue: 0.99)
    static let backgroundDark = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let surfaceLight = Color(red: 1.0, green: 1.0, blue: 1.0)
    static let surfaceDark = Color(red: 0.15, green: 0.15, blue: 0.16)
    static let surfaceSecondaryLight = Color(red: 0.96, green: 0.97, blue: 0.98)
    static let surfaceSecondaryDark = Color(red: 0.20, green: 0.20, blue: 0.21)
    static let surfaceGlowLight = Color(red: 0.30, green: 0.65, blue: 1.0).opacity(0.05)
    static let surfaceGlowDark = Color(red: 0.30, green: 0.65, blue: 1.0).opacity(0.1)
    static let textPrimaryLight = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let textPrimaryDark = Color.white
    static let textSecondaryLight = Color(red: 0.11, green: 0.11, blue: 0.12).opacity(0.7)
    static let textSecondaryDark = Color.white.opacity(0.8)
    static let textTertiaryLight = Color(red: 0.11, green: 0.11, blue: 0.12).opacity(0.5)
    static let textTertiaryDark = Color.white.opacity(0.6)
    
    // Status colors - using the new palette
    static let success = Color(red: 0.20, green: 0.80, blue: 0.60) // Sky blue-green
    static let warning = Color(red: 1.0, green: 0.73, blue: 0.30) // Peach-orange
    static let error = Color(red: 0.95, green: 0.40, blue: 0.40) // Coral-red
    
    // Mood colors - Gen Z friendly palette
    static let moodVeryLow = Color(red: 0.95, green: 0.40, blue: 0.40) // Coral-red
    static let moodLow = Color(red: 1.0, green: 0.60, blue: 0.40) // Peach-orange
    static let moodNeutral = Color(red: 1.0, green: 0.85, blue: 0.70) // Light peach
    static let moodGood = Color(red: 0.30, green: 0.65, blue: 1.0) // Sky blue
    static let moodGreat = Color(red: 0.20, green: 0.80, blue: 1.0) // Bright sky blue

    // Achievement colors - using the new palette
    static let achievementDaily = Color(red: 0.30, green: 0.65, blue: 1.0) // Sky blue
    static let achievementWeekly = Color(red: 1.0, green: 0.73, blue: 0.59) // Soft peach
    static let achievementMonthly = Color(red: 0.85, green: 0.45, blue: 0.35) // Deeper peach
}

// MARK: - Spacing
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Typography
struct Typography {
    static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    static let title = Font.system(size: 28, weight: .bold, design: .rounded)
    static let title2 = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let title3 = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let headline = Font.system(size: 17, weight: .semibold, design: .default)
    static let body = Font.system(size: 17, weight: .regular, design: .default)
    static let callout = Font.system(size: 16, weight: .regular, design: .default)
    static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
    static let footnote = Font.system(size: 13, weight: .regular, design: .default)
    static let caption = Font.system(size: 12, weight: .regular, design: .default)
    static let captionBold = Font.system(size: 12, weight: .semibold, design: .default)
}


// MARK: - Corner Radius
struct CornerRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
}

// MARK: - Shadows
struct Shadows {
    static let small = Shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    static let medium = Shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
    static let large = Shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
    static let card = Shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Theme Environment
struct ThemeEnvironment: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.background)
            .foregroundColor(Color.textPrimary)
    }
}

// MARK: - Dynamic Color Helpers
extension Color {
    // Dynamic colors that adapt to light/dark mode (using the new adaptive colors)
    static func dynamicBackground(_ colorScheme: ColorScheme) -> Color {
        return .background
    }
    
    static func dynamicSurface(_ colorScheme: ColorScheme) -> Color {
        return .surface
    }
    
    static func dynamicSurfaceSecondary(_ colorScheme: ColorScheme) -> Color {
        return .surfaceSecondary
    }
    
    static func dynamicTextPrimary(_ colorScheme: ColorScheme) -> Color {
        return .textPrimary
    }
    
    static func dynamicTextSecondary(_ colorScheme: ColorScheme) -> Color {
        return .textSecondary
    }
    
    static func dynamicTextTertiary(_ colorScheme: ColorScheme) -> Color {
        return .textTertiary
    }
}

extension View {
    func themeEnvironment() -> some View {
        modifier(ThemeEnvironment())
    }
}
