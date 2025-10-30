# Haptic Feedback Implementation Guide

## Overview

The UrGood app now includes comprehensive haptic feedback designed specifically for mental health applications. This implementation provides therapeutic haptic patterns, accessibility-aware feedback, and mental health-specific tactile responses that enhance user experience and support emotional wellbeing.

## Features Implemented

### 1. Basic Haptic Feedback
- **Impact feedback** with light, medium, and heavy intensities
- **Notification feedback** for success, warning, and error states
- **Selection feedback** for UI interactions and navigation
- **Customizable intensity levels** based on user preference

### 2. Mental Health Specific Haptics
- **Calming patterns** for relaxation and anxiety reduction
- **Encouraging patterns** for positive reinforcement
- **Mood-based feedback** that adapts to emotional state
- **Crisis alert patterns** with urgent, attention-grabbing feedback

### 3. Therapeutic Haptic Patterns
- **Grounding technique** (5-4-3-2-1) haptic sequence
- **Breathing exercise** (4-7-8) haptic guidance
- **Meditation support** with gentle, rhythmic patterns
- **Progress celebration** with uplifting haptic sequences

### 4. Voice Chat Integration
- **Session state feedback** for voice chat interactions
- **Listening confirmation** with subtle haptic cues
- **Processing indication** with gentle pulsing patterns
- **Response ready** notification with encouraging feedback

### 5. Accessibility Integration
- **Enhanced intensity** for accessibility users
- **VoiceOver coordination** with haptic feedback timing
- **Motor accessibility** support with customizable patterns
- **Reduce Motion** compatibility with haptic alternatives

## Architecture

### Core Components

#### HapticFeedbackService
```swift
@MainActor
class HapticFeedbackService: ObservableObject {
    // Basic haptic feedback methods
    // Mental health specific patterns
    // Therapeutic haptic sequences
    // Accessibility integration
}
```

#### Haptic View Modifiers
```swift
// Mental health haptic feedback
.mentalHealthHaptic(
    contentType: .encouragement,
    triggerOn: .tap
)

// Mood-based haptic feedback
.moodHaptic(
    moodLevel: 7,
    triggerOn: .appear
)

// Therapeutic haptic patterns
.therapeuticHaptic(
    pattern: .breathing,
    triggerOn: .tap
)
```

### Integration Points

#### 1. Voice Chat Integration
```swift
// In OpenAIRealtimeClient.swift
func updateVoiceChatState(_ state: VoiceChatState) {
    HapticFeedbackService.shared.playVoiceChatFeedback(for: state.hapticState)
}
```

#### 2. Mood Tracking Integration
```swift
// In mood entry views
func recordMoodEntry(_ mood: Int) {
    HapticFeedbackService.shared.playMoodFeedback(for: mood)
}
```

#### 3. Crisis Detection Integration
```swift
// In crisis detection service
func triggerCrisisAlert() {
    HapticFeedbackService.shared.playCrisisAlert()
}
```

## Usage Examples

### Basic Haptic Feedback
```swift
Button("Submit") {
    // Action
}
.hapticButton(type: .success, intensity: .medium)
```

### Mental Health Content
```swift
Text("You're making great progress!")
    .mentalHealthHaptic(
        contentType: .encouragement,
        triggerOn: .appear
    )
```

### Mood Tracking
```swift
Slider(value: $moodLevel, in: 1...10)
    .moodHaptic(
        moodLevel: Int(moodLevel),
        triggerOn: .tap
    )
```

### Voice Chat States
```swift
VoiceChatButton()
    .voiceChatHaptic(
        state: voiceChatState,
        triggerOn: .stateChange
    )
```

### Therapeutic Patterns
```swift
Button("Start Breathing Exercise") {
    // Action
}
.therapeuticHaptic(
    pattern: .breathing,
    triggerOn: .tap
)
```

### Accessibility Support
```swift
NavigationLink("Settings") {
    SettingsView()
}
.accessibilityHaptic(
    type: .navigation,
    triggerOn: .tap
)
```

## Haptic Patterns

### Mental Health Patterns

#### Calming Pattern
- **Duration**: 2.0 seconds
- **Intensity**: Gentle (0.2-0.4)
- **Rhythm**: Slow, wave-like progression
- **Purpose**: Anxiety reduction, relaxation

#### Encouraging Pattern
- **Duration**: 0.7 seconds
- **Intensity**: Building (0.5-0.9)
- **Rhythm**: Quick, uplifting sequence
- **Purpose**: Positive reinforcement, motivation

#### Crisis Alert Pattern
- **Duration**: 0.8 seconds
- **Intensity**: Strong (1.0)
- **Rhythm**: Urgent, attention-grabbing
- **Purpose**: Emergency situations, immediate attention

### Therapeutic Patterns

#### Grounding Technique (5-4-3-2-1)
```swift
// 5 gentle taps for grounding
for i in 0..<5 {
    playImpact(.light)
    delay(0.5)
}
playImpact(.medium) // Final grounding
```

#### Breathing Exercise (4-7-8)
```swift
// Inhale (4 seconds)
playImpact(.light)
delay(4.0)

// Hold (7 seconds) - gentle pulse
playSelection()
delay(7.0)

// Exhale (8 seconds)
playImpact(.medium)
```

### Voice Chat Patterns

#### Session States
- **Session Start**: Welcoming double-tap
- **Listening**: Subtle single pulse
- **Processing**: Gentle triple-pulse
- **Response Ready**: Encouraging double-tap
- **Session End**: Completion sequence

## Settings and Customization

### User Preferences
```swift
struct HapticSettings {
    var isEnabled: Bool = true
    var intensity: HapticIntensity = .medium
    var therapeuticEnabled: Bool = true
}
```

### Intensity Levels
- **Light**: 0.5 intensity for subtle feedback
- **Medium**: 0.75 intensity for standard feedback
- **Strong**: 1.0 intensity for prominent feedback

### Accessibility Adaptations
- **Enhanced intensity** for users with motor disabilities
- **Extended duration** for users with processing delays
- **Simplified patterns** for users with cognitive disabilities

## Performance Considerations

### Battery Optimization
- **Efficient pattern caching** to reduce CPU usage
- **Smart intensity scaling** based on battery level
- **Background haptic suspension** when app is inactive
- **Haptic engine lifecycle management** for optimal performance

### Memory Management
- **Lazy pattern loading** for complex therapeutic sequences
- **Automatic cleanup** of haptic engine resources
- **Efficient event scheduling** for multi-step patterns
- **Memory-conscious pattern storage** with compression

## Testing Guidelines

### Manual Testing
1. **Basic Feedback**: Test all impact and notification types
2. **Mental Health Patterns**: Verify therapeutic effectiveness
3. **Accessibility Integration**: Test with VoiceOver enabled
4. **Battery Impact**: Monitor power consumption during extended use
5. **Device Compatibility**: Test across different iPhone models

### Automated Testing
```swift
func testHapticFeedback() {
    let service = HapticFeedbackService.shared
    
    // Test basic feedback
    service.playImpact(.medium)
    service.playNotification(.success)
    service.playSelection()
    
    // Test mental health patterns
    service.playCalming()
    service.playEncouraging()
    service.playMoodFeedback(for: 7)
    
    // Test therapeutic patterns
    service.playVoiceChatFeedback(for: .sessionStart)
}
```

### Accessibility Testing
1. **VoiceOver Integration**: Test haptic timing with announcements
2. **Motor Accessibility**: Verify enhanced patterns for motor disabilities
3. **Cognitive Accessibility**: Test simplified patterns for cognitive needs
4. **Sensory Integration**: Ensure haptics complement other feedback

## Integration with Existing Features

### Voice Chat Integration
```swift
// In OpenAIRealtimeClient.swift
private func handleStateChange(_ newState: VoiceChatState) {
    let hapticState = newState.toHapticState()
    HapticFeedbackService.shared.playVoiceChatFeedback(for: hapticState)
}
```

### Mood Tracking Integration
```swift
// In mood tracking views
func updateMoodSlider(_ value: Double) {
    let moodLevel = Int(value)
    HapticFeedbackService.shared.playMoodFeedback(for: moodLevel)
}
```

### Crisis Detection Integration
```swift
// In crisis detection service
func handleCrisisDetection(_ severity: CrisisSeverity) {
    if severity >= .high {
        HapticFeedbackService.shared.playCrisisAlert()
    }
}
```

### Accessibility Service Integration
```swift
// In AccessibilityService.swift
func announceWithHaptic(_ text: String, hapticType: AccessibilityHapticType) {
    announceToVoiceOver(text)
    HapticFeedbackService.shared.playAccessibilityHaptic(type: hapticType)
}
```

## Troubleshooting

### Common Issues

#### Haptics Not Working
1. Check device haptic capabilities
2. Verify haptic settings are enabled
3. Ensure haptic engine is properly initialized
4. Test with different intensity levels

#### Performance Issues
1. Monitor haptic engine lifecycle
2. Check for memory leaks in pattern generation
3. Verify efficient pattern caching
4. Optimize complex therapeutic sequences

#### Accessibility Issues
1. Test haptic timing with VoiceOver
2. Verify enhanced patterns for accessibility users
3. Check compatibility with assistive technologies
4. Ensure haptics don't interfere with other feedback

## Future Enhancements

### Planned Features
- **Biometric integration** for stress-responsive haptics
- **Machine learning** for personalized haptic patterns
- **Wearable integration** for extended haptic feedback
- **Social haptics** for shared therapeutic experiences

### Mental Health Expansions
- **Emotion-specific patterns** based on detected mood
- **Therapy session haptics** that adapt to session progress
- **Mindfulness haptics** for meditation and relaxation
- **Sleep haptics** for bedtime routines and sleep support

## Resources

### Apple Documentation
- [Core Haptics Framework](https://developer.apple.com/documentation/corehaptics)
- [UIFeedbackGenerator](https://developer.apple.com/documentation/uikit/uifeedbackgenerator)
- [Haptic Design Guidelines](https://developer.apple.com/design/human-interface-guidelines/playing-haptics)

### Research Resources
- [Haptic Feedback in Mental Health](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7308123/)
- [Therapeutic Applications of Haptics](https://ieeexplore.ieee.org/document/8456229)
- [Accessibility and Haptic Feedback](https://dl.acm.org/doi/10.1145/3373625.3417024)

### Testing Tools
- [Haptic Feedback Tester](https://developer.apple.com/documentation/corehaptics/testing_haptic_patterns)
- [Accessibility Inspector](https://developer.apple.com/documentation/accessibility/accessibility_inspector)
- [Battery Usage Profiler](https://developer.apple.com/documentation/xcode/improving_your_app_s_performance)

## Support

For haptic feedback related issues or questions:
1. Check the troubleshooting section above
2. Review Apple's Core Haptics documentation
3. Test with actual users for therapeutic effectiveness
4. Consider mental health accessibility best practices
5. Ensure haptic patterns support emotional wellbeing

---

**Note**: This implementation prioritizes therapeutic effectiveness and mental health user needs while maintaining optimal performance and accessibility standards. The haptic patterns are designed to support emotional regulation and enhance the therapeutic experience.
