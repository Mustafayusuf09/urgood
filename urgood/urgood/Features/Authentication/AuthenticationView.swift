import SwiftUI
import Combine
import AuthenticationServices

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
            // Beautiful gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.1, blue: 0.2),   // Dark blue
                    Color(red: 0.1, green: 0.2, blue: 0.4),    // Medium dark blue
                    Color(red: 0.15, green: 0.3, blue: 0.6)    // Medium blue
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Logo and welcome text
                VStack(spacing: 20) {
                    Text("urgood")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    
                    Text("Join thousands of people building better habits")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                
                // Authentication options
                VStack(spacing: 16) {
                    // Apple Sign In
                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            handleAppleSignIn(result)
                        }
                    )
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .cornerRadius(12)
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
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: .blue.opacity(0.4), radius: 10, x: 0, y: 5)
                    .disabled(isLocalLoading || container.unifiedAuthService.isLoading)
                    
                    // Sign In Link
                    Button("Already have an account? Sign In") {
                        showSignIn = true
                    }
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .disabled(isLocalLoading || container.unifiedAuthService.isLoading)
                }
                .padding(.horizontal, 40)
                
                Spacer()
            }
            .padding()
            
            // Loading overlay - use local loading state for better control
            if isLocalLoading || container.unifiedAuthService.isLoading {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    
                    Text("Signing you in...")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
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
        .onReceive(container.$isAuthenticationStateChanged) { _ in
            guard container.unifiedAuthService.isAuthenticated else { return }
            showSignIn = false
            showSignUp = false
            dismiss()
        }
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        Task {
            await MainActor.run {
                isLocalLoading = true
            }
            
            do {
                try await container.unifiedAuthService.signInWithApple()
                await MainActor.run {
                    isLocalLoading = false
                    dismiss()
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
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.1, blue: 0.2),
                        Color(red: 0.1, green: 0.2, blue: 0.4)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 16) {
                        Text("Create Account")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Start your journey to better habits")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    
                    // Form
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                            
                            TextField("Enter your name", text: $name)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.words)
                                .disabled(isLocalLoading || container.unifiedAuthService.isLoading)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                            
                            TextField("Enter your email", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disabled(isLocalLoading || container.unifiedAuthService.isLoading)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                            
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
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: .blue.opacity(0.4), radius: 10, x: 0, y: 5)
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
                    .foregroundColor(.white)
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
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.1, blue: 0.2),
                        Color(red: 0.1, green: 0.2, blue: 0.4)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 16) {
                        Text("Welcome Back")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Sign in to continue your journey")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    
                    // Form
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                            
                            TextField("Enter your email", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disabled(isLocalLoading || container.unifiedAuthService.isLoading)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                            
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
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: .blue.opacity(0.4), radius: 10, x: 0, y: 5)
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
                    .foregroundColor(.white)
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
