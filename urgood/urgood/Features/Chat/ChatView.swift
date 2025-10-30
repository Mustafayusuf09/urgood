import SwiftUI

struct ChatView: View {
    private let container: DIContainer
    
    init(container: DIContainer) {
        self.container = container
    }
    
    var body: some View {
        VoiceChatView()
            .overlay(alignment: .bottom) {
                CrisisDisclaimerFooter()
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.xl)
            }
            .accessibilityIdentifier("VoiceChatScreen")
    }
}

// MARK: - Crisis Disclaimer
struct CrisisDisclaimerFooter: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.brandAccent)
                
                Text("Not an emergency service")
                    .font(Typography.caption)
                    .foregroundColor(.textSecondary)
            }
            
            Text("If you’re in immediate danger or thinking about harming yourself, call 911 or your local emergency number right away.")
                .font(Typography.caption)
                .foregroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack(spacing: Spacing.sm) {
                Link(destination: URL(string: "https://988lifeline.org/")!) {
                    Text("988 Lifeline")
                        .font(Typography.captionBold)
                }
                
                Link(destination: URL(string: "https://www.crisisservicescanada.ca/en/")!) {
                    Text("Canada")
                        .font(Typography.captionBold)
                }
            }
            .foregroundColor(.brandPrimary)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(Color.black.opacity(0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Crisis resources. UrGood is not an emergency service.")
    }
}
