import SwiftUI

struct EmptyState: View {
    let icon: String
    let title: String
    let subtitle: String?
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [.brandPrimary.opacity(0.35), .brandAccent.opacity(0.18)]),
                            center: .center,
                            startRadius: 8,
                            endRadius: 80
                        )
                    )
                    .frame(width: 96, height: 96)
                    .blur(radius: 2)
                    .overlay(
                        Circle()
                            .stroke(Color.brandPrimary.opacity(0.4), lineWidth: 2)
                            .frame(width: 92, height: 92)
                    )
                    .shadow(color: Color.brandPrimary.opacity(0.25), radius: 12, x: 0, y: 6)
                
                Image(systemName: icon)
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 4)
            }
            
            VStack(spacing: Spacing.md) {
                Text(title)
                    .font(Typography.title2)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .kerning(0.4)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(Typography.body)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xl)
                        .lineSpacing(3)
                }
            }
            
            if let actionTitle = actionTitle, let action = action {
                PrimaryButton(actionTitle, action: action)
                    .padding(.horizontal, Spacing.xl)
            }
            
            Spacer()
        }
        .padding(Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.surface, Color.surfaceGlow.opacity(0.6)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.xl)
                        .stroke(Color.brandPrimary.opacity(0.14), lineWidth: 1)
                )
        )
    }
}

#Preview {
    VStack(spacing: Spacing.lg) {
        EmptyState(
            icon: "message",
            title: "No messages yet",
            subtitle: "Start a conversation with your AI coach to get personalized support and guidance.",
            actionTitle: "Start Chatting"
        ) {
            print("Start chatting tapped")
        }
        
        EmptyState(
            icon: "heart",
            title: "No mood entries",
            subtitle: "Track your daily mood to build healthy habits and see your progress over time.",
            actionTitle: "Check In Now"
        ) {
            print("Check in tapped")
        }
        
        EmptyState(
            icon: "bubble.left.and.bubble.right",
            title: "No sessions yet",
            subtitle: "Start chatting to begin your mental wellness journey."
        )
    }
    .themeEnvironment()
}
