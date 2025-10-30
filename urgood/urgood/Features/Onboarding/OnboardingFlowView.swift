import SwiftUI

struct OnboardingFlowView: View {
    let container: DIContainer
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = OnboardingFlowViewModel()
    
    var body: some View {
        ZStack {
            // Background gradient
            AngularGradient(
                gradient: Gradient(colors: [.brandPrimary.opacity(0.3), .brandAccent.opacity(0.2), .brandElectric.opacity(0.3)]),
                center: .center
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress bar
                OnboardingProgressHeader(viewModel: viewModel)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.lg)
                
                // Content
                TabView(selection: $viewModel.currentStep) {
                    // Q1: Check-In Spark
                    CheckInSparkScreen(viewModel: viewModel)
                        .tag(OnboardingStep.checkInSpark)

                    // Q2: Energy Check
                    EnergyCheckScreen(viewModel: viewModel)
                        .tag(OnboardingStep.energyCheck)

                    // Q3: Support Tone
                    SupportToneScreen(viewModel: viewModel)
                        .tag(OnboardingStep.supportTone)

                    // Q4: Focus Priority
                    FocusPriorityScreen(viewModel: viewModel)
                        .tag(OnboardingStep.focusPriority)

                    // Q5: Boost Moment
                    BoostMomentScreen(viewModel: viewModel)
                        .tag(OnboardingStep.boostMoment)

                    // Q6: Celebration Style
                    CelebrationStyleScreen(viewModel: viewModel)
                        .tag(OnboardingStep.celebrationStyle)

                    // Q7: Accountability Style
                    AccountabilityStyleScreen(viewModel: viewModel)
                        .tag(OnboardingStep.accountabilityStyle)

                    // Q8: Win Signal
                    WinSignalScreen(viewModel: viewModel)
                        .tag(OnboardingStep.winSignal)

                    // Privacy Promise Screen
                    PrivacyPromiseScreen(viewModel: viewModel)
                        .tag(OnboardingStep.privacyPromise)

                    // Loading Screen
                    LoadingScreen(viewModel: viewModel, container: container)
                        .tag(OnboardingStep.loading)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)
            }
        }
        .sheet(isPresented: $viewModel.showPremiumOffer) {
            PremiumOfferSheet(
                userResponses: viewModel.userResponses,
                container: container,
                onDismiss: { dismiss() }
            )
        }
        .onAppear {
            viewModel.logInteraction(for: .checkInSpark)
        }
    }
}

struct OnboardingProgressHeader: View {
    @ObservedObject var viewModel: OnboardingFlowViewModel

    var body: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                Text("vibe score")
                    .font(Typography.footnote)
                    .foregroundColor(.textSecondary)
                Spacer()
                Text("\(Int(viewModel.vibeScore.rounded()))")
                    .font(Typography.headline)
                    .foregroundColor(.brandAccent)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.vibeScore)
            }

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.surfaceSecondary.opacity(0.4))
                    .frame(height: 8)

                Capsule()
                    .fill(LinearGradient(colors: [.brandPrimary, .brandAccent], startPoint: .leading, endPoint: .trailing))
                    .frame(width: progressWidth, height: 8)
                    .animation(.easeInOut(duration: 0.4), value: viewModel.vibeScore)
            }

            if let latest = viewModel.hypeMomentsUnlocked.last {
                HStack(spacing: Spacing.sm) {
                    Text(latest.emoji)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(latest.title)
                            .font(Typography.subheadline)
                            .foregroundColor(.textPrimary)
                        Text(latest.description)
                            .font(Typography.caption)
                            .foregroundColor(.textSecondary)
                    }
                    Spacer()
                }
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .fill(Color.surfaceSecondary.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.lg)
                                .stroke(Color.brandPrimary.opacity(0.1), lineWidth: 1)
                        )
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var progressWidth: CGFloat {
        let total = OnboardingHypeMoment.maxVibeScore
        return CGFloat((viewModel.vibeScore / total) * 280)
    }
}

// MARK: - Q1 Check-In Spark
struct CheckInSparkScreen: View {
    @ObservedObject var viewModel: OnboardingFlowViewModel

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            VStack(spacing: Spacing.lg) {
                Text("what sparked you to join UrGood today?")
                    .font(Typography.title2)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
            }

            VStack(spacing: Spacing.md) {
                ForEach(CheckInSpark.allCases, id: \.self) { spark in
                    SelectionOptionButton(
                        emoji: spark.emoji,
                        title: spark.title,
                        isSelected: viewModel.userResponses.checkInSpark == spark
                    ) {
                        viewModel.userResponses.checkInSpark = spark
                        viewModel.nextStep()
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
    }
}

// MARK: - Q2 Energy Check
struct EnergyCheckScreen: View {
    @ObservedObject var viewModel: OnboardingFlowViewModel

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            VStack(spacing: Spacing.lg) {
                Text("where's your energy at right now?")
                    .font(Typography.title2)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
            }

            VStack(spacing: Spacing.md) {
                ForEach(EnergyCheck.allCases, id: \.self) { state in
                    SelectionOptionButton(
                        emoji: state.emoji,
                        title: state.title,
                        isSelected: viewModel.userResponses.energyCheck == state
                    ) {
                        viewModel.userResponses.energyCheck = state
                        viewModel.nextStep()
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
    }
}

// MARK: - Q3 Support Tone
struct SupportToneScreen: View {
    @ObservedObject var viewModel: OnboardingFlowViewModel

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            VStack(spacing: Spacing.lg) {
                Text("how should i show up for you?")
                    .font(Typography.title2)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
            }

            VStack(spacing: Spacing.md) {
                ForEach(SupportTonePreference.allCases, id: \.self) { tone in
                    SelectionOptionButton(
                        emoji: tone.emoji,
                        title: tone.title,
                        isSelected: viewModel.userResponses.supportTone == tone
                    ) {
                        viewModel.userResponses.supportTone = tone
                        viewModel.nextStep()
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
    }
}

// MARK: - Q4 Focus Priority
struct FocusPriorityScreen: View {
    @ObservedObject var viewModel: OnboardingFlowViewModel

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            VStack(spacing: Spacing.lg) {
                Text("what are we spotlighting first?")
                    .font(Typography.title2)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
            }

            VStack(spacing: Spacing.md) {
                ForEach(FocusPriority.allCases, id: \.self) { focus in
                    SelectionOptionButton(
                        emoji: focus.emoji,
                        title: focus.title,
                        isSelected: viewModel.userResponses.focusPriority == focus
                    ) {
                        viewModel.userResponses.focusPriority = focus
                        viewModel.nextStep()
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
    }
}

// MARK: - Q5 Boost Moment
struct BoostMomentScreen: View {
    @ObservedObject var viewModel: OnboardingFlowViewModel

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            VStack(spacing: Spacing.lg) {
                Text("when do you love a little boost?")
                    .font(Typography.title2)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
            }

            VStack(spacing: Spacing.md) {
                ForEach(BoostMoment.allCases, id: \.self) { moment in
                    SelectionOptionButton(
                        emoji: moment.emoji,
                        title: moment.title,
                        isSelected: viewModel.userResponses.boostMoment == moment
                    ) {
                        viewModel.userResponses.boostMoment = moment
                        viewModel.nextStep()
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
    }
}

// MARK: - Q6 Celebration Style
struct CelebrationStyleScreen: View {
    @ObservedObject var viewModel: OnboardingFlowViewModel

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            VStack(spacing: Spacing.lg) {
                Text("how should we celebrate your wins?")
                    .font(Typography.title2)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
            }

            VStack(spacing: Spacing.md) {
                ForEach(CelebrationStyle.allCases, id: \.self) { style in
                    SelectionOptionButton(
                        emoji: style.emoji,
                        title: style.title,
                        isSelected: viewModel.userResponses.celebrationStyle == style
                    ) {
                        viewModel.userResponses.celebrationStyle = style
                        viewModel.nextStep()
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
    }
}

// MARK: - Q7 Accountability Style
struct AccountabilityStyleScreen: View {
    @ObservedObject var viewModel: OnboardingFlowViewModel

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            VStack(spacing: Spacing.lg) {
                Text("what kind of accountability feels good?")
                    .font(Typography.title2)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
            }

            VStack(spacing: Spacing.md) {
                ForEach(AccountabilityStyle.allCases, id: \.self) { style in
                    SelectionOptionButton(
                        emoji: style.emoji,
                        title: style.title,
                        isSelected: viewModel.userResponses.accountabilityStyle == style
                    ) {
                        viewModel.userResponses.accountabilityStyle = style
                        viewModel.nextStep()
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
    }
}

// MARK: - Q8 Win Signal
struct WinSignalScreen: View {
    @ObservedObject var viewModel: OnboardingFlowViewModel

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            VStack(spacing: Spacing.lg) {
                Text("what's a sign things are working?")
                    .font(Typography.title2)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
            }

            VStack(spacing: Spacing.md) {
                ForEach(WinSignal.allCases, id: \.self) { signal in
                    SelectionOptionButton(
                        emoji: signal.emoji,
                        title: signal.title,
                        isSelected: viewModel.userResponses.winSignal == signal
                    ) {
                        viewModel.userResponses.winSignal = signal
                        viewModel.nextStep()
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
    }
}

// Commitment step removed in new flow.

// MARK: - Loading Screen
struct LoadingScreen: View {
    @ObservedObject var viewModel: OnboardingFlowViewModel
    let container: DIContainer
    @State private var currentLoadingText = 0
    
    private let loadingTexts = [
        "crunching your vibe 🌈",
        "mapping your energy ⚡",
        "manifesting your best self ✨",
        "building your roadmap 🔮"
    ]
    
    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            
            // Loading animation
            VStack(spacing: Spacing.lg) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .brandPrimary))
                    .scaleEffect(2.0)
                
                Text(loadingTexts[currentLoadingText])
                    .font(Typography.title2)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut(duration: 0.5), value: currentLoadingText)
            }
            
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .onAppear {
            startLoadingSequence(container: container)
        }
    }
    
    private func startLoadingSequence(container: DIContainer) {
        var textIndex = 0
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            currentLoadingText = textIndex
            textIndex += 1
            
            if textIndex >= loadingTexts.count {
                timer.invalidate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    // Mark onboarding as complete when showing premium offer
                    viewModel.markOnboardingComplete(container: container)
                    viewModel.showPremiumOffer = true
                }
            }
        }
    }
}

// MARK: - Supporting Views
// Generic selection button used by all new multiple-choice screens
struct SelectionOptionButton: View {
    let emoji: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                Text(emoji)
                    .font(.title2)

                Text(title)
                    .font(Typography.headline)
                    .foregroundColor(isSelected ? .white : .textPrimary)

                Spacer()
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(isSelected ? Color.brandPrimary : Color.surface)
            .cornerRadius(CornerRadius.lg)
            .shadow(color: isSelected ? .brandPrimary.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EmotionOptionButton: View {
    let emotion: EmotionState
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(emotion.emoji)
                    .font(.title)
                
                Text(emotion.title)
                    .font(Typography.headline)
                    .foregroundColor(isSelected ? .white : .textPrimary)
                
                Spacer()
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(isSelected ? Color.brandPrimary : Color.surface)
            .cornerRadius(CornerRadius.lg)
            .shadow(color: isSelected ? .brandPrimary.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TimeCommitmentButton: View {
    let commitment: TimeCommitment
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(commitment.emoji)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(commitment.title)
                        .font(Typography.headline)
                        .foregroundColor(isSelected ? .white : .textPrimary)
                    
                    Text(commitment.description)
                        .font(Typography.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .textSecondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(isSelected ? Color.brandPrimary : Color.surface)
            .cornerRadius(CornerRadius.lg)
            .shadow(color: isSelected ? .brandPrimary.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct VisionOptionButton: View {
    let vision: FutureVision
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(vision.emoji)
                    .font(.title2)
                
                Text(vision.title)
                    .font(Typography.headline)
                    .foregroundColor(isSelected ? .white : .textPrimary)
                
                Spacer()
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(isSelected ? Color.brandPrimary : Color.surface)
            .cornerRadius(CornerRadius.lg)
            .shadow(color: isSelected ? .brandPrimary.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SocialProofStat: View {
    let number: String
    let label: String
    
    var body: some View {
        VStack(spacing: Spacing.xs) {
            Text(number)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.brandPrimary)
            
            Text(label)
                .font(Typography.caption)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Privacy Promise Screen
struct PrivacyPromiseScreen: View {
    @ObservedObject var viewModel: OnboardingFlowViewModel
    
    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            
            // Header
            VStack(spacing: Spacing.lg) {
                Text("🔒")
                    .font(.system(size: 60))
                
                Text("Your data stays on your phone")
                    .font(Typography.title2)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
                
                Text("UrGood works offline and nothing is shared unless you choose")
                    .font(Typography.body)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
            }
            
            // Legal Disclaimer
            VStack(spacing: Spacing.md) {
                Card {
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.warning)
                            .font(.title2)
                        
                        Text("Important Disclaimer")
                            .font(Typography.headline)
                            .foregroundColor(.textPrimary)
                        
                        Text("UrGood is not therapy or medical treatment. If you're in crisis, call 988 (US) or your local emergency services.")
                            .font(Typography.footnote)
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(Spacing.md)
                }
                .padding(.horizontal, Spacing.lg)
            }
            
            // Privacy Features
            VStack(spacing: Spacing.md) {
                PrivacyFeatureRow(
                    icon: "iphone",
                    title: "Local Storage",
                    description: "All your data stays on your device"
                )
                
                PrivacyFeatureRow(
                    icon: "wifi.slash",
                    title: "Works Offline",
                    description: "No internet? No problem"
                )
                
                PrivacyFeatureRow(
                    icon: "lock.shield",
                    title: "End-to-End Encrypted",
                    description: "Your conversations are private"
                )
            }
            .padding(.horizontal, Spacing.lg)
            
            // Data & Privacy Link
            Button(action: {
                // In a real app, this would open data privacy settings
                print("Open data privacy settings")
            }) {
                HStack(spacing: Spacing.sm) {
                    Text("Data & Privacy Settings")
                        .font(Typography.headline)
                        .foregroundColor(.brandPrimary)
                    
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.brandPrimary)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .fill(Color.brandPrimary.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.lg)
                                .stroke(Color.brandPrimary.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Continue button
            PrimaryButton("I trust UrGood ✨") {
                viewModel.nextStep()
            }
            .padding(.horizontal, Spacing.xl)
        }
        .padding(.horizontal, Spacing.lg)
    }
}

// MARK: - Privacy Feature Row
struct PrivacyFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.brandPrimary)
                .frame(width: 30)
            
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
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(Color.surface)
                .shadow(
                    color: Shadows.small.color,
                    radius: Shadows.small.radius,
                    x: Shadows.small.x,
                    y: Shadows.small.y
                )
        )
    }
}

#Preview {
    OnboardingFlowView(container: DIContainer.shared)
        .themeEnvironment()
}
