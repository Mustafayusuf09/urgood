import SwiftUI

struct LegalComplianceView: View {
    @StateObject private var legalService = LegalComplianceService()
    @Environment(\.dismiss) private var dismiss
    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var ageConfirmed = false
    @State private var termsAccepted = false
    @State private var disclaimerAcknowledged = false
    
    let onCompletion: () -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.brandPrimary)
                        
                        Text("Legal Requirements")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.textPrimary)
                        
                        Text("Please review and confirm the following before using UrGood")
                            .font(.body)
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top)
                    
                    // Age Verification
                    LegalComplianceCard(
                        title: "Age Verification",
                        icon: "person.badge.plus",
                        isCompleted: ageConfirmed
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(legalService.getAgeRequirement())
                                .font(.body)
                                .foregroundColor(.textSecondary)
                            
                            Button(action: {
                                ageConfirmed = true
                                legalService.confirmAge16Plus()
                            }) {
                                HStack {
                                    Image(systemName: ageConfirmed ? "checkmark.square.fill" : "square")
                                        .foregroundColor(ageConfirmed ? .brandPrimary : .textSecondary)
                                    
                                    Text("I confirm that I am 16 years or older")
                                        .font(.body)
                                        .foregroundColor(.textPrimary)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    // Medical Disclaimer
                    LegalComplianceCard(
                        title: "Medical Disclaimer",
                        icon: "exclamationmark.triangle.fill",
                        isCompleted: disclaimerAcknowledged,
                        accentColor: .warning
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(legalService.getMainDisclaimer())
                                .font(.body)
                                .foregroundColor(.textSecondary)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Crisis Resources:")
                                    .font(.headline)
                                    .foregroundColor(.textPrimary)
                                
                                ForEach(Array(legalService.getInternationalCrisisResources().prefix(3)), id: \.key) { key, value in
                                    HStack {
                                        Text("• \(key):")
                                            .font(.body)
                                            .foregroundColor(.textSecondary)
                                        
                                        Text(value)
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .foregroundColor(.brandPrimary)
                                        
                                        Spacer()
                                    }
                                }
                            }
                            
                            Button(action: {
                                disclaimerAcknowledged = true
                                legalService.markDisclaimerSeen()
                            }) {
                                HStack {
                                    Image(systemName: disclaimerAcknowledged ? "checkmark.square.fill" : "square")
                                        .foregroundColor(disclaimerAcknowledged ? .brandPrimary : .textSecondary)
                                    
                                    Text("I understand UrGood is not medical treatment")
                                        .font(.body)
                                        .foregroundColor(.textPrimary)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    // Terms and Privacy
                    LegalComplianceCard(
                        title: "Terms & Privacy",
                        icon: "doc.text.fill",
                        isCompleted: termsAccepted
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(legalService.getTermsAndPrivacySummary())
                                .font(.body)
                                .foregroundColor(.textSecondary)
                            
                            HStack(spacing: 16) {
                                Button("View Terms") {
                                    showTerms = true
                                }
                                .font(.body)
                                .foregroundColor(.brandPrimary)
                                
                                Button("View Privacy Policy") {
                                    showPrivacy = true
                                }
                                .font(.body)
                                .foregroundColor(.brandPrimary)
                            }
                            
                            Button(action: {
                                termsAccepted = true
                                legalService.acceptTermsAndPrivacy()
                            }) {
                                HStack {
                                    Image(systemName: termsAccepted ? "checkmark.square.fill" : "square")
                                        .foregroundColor(termsAccepted ? .brandPrimary : .textSecondary)
                                    
                                    Text("I agree to the Terms of Service and Privacy Policy")
                                        .font(.body)
                                        .foregroundColor(.textPrimary)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    // Continue Button
                    PrimaryButton("Continue to UrGood") {
                        onCompletion()
                    }
                    .disabled(!allRequirementsMet)
                    .padding(.horizontal)
                    .padding(.top)
                    
                    Spacer(minLength: 32)
                }
                .padding()
            }
            .navigationTitle("Legal Compliance")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
        }
        .sheet(isPresented: $showTerms) {
            LegalDocumentView(
                title: "Terms of Service",
                content: TermsOfService.content,
                isPresented: $showTerms
            )
        }
        .sheet(isPresented: $showPrivacy) {
            LegalDocumentView(
                title: "Privacy Policy",
                content: PrivacyPolicy.content,
                isPresented: $showPrivacy
            )
        }
    }
    
    private var allRequirementsMet: Bool {
        return ageConfirmed && disclaimerAcknowledged && termsAccepted
    }
}

// MARK: - Legal Compliance Card

struct LegalComplianceCard<Content: View>: View {
    let title: String
    let icon: String
    let isCompleted: Bool
    let accentColor: Color
    let content: () -> Content
    
    init(
        title: String,
        icon: String,
        isCompleted: Bool,
        accentColor: Color = .brandPrimary,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.isCompleted = isCompleted
        self.accentColor = accentColor
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(accentColor)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.success)
                }
            }
            
            // Content
            content()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isCompleted ? Color.success.opacity(0.3) : Color.textSecondary.opacity(0.2),
                            lineWidth: isCompleted ? 2 : 1
                        )
                )
        )
    }
}

// MARK: - Legal Document View

struct LegalDocumentView: View {
    let title: String
    let content: String
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(content)
                        .font(.body)
                        .foregroundColor(.textPrimary)
                        .padding()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

#Preview {
    LegalComplianceView {
    }
    .themeEnvironment()
}
