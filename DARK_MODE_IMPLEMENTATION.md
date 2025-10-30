# Dark Mode Implementation Guide

## Overview

The UrGood app now includes comprehensive dark mode support with system preference detection and mental health-specific theming. This implementation provides automatic theme switching, accessibility integration, and therapeutic color schemes designed for mental wellness.

## Features Implemented

### 1. System Preference Detection
- **Automatic theme switching** based on iOS system settings
- **Real-time updates** when system theme changes
- **Manual override options** for user preference
- **Accessibility integration** with system accessibility settings

### 2. Mental Health Specific Themes
- **Calming theme** with soothing blues for relaxation
- **Energizing theme** with warm oranges for motivation
- **Neutral theme** with balanced grays for focus
- **Therapeutic theme** with gentle purples for healing

### 3. Accessibility Integration
- **High contrast mode** support with WCAG compliance
- **VoiceOver announcements** for theme changes
- **Dynamic Type integration** with theme scaling
- **Enhanced accessibility theme** for improved visibility

### 4. Mood-Based Theming
- **Mood color gradients** that adapt to dark/light mode
- **Emotional context coloring** for mood tracking
- **Crisis alert theming** with appropriate urgency colors
- **Progress celebration themes** with positive reinforcement

## Architecture

### Core Components

#### ThemeService
```swift
@MainActor
class ThemeService: ObservableObject {
    // System preference detection
    // Mental health theme management
    // Accessibility integration
    // Color scheme management
}
```

#### Theme Types
```swift
enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
}

enum MentalHealthTheme: String, CaseIterable {
    case calming = "calming"
    case energizing = "energizing"
    case neutral = "neutral"
    case therapeutic = "therapeutic"
}
```

### Integration Points

#### 1. System Theme Detection
```swift
// Automatic system theme detection
private func setupSystemColorSchemeObserver() {
    systemColorSchemeObserver = NotificationCenter.default.addObserver(
        forName: UIApplication.didBecomeActiveNotification,
        object: nil,
        queue: .main
    ) { [weak self] _ in
        self?.updateColorScheme()
    }
}
```

#### 2. Accessibility Integration
```swift
// Accessibility-aware theming
private func setupAccessibilityObserver() {
    accessibilityService.$accessibilitySettings
        .receive(on: DispatchQueue.main)
        .sink { [weak self] settings in
            self?.handleAccessibilityChange(settings)
        }
        .store(in: &cancellables)
}
```

## Usage Examples

### Basic Theme Application
```swift
// Apply app-wide theme
VStack {
    // Content
}
.urGoodThemed()
```

### Mental Health Content Theming
```swift
Text("Therapy response content")
    .mentalHealthThemed(
        contentType: .therapyResponse,
        intensity: .moderate
    )
```

### Mood-Based Theming
```swift
Circle()
    .moodThemed(
        moodLevel: 7,
        showGradient: true
    )
```

### Voice Chat Theming
```swift
Button("Start Voice Chat") {
    // Action
}
.voiceChatThemed(
    state: .listening,
    isActive: true
)
```

### Accessibility Enhanced Theming
```swift
Text("Important information")
    .accessibilityThemed(
        enhanceContrast: true,
        increaseTouchTargets: true
    )
```

### Crisis Alert Theming
```swift
VStack {
    Text("Crisis alert content")
}
.crisisThemed(
    severity: .high,
    isPulsing: true
)
```

### Progress Celebration Theming
```swift
Text("Goal completed!")
    .progressThemed(
        progressType: .goalCompletion,
        celebrationLevel: .enthusiastic
    )
```

## Theme Settings Integration

### Theme Selection View
```swift
struct ThemeSettingsView: View {
    @EnvironmentObject private var themeService: ThemeService
    
    var body: some View {
        List {
            // App theme selection
            // Mental health theme selection
            // Accessibility options
            // Theme preview
        }
    }
}
```

### Theme Preview
```swift
struct ThemePreviewView: View {
    // Live preview of current theme
    // Mood color demonstrations
    // Mental health content examples
    // Voice chat state previews
}
```

## Color Schemes

### Light Mode Colors
- **Background**: Pure white (#FFFFFF)
- **Text**: Pure black (#000000)
- **Secondary**: Light gray (#F5F5F7)
- **Tertiary**: Medium gray (#E5E5E7)

### Dark Mode Colors
- **Background**: Pure black (#000000)
- **Text**: Pure white (#FFFFFF)
- **Secondary**: Dark gray (#1A1A1A)
- **Tertiary**: Medium dark gray (#262626)

### Mental Health Theme Colors

#### Calming Theme
- **Accent**: Soft blue (#66B3E6)
- **Background Tint**: Light blue (#F2F7FF)
- **Success**: Gentle green (#4DCC80)
- **Warning**: Warm yellow (#FFCC66)
- **Crisis**: Soft red (#E6664D)

#### Energizing Theme
- **Accent**: Warm orange (#FF9933)
- **Background Tint**: Light orange (#FFF7F2)
- **Success**: Bright green (#33CC33)
- **Warning**: Golden yellow (#FFB300)
- **Crisis**: Bright red (#FF3333)

#### Neutral Theme
- **Accent**: Medium gray (#808080)
- **Background Tint**: Light gray (#FAFAFA)
- **Success**: Muted green (#66B366)
- **Warning**: Muted yellow (#CCB366)
- **Crisis**: Muted red (#CC6666)

#### Therapeutic Theme
- **Accent**: Gentle purple (#9966CC)
- **Background Tint**: Light purple (#F7F2FF)
- **Success**: Calming blue (#6699CC)
- **Warning**: Warm beige (#CC9966)
- **Crisis**: Soft coral (#CC6699)

## Accessibility Considerations

### WCAG Compliance
- **AA Level**: 4.5:1 contrast ratio for normal text
- **AAA Level**: 7:1 contrast ratio for enhanced accessibility
- **Large Text**: 3:1 contrast ratio minimum
- **Color Independence**: Information not conveyed by color alone

### Mental Health Accessibility
- **Crisis alerts** use high contrast and pulsing animations
- **Mood colors** maintain accessibility across all levels
- **Therapy content** uses calming, non-threatening colors
- **Progress indicators** use encouraging, positive colors

### System Integration
- **VoiceOver announcements** for theme changes
- **Dynamic Type scaling** with theme adaptation
- **Reduce Motion** support with alternative animations
- **High Contrast** mode automatic activation

## Performance Considerations

### Theme Switching
- **Instant updates** with @Published properties
- **Efficient color calculations** with cached values
- **Memory management** with proper observer cleanup
- **Battery optimization** with minimal system calls

### Color Management
- **Lazy loading** of color schemes
- **Efficient contrast calculations** using luminance formulas
- **Cached accessibility colors** for performance
- **Optimized gradient generation** for mood colors

## Testing Guidelines

### Manual Testing
1. **System Theme Changes**: Test automatic switching
2. **Accessibility Settings**: Verify high contrast activation
3. **Mental Health Themes**: Test all four theme variations
4. **Mood Colors**: Verify colors across all mood levels
5. **Crisis Alerts**: Test urgency color schemes

### Automated Testing
```swift
func testThemeSystemDetection() {
    // Test system theme detection
    // Verify color scheme updates
    // Check accessibility integration
}

func testMentalHealthThemes() {
    // Test all mental health themes
    // Verify color accessibility
    // Check mood color gradients
}

func testAccessibilityIntegration() {
    // Test high contrast mode
    // Verify VoiceOver announcements
    // Check Dynamic Type scaling
}
```

### Accessibility Testing
1. **VoiceOver**: Test theme change announcements
2. **High Contrast**: Verify color contrast ratios
3. **Dynamic Type**: Test theme scaling with large text
4. **Color Blind**: Test with color blind simulators

## Integration with Existing Features

### Voice Chat Integration
```swift
// In OpenAIRealtimeClient.swift
func updateVoiceChatState(_ state: VoiceChatState) {
    // Theme service automatically updates colors
    // Accessibility announcements included
    // Crisis detection uses appropriate colors
}
```

### Mood Tracking Integration
```swift
// In mood tracking views
func displayMoodEntry(_ mood: Int) {
    // Automatic mood color application
    // Accessibility-friendly color selection
    // Dark mode adaptation
}
```

### Crisis Detection Integration
```swift
// In crisis detection service
func displayCrisisAlert(_ severity: CrisisSeverity) {
    // Urgent color schemes
    // High contrast for visibility
    // Pulsing animations for attention
}
```

## Troubleshooting

### Common Issues

#### Theme Not Switching
1. Check system theme detection observer
2. Verify UserDefaults persistence
3. Ensure proper @Published property updates
4. Test with different iOS versions

#### Colors Not Updating
1. Verify color calculation methods
2. Check accessibility color overrides
3. Ensure proper contrast calculations
4. Test with different accessibility settings

#### Performance Issues
1. Check for memory leaks in observers
2. Verify efficient color caching
3. Optimize gradient calculations
4. Monitor battery usage during theme switches

## Future Enhancements

### Planned Features
- **Custom theme creation** for personalized experiences
- **Seasonal themes** that change automatically
- **Therapy session themes** that adapt to session type
- **Biometric integration** for mood-responsive theming

### Mental Health Expansions
- **Emotion-based color adaptation** using AI analysis
- **Circadian rhythm theming** for sleep health
- **Stress-responsive colors** based on user input
- **Therapeutic color sequences** for guided sessions

## Resources

### Apple Documentation
- [Supporting Dark Mode](https://developer.apple.com/documentation/uikit/appearance_customization/supporting_dark_mode_in_your_interface)
- [UITraitCollection](https://developer.apple.com/documentation/uikit/uitraitcollection)
- [Color and Contrast](https://developer.apple.com/design/human-interface-guidelines/color)

### Color Theory Resources
- [Color Psychology in Mental Health](https://www.colorpsychology.org/)
- [Therapeutic Color Applications](https://www.arttherapy.org/color-therapy/)
- [WCAG Color Guidelines](https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html)

### Testing Tools
- [Accessibility Inspector](https://developer.apple.com/documentation/accessibility/accessibility_inspector)
- [Color Contrast Analyzers](https://www.tpgi.com/color-contrast-checker/)
- [Color Blind Simulators](https://www.color-blindness.com/coblis-color-blindness-simulator/)

## Support

For theme-related issues or questions:
1. Check the troubleshooting section above
2. Review Apple's dark mode documentation
3. Test with actual users in different lighting conditions
4. Consider mental health accessibility best practices
5. Ensure therapeutic color choices support user wellbeing

---

**Note**: This implementation prioritizes mental health user needs while maintaining comprehensive iOS theming standards. The color choices are designed to support emotional wellbeing and therapeutic interactions.
