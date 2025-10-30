import SwiftUI

class OnboardingFlowViewModel: ObservableObject {
    @Published var currentStep: OnboardingStep = .checkInSpark
    @Published var userResponses = OnboardingUserResponses()
    @Published var showPremiumOffer = false
    @Published var vibeScore: Double = 0.0
    @Published var hypeMomentsUnlocked: [OnboardingHypeMoment] = []
    
    func nextStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if let currentIndex = OnboardingStep.allCases.firstIndex(of: currentStep),
               currentIndex + 1 < OnboardingStep.allCases.count {
                let next = OnboardingStep.allCases[currentIndex + 1]
                currentStep = next
                logInteraction(for: next)
            }
        }
    }
    
    func previousStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if let currentIndex = OnboardingStep.allCases.firstIndex(of: currentStep),
               currentIndex > 0 {
                currentStep = OnboardingStep.allCases[currentIndex - 1]
            }
        }
    }
    
    func reset() {
        currentStep = .checkInSpark
        userResponses = OnboardingUserResponses()
        showPremiumOffer = false
        vibeScore = 0.0
        hypeMomentsUnlocked = []
    }
    
    @MainActor
    func markOnboardingComplete(container: DIContainer) {
        container.localStore.markOnboardingComplete()
    }

    func logInteraction(for step: OnboardingStep) {
        vibeScore = min(vibeScore + step.hypeValue, OnboardingHypeMoment.maxVibeScore)
        if let moment = OnboardingHypeMoment(step: step), hypeMomentsUnlocked.contains(where: { $0.id == moment.id }) == false {
            hypeMomentsUnlocked.append(moment)
        }
    }
}

// MARK: - Onboarding Steps
enum OnboardingStep: Int, CaseIterable {
    case checkInSpark = 0
    case energyCheck = 1
    case supportTone = 2
    case focusPriority = 3
    case boostMoment = 4
    case celebrationStyle = 5
    case accountabilityStyle = 6
    case winSignal = 7
    case privacyPromise = 8
    case loading = 9

    var hypeValue: Double {
        switch self {
        case .checkInSpark: return 9
        case .energyCheck: return 8
        case .supportTone: return 8
        case .focusPriority: return 9
        case .boostMoment: return 7
        case .celebrationStyle: return 7
        case .accountabilityStyle: return 7
        case .winSignal: return 8
        case .privacyPromise: return 5
        case .loading: return 2
        }
    }
}

// MARK: - User Response Models
struct OnboardingUserResponses {
    var checkInSpark: CheckInSpark?
    var energyCheck: EnergyCheck?
    var supportTone: SupportTonePreference?
    var focusPriority: FocusPriority?
    var boostMoment: BoostMoment?
    var celebrationStyle: CelebrationStyle?
    var accountabilityStyle: AccountabilityStyle?
    var winSignal: WinSignal?

    init(
        checkInSpark: CheckInSpark? = nil,
        energyCheck: EnergyCheck? = nil,
        supportTone: SupportTonePreference? = nil,
        focusPriority: FocusPriority? = nil,
        boostMoment: BoostMoment? = nil,
        celebrationStyle: CelebrationStyle? = nil,
        accountabilityStyle: AccountabilityStyle? = nil,
        winSignal: WinSignal? = nil
    ) {
        self.checkInSpark = checkInSpark
        self.energyCheck = energyCheck
        self.supportTone = supportTone
        self.focusPriority = focusPriority
        self.boostMoment = boostMoment
        self.celebrationStyle = celebrationStyle
        self.accountabilityStyle = accountabilityStyle
        self.winSignal = winSignal
    }
    
    var isComplete: Bool {
        return checkInSpark != nil &&
               energyCheck != nil &&
               supportTone != nil &&
               focusPriority != nil &&
               boostMoment != nil &&
               celebrationStyle != nil &&
               accountabilityStyle != nil &&
               winSignal != nil
    }
}

// MARK: - Goal Categories
// Onboarding enums with display metadata live in Models.swift.

// MARK: - Hype Moments

struct OnboardingHypeMoment: Identifiable, Hashable {
    static let maxVibeScore: Double = 70

    let id: OnboardingStep
    let emoji: String
    let title: String
    let description: String

    init?(step: OnboardingStep) {
        self.id = step
        switch step {
        case .checkInSpark:
            self.emoji = "✨"
            self.title = "Spark locked in"
            self.description = "We know exactly why you popped in."
        case .energyCheck:
            self.emoji = "🔋"
            self.title = "Energy mapped"
            self.description = "Your current vibe is on our radar."
        case .supportTone:
            self.emoji = "🎧"
            self.title = "Tone dialed"
            self.description = "Support style set to your liking."
        case .focusPriority:
            self.emoji = "🎯"
            self.title = "Focus spotlight"
            self.description = "Your first priority is front and center."
        case .boostMoment:
            self.emoji = "⏰"
            self.title = "Boost timing set"
            self.description = "We'll show up right when you like it."
        case .celebrationStyle:
            self.emoji = "🎉"
            self.title = "Celebration style"
            self.description = "We know how to cheer you on."
        case .accountabilityStyle:
            self.emoji = "🤝"
            self.title = "Accountability vibe"
            self.description = "We'll keep pace the way you prefer."
        case .winSignal:
            self.emoji = "🏅"
            self.title = "Win signal set"
            self.description = "We know the signs you're thriving."
        case .privacyPromise:
            self.emoji = "🔒"
            self.title = "Privacy promise"
            self.description = "Your data stays on your phone, always."
        case .loading:
            self.emoji = "⚡️"
            self.title = "Personalizing"
            self.description = "Coach is tailoring your dashboard."
        }
    }
}

