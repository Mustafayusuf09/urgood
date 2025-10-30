import SwiftUI

struct VoiceFocusedSettingsView: View {
    private let container: DIContainer
    @StateObject private var viewModel: SettingsViewModel
    @ObservedObject private var hapticService: HapticFeedbackService
    @State private var voiceSpeed: Double
    @State private var voiceVolume: Double
    @State private var selectedVoice: ElevenLabsVoice
    @State private var showingVoicePicker = false
    @State private var showingPaywall = false
    @State private var showSignOutAlert = false
    @Environment(\.openURL) private var openURL
    
    init(container: DIContainer) {
        self.container = container
        _viewModel = StateObject(wrappedValue: SettingsViewModel(
            localStore: container.localStore,
            billingService: container.billingService,
            authService: container.authService,
            notificationService: container.notificationService
        ))
        _hapticService = ObservedObject(wrappedValue: container.hapticService)
        _voiceSpeed = State(initialValue: UserDefaults.standard.voiceSpeed)
        _voiceVolume = State(initialValue: UserDefaults.standard.voiceVolume)
        _selectedVoice = State(initialValue: UserDefaults.standard.selectedVoice)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                profileHeader
                voicePreferences
                appPreferences
                accountSection
                supportSection
                EmergencyDisclaimerSection()
                
                if DevelopmentConfig.isDevelopmentMode {
                    DemoResetSection {
                        viewModel.clearAllData()
                        refreshUserData()
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 80)
        }
        .background(
            Color.background
                .ignoresSafeArea()
                .allowsHitTesting(false)
        )
        .onAppear {
            refreshUserData()
        }
        .refreshable {
            refreshUserData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .voiceSelectionChanged)) { notification in
            if let voice = notification.object as? ElevenLabsVoice {
                selectedVoice = voice
            }
        }
        .onChange(of: selectedVoice) { newValue in
            UserDefaults.standard.selectedVoice = newValue
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                Task {
                    await viewModel.signOut()
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .sheet(isPresented: $showingVoicePicker) {
            VoicePickerView(selectedVoice: $selectedVoice)
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(
                isPresented: $showingPaywall,
                onUpgrade: { _ in
                    showingPaywall = false
                    refreshUserData()
                },
                onDismiss: {
                    showingPaywall = false
                },
                billingService: viewModel.billingService
            )
        }
    }
    
    private func refreshUserData() {
        viewModel.refreshData()
    }
    
    // MARK: - Sections
    
    private var profileHeader: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.brandPrimary, Color.brandSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                    
                    Text(userInitial)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 4) {
                    Text(displayName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.textPrimary)
                    
                    Text(greetingSubtitle)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .padding(.vertical, 20)
    }
    
    private var voicePreferences: some View {
        VoiceSettingsSection(title: "Voice Settings", icon: "waveform") {
            VStack(spacing: 16) {
                Button(action: { showingVoicePicker = true }) {
                    HStack(spacing: 16) {
                        Text(selectedVoice.icon)
                            .font(.system(size: 24))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("UrGood Voice (\"your good\")")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.textPrimary)
                            
                            Text("\(selectedVoice.displayName) - \(selectedVoice.description)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.textTertiary)
                    }
                }
                .buttonStyle(.plain)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Speaking Speed")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.textPrimary)
                        
                        Spacer()
                        
                        Text("\(voiceSpeed, specifier: "%.1f")x")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }
                    
                    Slider(value: $voiceSpeed, in: 0.5...2.0, step: 0.1)
                        .accentColor(.brandPrimary)
                        .onChange(of: voiceSpeed) { newValue in
                            UserDefaults.standard.voiceSpeed = newValue
                        }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Volume")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.textPrimary)
                        
                        Spacer()
                        
                        Text("\(Int(voiceVolume * 100))%")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }
                    
                    Slider(value: $voiceVolume, in: 0.0...1.0)
                        .accentColor(.brandPrimary)
                        .onChange(of: voiceVolume) { newValue in
                            UserDefaults.standard.voiceVolume = newValue
                            container.audioPlaybackService.setVolume(Float(newValue))
                        }
                }
                
                Divider()
                
                SettingsToggle(
                    title: "Haptic Feedback",
                    subtitle: "Feel subtle vibrations during voice interactions",
                    isOn: hapticsEnabledBinding
                )
                
                SettingsToggle(
                    title: "Therapeutic Patterns",
                    subtitle: "Enable calming haptics designed for grounding",
                    isOn: therapeuticHapticsBinding
                )
            }
        }
    }
    
    private var appPreferences: some View {
        VoiceSettingsSection(title: "Preferences", icon: "gear") {
            VStack(spacing: 16) {
                SettingsToggle(
                    title: "Daily Reminders",
                    subtitle: "Get gentle reminders to check in with UrGood",
                    isOn: notificationsBinding
                )
                
                Divider()
                
                VoiceSettingsRow(
                    title: "Notification Time",
                    subtitle: "Adjust reminder schedule in system settings",
                    icon: "bell.fill"
                ) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
            }
        }
    }
    
    private var accountSection: some View {
        VoiceSettingsSection(title: "Account", icon: "person.circle") {
            VStack(spacing: 16) {
                VoiceSettingsRow(
                    title: viewModel.isPremium ? "UrGood Pro" : "Upgrade to Pro",
                    subtitle: viewModel.isPremium ? "Premium access is active" : "Unlock weekly recaps & deeper insights",
                    icon: "crown.fill"
                ) {
                    if viewModel.isPremium {
                        Task {
                            await viewModel.billingService.refreshSubscriptionStatus()
                            refreshUserData()
                        }
                    } else {
                        showingPaywall = true
                    }
                }
                
                Divider()
                
                VoiceSettingsRow(
                    title: "Sign Out",
                    subtitle: "Sign out of your account",
                    icon: "rectangle.portrait.and.arrow.right.fill",
                    isDestructive: true
                ) {
                    showSignOutAlert = true
                }
            }
        }
    }
    
    private var supportSection: some View {
        VoiceSettingsSection(title: "Support", icon: "questionmark.circle") {
            VStack(spacing: 16) {
                VoiceSettingsRow(
                    title: "Help & FAQ",
                    subtitle: "Get answers to common questions",
                    icon: "book.fill"
                ) {
                    openSupportURL("https://urgood.app/support")
                }
                
                Divider()
                
                VoiceSettingsRow(
                    title: "Contact Support",
                    subtitle: "Talk with the UrGood support team",
                    icon: "envelope.fill"
                ) {
                    openSupportURL("mailto:hello@urgood.app")
                }
                
                Divider()
                
                VoiceSettingsRow(
                    title: "About UrGood",
                    subtitle: "Version \(appVersion)",
                    icon: "info.circle.fill"
                ) {
                    openSupportURL("https://urgood.app")
                }
            }
        }
    }
    
    // MARK: - Bindings & Helpers
    
    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { viewModel.notificationsEnabled },
            set: { newValue in
                if newValue != viewModel.notificationsEnabled {
                    viewModel.toggleNotifications()
                }
            }
        )
    }
    
    private var hapticsEnabledBinding: Binding<Bool> {
        Binding(
            get: { hapticService.isHapticsEnabled },
            set: { newValue in
                hapticService.setHapticsEnabled(newValue)
            }
        )
    }
    
    private var therapeuticHapticsBinding: Binding<Bool> {
        Binding(
            get: { hapticService.therapeuticHapticsEnabled },
            set: { newValue in
                hapticService.setTherapeuticHapticsEnabled(newValue)
            }
        )
    }
    
    private var displayName: String {
        if let name = viewModel.user.displayName, !name.isEmpty {
            return name
        }
        if let email = viewModel.user.email, !email.isEmpty {
            return email.components(separatedBy: "@").first?.capitalized ?? "UrGood Member"
        }
        return "UrGood Member"
    }
    
    private var userInitial: String {
        return String(displayName.prefix(1)).uppercased()
    }
    
    private var greetingSubtitle: String {
        if viewModel.user.streakCount > 0 {
            return "On a \(viewModel.user.streakCount)-day streak — stay with it"
        } else {
            return "Keep up the great work with UrGood"
        }
    }
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    private func openSupportURL(_ string: String) {
        guard let url = URL(string: string) else { return }
        openURL(url)
    }
    
}

// MARK: - Voice Settings Section
struct VoiceSettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.brandPrimary)
                
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.textPrimary)
            }
            
            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.brandPrimary.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Voice Settings Row
struct VoiceSettingsRow: View {
    let title: String
    let subtitle: String
    let icon: String
    var isDestructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isDestructive ? .error : .brandPrimary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isDestructive ? .error : .textPrimary)
                        .lineLimit(1)
                    
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if !isDestructive {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings Toggle
struct SettingsToggle: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .tint(.brandPrimary)
        }
    }
}

#Preview {
    VoiceFocusedSettingsView(container: DIContainer.shared)
}
