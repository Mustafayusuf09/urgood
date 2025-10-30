import SwiftUI

/// Debug view to display and validate app configuration
/// Only available in development builds
struct ConfigurationDebugView: View {
    @StateObject private var validationService = ConfigurationValidationService.shared
    @State private var selectedCategory: ConfigurationValidationService.ValidationIssue.Category?
    
    var body: some View {
        NavigationView {
            List {
                // Environment Information
                Section("Environment") {
                    InfoRow(title: "Mode", value: EnvironmentConfig.isProduction ? "Production" : "Development")
                    InfoRow(title: "Backend URL", value: EnvironmentConfig.backendURL)
                    InfoRow(title: "Firebase Functions", value: EnvironmentConfig.firebaseFunctionsURL)
                    InfoRow(title: "Bundle ID", value: EnvironmentConfig.App.bundleId)
                    InfoRow(title: "Version", value: "\(EnvironmentConfig.App.version) (\(EnvironmentConfig.App.buildNumber))")
                }
                
                // Feature Flags
                Section("Features") {
                    FeatureRow(title: "Voice Chat", enabled: EnvironmentConfig.Features.voiceChatEnabled)
                    FeatureRow(title: "Crisis Detection", enabled: EnvironmentConfig.Features.crisisDetectionEnabled)
                    FeatureRow(title: "Analytics", enabled: EnvironmentConfig.Features.analyticsEnabled)
                    FeatureRow(title: "Debug Mode", enabled: EnvironmentConfig.Features.debugModeEnabled)
                    FeatureRow(title: "Beta Features", enabled: EnvironmentConfig.Features.betaFeaturesEnabled)
                    FeatureRow(title: "Offline Mode", enabled: EnvironmentConfig.Features.offlineModeEnabled)
                }
                
                // API Configuration
                Section("API Configuration") {
                    InfoRow(title: "OpenAI Base URL", value: EnvironmentConfig.ExternalServices.openAIBaseURL)
                    InfoRow(title: "ElevenLabs Base URL", value: EnvironmentConfig.ExternalServices.elevenLabsBaseURL)
                    InfoRow(title: "Request Timeout", value: "\(EnvironmentConfig.Network.requestTimeout)s")
                    InfoRow(title: "Retry Attempts", value: "\(EnvironmentConfig.Network.retryAttempts)")
                }
                
                // Validation Results
                if let results = validationService.validationResults {
                    Section("Validation Results") {
                        HStack {
                            Image(systemName: results.isValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(results.isValid ? .green : .red)
                            Text(results.isValid ? "Configuration Valid" : "Configuration Issues Found")
                                .fontWeight(.medium)
                            Spacer()
                            Text(formatDate(results.timestamp))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if !results.errors.isEmpty {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                Text("\(results.errors.count) Error\(results.errors.count == 1 ? "" : "s")")
                                Spacer()
                            }
                        }
                        
                        if !results.warnings.isEmpty {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("\(results.warnings.count) Warning\(results.warnings.count == 1 ? "" : "s")")
                                Spacer()
                            }
                        }
                    }
                    
                    // Issues by Category
                    let issuesByCategory = validationService.getIssuesByCategory()
                    if !issuesByCategory.isEmpty {
                        Section("Issues by Category") {
                            ForEach(Array(issuesByCategory.keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { category in
                                NavigationLink(destination: CategoryIssuesView(category: category, issues: issuesByCategory[category] ?? [])) {
                                    HStack {
                                        Image(systemName: iconForCategory(category))
                                            .foregroundColor(colorForCategory(category, issues: issuesByCategory[category] ?? []))
                                        Text(category.rawValue)
                                        Spacer()
                                        Text("\(issuesByCategory[category]?.count ?? 0)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Development Tools
                if EnvironmentConfig.isDevelopment {
                    Section("Development Tools") {
                        Button("Validate Configuration") {
                            Task {
                                await validationService.validateConfiguration()
                            }
                        }
                        .disabled(validationService.isValidating)
                        
                        Button("Print Configuration") {
                            EnvironmentConfig.printConfiguration()
                        }
                        
                        Button("Test Network Connectivity") {
                            testNetworkConnectivity()
                        }
                        
                        Button("Clear Configuration Cache") {
                            // Clear any cached configuration
                            UserDefaults.standard.removeObject(forKey: "cached_config")
                        }
                    }
                }
            }
            .navigationTitle("Configuration")
            .refreshable {
                await validationService.validateConfiguration()
            }
        }
        .task {
            if validationService.validationResults == nil {
                await validationService.validateConfiguration()
            }
        }
    }
    
    // MARK: - Helper Views
    
    private struct InfoRow: View {
        let title: String
        let value: String
        
        var body: some View {
            HStack {
                Text(title)
                Spacer()
                Text(value)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
    
    private struct FeatureRow: View {
        let title: String
        let enabled: Bool
        
        var body: some View {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: enabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(enabled ? .green : .red)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    private func iconForCategory(_ category: ConfigurationValidationService.ValidationIssue.Category) -> String {
        switch category {
        case .network:
            return "network"
        case .authentication:
            return "person.badge.key"
        case .configuration:
            return "gearshape"
        case .permissions:
            return "lock"
        case .services:
            return "server.rack"
        case .security:
            return "shield"
        }
    }
    
    private func colorForCategory(_ category: ConfigurationValidationService.ValidationIssue.Category, issues: [ConfigurationValidationService.ValidationIssue]) -> Color {
        let hasErrors = issues.contains { $0.severity == .error }
        let hasWarnings = issues.contains { $0.severity == .warning }
        
        if hasErrors {
            return .red
        } else if hasWarnings {
            return .orange
        } else {
            return .green
        }
    }
    
    private func testNetworkConnectivity() {
        Task {
            do {
                let url = URL(string: EnvironmentConfig.Endpoints.health)!
                let (_, response) = try await URLSession.shared.data(from: url)
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("🌐 Network test: \(httpResponse.statusCode)")
                }
            } catch {
                print("❌ Network test failed: \(error)")
            }
        }
    }
}

// MARK: - Category Issues View

private struct CategoryIssuesView: View {
    let category: ConfigurationValidationService.ValidationIssue.Category
    let issues: [ConfigurationValidationService.ValidationIssue]
    
    var body: some View {
        List {
            ForEach(issues.indices, id: \.self) { index in
                let issue = issues[index]
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: issue.severity == .error ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(issue.severity == .error ? .red : .orange)
                        
                        Text(issue.severity.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(issue.severity == .error ? .red : .orange)
                        
                        Spacer()
                    }
                    
                    Text(issue.message)
                        .font(.body)
                    
                    if let suggestion = issue.suggestion {
                        Text(suggestion)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle(category.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#if DEBUG
struct ConfigurationDebugView_Previews: PreviewProvider {
    static var previews: some View {
        ConfigurationDebugView()
    }
}
#endif
