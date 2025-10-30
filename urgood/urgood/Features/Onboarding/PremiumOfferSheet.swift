import SwiftUI

struct PremiumOfferSheet: View {
    let userResponses: OnboardingUserResponses
    let container: DIContainer
    let onDismiss: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = false
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: Spacing.xl) {
                    // Header
                    VStack(spacing: Spacing.lg) {
                        Text("✨ your urgood roadmap ✨")
                            .font(Typography.largeTitle)
                            .foregroundColor(.brandPrimary)
                            .multilineTextAlignment(.center)
                        
                        Text("here's your personalized path to leveling up")
                            .font(Typography.title2)
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, Spacing.lg)
                    
                    // Current State vs Future Vision
                    VStack(spacing: Spacing.lg) {
                        // Current state
                        VStack(spacing: Spacing.md) {
                            Text("rn you're...")
                                .font(Typography.title3)
                                .foregroundColor(.textSecondary)
                            
                            HStack(spacing: Spacing.md) {
                                Text(currentStateEmoji)
                                    .font(.system(size: 48))
                                
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    Text(currentStateText)
                                        .font(Typography.headline)
                                        .foregroundColor(.textPrimary)
                                    
                                    Text(currentStateDescription)
                                        .font(Typography.body)
                                        .foregroundColor(.textSecondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.md)
                            .background(Color.surface)
                            .cornerRadius(CornerRadius.lg)
                        }
                        
                        // Arrow
                        Text("⬇️")
                            .font(.title)
                        
                        // Future vision
                        VStack(spacing: Spacing.md) {
                            Text("in 3 months you could be...")
                                .font(Typography.title3)
                                .foregroundColor(.textSecondary)
                            
                            HStack(spacing: Spacing.md) {
                                Text(futureVisionEmoji)
                                    .font(.system(size: 48))
                                
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    Text(futureVisionText)
                                        .font(Typography.headline)
                                        .foregroundColor(.textPrimary)
                                    
                                    Text(futureVisionDescription)
                                        .font(Typography.body)
                                        .foregroundColor(.textSecondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.md)
                            .background(Color.brandPrimary.opacity(0.1))
                            .cornerRadius(CornerRadius.lg)
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    
                    // Why Premium
                    VStack(spacing: Spacing.lg) {
                        Text("why Premium is your only path there:")
                            .font(Typography.title2)
                            .foregroundColor(.textPrimary)
                            .multilineTextAlignment(.center)
                        
                        VStack(spacing: Spacing.md) {
                            PremiumFeatureRow(
                                emoji: "🚀",
                                title: "daily check-ins to stay consistent",
                                description: "never run out of motivation again"
                            )
                            
                            PremiumFeatureRow(
                                emoji: "🎯",
                                title: "personalized insights",
                                description: "AI-powered recommendations tailored to you"
                            )
                            
                            PremiumFeatureRow(
                                emoji: "⚡",
                                title: "boosts when stuck",
                                description: "get unstuck with AI-powered guidance"
                            )
                            
                            PremiumFeatureRow(
                                emoji: "🎯",
                                title: "step-by-step roadmap",
                                description: "exactly what to do, when to do it"
                            )
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    
                    // Social proof
                    VStack(spacing: Spacing.md) {
                        Text("join 10,000+ Gen Z already crushing it 🚀")
                            .font(Typography.body)
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: Spacing.xl) {
                            SocialProofStat(number: "94%", label: "see results")
                            SocialProofStat(number: "87%", label: "stay consistent")
                            SocialProofStat(number: "91%", label: "feel better")
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    
                    // CTA Section
                    VStack(spacing: Spacing.lg) {
                        Text("start your free trial today 🎉")
                            .font(Typography.title2)
                            .foregroundColor(.brandPrimary)
                            .multilineTextAlignment(.center)
                        
                        VStack(spacing: Spacing.md) {
                            PrimaryButton("✨ Start Free Trial") {
                                showPaywall = true
                            }
                            
                            Button("💸 Subscribe Now") {
                                showPaywall = true
                            }
                            .font(Typography.body)
                            .foregroundColor(.textSecondary)
                        }
                        .padding(.horizontal, Spacing.xl)
                    }
                    
                    Spacer(minLength: Spacing.xl)
                }
                .padding(.bottom, Spacing.xl)
            }
            .background(Color.background)
            .navigationTitle("Your Roadmap")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(
                isPresented: $showPaywall,
                onUpgrade: { _ in
                    showPaywall = false
                    onDismiss() // This will dismiss the PremiumOfferSheet
                },
                onDismiss: {
                    showPaywall = false
                },
                billingService: container.billingService
            )
        }
    }
    
    // MARK: - Computed Properties
    private var currentStateEmoji: String {
        if let energy = userResponses.energyCheck {
            return energy.emoji
        }
        return "🙂"
    }
    
    private var currentStateText: String {
        if let energy = userResponses.energyCheck {
            return energy.title.lowercased()
        }
        return "finding your vibe"
    }
    
    private var currentStateDescription: String {
        guard let spark = userResponses.checkInSpark else {
            return "and open to whatever feels good"
        }
        switch spark {
        case .pepTalk:
            return "and chasing that spark of motivation"
        case .stayConsistent:
            return "and dialed in on staying consistent"
        case .getClarity:
            return "and sorting through what's on your mind"
        case .justCurious:
            return "and exploring what feels good today"
        }
    }
    
    private var futureVisionEmoji: String {
        if let signal = userResponses.winSignal {
            return signal.emoji
        }
        if let focus = userResponses.focusPriority {
            return focus.emoji
        }
        return "✨"
    }
    
    private var futureVisionText: String {
        guard let focus = userResponses.focusPriority else {
            return "feeling unstoppable"
        }
        switch focus {
        case .dailyWins:
            return "celebrating your daily wins"
        case .buildConfidence:
            return "walking taller every day"
        case .findBalance:
            return "gliding through a balanced week"
        case .trySomethingNew:
            return "living in explorer mode"
        }
    }
    
    private var futureVisionDescription: String {
        if let signal = userResponses.winSignal {
            switch signal {
            case .takingBreaks:
                return "taking breaks that actually recharge you"
            case .kinderSelfTalk:
                return "talking to yourself like a best friend"
            case .finishingTasks:
                return "checking off the stuff that matters"
            case .feelingOrganized:
                return "feeling calm because everything has a place"
            }
        }
        if let celebration = userResponses.celebrationStyle {
            switch celebration {
            case .emojiHype:
                return "celebrating every win with emoji fireworks"
            case .heartfeltShoutout:
                return "soaking in heartfelt shoutouts"
            case .nextStep:
                return "turning wins into your next steps"
            case .surpriseMe:
                return "keeping things playful with surprises"
            }
        }
        return "with your crew cheering loudly"
    }
}

// MARK: - Premium Feature Row
struct PremiumFeatureRow: View {
    let emoji: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            Text(emoji)
                .font(.title2)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(Typography.headline)
                    .foregroundColor(.textPrimary)
                
                Text(description)
                    .font(Typography.body)
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(Color.surface)
        .cornerRadius(CornerRadius.lg)
    }
}

#Preview {
    let sampleResponses = OnboardingUserResponses(
        checkInSpark: .stayConsistent,
        energyCheck: .holdingItTogether,
        supportTone: .softSupport,
        focusPriority: .dailyWins,
        boostMoment: .morningJumpstart,
        celebrationStyle: .emojiHype,
        accountabilityStyle: .gentleNudges,
        winSignal: .finishingTasks
    )
    
    PremiumOfferSheet(
        userResponses: sampleResponses,
        container: DIContainer.shared,
        onDismiss: {}
    )
    .themeEnvironment()
}
