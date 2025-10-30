import SwiftUI

struct ThemeSettingsView: View {
    @EnvironmentObject private var themeService: ThemeService
    @EnvironmentObject private var accessibilityService: AccessibilityService
    @State private var showingThemePreview = false
    
    var body: some View {
        NavigationView {
            List {
                // App Theme Section
                Section {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        ThemeSelectionRow(
                            theme: theme,
                            isSelected: themeService.currentTheme == theme
                        ) {
                            themeService.setTheme(theme)
                        }
                    }
                } header: {
                    Text("App Theme")
                        .accessibilityEnhanced(
                            label: "App Theme Selection",
                            hint: "Choose between light, dark, or system preference"
                        )
                } footer: {
                    Text("System theme automatically switches between light and dark based on your device settings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Mental Health Theme Section
                Section {
                    ForEach(MentalHealthTheme.allCases, id: \.self) { theme in
                        MentalHealthThemeRow(
                            theme: theme,
                            isSelected: themeService.mentalHealthTheme == theme
                        ) {
                            themeService.setMentalHealthTheme(theme)
                        }
                    }
                } header: {
                    Text("Mental Health Theme")
                        .accessibilityEnhanced(
                            label: "Mental Health Theme Selection",
                            hint: "Choose colors that support your mental wellness"
                        )
                } footer: {
                    Text("Mental health themes use colors scientifically chosen to support different emotional states.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Accessibility Section
                Section {
                    Toggle("Enhanced Accessibility", isOn: Binding(
                        get: { themeService.accessibilityEnhanced },
                        set: { _ in themeService.toggleAccessibilityEnhanced() }
                    ))
                    .accessibilityEnhanced(
                        label: "Enhanced Accessibility Theme",
                        hint: "Enables high contrast colors and improved visibility"
                    )
                    
                    if accessibilityService.isAccessibilityEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Accessibility Features Active")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(themeService.successColor)
                            
                            if accessibilityService.accessibilitySettings.isVoiceOverEnabled {
                                Label("VoiceOver", systemImage: "speaker.wave.2")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if accessibilityService.accessibilitySettings.isDarkerSystemColorsEnabled {
                                Label("Darker System Colors", systemImage: "circle.righthalf.filled")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if accessibilityService.isAccessibilityTextSize {
                                Label("Large Text", systemImage: "textformat.size")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Accessibility")
                        .accessibilityEnhanced(
                            label: "Accessibility Settings",
                            hint: "Configure accessibility enhancements"
                        )
                } footer: {
                    Text("Enhanced accessibility automatically activates when system accessibility features are enabled.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Theme Preview Section
                Section {
                    Button("Preview Theme") {
                        showingThemePreview = true
                    }
                    .accessibilityEnhanced(
                        label: "Preview Current Theme",
                        hint: "See how your theme choices look across the app",
                        isButton: true
                    )
                } header: {
                    Text("Preview")
                }
            }
            .navigationTitle("Theme Settings")
            .navigationBarTitleDisplayMode(.large)
            .urGoodThemed()
        }
        .sheet(isPresented: $showingThemePreview) {
            ThemePreviewView()
        }
    }
}

struct ThemeSelectionRow: View {
    let theme: AppTheme
    let isSelected: Bool
    let onSelect: () -> Void
    
    @EnvironmentObject private var themeService: ThemeService
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: theme.icon)
                    .foregroundColor(themeService.accentColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.displayName)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    Text(getThemeDescription())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(themeService.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityEnhanced(
            label: "\(theme.displayName) theme",
            hint: isSelected ? "Currently selected" : "Tap to select this theme",
            isButton: true
        )
    }
    
    private func getThemeDescription() -> String {
        switch theme {
        case .light:
            return "Always use light colors"
        case .dark:
            return "Always use dark colors"
        case .system:
            return "Follow system preference"
        }
    }
}

struct MentalHealthThemeRow: View {
    let theme: MentalHealthTheme
    let isSelected: Bool
    let onSelect: () -> Void
    
    @EnvironmentObject private var themeService: ThemeService
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: theme.icon)
                    .foregroundColor(getThemeColor())
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.displayName)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    Text(theme.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Color preview
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(getPreviewColor(index))
                            .frame(width: 12, height: 12)
                    }
                }
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(themeService.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityEnhanced(
            label: "\(theme.displayName) mental health theme",
            hint: isSelected ? "Currently selected" : "Tap to select this theme",
            isButton: true
        )
    }
    
    private func getThemeColor() -> Color {
        // Temporarily set theme to get color
        let tempService = ThemeService.shared
        let originalTheme = tempService.mentalHealthTheme
        tempService.setMentalHealthTheme(theme)
        let color = tempService.accentColor
        tempService.setMentalHealthTheme(originalTheme)
        return color
    }
    
    private func getPreviewColor(_ index: Int) -> Color {
        let tempService = ThemeService.shared
        let originalTheme = tempService.mentalHealthTheme
        tempService.setMentalHealthTheme(theme)
        let colors = tempService.mentalHealthColors.moodGradient
        tempService.setMentalHealthTheme(originalTheme)
        
        let colorIndex = min(index * 3, colors.count - 1)
        return colors[colorIndex]
    }
}

struct ThemePreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeService: ThemeService
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Preview
                    VStack(spacing: 12) {
                        Text("UrGood")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(themeService.accentColor)
                        
                        Text("Your mental health companion")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(themeService.backgroundColor)
                    
                    // Mood Preview
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Mood Tracking")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        HStack {
                            ForEach(1...5, id: \.self) { level in
                                Circle()
                                    .fill(themeService.getMoodColor(for: level * 2))
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Text("\(level * 2)")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                    )
                            }
                        }
                    }
                    .padding()
                    .background(themeService.backgroundColor.opacity(0.5))
                    .cornerRadius(12)
                    
                    // Mental Health Content Preview
                    VStack(spacing: 12) {
                        PreviewCard(
                            title: "Therapy Response",
                            content: "You're making great progress with your mindfulness practice.",
                            contentType: .therapyResponse
                        )
                        
                        PreviewCard(
                            title: "Encouragement",
                            content: "Remember, every small step counts towards your wellbeing.",
                            contentType: .encouragement
                        )
                        
                        PreviewCard(
                            title: "Progress Update",
                            content: "You've completed 7 days of mood tracking!",
                            contentType: .progress
                        )
                    }
                    
                    // Voice Chat Preview
                    VStack(spacing: 12) {
                        Text("Voice Chat States")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        HStack(spacing: 12) {
                            VoiceChatPreviewButton(state: .idle, label: "Ready")
                            VoiceChatPreviewButton(state: .listening, label: "Listening")
                            VoiceChatPreviewButton(state: .responding, label: "Responding")
                        }
                    }
                    .padding()
                    .background(themeService.backgroundColor.opacity(0.5))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Theme Preview")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityEnhanced(
                        label: "Done previewing theme",
                        hint: "Return to theme settings",
                        isButton: true
                    )
                }
            }
            .urGoodThemed()
        }
    }
}

struct PreviewCard: View {
    let title: String
    let content: String
    let contentType: MentalHealthContentType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text(content)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .mentalHealthThemed(contentType: contentType, intensity: .moderate)
        .cornerRadius(8)
    }
}

struct VoiceChatPreviewButton: View {
    let state: VoiceChatState
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .frame(width: 40, height: 40)
                .voiceChatThemed(state: state, isActive: state == .listening)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ThemeSettingsView()
        .environmentObject(ThemeService.shared)
        .environmentObject(AccessibilityService.shared)
}
