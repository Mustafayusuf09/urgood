import Foundation
import FirebaseAuth
import AuthenticationServices
import CryptoKit
import os.log
import UIKit

private let log = Logger(subsystem: "com.urgood.urgood", category: "ProductionAuth")

@MainActor
final class ProductionAuthService: ObservableObject, AuthServiceProtocol {
    @Published var isAuthenticated = false
    @Published private var _currentUser: ProductionUser?
    
    var currentUser: Any? {
        return _currentUser
    }
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Development mode - set to true to bypass authentication
    private let developmentMode = DevelopmentConfig.bypassAuthentication
    
    private var currentNonce: String?
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    // Keep controller + delegate alive during the flow
    private var appleController: ASAuthorizationController?
    private var appleDelegate: ProductionAppleSignInDelegate?
    
    // Guard to prevent multiple simultaneous sign-in attempts
    private var isSigningIn = false
    
    struct ProductionUser {
        let id: String
        let email: String?
        let name: String?
        let authProvider: AuthProvider
        let createdAt: Date
        let isEmailVerified: Bool
    }
    
    enum AuthProvider: String, CaseIterable {
        case apple = "apple.com"
        case email = "password"
    }
    
    init() {
        if developmentMode {
            // Auto-authenticate in development mode
            isAuthenticated = true
            _currentUser = ProductionUser(
                id: "dev-user-123",
                email: "dev@urgood.com",
                name: "Development User",
                authProvider: .email,
                createdAt: Date(),
                isEmailVerified: true
            )
            log.info("🔧 Development mode: Auto-authenticated user")
        } else {
            // Production mode - clear any cached development users
            print("🚀 Production mode: Clearing any cached authentication state")
            
            // Listen for auth state changes
            authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
                Task { @MainActor in
                    self?.updateAuthState(user: user)
                }
            }
            
            // Check current Firebase auth state
            if let currentUser = Auth.auth().currentUser {
                print("🔍 Found existing Firebase user: \(currentUser.email ?? "no-email")")
                updateAuthState(user: currentUser)
            } else {
                print("🔍 No existing Firebase user found")
                updateAuthState(user: nil)
            }
        }
    }
    
    // MARK: - Apple Sign In
    
    func signInWithApple() async throws {
        // Guard against multiple simultaneous sign-in attempts
        guard !isSigningIn else {
            log.info("🍎 Apple Sign In already in progress, ignoring duplicate request")
            throw ProductionAuthError.signInInProgress
        }
        
        if developmentMode {
            // Simulate successful Apple Sign In in development mode
            isAuthenticated = true
            _currentUser = ProductionUser(
                id: "dev-apple-user-123",
                email: "dev.apple@urgood.com",
                name: "Apple Dev User",
                authProvider: .apple,
                createdAt: Date(),
                isEmailVerified: true
            )
            return
        }
        
        isSigningIn = true
        isLoading = true
        errorMessage = nil
        
        log.info("🍎 Starting Apple Sign In flow")
        
        // Add timeout to reset loading state if sign-in hangs
        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            await MainActor.run {
                if self.isLoading {
                    self.isLoading = false
                    self.errorMessage = "Sign in timed out. Please try again."
                    log.error("❌ Apple Sign In timed out after 30 seconds")
                }
            }
        }
        
        defer {
            timeoutTask.cancel()
            isSigningIn = false
            log.info("🍎 Apple Sign In flow completed, resetting guard")
        }
        
        let nonce: String
        do {
            nonce = try SecureNonceGenerator.randomNonce()
        } catch {
            isLoading = false
            isSigningIn = false
            errorMessage = "Unable to prepare Apple Sign In. Please try again."
            log.error("🍎 Failed to generate nonce: \(error.localizedDescription)")
            throw ProductionAuthError.nonceGenerationFailed
        }
        currentNonce = nonce
        
        guard let anchorWindow = WindowProvider.activeWindow() else {
            isLoading = false
            isSigningIn = false
            errorMessage = "App window unavailable for Apple Sign In. Please ensure the app is active."
            log.error("🍎 No anchor window available for Apple Sign In")
            throw ProductionAuthError.presentationAnchorUnavailable
        }
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        // Use continuation to properly await the Apple Sign In flow
        log.info("🍎 Setting up Apple Sign In controller and delegate")
        
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let authorizationController = ASAuthorizationController(authorizationRequests: [request])
                
                // Create delegate with completion handler
                appleDelegate = ProductionAppleSignInDelegate(anchorWindow: anchorWindow) { [weak self] result in
                    log.info("🍎 Apple Sign In delegate callback received")
                    
                    Task { @MainActor in
                        guard let self else {
                            log.error("🍎 Self was deallocated during Apple Sign In")
                            continuation.resume(throwing: ProductionAuthError.userNotFound)
                            return
                        }
                        
                        do {
                            try await self.handleAppleSignInResult(result)
                            log.info("🍎 Apple Sign In result handled successfully")
                            continuation.resume()
                        } catch {
                            log.error("🍎 Error handling Apple Sign In result: \(error.localizedDescription)")
                            continuation.resume(throwing: error)
                        }
                    }
                }
                
                authorizationController.delegate = appleDelegate
                authorizationController.presentationContextProvider = appleDelegate
                appleController = authorizationController
                
                log.info("🍎 Performing Apple Sign In requests")
                authorizationController.performRequests()
            }
            
            // Ensure loading state is reset on success
            log.info("🍎 Apple Sign In flow completed successfully, resetting loading state")
            isLoading = false
        } catch {
            // Ensure loading state is reset on error
            log.error("🍎 Apple Sign In flow failed: \(error.localizedDescription), resetting loading state")
            isLoading = false
            throw error
        }
    }
    
    // MARK: - Email/Password Authentication
    
    func signUp(email: String, password: String, name: String) async throws {
        if developmentMode {
            // Simulate successful sign up in development mode
            isAuthenticated = true
            _currentUser = ProductionUser(
                id: "dev-email-user-123",
                email: email,
                name: name,
                authProvider: .email,
                createdAt: Date(),
                isEmailVerified: false
            )
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            
            // Update display name
            let changeRequest = authResult.user.createProfileChangeRequest()
            changeRequest.displayName = name
            try await changeRequest.commitChanges()
            
            // Send email verification
            try await authResult.user.sendEmailVerification()
            
            updateAuthState(user: authResult.user)
            
            FirebaseConfig.logEvent("user_signed_up", parameters: [
                "method": "email",
                "email_verified": false
            ])
            
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            throw error
        }
    }
    
    func signIn(email: String, password: String) async throws {
        if developmentMode {
            // Simulate successful sign in in development mode
            isAuthenticated = true
            _currentUser = ProductionUser(
                id: "dev-email-user-123",
                email: email,
                name: "Dev User",
                authProvider: .email,
                createdAt: Date(),
                isEmailVerified: true
            )
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            updateAuthState(user: authResult.user)
            
            FirebaseConfig.logEvent("user_signed_in", parameters: [
                "method": "email",
                "email_verified": authResult.user.isEmailVerified
            ])
            
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            throw error
        }
    }
    
    func signOut() async throws {
        if developmentMode {
            isAuthenticated = false
            _currentUser = nil
            return
        }
        
        try Auth.auth().signOut()
        isAuthenticated = false
        _currentUser = nil
        
        FirebaseConfig.logEvent("user_signed_out", parameters: [:])
        print("🚀 Production mode: User signed out successfully")
    }
    
    /// Force clear all authentication state - useful for clearing development data
    func forceSignOut() async throws {
        print("🧹 Force clearing all authentication state...")
        
        // Sign out from Firebase
        try Auth.auth().signOut()
        
        // Clear local state
        isAuthenticated = false
        _currentUser = nil
        
        print("✅ All authentication state cleared")
    }
    
    func resetPassword(email: String) async throws {
        if developmentMode {
            print("🔧 Development mode: Simulating password reset email sent")
            return
        }
        
        try await Auth.auth().sendPasswordReset(withEmail: email)
        FirebaseConfig.logEvent("password_reset_requested", parameters: [:])
    }
    
    func resendEmailVerification() async throws {
        if developmentMode {
            print("🔧 Development mode: Simulating email verification sent")
            return
        }
        
        guard let user = Auth.auth().currentUser else {
            throw AuthError.userNotFound
        }
        
        try await user.sendEmailVerification()
        FirebaseConfig.logEvent("email_verification_resent", parameters: [:])
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    // MARK: - Private Methods
    
    private func updateAuthState(user: FirebaseAuth.User?) {
        if let user = user {
            isAuthenticated = true
            _currentUser = ProductionUser(
                id: user.uid,
                email: user.email,
                name: user.displayName,
                authProvider: mapAuthProvider(from: user),
                createdAt: user.metadata.creationDate ?? Date(),
                isEmailVerified: user.isEmailVerified
            )
            
            log.info("✅ User authenticated: \(user.uid)")
        } else {
            isAuthenticated = false
            _currentUser = nil
            log.info("❌ User signed out")
        }
    }
    
    private func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) async throws {
        log.info("🍎 Handling Apple Sign In result")
        
        switch result {
        case .success(let authorization):
            log.info("🍎 Apple Sign In authorization successful")
            
            defer {
                log.info("🍎 Cleaning up Apple Sign In controller and delegate")
                appleController = nil
                appleDelegate = nil
                currentNonce = nil
            }
            
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Invalid Apple ID credential"
                log.error("❌ Apple Sign In failed: Invalid credential")
                throw ProductionAuthError.invalidCredentials
            }
            
            guard let nonce = currentNonce else {
                errorMessage = "Invalid state: A login callback was received, but no login request was sent."
                log.error("❌ Apple Sign In failed: Missing nonce")
                throw ProductionAuthError.invalidCredentials
            }
            
            guard let appleIDToken = appleIDCredential.identityToken,
                  let identityToken = String(data: appleIDToken, encoding: .utf8) else {
                errorMessage = "Unable to fetch identity token"
                log.error("❌ Apple Sign In failed: Missing identity token")
                throw ProductionAuthError.invalidCredentials
            }
            
            guard let authorizationCodeData = appleIDCredential.authorizationCode,
                  let authorizationCode = String(data: authorizationCodeData, encoding: .utf8) else {
                errorMessage = "Unable to fetch authorization code"
                log.error("❌ Apple Sign In failed: Missing authorization code")
                throw ProductionAuthError.invalidCredentials
            }
            
            do {
                let credential = OAuthProvider.appleCredential(
                    withIDToken: identityToken,
                    rawNonce: nonce,
                    fullName: appleIDCredential.fullName
                )
                
                let authResult = try await Auth.auth().signIn(with: credential)
                updateAuthState(user: authResult.user)
                errorMessage = nil
                
                FirebaseConfig.logEvent("user_signed_in", parameters: [
                    "method": "apple",
                    "email_verified": authResult.user.isEmailVerified
                ])
                
                let resolvedEmail = appleIDCredential.email ?? authResult.user.email
                let resolvedName = formattedFullName(from: appleIDCredential.fullName) ?? authResult.user.displayName
                
                // Backend authentication - with proper error handling
                do {
                    try await authenticateWithBackend(
                        identityToken: identityToken,
                        authorizationCode: authorizationCode,
                        email: resolvedEmail,
                        name: resolvedName
                    )
                } catch {
                    log.error("🍎 Backend authentication failed: \(error.localizedDescription, privacy: .public)")
                    // Continue with Firebase auth even if backend fails
                    // This ensures users can still sign in if backend is temporarily unavailable
                }
                
                log.info("🍎 Setting user as authenticated")
                isAuthenticated = true
                log.info("✅ Apple Sign In successful for user: \(authResult.user.uid, privacy: .public)")
            } catch {
                errorMessage = "Unable to sign in with Apple. Please try again."
                log.error("❌ Firebase Apple Sign In failed: \(error.localizedDescription, privacy: .public)")
                throw error
            }
            
        case .failure(let error):
            log.error("🍎 Apple Sign In authorization failed: \(error.localizedDescription)")
            
            appleController = nil
            appleDelegate = nil
            currentNonce = nil
            
            // Check if user cancelled
            if let authError = error as? ASAuthorizationError {
                switch authError.code {
                case .canceled:
                    errorMessage = nil // Don't show error for user cancellation
                    throw ProductionAuthError.userCancelled
                case .unknown:
                    errorMessage = "Unable to sign in with Apple. Please try again."
                case .invalidResponse:
                    errorMessage = "Invalid response from Apple. Please try again."
                case .notHandled:
                    errorMessage = "Apple Sign-In not available. Please try again."
                case .failed:
                    errorMessage = "Apple Sign-In failed. Please try again."
                case .notInteractive:
                    errorMessage = "Apple Sign-In requires user interaction. Please try again."
                case .matchedExcludedCredential:
                    errorMessage = "This Apple ID is not available. Please try a different account."
                case .credentialImport:
                    errorMessage = "Unable to import credentials. Please try again."
                case .credentialExport:
                    errorMessage = "Unable to export credentials. Please try again."
                case .preferSignInWithApple:
                    errorMessage = "Please use Sign In with Apple for this account."
                case .deviceNotConfiguredForPasskeyCreation:
                    errorMessage = "Device not configured for passkey creation. Please try again."
                @unknown default:
                    errorMessage = "Unable to sign in with Apple. Please try again."
                }
            } else {
                errorMessage = error.localizedDescription
            }
            
            log.error("❌ Apple Sign In failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    private func mapAuthProvider(from user: FirebaseAuth.User) -> AuthProvider {
        if let providerID = user.providerData.first?.providerID {
            switch providerID {
            case AuthProvider.apple.rawValue:
                return .apple
            default:
                return .email
            }
        }
        return .email
    }

    private func authenticateWithBackend(identityToken: String, authorizationCode: String, email: String?, name: String?) async throws {
        guard let url = URL(string: "https://api.urgood.app/v1/auth/apple") else {
            throw ProductionAuthError.networkError
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0 // 10 second timeout

        let requestBody: [String: Any] = [
            "identityToken": identityToken,
            "authorizationCode": authorizationCode,
            "user": [
                "email": email ?? "",
                "name": name ?? ""
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        // Use Task.withTimeout to ensure the request doesn't hang indefinitely
        let (data, response) = try await withThrowingTaskGroup(of: (Data, URLResponse).self) { group in
            group.addTask {
                try await URLSession.shared.data(for: request)
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                throw ProductionAuthError.networkTimeout
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProductionAuthError.networkError
        }

        guard httpResponse.statusCode == 200 else {
            if let responseString = String(data: data, encoding: .utf8) {
                log.error("🍎 Backend authentication failed with status: \(httpResponse.statusCode, privacy: .public) response: \(responseString, privacy: .public)")
            }
            throw ProductionAuthError.networkError
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = json["success"] as? Bool, !success {
            log.error("🍎 Backend authentication response indicated failure")
            throw ProductionAuthError.networkError
        }
    }

    private func formattedFullName(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let formatter = PersonNameComponentsFormatter()
        return formatter.string(from: components)
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}

// MARK: - Apple Sign In Delegate

class ProductionAppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private weak var anchorWindow: UIWindow?
    private let completion: (Result<ASAuthorization, Error>) -> Void
    
    init(anchorWindow: UIWindow, completion: @escaping (Result<ASAuthorization, Error>) -> Void) {
        self.anchorWindow = anchorWindow
        self.completion = completion
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        completion(.success(authorization))
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion(.failure(error))
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let window = anchorWindow {
            return window
        }
        if let fallback = WindowProvider.activeWindow() {
            anchorWindow = fallback
            return fallback
        }
        log.error("🍎 ProductionAppleSignInDelegate missing window; returning empty anchor")
        return UIWindow()
    }
}

// MARK: - Production Auth Errors

enum ProductionAuthError: Error, LocalizedError, Equatable {
    case userNotFound
    case invalidCredentials
    case emailNotVerified
    case networkError
    case networkTimeout
    case nonceGenerationFailed
    case presentationAnchorUnavailable
    case userCancelled
    case signInInProgress
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User not found"
        case .invalidCredentials:
            return "Invalid email or password"
        case .emailNotVerified:
            return "Please verify your email address"
        case .networkError:
            return "Network error. Please check your connection"
        case .networkTimeout:
            return "Request timed out. Please try again"
        case .nonceGenerationFailed:
            return "Unable to securely prepare sign in. Please try again."
        case .presentationAnchorUnavailable:
            return "Unable to find a window to present Apple Sign In. Please try again when the app is active."
        case .userCancelled:
            return "Sign in was cancelled"
        case .signInInProgress:
            return "Sign in already in progress"
        }
    }
}
