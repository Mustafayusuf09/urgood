//
//  SafeContentView.swift
//  urgood
//
//  Created for debugging white screen issue
//

import SwiftUI

struct SafeContentView: View {
    @State private var isInitialized = false
    @State private var initError: String?
    @StateObject private var container: DIContainer = DIContainer.shared
    @StateObject private var router = AppRouter()
    
    var body: some View {
        Group {
            if let error = initError {
                // Show error state
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    
                    Text("Initialization Error")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(error)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Retry") {
                        initError = nil
                        isInitialized = false
                        initializeApp()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            } else if !isInitialized {
                // Show loading state
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    
                    Text("Initializing Urgood...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Setting up your mental wellness companion")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                // Show main content
                mainContent
            }
        }
        .onAppear {
            initializeApp()
        }
    }
    
    private var mainContent: some View {
        Group {
            // Use unified auth service for consistent navigation after login
            if container.unifiedAuthService.isAuthenticated {
                // Main app content
                MainAppView(container: container, router: router)
            } else {
                // Auth flow
                if !container.localStore.hasCompletedFirstRun {
                    FirstRunFlowView(container: container)
                        .interactiveDismissDisabled()
                } else {
                    AuthenticationView(container: container)
                        .interactiveDismissDisabled()
                }
            }
        }
    }
    
    private func initializeApp() {
        Task { @MainActor in
            do {
                // Simulate async initialization
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                
                // Proceed regardless of auth state; routing below will handle auth vs main app
                isInitialized = true
            } catch {
                initError = error.localizedDescription
            }
        }
    }
}

// Separate main app view to keep things clean
struct MainAppView: View {
    let container: DIContainer
    @ObservedObject var router: AppRouter
    
    @State private var showSideMenu = false
    @State private var selectedView: MainTab = .chat
    
    enum MainTab: String, CaseIterable {
        case chat = "Chat"
        case insights = "Insights"
        case settings = "Settings"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Main content based on selected view
                Group {
                    switch selectedView {
                    case .chat:
                        ChatView(container: container)
                    case .insights:
                        InsightsView(container: container)
                    case .settings:
                        SettingsView(container: container)
                    }
                }
                .environmentObject(container)
                .environmentObject(router)
                .themeEnvironment()
                .navigationTitle(showSideMenu ? "" : selectedView.rawValue)
                .navigationBarTitleDisplayMode(showSideMenu ? .inline : .large)
                
                // Side menu overlay
                if showSideMenu {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .allowsHitTesting(showSideMenu)
                        .onTapGesture {
                            withAnimation {
                                showSideMenu = false
                            }
                        }
                        .transition(.opacity)
                        .zIndex(1)
                    
                    // Side menu content
                    HStack {
                        SideMenuView(
                            selectedView: $selectedView,
                            showSideMenu: $showSideMenu
                        )
                        .frame(width: 280)
                        .background(Color(.systemBackground))
                        .transition(.move(edge: .leading))
                        .zIndex(2)
                        
                        Spacer()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showSideMenu.toggle()
                        }
                    }) {
                        Image(systemName: "line.horizontal.3")
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .sheet(item: $router.presentedSheet) { route in
            switch route {
            case .paywall:
                PaywallView(
                    isPresented: .constant(true),
                    onUpgrade: { _ in
                        router.dismiss()
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
                EmptyView()
            }
        }
    }
}

// MARK: - Side Menu View
struct SideMenuView: View {
    @Binding var selectedView: MainAppView.MainTab
    @Binding var showSideMenu: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("UrGood")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Your mental wellness companion")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 60)
            .padding(.bottom, 40)
            
            // Menu Items
            VStack(spacing: 0) {
                MenuItemView(
                    title: "Chat",
                    icon: "message.circle.fill",
                    isSelected: selectedView == .chat
                ) {
                    selectedView = .chat
                    withAnimation {
                        showSideMenu = false
                    }
                }
                
                MenuItemView(
                    title: "Insights",
                    icon: "chart.bar.fill",
                    isSelected: selectedView == .insights
                ) {
                    selectedView = .insights
                    withAnimation {
                        showSideMenu = false
                    }
                }
                
                MenuItemView(
                    title: "Settings",
                    icon: "gearshape.fill",
                    isSelected: selectedView == .settings
                ) {
                    selectedView = .settings
                    withAnimation {
                        showSideMenu = false
                    }
                }
            }
            
            Spacer()
            
            // Footer
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                    .padding(.horizontal, 24)
                
                Text("Made with ❤️ for your wellbeing")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Menu Item View
struct MenuItemView: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .padding(.horizontal, 12)
            )
        }
        .buttonStyle(.plain)
    }
}
