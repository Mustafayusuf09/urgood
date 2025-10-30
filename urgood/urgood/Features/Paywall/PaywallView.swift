import SwiftUI

struct PaywallView: View {
    @Binding var isPresented: Bool
    let onUpgrade: (SubscriptionType) -> Void
    let onDismiss: () -> Void
    let billingService: (any BillingServiceProtocol)?
    
    @State private var selectedSubscriptionType: SubscriptionType = .core
    
    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            // Paywall card
            VStack(spacing: 0) {
                // Header with close button
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
                
                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        // Hero section
                        VStack(spacing: Spacing.md) {
                            ZStack {
                                RoundedRectangle(cornerRadius: CornerRadius.xl)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.brandPrimary.opacity(0.18), Color.brandSecondary.opacity(0.12)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 120, height: 120)
                                
                                Image(systemName: "waveform.and.mic")
                                    .font(.system(size: 40, weight: .semibold))
                                    .foregroundColor(.brandPrimary)
                            }
                            
                            VStack(spacing: Spacing.sm) {
                                Text("Upgrade to Core")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .multilineTextAlignment(.center)
                                
                                Text("Lock in daily voice sessions and keep every text conversation flowing.")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, Spacing.md)
                            }
                        }
                        
                        SubscriptionPlanCard(
                            planName: selectedSubscriptionType.displayName,
                            priceText: billingService?.getPremiumPrice(for: selectedSubscriptionType) ?? selectedSubscriptionType.displayPrice,
                            highlight: selectedSubscriptionType.highlight
                        )
                        
                        Button(action: {
                            onUpgrade(selectedSubscriptionType)
                        }) {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Start daily sessions")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                            .background(
                                LinearGradient(
                                    colors: [Color.brandPrimary, Color.brandSecondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(CornerRadius.lg)
                            .shadow(color: Color.brandPrimary.opacity(0.3), radius: 12, x: 0, y: 6)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Text("By subscribing, you agree to our Terms of Service and Privacy Policy")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.lg)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.xl)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.background)
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, Spacing.lg)
            .scaleEffect(isPresented ? 1 : 0.8)
            .opacity(isPresented ? 1 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isPresented)
        }
    }
    
    // MARK: - Helper Methods
}

struct SubscriptionPlanCard: View {
    let planName: String
    let priceText: String
    let highlight: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(planName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                    
                    Text(priceText)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.brandPrimary)
                    
                    Text("Billed monthly")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "seal.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.brandPrimary)
                    .shadow(color: Color.brandPrimary.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            
            Text(highlight)
                .font(.callout)
                .fontWeight(.medium)
                .foregroundColor(.brandSecondary)
                .padding(.vertical, Spacing.sm)
                .padding(.horizontal, Spacing.md)
                .background(Color.brandSecondary.opacity(0.18))
                .cornerRadius(CornerRadius.md)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .fill(Color.surface)
                .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .stroke(Color.brandPrimary.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Preview
struct PaywallView_Previews: PreviewProvider {
    static var previews: some View {
        PaywallView(
            isPresented: .constant(true),
            onUpgrade: { _ in },
            onDismiss: {},
            billingService: BillingService(localStore: EnhancedLocalStore.shared)
        )
        .background(Color.gray.opacity(0.3))
    }
}
