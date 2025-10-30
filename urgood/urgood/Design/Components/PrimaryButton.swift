import SwiftUI

struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    let style: PrimaryButtonVariant
    let isLoading: Bool
    
    init(_ title: String, style: PrimaryButtonVariant = .primary, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.isLoading = isLoading
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: style.textColor))
                        .scaleEffect(0.8)
                }
                
                Text(title)
                    .font(Typography.headline)
                    .foregroundColor(style.textColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                LinearGradient(
                    colors: style.backgroundGradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(CornerRadius.lg)
            .shadow(color: style.shadowColor, radius: 4, x: 0, y: 2)
        }
        .disabled(isLoading)
        .scaleEffect(isLoading ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isLoading)
    }
}

enum PrimaryButtonVariant {
    case primary
    case secondary
    case destructive
    
    var backgroundGradient: [Color] {
        switch self {
        case .primary:
            return [.brandPrimary, .brandAccent]
        case .secondary:
            return [.surfaceSecondary, .surfaceSecondary]
        case .destructive:
            return [.error, .error]
        }
    }
    
    var textColor: Color {
        switch self {
        case .primary:
            return .white
        case .secondary:
            return .brandPrimary
        case .destructive:
            return .white
        }
    }
    
    var shadowColor: Color {
        switch self {
        case .primary:
            return .brandPrimary.opacity(0.3)
        case .secondary:
            return .clear
        case .destructive:
            return .error.opacity(0.3)
        }
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        PrimaryButton("Primary Action") {
            print("Primary tapped")
        }
        
        PrimaryButton("Secondary Action", style: .secondary) {
            print("Secondary tapped")
        }
        
        PrimaryButton("Destructive Action", style: .destructive) {
            print("Destructive tapped")
        }
        
        PrimaryButton("Loading...", isLoading: true) {
            print("Loading tapped")
        }
    }
    .padding()
    .themeEnvironment()
}
