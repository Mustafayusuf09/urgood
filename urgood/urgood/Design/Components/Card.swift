import SwiftUI

struct Card<Content: View>: View {
    let content: Content
    let padding: EdgeInsets
    let backgroundColor: Color
    let shadow: Shadow
    
    init(
        padding: EdgeInsets = EdgeInsets(top: Spacing.md, leading: Spacing.md, bottom: Spacing.md, trailing: Spacing.md),
        backgroundColor: Color = .surface,
        shadow: Shadow = Shadows.card,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.backgroundColor = backgroundColor
        self.shadow = shadow
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [backgroundColor.opacity(0.95), backgroundColor.opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.lg)
                            .stroke(Color.brandPrimary.opacity(0.12), lineWidth: 1)
                            .blendMode(.screen)
                    )
            )
            .shadow(
                color: shadow.color,
                radius: shadow.radius,
                x: shadow.x,
                y: shadow.y
            )
    }
}

struct InfoCard: View {
    let title: String
    let subtitle: String?
    let icon: String
    let action: (() -> Void)?
    
    init(title: String, subtitle: String? = nil, icon: String, action: (() -> Void)? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Card {
            HStack(spacing: Spacing.md) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.brandPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.brandPrimary.opacity(0.1))
                    .cornerRadius(CornerRadius.md)
                
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(title)
                        .font(Typography.headline)
                        .foregroundColor(.textPrimary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(Typography.footnote)
                            .foregroundColor(.textSecondary)
                    }
                }
                
                Spacer()
                
                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .onTapGesture {
            action?()
        }
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        Card {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Sample Card")
                    .font(Typography.title3)
                Text("This is a sample card with some content inside.")
                    .font(Typography.body)
                    .foregroundColor(.textSecondary)
            }
        }
        
        InfoCard(
            title: "Daily Check-in",
            subtitle: "Track your mood and build streaks",
            icon: "heart.fill"
        ) {
            print("Card tapped")
        }
        
        InfoCard(
            title: "Premium Feature",
            subtitle: "Unlock unlimited access",
            icon: "star.fill"
        ) {
            print("Premium tapped")
        }
    }
    .padding()
    .themeEnvironment()
}
