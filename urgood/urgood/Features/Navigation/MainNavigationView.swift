import SwiftUI
import OSLog

/// Main navigation container with hamburger menu
/// Provides access to Chat, Insights, and Settings with slide-out menu
struct MainNavigationView: View {
    @EnvironmentObject var container: DIContainer
    @EnvironmentObject var router: AppRouter
    
    @State private var selectedTab: AppTab = .chat
    @State private var showMenu = false
    @State private var pendingTab: AppTab?
    private let menuWidth: CGFloat = 280
    private let menuAnimation = Animation.easeInOut(duration: 0.3)
    
    private static let log = Logger(subsystem: "com.urgood.urgood", category: "MainNavigationView")
    
    var body: some View {
        ZStack {
            NavigationStack {
                mainContent
                    .id(selectedTab)
                    .navigationTitle(selectedTab.rawValue)
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            hamburgerButton
                    }
                }
            }
            .disabled(showMenu)
            .allowsHitTesting(!showMenu)
            .blur(radius: showMenu ? 2 : 0)
            .zIndex(0)
            .onChange(of: showMenu) { isOpen in
                guard !isOpen else { return }
                if let tab = pendingTab {
                    updateSelectedTab(to: tab)
                    pendingTab = nil
                }
            }
            .onChange(of: selectedTab) { newValue in
                print("✅ Navigated to \(newValue.rawValue)")
            }
            
            // Overlay and menu on top
            menuOverlay
                .zIndex(1)
            
            // Debug: Demo switcher (only in DEBUG builds)
            #if DEBUG
            if container.unifiedAuthService.isAuthenticated {
                DemoSwitcherButton(
                    authService: container.unifiedAuthService,
                    appSession: container.appSession
                )
                .zIndex(2)
            }
            #endif
        }
    }
    
    // MARK: - Main Content
    @ViewBuilder
    private var mainContent: some View {
        Group {
            switch selectedTab {
            case .chat:
                VoiceHomeView()
            case .insights:
                VoiceFocusedInsightsView(container: container)
            case .settings:
                VoiceFocusedSettingsView(container: container)
            }
        }
        .environmentObject(container)
        .environmentObject(router)
        .themeEnvironment()
        .modifier(TabContentAnimationModifier(selectedTab: selectedTab))
    }
    
    // MARK: - Hamburger Button
    private var hamburgerButton: some View {
        Button(action: {
            if showMenu {
                Self.log.notice("🔒 Hamburger tapped → closing menu")
                closeMenu(cancelPendingSelection: true)
            } else {
                Self.log.notice("📂 Hamburger tapped → opening menu")
                openMenu()
            }
        }) {
            Image(systemName: showMenu ? "xmark" : "line.horizontal.3")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Menu Helpers
    private var activeMenuTab: AppTab {
        pendingTab ?? selectedTab
    }
    
    private func openMenu() {
        guard !showMenu else { return }
        pendingTab = nil
        withAnimation(menuAnimation) {
            showMenu = true
        }
        Self.log.notice("📂 Menu opened")
    }
    
    private func closeMenu(cancelPendingSelection: Bool = false) {
        guard showMenu else {
            if cancelPendingSelection {
                pendingTab = nil
            }
            return
        }
        if cancelPendingSelection {
            pendingTab = nil
        }
        withAnimation(menuAnimation) {
            showMenu = false
        }
        Self.log.notice("📁 Menu closed (cancelPending=\(cancelPendingSelection))")
    }
    
    private func handleMenuSelection(_ tab: AppTab) {
        print("🧭 Menu tapped \(tab.rawValue)")
        Self.log.notice("🧭 Menu selection: \(tab.rawValue, privacy: .public)")
        if tab == selectedTab {
            closeMenu()
            return
        }
        pendingTab = tab
        closeMenu()
    }
    
    private func updateSelectedTab(to tab: AppTab) {
        guard tab != selectedTab else { return }
        print("➡️ Switching to \(tab.rawValue)")
        selectedTab = tab
    }
}

// MARK: - Overlay Components

private extension MainNavigationView {
    var menuOverlay: some View {
        ZStack {
            Color.black.opacity(showMenu ? 0.4 : 0)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    guard showMenu else { return }
                    closeMenu(cancelPendingSelection: true)
                }
            
            HStack(spacing: 0) {
                HamburgerMenuView(
                    selectedTab: activeMenuTab,
                    onSelect: handleMenuSelection
                )
                .frame(width: menuWidth)
                .background(Color(.systemBackground))
                .shadow(color: .black.opacity(0.3), radius: 20, x: 5, y: 0)
                .offset(x: showMenu ? 0 : -menuWidth)
                .animation(menuAnimation, value: showMenu)
                
                Spacer()
            }
        }
        .allowsHitTesting(showMenu)
        .animation(menuAnimation, value: showMenu)
        .opacity(showMenu ? 1 : 0)
    }
}

#Preview {
    MainNavigationView()
        .environmentObject(DIContainer.shared)
        .environmentObject(AppRouter())
}

private struct TabContentAnimationModifier: ViewModifier {
    let selectedTab: AppTab
    
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: selectedTab)
        } else {
            content
                .animation(.easeInOut(duration: 0.3), value: selectedTab)
        }
    }
}
