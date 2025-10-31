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
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    private let menuWidth: CGFloat = 280
    private let menuAnimation = Animation.easeInOut(duration: 0.3)
    private let swipeEdgeThreshold: CGFloat = 20 // Distance from left edge to trigger swipe
    private let swipeThreshold: CGFloat = 50 // Minimum drag distance to open menu
    
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
            .simultaneousGesture(
                // Swipe to open: only when menu is closed
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        // Only allow swipe from left edge when menu is closed
                        guard !showMenu else { return }
                        if value.startLocation.x < swipeEdgeThreshold && value.translation.width > 0 {
                            isDragging = true
                            // Limit drag offset to menu width
                            dragOffset = min(value.translation.width, menuWidth)
                            Self.log.debug("📱 Swiping right: \(dragOffset)")
                        }
                    }
                    .onEnded { value in
                        // Only handle if menu is closed
                        guard !showMenu else { return }
                        isDragging = false
                        
                        // Opening menu: check if swipe was far enough
                        if value.translation.width > swipeThreshold {
                            Self.log.notice("📂 Swipe right detected → opening menu")
                            openMenu()
                        } else {
                            // Snap back if not far enough
                            withAnimation(menuAnimation) {
                                dragOffset = 0
                            }
                        }
                        
                        // Reset drag offset
                        dragOffset = 0
                    }
            )
            .onChange(of: showMenu) { isOpen in
                // Reset drag offset when menu state changes
                dragOffset = 0
                isDragging = false
                
                guard !isOpen else { return }
                if let tab = pendingTab {
                    updateSelectedTab(to: tab)
                    pendingTab = nil
                }
            }
            
            // Overlay and menu on top
            menuOverlay
                .zIndex(1)
            
            // Demo switcher removed
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
                .simultaneousGesture(
                    // Swipe to close: only when menu is open
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            // Only allow swipe left when menu is open
                            guard showMenu else { return }
                            if value.translation.width < 0 {
                                isDragging = true
                                // Calculate offset based on menu position
                                dragOffset = max(value.translation.width, -menuWidth)
                                Self.log.debug("📱 Swiping left: \(dragOffset)")
                            }
                        }
                        .onEnded { value in
                            // Only handle if menu is open
                            guard showMenu else { return }
                            isDragging = false
                            
                            // Closing menu: check if swipe was far enough
                            if abs(value.translation.width) > swipeThreshold {
                                Self.log.notice("🔒 Swipe left detected → closing menu")
                                closeMenu(cancelPendingSelection: true)
                            } else {
                                // Snap back if not far enough
                                withAnimation(menuAnimation) {
                                    dragOffset = 0
                                }
                            }
                            
                            // Reset drag offset
                            dragOffset = 0
                        }
                )
            
            HStack(spacing: 0) {
                HamburgerMenuView(
                    selectedTab: activeMenuTab,
                    onSelect: handleMenuSelection
                )
                .frame(width: menuWidth)
                .background(Color(.systemBackground))
                .shadow(color: .black.opacity(0.3), radius: 20, x: 5, y: 0)
                .offset(x: (showMenu ? 0 : -menuWidth) + dragOffset)
                .animation(isDragging ? nil : menuAnimation, value: showMenu)
                
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
