import SwiftUI

struct CrisisHelpSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var acknowledged = false
    
    private let crisisDetectionService = CrisisDetectionService()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Header
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.warning)
                        
                        Text("I'm concerned about what you're sharing")
                            .font(Typography.title)
                            .foregroundColor(.textPrimary)
                            .multilineTextAlignment(.center)
                        
                        Text(crisisDetectionService.getCrisisHelpMessage())
                            .font(Typography.body)
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.lg)
                    }
                    .padding(.top, Spacing.lg)
                    
                    // Crisis resources
                    VStack(spacing: Spacing.md) {
                        Text("Get help now")
                            .font(Typography.title2)
                            .foregroundColor(.textPrimary)
                        
                        VStack(spacing: Spacing.sm) {
                            ForEach(Array(crisisDetectionService.getCrisisResources().keys.sorted()), id: \.self) { key in
                                if let value = crisisDetectionService.getCrisisResources()[key] {
                                    CrisisResourceRow(title: key, value: value)
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.md)
                    }
                    
                    // Disclaimer
                    Card {
                        VStack(spacing: Spacing.sm) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.brandPrimary)
                                .font(.title2)
                            
                            Text("Important")
                                .font(Typography.headline)
                                .foregroundColor(.textPrimary)
                            
                            Text(crisisDetectionService.getCrisisDisclaimer())
                                .font(Typography.footnote)
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    
                    // Acknowledgment
                    VStack(spacing: Spacing.md) {
                        Text("I understand this is not a substitute for professional help")
                            .font(Typography.body)
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                        
                        PrimaryButton("I'm safe, continue chatting") {
                            acknowledged = true
                            dismiss()
                        }
                        .disabled(acknowledged)
                    }
                    .padding(.horizontal, Spacing.lg)
                    
                    Spacer(minLength: Spacing.xl)
                }
                .padding(.bottom, Spacing.xl)
            }
            .navigationTitle("Crisis Help")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.textSecondary)
                }
            }
            .background(Color.background)
        }
    }
}

struct CrisisResourceRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(Typography.headline)
                    .foregroundColor(.textPrimary)
                
                Text(value)
                    .font(Typography.body)
                    .foregroundColor(.brandPrimary)
            }
            
            Spacer()
            
            if value.hasPrefix("http") {
                Button("Open") {
                    if let url = URL(string: value) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(Typography.footnote)
                .foregroundColor(.brandPrimary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .fill(Color.brandPrimary.opacity(0.1))
                )
            } else {
                Button("Call") {
                    if let url = URL(string: "tel:\(value.replacingOccurrences(of: " ", with: ""))") {
                        UIApplication.shared.open(url)
                    }
                }
                .font(Typography.footnote)
                .foregroundColor(.success)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .fill(Color.success.opacity(0.1))
                )
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .stroke(Color.textSecondary.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

#Preview {
    CrisisHelpSheet()
        .themeEnvironment()
}
