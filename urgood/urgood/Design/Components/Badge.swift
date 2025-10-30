import SwiftUI

struct Badge: View {
    let text: String
    let style: BadgeStyle
    let size: BadgeSize
    
    init(_ text: String, style: BadgeStyle = .primary, size: BadgeSize = .medium) {
        self.text = text
        self.style = style
        self.size = size
    }
    
    var body: some View {
        Text(text)
            .font(size.font)
            .foregroundColor(style.textColor)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(style.background)
            .cornerRadius(CornerRadius.xl)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.xl)
                    .stroke(style.borderColor, lineWidth: style.borderWidth)
            )
    }
}

enum BadgeStyle {
    case primary
    case secondary
    case success
    case warning
    case error
    
    var background: LinearGradient {
        switch self {
        case .primary:
            return LinearGradient(colors: [.brandPrimary, .brandAccent], startPoint: .leading, endPoint: .trailing)
        case .secondary:
            return LinearGradient(colors: [.surfaceSecondary, .surfaceGlow], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .success:
            return LinearGradient(colors: [.success, .brandElectric], startPoint: .leading, endPoint: .trailing)
        case .warning:
            return LinearGradient(colors: [.warning, .brandGlow], startPoint: .leading, endPoint: .trailing)
        case .error:
            return LinearGradient(colors: [.error, .brandAccent], startPoint: .leading, endPoint: .trailing)
        }
    }
    
    var textColor: Color {
        switch self {
        case .primary, .success, .error:
            return .white
        case .secondary, .warning:
            return .textPrimary
        }
    }
    
    var borderColor: Color {
        switch self {
        case .primary:
            return .brandPrimary.opacity(0.3)
        case .secondary:
            return .brandSecondary.opacity(0.3)
        case .success:
            return .success.opacity(0.3)
        case .warning:
            return .warning.opacity(0.3)
        case .error:
            return .error.opacity(0.3)
        }
    }
    
    var borderWidth: CGFloat {
        switch self {
        case .secondary:
            return 1
        default:
            return 0
        }
    }
}

enum BadgeSize {
    case small
    case medium
    case large
    
    var font: Font {
        switch self {
        case .small:
            return Typography.caption
        case .medium:
            return Typography.footnote
        case .large:
            return Typography.subheadline
        }
    }
    
    var horizontalPadding: CGFloat {
        switch self {
        case .small:
            return Spacing.sm
        case .medium:
            return Spacing.md
        case .large:
            return Spacing.lg
        }
    }
    
    var verticalPadding: CGFloat {
        switch self {
        case .small:
            return Spacing.xs
        case .medium:
            return Spacing.sm
        case .large:
            return Spacing.md
        }
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        HStack(spacing: Spacing.sm) {
            Badge("New", style: .primary)
            Badge("5", style: .secondary)
            Badge("Success", style: .success)
            Badge("Warning", style: .warning)
            Badge("Error", style: .error)
        }
        
        HStack(spacing: Spacing.sm) {
            Badge("Small", size: .small)
            Badge("Medium", size: .medium)
            Badge("Large", size: .large)
        }
    }
    .padding()
    .themeEnvironment()
}
