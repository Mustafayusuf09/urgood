//
//  ContentView.swift
//  urgood
//
//  Created by Mustafa Yusuf on 8/29/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var container = DIContainer.shared
    @StateObject private var router = AppRouter()
    @State private var hasMigrated = false
    
    var body: some View {
        Group {
            // Use unified auth service for authentication state
            if container.unifiedAuthService.isAuthenticated {
                // Main app content with hamburger menu navigation
                MainNavigationView()
                    .environmentObject(container)
                    .environmentObject(router)
                    .withAppSession(container.appSession) // Inject AppSession
                    .themeEnvironment()
                    .task {
                        // Run migration on first authenticated launch
                        if !hasMigrated {
                            await runMigrationIfNeeded()
                            hasMigrated = true
                        }
                    }
                    .sheet(item: $router.presentedSheet) { route in
                        switch route {
                        case .paywall:
                            PaywallView(
                                isPresented: .constant(true),
                                onUpgrade: { _ in
                                    // Handle upgrade action
                                    router.dismiss()
                                    // Upgrade flow handled by BillingService
                                },
                                onDismiss: {
                                    router.dismiss()
                                },
                                billingService: container.billingService
                            )
                        case .crisisHelp:
                            CrisisHelpSheet()

                        case .onboarding:
                            OnboardingFlowView(container: container)
                        case .firstRun:
                            EmptyView() // FirstRun will be handled by fullScreenCover
                        }
                    }
            } else {
                // Show authentication or first run flow
                if !container.localStore.hasCompletedFirstRun {
                    FirstRunFlowView(container: container)
                        .interactiveDismissDisabled()
                } else {
                    AuthenticationView(container: container)
                        .interactiveDismissDisabled()
                }
            }
        }
        .onAppear {
            // First run flow is handled by the conditional view above
        }
    }
    
    // MARK: - Migration Helper
    private func runMigrationIfNeeded() async {
        guard let uid = container.appSession.uid else { return }
        
        do {
            let needsMigration = try await container.migrationService.needsMigration(uid: uid)
            if needsMigration {
                print("🔄 Starting data migration for user: \(uid)")
                try await container.migrationService.migrateUserData(uid: uid)
                print("✅ Migration completed successfully")
            }
        } catch {
            print("❌ Migration failed: \(error.localizedDescription)")
            // Migration failure is logged but doesn't block the app
        }
    }
}

#Preview {
    ContentView()
        .themeEnvironment()
}
