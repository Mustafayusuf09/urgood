import SwiftUI

struct AuthenticationView: View {
    let container: DIContainer
    @Environment(\.dismiss) private var dismiss
    @State private var showSignUp = false
    @State private var showSignIn = false
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var isLocalLoading = false
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Logo and welcome text
                VStack(spacing: 20) {
                    Text("urgood")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Join thousands of people building better habits")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                
                // Authentication options
                VStack(spacing: 16) {
                    // Apple Sign In - Custom button that calls the auth service directly
                    Button(action: {
                        handleAppleSignIn()
                    }) {
                        HStack {
                            Image(systemName: "applelogo")
                                .font(.title3)
                            Text("Sign in with Apple")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                    .disabled(isLocalLoading || container.unifiedAuthService.isLoading)
                    
                    // Email Sign Up
                    Button("Continue with Email") {
                        showSignUp = true
                    }
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(red: 1.0, green: 0.73, blue: 0.59))
                    .cornerRadius(12)
                    .shadow(color: Color(red: 1.0, green: 0.73, blue: 0.59).opacity(0.4), radius: 10, x: 0, y: 5)
                    .disabled(isLocalLoading || container.unifiedAuthService.isLoading)
                    
                    // Sign In Link
                    Button("Already have an account? Sign In") {
                        showSignIn = true
                    }
                    .font(.body)
                    .foregroundColor(.secondary)
                    .disabled(isLocalLoading || container.unifiedAuthService.isLoading)
                }
                .padding(.horizontal, 40)
                
                Spacer()
            }
            .padding()
            
            // Loading overlay - use local loading state for better control
            if isLocalLoading || container.unifiedAuthService.isLoading {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 1.0, green: 0.73, blue: 0.59)))
                    
                    Text("Signing you in...")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }
        }
        .sheet(isPresented: $showSignUp) {
            EmailSignUpView(container: container, onSuccess: {
                showSignUp = false
                dismiss()
            })
        }
        .sheet(isPresented: $showSignIn) {
            EmailSignInView(container: container, onSuccess: {
                showSignIn = false
                dismiss()
            })
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onChange(of: container.unifiedAuthService.isAuthenticated) { isAuthenticated in
            // Close any open sheets when authentication succeeds
            if isAuthenticated {
                showSignIn = false
                showSignUp = false
                // Dismiss will be handled by ContentView's transition
            }
        }
        .onReceive(container.$isAuthenticationStateChanged) { _ in
            // Also listen to container's auth state change signal
            guard container.unifiedAuthService.isAuthenticated else { return }
            showSignIn = false
            showSignUp = false
        }
    }
    
    private func handleAppleSignIn() {
        Task {
            await MainActor.run {
                isLocalLoading = true
            }
            
            do {
                try await container.unifiedAuthService.signInWithApple()
                await MainActor.run {
                    isLocalLoading = false
                }
            } catch {
                await MainActor.run {
                    isLocalLoading = false
                    
                    // Don't show error if user cancelled or sign-in already in progress
                    if let authError = error as? UnifiedAuthError {
                        switch authError {
                        case .userCancelled:
                            // Silently handle cancellation
                            return
                        case .signInInProgress:
                            // Silently handle duplicate attempts
                            return
                        default:
                            break
                        }
                    }
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Email Sign Up View
struct EmailSignUpView: View {
    let container: DIContainer
    let onSuccess: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var isLocalLoading = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.white
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 16) {
                        Text("Create Account")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("Start your journey to better habits")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    
                    // Form
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                            
                            TextField("Enter your name", text: $name)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.words)
                                .disabled(isLocalLoading || container.unifiedAuthService.isLoading)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                            
                            TextField("Enter your email", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disabled(isLocalLoading || container.unifiedAuthService.isLoading)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                            
                            SecureField("Enter your password", text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .disabled(isLocalLoading || container.unifiedAuthService.isLoading)
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    Spacer()
                    
                    // Sign Up Button
                    Button("Create Account") {
                        Task {
                            await signUp()
                        }
                    }
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(red: 1.0, green: 0.73, blue: 0.59))
                    .cornerRadius(12)
                    .shadow(color: Color(red: 1.0, green: 0.73, blue: 0.59).opacity(0.4), radius: 10, x: 0, y: 5)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                    .disabled(isLocalLoading || container.unifiedAuthService.isLoading || email.isEmpty || password.isEmpty || name.isEmpty)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                    .disabled(isLocalLoading || container.unifiedAuthService.isLoading)
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func signUp() async {
        await MainActor.run {
            isLocalLoading = true
        }
        do {
            try await container.unifiedAuthService.signUpWithEmail(email: email, password: password, displayName: name)
            await MainActor.run {
                isLocalLoading = false
                onSuccess()
            }
        } catch {
            await MainActor.run {
                isLocalLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Email Sign In View
struct EmailSignInView: View {
    let container: DIContainer
    let onSuccess: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var isLocalLoading = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.white
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 16) {
                        Text("Welcome Back")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("Sign in to continue your journey")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    
                    // Form
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                            
                            TextField("Enter your email", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disabled(isLocalLoading || container.unifiedAuthService.isLoading)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                            
                            SecureField("Enter your password", text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .disabled(isLocalLoading || container.unifiedAuthService.isLoading)
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    Spacer()
                    
                    // Sign In Button
                    Button("Sign In") {
                        Task {
                            await signIn()
                        }
                    }
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(red: 1.0, green: 0.73, blue: 0.59))
                    .cornerRadius(12)
                    .shadow(color: Color(red: 1.0, green: 0.73, blue: 0.59).opacity(0.4), radius: 10, x: 0, y: 5)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                    .disabled(isLocalLoading || container.unifiedAuthService.isLoading || email.isEmpty || password.isEmpty)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                    .disabled(isLocalLoading || container.unifiedAuthService.isLoading)
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func signIn() async {
        await MainActor.run {
            isLocalLoading = true
        }
        do {
            try await container.unifiedAuthService.signInWithEmail(email: email, password: password)
            await MainActor.run {
                isLocalLoading = false
                onSuccess()
            }
        } catch {
            await MainActor.run {
                isLocalLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

#Preview {
    AuthenticationView(container: DIContainer.shared)
        .preferredColorScheme(.dark)
}
