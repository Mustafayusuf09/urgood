import Foundation
import FirebaseAuth
import FirebaseFirestore
import UIKit
import AuthenticationServices
import CryptoKit
import os.log

// Import Firebase types with aliases to avoid conflicts
typealias FirebaseUserMetadata = FirebaseAuth.UserMetadata
typealias FirebaseUser = FirebaseAuth.User

private let log = Logger(subsystem: "com.urgood.urgood", category: "FirebaseAuth")

@MainActor
final class FirebaseAuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: UrGoodFirebaseUser?
    @Published var isLoading = false
    
    // Development mode - set to true to bypass authentication
    private let developmentMode = DevelopmentConfig.bypassAuthentication
    
    private var currentNonce: String?
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    // Keep controller + delegate alive during the flow
    private var appleController: ASAuthorizationController?
    private var appleDelegate: FirebaseAppleSignInDelegate?
    
    struct UrGoodFirebaseUser {
        let uid: String
        let email: String?
        let displayName: String?
        let authProvider: AuthProvider
        let isEmailVerified: Bool
        let createdAt: Date
        let lastSignInAt: Date?
        
        init(from firebaseUser: FirebaseUser) {
            self.uid = firebaseUser.uid
            self.email = firebaseUser.email
            self.displayName = firebaseUser.displayName
            self.isEmailVerified = firebaseUser.isEmailVerified
            self.createdAt = firebaseUser.metadata.creationDate ?? Date()
            self.lastSignInAt = firebaseUser.metadata.lastSignInDate
            
            // Determine auth provider
            if let providerData = firebaseUser.providerData.first {
                switch providerData.providerID {
                case "apple.com":
                    self.authProvider = .apple
                case "password":
                    self.authProvider = .email
                default:
                    self.authProvider = .email
                }
            } else {
                self.authProvider = .email
            }
        }

        init(
            uid: String,
            email: String?,
            displayName: String?,
            authProvider: AuthProvider,
            isEmailVerified: Bool,
            createdAt: Date,
            lastSignInAt: Date?
        ) {
            self.uid = uid
            self.email = email
            self.displayName = displayName
            self.authProvider = authProvider
            self.isEmailVerified = isEmailVerified
            self.createdAt = createdAt
            self.lastSignInAt = lastSignInAt
        }
    }
    
    enum AuthProvider: String, CaseIterable {
        case apple = "apple.com"
        case email = "password"
    }
    
    init() {
        setupAuthStateListener()
        
        if developmentMode {
            // Auto-authenticate in development mode
            isAuthenticated = true
            // Create a local user for development
            currentUser = UrGoodFirebaseUser(
                uid: "dev-user-123",
                email: "dev@urgood.com",
                displayName: "Development User",
                authProvider: .email,
                isEmailVerified: true,
                createdAt: Date(),
                lastSignInAt: Date()
            )
            log.info("🔧 Development mode: Auto-authenticated user")
        }
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    // MARK: - Auth State Management
    
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user = user {
                    self?.currentUser = UrGoodFirebaseUser(from: user)
                    self?.isAuthenticated = true
                    log.info("🔥 User signed in: \(user.uid)")
                    
                    // Create or update user profile in Firestore
                    await self?.createOrUpdateUserProfile(user: user)
                } else {
                    self?.currentUser = nil
                    self?.isAuthenticated = false
                    log.info("🔥 User signed out")
                }
            }
        }
    }
    
    // MARK: - Apple Sign In
    
    func signInWithApple() async throws {
        guard !developmentMode else {
            log.info("🔧 Development mode: Apple Sign In bypassed")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        log.info("🍎 Starting Apple Sign In")
        
        // Generate nonce
        let nonce: String
        do {
            nonce = try SecureNonceGenerator.randomNonce()
        } catch {
            log.error("🍎 Failed to generate nonce: \(error.localizedDescription, privacy: .public)")
            throw AuthError.nonceGenerationFailed
        }
        currentNonce = nonce
        
        guard let anchorWindow = WindowProvider.activeWindow() else {
            throw AuthError.presentationAnchorUnavailable
        }
        
        // Create Apple ID request
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        // Set up controller and delegate
        let controller = ASAuthorizationController(authorizationRequests: [request])
        self.appleController = controller
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let delegate = FirebaseAppleSignInDelegate(currentNonce: nonce, anchorWindow: anchorWindow) { [weak self] result in
                Task { @MainActor in
                    switch result {
                    case .success(let credential):
                        do {
                            try await self?.handleAppleSignInSuccess(credential: credential)
                            continuation.resume()
                        } catch {
                            log.error("🍎 Firebase Apple Sign In failed: \(error.localizedDescription)")
                            continuation.resume(throwing: error)
                        }
                    case .failure(let error):
                        log.error("🍎 Apple Sign In failed: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            self.appleDelegate = delegate
            controller.delegate = delegate
            controller.presentationContextProvider = delegate
            controller.performRequests()
        }
    }
    
    private func handleAppleSignInSuccess(credential: FirebaseAuthCredential) async throws {
        guard let identityToken = credential.identityToken,
              let identityTokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.invalidCredential
        }
        
        guard let authorizationCode = credential.authorizationCode,
              let authCodeString = String(data: authorizationCode, encoding: .utf8) else {
            throw AuthError.invalidCredential
        }
        
        // Verify the nonce
        guard let currentNonce = currentNonce else {
            throw AuthError.invalidNonce
        }
        
        // Create Firebase credential (new API in FirebaseAuth >= 12)
        let firebaseCredential: AuthCredential = OAuthProvider.appleCredential(
            withIDToken: identityTokenString,
            rawNonce: currentNonce,
            fullName: nil
        )
        
        // Sign in with Firebase
        let result = try await Auth.auth().signIn(with: firebaseCredential)
        
        log.info("🍎 Firebase Apple Sign In successful for user: \(result.user.uid)")
        
        // Update display name if this is a new user and we have the full name
        if let fullName = credential.fullName, !fullName.isEmpty {
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = fullName
            try await changeRequest.commitChanges()
        }
        
        // Also authenticate with backend API
        do {
            try await authenticateWithBackend(
                identityToken: identityTokenString,
                authorizationCode: authCodeString,
                email: credential.email,
                name: credential.fullName
            )
            log.info("🍎 Backend authentication successful")
        } catch {
            log.error("🍎 Backend authentication failed: \(error.localizedDescription)")
            // Continue with Firebase auth even if backend fails
        }
        
        // Post notification
        NotificationCenter.default.post(name: FirebaseNotifications.didSignIn, object: nil)
    }
    
    private func authenticateWithBackend(identityToken: String, authorizationCode: String, email: String?, name: String?) async throws {
        guard let url = URL(string: "https://api.urgood.app/v1/auth/apple") else {
            throw AuthError.networkError
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "identityToken": identityToken,
            "authorizationCode": authorizationCode,
            "user": [
                // Send empty strings for optional fields to avoid JSONSerialization errors
                "email": email ?? "",
                "name": name ?? ""
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError
        }
        
        if httpResponse.statusCode != 200 {
            log.error("Backend authentication failed with status: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                log.error("Response: \(responseString)")
            }
            throw AuthError.networkError
        }
        
        // Parse response to get backend tokens if needed
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = json["success"] as? Bool, success {
            log.info("Backend authentication successful")
            
            // Store backend tokens if needed
            if let data = json["data"] as? [String: Any],
               let tokens = data["tokens"] as? [String: Any] {
                // Store tokens securely (Keychain recommended)
                // For now, just log token keys for debugging
                log.info("Received backend tokens: \(tokens.keys.joined(separator: ","))")
            }
        }
    }
    
    // MARK: - Email/Password Authentication
    
    func signUpWithEmail(_ email: String, password: String, name: String?) async throws {
        guard !developmentMode else {
            log.info("🔧 Development mode: Email Sign Up bypassed")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        log.info("📧 Starting email sign up for: \(email)")
        
        // Create user with email and password
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        
        // Update display name if provided
        if let name = name, !name.isEmpty {
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = name
            try await changeRequest.commitChanges()
        }
        
        // Send email verification
        try await result.user.sendEmailVerification()
        
        log.info("📧 Email sign up successful for: \(email)")
        
        // Post notification
        NotificationCenter.default.post(name: FirebaseNotifications.didSignIn, object: nil)
    }
    
    func signInWithEmail(_ email: String, password: String) async throws {
        guard !developmentMode else {
            log.info("🔧 Development mode: Email Sign In bypassed")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        log.info("📧 Starting email sign in for: \(email)")
        
        // Sign in with email and password
        _ = try await Auth.auth().signIn(withEmail: email, password: password)
        
        log.info("📧 Email sign in successful for: \(email)")
        
        // Post notification
        NotificationCenter.default.post(name: FirebaseNotifications.didSignIn, object: nil)
    }
    
    // MARK: - Password Reset
    
    func sendPasswordReset(email: String) async throws {
        log.info("🔑 Sending password reset for: \(email)")
        
        try await Auth.auth().sendPasswordReset(withEmail: email)
        
        log.info("🔑 Password reset sent for: \(email)")
    }
    
    // MARK: - Sign Out
    
    func signOut() async throws {
        log.info("🚪 Signing out user")
        
        try Auth.auth().signOut()
        
        currentUser = nil
        isAuthenticated = false
        currentNonce = nil
        appleController = nil
        appleDelegate = nil
        
        log.info("🚪 Sign out successful")
    }
    
    // MARK: - User Profile Management
    
    private func createOrUpdateUserProfile(user: FirebaseUser) async {
        do {
            let enhancedFirebaseService = EnhancedFirebaseService.shared
            
            // Check if user profile already exists
            let userRef = Firestore.firestore().collection("users").document(user.uid)
            let document = try await userRef.getDocument()
            
            if !document.exists {
                // Create new user profile
                try await enhancedFirebaseService.createUserProfile(
                    uid: user.uid,
                    email: user.email,
                    name: user.displayName
                )
            } else {
                // Update last active time
                try await enhancedFirebaseService.updateUserActivity(uid: user.uid)
            }
        } catch {
            log.error("Failed to create/update user profile: \(error.localizedDescription)")
        }
    }

    // MARK: - Onboarding Quiz (No-op stub for compatibility)
    func saveQuizAnswers(_ answers: [QuizAnswer]) async throws {
        // In a future version, this can persist answers to Firestore.
        // For now we just log to keep build compatibility.
        log.info("📝 Received onboarding quiz answers: \(answers.count) selected")
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

// MARK: - Supporting Types

struct FirebaseAuthCredential {
    let userID: String
    let email: String?
    let fullName: String?
    let identityToken: Data?
    let authorizationCode: Data?
}

final class FirebaseAppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let currentNonce: String
    private let completion: (Result<FirebaseAuthCredential, Error>) -> Void
    private weak var anchorWindow: UIWindow?
    
    init(currentNonce: String, anchorWindow: UIWindow, completion: @escaping (Result<FirebaseAuthCredential, Error>) -> Void) {
        self.currentNonce = currentNonce
        self.completion = completion
        self.anchorWindow = anchorWindow
        super.init()
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            completion(.failure(AuthError.invalidCredential))
            return
        }
        
        // Verify we have the required token
        guard let identityToken = appleIDCredential.identityToken else {
            completion(.failure(AuthError.missingIdentityToken))
            return
        }
        
        // Create Firebase credential
        let credential = FirebaseAuthCredential(
            userID: appleIDCredential.user,
            email: appleIDCredential.email,
            fullName: [appleIDCredential.fullName?.givenName, appleIDCredential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " "),
            identityToken: identityToken,
            authorizationCode: appleIDCredential.authorizationCode
        )
        
        completion(.success(credential))
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
        log.error("🍎 No presentation window available; using empty anchor")
        return UIWindow()
    }
}

// MARK: - Error Types

enum AuthError: LocalizedError {
    case invalidCredential
    case missingIdentityToken
    case invalidNonce
    case nonceGenerationFailed
    case presentationAnchorUnavailable
    case userNotFound
    case emailAlreadyInUse
    case weakPassword
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Invalid authentication credential"
        case .missingIdentityToken:
            return "Missing identity token from Apple"
        case .invalidNonce:
            return "Invalid nonce for Apple Sign In"
        case .nonceGenerationFailed:
            return "Unable to securely prepare sign in. Please try again."
        case .presentationAnchorUnavailable:
            return "Unable to find a window to present Apple Sign In. Please try again when the app is active."
        case .userNotFound:
            return "User not found"
        case .emailAlreadyInUse:
            return "Email is already in use"
        case .weakPassword:
            return "Password is too weak"
        case .networkError:
            return "Network error occurred"
        }
    }
}

// MARK: - Notifications

struct FirebaseNotifications {
    static let didSignIn = Notification.Name("firebaseDidSignIn")
    static let didSignOut = Notification.Name("firebaseDidSignOut")
}

// MARK: - Development Note
// Development-time mock subclasses removed to avoid overriding non-open SDK types.
