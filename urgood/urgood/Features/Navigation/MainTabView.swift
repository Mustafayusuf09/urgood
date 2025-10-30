import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .voice
    
    enum Tab: String, CaseIterable {
        case insights = "Insights"
        case voice = "Voice"
        case profile = "Profile"
        
        var icon: String {
            switch self {
            case .insights: return "chart.bar.fill"
            case .voice: return "waveform"
            case .profile: return "person.circle.fill"
            }
        }
        
        var activeColor: Color {
            switch self {
            case .insights: return .brandSecondary
            case .voice: return .brandPrimary
            case .profile: return .brandAccent
            }
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content
            Group {
                switch selectedTab {
                case .insights:
                    VoiceFocusedInsightsView(container: DIContainer.shared)
                case .voice:
                    VoiceHomeView()
                case .profile:
                    VoiceFocusedSettingsView(container: DIContainer.shared)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .zIndex(0)
            
            // Custom tab bar
            CustomTabBar(selectedTab: $selectedTab)
                .zIndex(1)
        }
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @Binding var selectedTab: MainTabView.Tab
    @Namespace private var tabAnimation
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTabView.Tab.allCases, id: \.self) { tab in
                TabBarButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    namespace: tabAnimation
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.brandPrimary.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 34)
    }
}

// MARK: - Tab Bar Button
struct TabBarButton: View {
    let tab: MainTabView.Tab
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    // Background for selected state
                    if isSelected {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(tab.activeColor.opacity(0.15))
                            .frame(width: 60, height: 36)
                            .matchedGeometryEffect(id: "selectedTab", in: namespace)
                    }
                    
                    // Icon
                    Image(systemName: tab.icon)
                        .font(.system(size: tab == .voice ? 24 : 20, weight: .medium))
                        .foregroundColor(isSelected ? tab.activeColor : .textTertiary)
                        .scaleEffect(isSelected && tab == .voice ? 1.1 : 1.0)
                }
                
                // Label
                Text(tab.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? tab.activeColor : .textTertiary)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    MainTabView()
}
