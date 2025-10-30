import Foundation

/// Service to handle legal compliance, disclaimers, and age verification
class LegalComplianceService: ObservableObject {
    @Published var hasAcceptedTerms = false
    @Published var hasConfirmedAge = false
    @Published var hasSeenDisclaimer = false
    
    private let userDefaults = UserDefaults.standard
    
    init() {
        loadComplianceStatus()
    }
    
    // MARK: - Age Verification
    
    func confirmAge16Plus() {
        hasConfirmedAge = true
        userDefaults.set(true, forKey: "hasConfirmedAge16Plus")
    }
    
    func isAgeVerified() -> Bool {
        return hasConfirmedAge
    }
    
    // MARK: - Terms and Privacy
    
    func acceptTermsAndPrivacy() {
        hasAcceptedTerms = true
        userDefaults.set(true, forKey: "hasAcceptedTermsAndPrivacy")
    }
    
    func hasAcceptedLegalTerms() -> Bool {
        return hasAcceptedTerms
    }
    
    // MARK: - Disclaimers
    
    func markDisclaimerSeen() {
        hasSeenDisclaimer = true
        userDefaults.set(true, forKey: "hasSeenLegalDisclaimer")
    }
    
    func needsToSeeDisclaimer() -> Bool {
        return !hasSeenDisclaimer
    }
    
    // MARK: - Legal Text Content
    
    func getMainDisclaimer() -> String {
        return "UrGood is not therapy or medical treatment. If you're in crisis, call 988 (US) or your local emergency services immediately."
    }
    
    func getOnboardingDisclaimer() -> String {
        return "UrGood provides wellness support and is not a substitute for professional mental health care, therapy, or medical treatment."
    }
    
    func getChatDisclaimer() -> String {
        return "Not therapy. For emergencies call 988 in the US or your local crisis services."
    }
    
    func getAgeRequirement() -> String {
        return "You must be 16 years or older to use UrGood. This app is designed for teens and adults and complies with age verification requirements."
    }
    
    func getTermsAndPrivacySummary() -> String {
        return "By using UrGood, you agree to our Terms of Service and Privacy Policy. Your data stays on your device and is never sold to third parties."
    }
    
    // MARK: - Crisis Resources
    
    func getInternationalCrisisResources() -> [String: String] {
        return [
            "US Crisis Line": "988",
            "US Crisis Text": "Text HOME to 741741",
            "Canada": "1-833-456-4566",
            "UK": "116 123",
            "Australia": "13 11 14",
            "International": "https://findahelpline.com",
            "Emergency Services": "911 (US) or your local emergency number"
        ]
    }
    
    func getCrisisKeywords() -> [String] {
        return [
            "suicide", "kill myself", "hurt myself", "end it", "end my life",
            "want to die", "don't want to live", "better off dead", "no reason to live",
            "self harm", "cutting", "overdose", "take pills", "jump off"
        ]
    }
    
    // MARK: - Compliance Validation
    
    func isFullyCompliant() -> Bool {
        return hasConfirmedAge && hasAcceptedTerms && hasSeenDisclaimer
    }
    
    func getComplianceStatus() -> LegalComplianceStatus {
        return LegalComplianceStatus(
            ageVerified: hasConfirmedAge,
            termsAccepted: hasAcceptedTerms,
            disclaimerSeen: hasSeenDisclaimer
        )
    }
    
    // MARK: - Private Methods
    
    private func loadComplianceStatus() {
        hasConfirmedAge = userDefaults.bool(forKey: "hasConfirmedAge16Plus")
        hasAcceptedTerms = userDefaults.bool(forKey: "hasAcceptedTermsAndPrivacy")
        hasSeenDisclaimer = userDefaults.bool(forKey: "hasSeenLegalDisclaimer")
    }
    
    func resetCompliance() {
        hasConfirmedAge = false
        hasAcceptedTerms = false
        hasSeenDisclaimer = false
        
        userDefaults.removeObject(forKey: "hasConfirmedAge16Plus")
        userDefaults.removeObject(forKey: "hasAcceptedTermsAndPrivacy")
        userDefaults.removeObject(forKey: "hasSeenLegalDisclaimer")
    }
}

// MARK: - Supporting Models

struct LegalComplianceStatus {
    let ageVerified: Bool
    let termsAccepted: Bool
    let disclaimerSeen: Bool
    
    var isComplete: Bool {
        return ageVerified && termsAccepted && disclaimerSeen
    }
}

enum LegalDocumentType {
    case termsOfService
    case privacyPolicy
    case disclaimer
    case ageVerification
    case crisisResources
}
