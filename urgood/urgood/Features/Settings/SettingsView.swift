import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @State private var showingPaywall = false
    @State private var showingVoicePicker = false
    @State private var selectedVoice: ElevenLabsVoice = UserDefaults.standard.selectedVoice
    
    init(container: DIContainer) {
        self._viewModel = StateObject(wrappedValue: SettingsViewModel(
            localStore: container.localStore,
            billingService: container.billingService,
            authService: container.authService,
            notificationService: container.notificationService
        ))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // User Profile Section
                    UserProfileSection(
                        user: viewModel.user,
                        isPremium: viewModel.isPremium
                    )
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
                    
                    // Subscription Section
                    SubscriptionSection(
                        isPremium: viewModel.isPremium,
                        onUpgrade: { showingPaywall = true }
                    )
                    .padding(.horizontal, Spacing.lg)
                    
                    // Settings Section
                    SettingsSection(
                        isDarkMode: viewModel.isDarkMode,
                        notificationsEnabled: viewModel.notificationsEnabled,
                        selectedVoice: selectedVoice,
                        onToggleDarkMode: viewModel.toggleDarkMode,
                        onToggleNotifications: viewModel.toggleNotifications,
                        onOpenVoiceSettings: { showingVoicePicker = true },
                        onOpenTerms: viewModel.openTerms,
                        onOpenPrivacyPolicy: viewModel.openPrivacyPolicy,
                        onSignOut: { Task { await viewModel.signOut() } }
                    )
                    .padding(.horizontal, Spacing.lg)
                    
                    // Emergency Disclaimer
                    EmergencyDisclaimerSection()
                        .padding(.horizontal, Spacing.lg)
                    
                    // Demo Reset Section (only in development)
                    if DevelopmentConfig.isDevelopmentMode {
                        DemoResetSection(
                            onClearData: {
                                viewModel.clearAllData()
                            }
                        )
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, Spacing.xl)
                    } else {
                        Spacer(minLength: Spacing.xl)
                    }
                }
            }
            .background(Color.background)
            .refreshable {
                viewModel.refreshData()
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(
                isPresented: .constant(true),
                onUpgrade: { _ in
                    showingPaywall = false
                    // Upgrade flow handled by BillingService
                },
                onDismiss: {
                    showingPaywall = false
                },
                billingService: viewModel.billingService
            )
        }
        .sheet(isPresented: $showingVoicePicker) {
            VoicePickerView(selectedVoice: $selectedVoice)
        }
        .themeEnvironment()
    }
}

// MARK: - User Profile Section
struct UserProfileSection: View {
    let user: User
    let isPremium: Bool
    
    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Profile Header
            VStack(spacing: Spacing.md) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.brandPrimary,
                                    Color.brandAccent
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                    
                    Text("U")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                VStack(spacing: Spacing.xs) {
                    Text("User")
                        .font(Typography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.textPrimary)
                    
                    Text("Account Settings")
                        .font(Typography.body)
                        .foregroundColor(.textSecondary)
                }
            }
            
            // Premium Badge
            if isPremium {
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.warning)
                        .font(.title3)
                    
                    Text("Premium Member")
                        .font(Typography.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .fill(Color.warning.opacity(0.1))
                )
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .fill(Color.surface)
                .shadow(
                    color: Shadows.card.color,
                    radius: Shadows.card.radius,
                    x: Shadows.card.x,
                    y: Shadows.card.y
                )
        )
    }
}

// MARK: - Subscription Section
struct SubscriptionSection: View {
    let isPremium: Bool
    let onUpgrade: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Subscription")
                .font(Typography.title3)
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)
            
            if isPremium {
                Card {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.warning)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Premium Active")
                                .font(Typography.headline)
                                .foregroundColor(.textPrimary)
                            
                            Text("You have access to all features")
                                .font(Typography.footnote)
                                .foregroundColor(.textSecondary)
                        }
                        
                        Spacer()
                        
                        Badge("Active", style: .success)
                    }
                }
            } else {
                Card {
                    VStack(spacing: Spacing.md) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.brandPrimary)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text("Upgrade to Core")
                                    .font(Typography.headline)
                                    .foregroundColor(.textPrimary)

                                Text("Daily voice sessions and unlimited text access")
                                    .font(Typography.footnote)
                                    .foregroundColor(.textSecondary)
                            }
                            
                            Spacer()
                        }
                        
                        PrimaryButton("Unlock Core") {
                            onUpgrade()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Settings Section
struct SettingsSection: View {
    let isDarkMode: Bool
    let notificationsEnabled: Bool
    let selectedVoice: ElevenLabsVoice
    let onToggleDarkMode: () -> Void
    let onToggleNotifications: () -> Void
    let onOpenVoiceSettings: () -> Void
    let onOpenTerms: () -> Void
    let onOpenPrivacyPolicy: () -> Void
    let onSignOut: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Settings")
                .font(Typography.title3)
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)
            
            VStack(spacing: 0) {
                // Voice Selection
                SettingsRow(
                    title: "UrGood Voice (\"your good\")",
                    subtitle: "\(selectedVoice.icon) \(selectedVoice.displayName) - \(selectedVoice.description)",
                    icon: "waveform",
                    action: onOpenVoiceSettings
                )
                
                Divider()
                    .padding(.leading, Spacing.xl)
                
                // Dark Mode Toggle
                SettingsRow(
                    title: "Dark Mode",
                    subtitle: "Give your eyes a break 🌙",
                    icon: isDarkMode ? "moon.fill" : "sun.max.fill",
                    action: onToggleDarkMode,
                    showToggle: true,
                    isToggled: isDarkMode
                )
                
                Divider()
                    .padding(.leading, Spacing.xl)
                
                SettingsRow(
                    title: "Notifications",
                    subtitle: "A gentle nudge, once a day",
                    icon: "bell.fill",
                    action: onToggleNotifications,
                    showToggle: true,
                    isToggled: notificationsEnabled
                )
                
                Divider()
                    .padding(.leading, Spacing.xl)
                
                SettingsRow(
                    title: "Terms of Service",
                    subtitle: "View our terms and conditions",
                    icon: "doc.text",
                    action: onOpenTerms
                )
                
                SettingsRow(
                    title: "Privacy Policy",
                    subtitle: "View our privacy policy",
                    icon: "hand.raised",
                    action: onOpenPrivacyPolicy
                )
                
                Divider()
                    .padding(.leading, Spacing.xl)
                
                SettingsRow(
                    title: "Sign Out",
                    subtitle: "Sign out of your account",
                    icon: "rectangle.portrait.and.arrow.right",
                    action: onSignOut,
                    isDestructive: true
                )
            }
            .background(Color.surface)
            .cornerRadius(CornerRadius.lg)
        }
    }
}

// MARK: - Emergency Disclaimer Section
struct EmergencyDisclaimerSection: View {
    var body: some View {
        VStack(spacing: Spacing.sm) {
            Text("Not therapy. For emergencies call local services.")
                .font(Typography.footnote)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
            
            Text("US: 988")
                .font(Typography.footnote)
                .foregroundColor(.brandPrimary)
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(Color.surfaceSecondary)
        )
    }
}

// MARK: - Settings Row Component
struct SettingsRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void
    var isDestructive: Bool = false
    var showToggle: Bool = false
    var isToggled: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                Image(systemName: icon)
                    .foregroundColor(isDestructive ? .error : .brandPrimary)
                    .font(.title3)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(title)
                        .font(Typography.headline)
                        .foregroundColor(isDestructive ? .error : .textPrimary)
                    
                    Text(subtitle)
                        .font(Typography.footnote)
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
                
                if showToggle {
                    Toggle("", isOn: .constant(isToggled))
                        .labelsHidden()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.textTertiary)
                        .font(.caption)
                }
            }
            .padding(Spacing.lg)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Demo Reset Section
struct DemoResetSection: View {
    let onClearData: () -> Void
    @State private var showingAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: "trash.fill")
                    .foregroundColor(.error)
                    .font(.title3)
                
                Text("Demo Reset")
                    .font(Typography.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)
            }
            
            Text("Clear all user data for a fresh demo experience")
                .font(Typography.body)
                .foregroundColor(.textSecondary)
            
            Button(action: { showingAlert = true }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Clear All Data")
                }
                .font(Typography.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(Spacing.md)
                .background(Color.error)
                .cornerRadius(CornerRadius.md)
            }
        }
        .padding(Spacing.lg)
        .background(Color.surface)
        .cornerRadius(CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(Color.error.opacity(0.3), lineWidth: 1)
        )
        .alert("Clear All Data", isPresented: $showingAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear Data", role: .destructive) {
                onClearData()
            }
        } message: {
            Text("This will permanently delete all your chat messages, mood entries, and progress data. This action cannot be undone.")
        }
    }
}


#Preview {
    SettingsView(container: DIContainer.shared)
        .themeEnvironment()
}
