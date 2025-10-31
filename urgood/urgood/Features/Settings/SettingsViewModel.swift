import Foundation
import SwiftUI

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var user: User
    @Published var showPaywall = false
    @Published var isDarkMode: Bool = false
    @Published var notificationsEnabled: Bool = true
    @Published var showTermsOfService = false
    @Published var showPrivacyPolicy = false
    
    private let localStore: LocalStore
    let billingService: any BillingServiceProtocol
    private let authService: any AuthServiceProtocol
    private let notificationService: NotificationService
    
    init(localStore: LocalStore, billingService: any BillingServiceProtocol, authService: any AuthServiceProtocol, notificationService: NotificationService) {
        self.localStore = localStore
        self.billingService = billingService
        self.authService = authService
        self.notificationService = notificationService
        self.user = localStore.user
        
        // Load preferences
        self.isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        self.notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        
        // Apply the saved dark mode preference
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.windows.forEach { window in
                window.overrideUserInterfaceStyle = isDarkMode ? .dark : .light
            }
        }
    }
    
    var subscriptionStatus: SubscriptionStatus {
        user.subscriptionStatus
    }
    
    var isPremium: Bool {
        subscriptionStatus == .premium
    }
    
    func refreshData() {
        user = localStore.user
    }
    
    func clearAllData() {
        localStore.clearAllData()
        user = localStore.user
    }
    
    func unlockPremium() {
        showPaywall = true
    }
    
    func dismissPaywall() {
        showPaywall = false
    }
    
    func toggleNotifications() {
        notificationsEnabled.toggle()
        UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
        
        if notificationsEnabled {
            Task {
                let granted = await notificationService.requestPermission()
                if granted {
                    notificationService.scheduleSmartNotifications()
                } else {
                    // If permission denied, disable notifications
                    notificationsEnabled = false
                    UserDefaults.standard.set(false, forKey: "notificationsEnabled")
                }
            }
        } else {
            notificationService.disableNotifications()
        }
    }
    
    func openTerms() {
        showTermsOfService = true
    }
    
    func openPrivacyPolicy() {
        showPrivacyPolicy = true
    }
    
    func toggleDarkMode() {
        isDarkMode.toggle()
        UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
        
        // Update the app's color scheme
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.windows.forEach { window in
                window.overrideUserInterfaceStyle = isDarkMode ? .dark : .light
            }
        }
    }
    
    func signOut() async {
        try? await authService.signOut()
    }
}

#Preview {
    SettingsView(container: DIContainer.shared)
}
