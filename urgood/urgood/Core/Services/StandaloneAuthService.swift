import Foundation
import AuthenticationServices
import CryptoKit
import UIKit
import os.log

private let log = Logger(subsystem: "com.urgood.urgood", category: "StandaloneAuth")

@MainActor
final class StandaloneAuthService: ObservableObject, AuthServiceProtocol {
    @Published var isAuthenticated = false
    @Published private var _currentUser: StandaloneUser?
    
    var currentUser: Any? {
        return _currentUser
    }
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Development mode - set to true to bypass authentication
    private let developmentMode = DevelopmentConfig.bypassAuthentication
    
    private var currentNonce: String?
    
    // Keep controller + delegate alive during the flow
    private var appleController: ASAuthorizationController?
    private var appleDelegate: StandaloneAppleSignInDelegate?
    
    struct StandaloneUser {
        let id: String
        let email: String?
        let name: String?
        let authProvider: AuthProvider
        let createdAt: Date
    }
    
    enum AuthProvider: String, CaseIterable {
        case apple = "apple.com"
        case email = "password"
    }
    
    init() {
        if developmentMode {
            // Auto-authenticate in development mode
            isAuthenticated = true
            _currentUser = StandaloneUser(
                id: "dev-user-123",
                email: "dev@urgood.com",
                name: "Development User",
                authProvider: .email,
                createdAt: Date()
            )
            log.info("🔧 Development mode: Auto-authenticated user")
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
            log.error("🍎 Failed to generate nonce: \(error.localizedDescription)")
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
            let delegate = StandaloneAppleSignInDelegate(currentNonce: nonce, anchorWindow: anchorWindow) { [weak self] result in
                Task { @MainActor in
                    switch result {
                    case .success(let credential):
                        self?.handleAppleSignInSuccess(credential: credential)
                        continuation.resume()
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
    
    // MARK: - Email/Password Authentication
    
    func signUpWithEmail(_ email: String, password: String, name: String?) async throws {
        guard !developmentMode else {
            log.info("🔧 Development mode: Email Sign Up bypassed")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        log.info("📧 Starting email sign up for: \(email)")
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Simulate successful signup
        let user = StandaloneUser(
            id: UUID().uuidString,
            email: email,
            name: name,
            authProvider: .email,
            createdAt: Date()
        )
        
        _currentUser = user
        isAuthenticated = true
        
        log.info("📧 Email sign up successful for: \(email)")
        
        // Post notification
        NotificationCenter.default.post(name: StandaloneNotifications.didSignIn, object: nil)
    }
    
    func signInWithEmail(_ email: String, password: String) async throws {
        guard !developmentMode else {
            log.info("🔧 Development mode: Email Sign In bypassed")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        log.info("📧 Starting email sign in for: \(email)")
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        // Simulate successful signin
        let user = StandaloneUser(
            id: UUID().uuidString,
            email: email,
            name: "User", // Would normally come from stored data
            authProvider: .email,
            createdAt: Date()
        )
        
        _currentUser = user
        isAuthenticated = true
        
        log.info("📧 Email sign in successful for: \(email)")
        
        // Post notification
        NotificationCenter.default.post(name: StandaloneNotifications.didSignIn, object: nil)
    }
    
    // MARK: - Sign Out
    
    func signOut() async throws {
        log.info("🚪 Signing out user")
        
        _currentUser = nil
        isAuthenticated = false
        currentNonce = nil
        appleController = nil
        appleDelegate = nil
        
        log.info("🚪 Sign out successful")
    }
    
    // MARK: - Quiz Answers
    
    func saveQuizAnswers(_ answers: [QuizAnswer]) async throws {
        log.info("📝 Saving quiz answers: \(answers.count) answers")
        
        // Simulate saving quiz answers
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        log.info("📝 Quiz answers saved successfully")
    }
    
    // MARK: - Private Methods
    
    private func handleAppleSignInSuccess(credential: StandaloneAuthCredential) {
        let user = StandaloneUser(
            id: credential.userID,
            email: credential.email,
            name: credential.fullName,
            authProvider: .apple,
            createdAt: Date()
        )
        
        _currentUser = user
        isAuthenticated = true
        
        log.info("🍎 Apple Sign In successful for user: \(credential.userID)")
        
        // Post notification
        NotificationCenter.default.post(name: StandaloneNotifications.didSignIn, object: nil)
    }
    
    // MARK: - Utility Functions
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    // MARK: - Protocol Conformance Methods
    
    func resetPassword(email: String) async throws {
        log.info("🔧 Development mode: Simulating password reset email sent to \(email)")
        // Simulate password reset
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
    }
    
    func resendEmailVerification() async throws {
        log.info("🔧 Development mode: Simulating email verification sent")
        // Simulate email verification
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
    }
    
    func signUp(email: String, password: String, name: String) async throws {
        try await signUpWithEmail(email, password: password, name: name)
    }
    
    func signIn(email: String, password: String) async throws {
        try await signInWithEmail(email, password: password)
    }
}

// MARK: - Supporting Types

struct StandaloneAuthCredential {
    let userID: String
    let email: String?
    let fullName: String?
    let identityToken: Data?
    let authorizationCode: Data?
}

final class StandaloneAppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let currentNonce: String
    private let completion: (Result<StandaloneAuthCredential, Error>) -> Void
    private weak var anchorWindow: UIWindow?
    
    init(currentNonce: String, anchorWindow: UIWindow, completion: @escaping (Result<StandaloneAuthCredential, Error>) -> Void) {
        self.currentNonce = currentNonce
        self.completion = completion
        self.anchorWindow = anchorWindow
        super.init()
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            completion(.failure(NSError(domain: "StandaloneAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing Apple ID token"])))
            return
        }
        
        // Create mock credential for standalone mode
        let mockCredential = StandaloneAuthCredential(
            userID: appleIDCredential.user,
            email: appleIDCredential.email,
            fullName: [appleIDCredential.fullName?.givenName, appleIDCredential.fullName?.familyName].compactMap { $0 }.joined(separator: " "),
            identityToken: appleIDCredential.identityToken,
            authorizationCode: appleIDCredential.authorizationCode
        )
        
        completion(.success(mockCredential))
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
        log.error("🍎 StandaloneAppleSignInDelegate missing window; returning empty anchor")
        return UIWindow()
    }
}

struct StandaloneNotifications {
    static let didSignIn = Notification.Name("standaloneDidSignIn")
}
