import SwiftUI

/// Hamburger menu navigation for UrGood app
/// Provides access to Chat, Insights, and Settings
struct HamburgerMenuView: View {
    let selectedTab: AppTab
    let onSelect: (AppTab) -> Void
    @EnvironmentObject var container: DIContainer
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            menuHeader
                .padding(.top, 60)
                .padding(.bottom, 40)
            
            // Menu Items
            VStack(spacing: 0) {
                MenuItemButton(
                    title: "Chat",
                    icon: "message.circle.fill",
                    isSelected: selectedTab == .chat,
                    color: .brandPrimary
                ) {
                    onSelect(.chat)
                }
                
                MenuItemButton(
                    title: "Insights",
                    icon: "chart.bar.fill",
                    isSelected: selectedTab == .insights,
                    color: .brandSecondary
                ) {
                    onSelect(.insights)
                }
                
                MenuItemButton(
                    title: "Settings",
                    icon: "gearshape.fill",
                    isSelected: selectedTab == .settings,
                    color: .brandAccent
                ) {
                    onSelect(.settings)
                }
            }
            
            Spacer()
            
            // Footer
            menuFooter
                .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Header
    private var menuHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("UrGood")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.textPrimary)
            
            Text("Your mental wellness companion")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.textSecondary)
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Footer
    private var menuFooter: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .padding(.horizontal, 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Made with care for your wellbeing")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSecondary)
                
                if let user = container.authService.currentUser as? FirebaseAuthService.UrGoodFirebaseUser {
                    Text(user.email ?? "User")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.textTertiary)
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Menu Item Button
struct MenuItemButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(isSelected ? .white : color)
                    .frame(width: 28)
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .textPrimary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? color : Color.clear)
                    .padding(.horizontal, 12)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - App Tab Enum
enum AppTab: String, CaseIterable {
    case chat = "Chat"
    case insights = "Insights"
    case settings = "Settings"
    
    var icon: String {
        switch self {
        case .chat: return "message.circle.fill"
        case .insights: return "chart.bar.fill"
        case .settings: return "gearshape.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .chat: return .brandPrimary
        case .insights: return .brandSecondary
        case .settings: return .brandAccent
        }
    }
}

#Preview {
    HamburgerMenuView(
        selectedTab: .chat,
        onSelect: { _ in }
    )
    .environmentObject(DIContainer.shared)
}
