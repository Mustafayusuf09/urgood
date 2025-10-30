//
//  DiagnosticView.swift
//  urgood
//
//  Diagnostic tool to debug white screen issues
//

import SwiftUI
import FirebaseCore

struct DiagnosticView: View {
    @State private var testResults: [TestResult] = []
    @State private var currentTest = 0
    @State private var isRunning = false
    
    struct TestResult {
        let name: String
        let passed: Bool
        let message: String
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "stethoscope")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("App Diagnostics")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Testing app initialization and routing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                // Test Results
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(testResults.indices, id: \.self) { index in
                            HStack {
                                Image(systemName: testResults[index].passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(testResults[index].passed ? .green : .red)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(testResults[index].name)
                                        .font(.headline)
                                    
                                    Text(testResults[index].message)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Actions
                VStack(spacing: 12) {
                    if isRunning {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("Running test \(currentTest) of 7...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if testResults.isEmpty {
                        Button("Run Diagnostics") {
                            runAllTests()
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                        .padding(.horizontal)
                    } else {
                        VStack(spacing: 12) {
                            let passed = testResults.filter { $0.passed }.count
                            let total = testResults.count
                            
                            Text("\(passed)/\(total) tests passed")
                                .font(.headline)
                                .foregroundColor(passed == total ? .green : .orange)
                            
                            HStack(spacing: 12) {
                                Button("Run Again") {
                                    testResults = []
                                    runAllTests()
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                                
                                if passed == total {
                                    NavigationLink(destination: SafeContentView()) {
                                        Text("Load App")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Color.green)
                                            .cornerRadius(10)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .navigationBarHidden(true)
        }
    }
    
    private func runAllTests() {
        isRunning = true
        testResults = []
        currentTest = 0
        
        Task {
            // Test 1: Basic SwiftUI rendering
            await runTest(name: "SwiftUI Rendering") {
                return true
            }
            
            // Test 2: Firebase initialization
            await runTest(name: "Firebase Configuration") {
                FirebaseConfig.configure()
                return FirebaseApp.app() != nil
            }
            
            // Test 3: Voice chat configuration
            await runTest(name: "Voice Chat Configuration") {
                return APIConfig.isConfigured
            }
            
            // Test 4: Auth service status
            await runTest(name: "Auth Service") {
                let container = DIContainer.shared
                let isConfigured = DevelopmentConfig.bypassAuthentication
                let authStatus = container.authService.isAuthenticated
                return isConfigured == authStatus
            }
            
            // Test 5: LocalStore
            await runTest(name: "Local Storage") {
                let container = DIContainer.shared
                return container.localStore.hasCompletedFirstRun
            }
            
            // Test 6: Theme environment
            await runTest(name: "Theme System") {
                _ = Color.brandPrimary
                _ = Color.background
                return true
            }
            
            // Test 7: Routing conditions
            await runTest(name: "Routing Logic") {
                let container = DIContainer.shared
                let authenticated = container.authService.isAuthenticated
                let firstRun = container.localStore.hasCompletedFirstRun
                
                // At least one path should be available
                return authenticated || !firstRun
            }
            
            isRunning = false
        }
    }
    
    private func runTest(name: String, test: @escaping () throws -> Bool) async {
        currentTest += 1
        
        // Small delay to show progress
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        let passed: Bool
        let message: String
        
        do {
            passed = try test()
            message = passed ? "✓ Passed" : "✗ Failed"
        } catch {
            passed = false
            message = "Error: \(error.localizedDescription)"
        }
        
        _ = await MainActor.run {
            testResults.append(TestResult(name: name, passed: passed, message: message))
        }
    }
}

#Preview {
    DiagnosticView()
}
