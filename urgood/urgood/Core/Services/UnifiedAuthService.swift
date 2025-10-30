//
//  UnifiedAuthService.swift
//  urgood
//
//  Multi-user authentication service with proper user profile management
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices
import CryptoKit
import Security
import os.log
import FirebaseAnalytics
import UIKit
import RevenueCat

private let log = Logger(subsystem: "com.urgood.urgood", category: "UnifiedAuth")

/// Extension to UserProfile for multi-user architecture compatibility
extension UserProfile {
    // Convert from SubscriptionStatus to SubscriptionPlan for compatibility
    var plan: SubscriptionPlan {
        get {
            return subscriptionStatus == .premium ? .premium : .free
        }
    }
    
    // Convenience init for multi-user architecture
    init(
        uid: String,
        email: String?,
        displayName: String?,
        createdAt: Date = Date(),
        plan: SubscriptionPlan,
        settings: UserPreferences?,
        lastActiveAt: Date?,
        streakCount: Int,
        totalCheckins: Int,
        messagesThisWeek: Int,
        isEmailVerified: Bool
    ) {
        self.init(
            uid: uid,
            email: email,
            displayName: displayName,
            subscriptionStatus: plan == .premium ? .premium : .free,
            streakCount: streakCount,
            totalCheckins: totalCheckins,
            messagesThisWeek: messagesThisWeek,
            isEmailVerified: isEmailVerified,
            createdAt: createdAt,
            lastActiveAt: lastActiveAt,
            preferences: settings
        )
    }
}

enum SubscriptionPlan: String, Codable {
    case free = "free"
    case premium = "premium"
    
    var displayName: String {
        switch self {
        case .free: return "Free"
        case .premium: return "Premium"
        }
    }
}

/// Keychain helper for secure storage
private class KeychainHelper {
    static func save(uid: String) {
        let data = Data(uid.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "currentUserUID",
            kSecValueData as String: data
        ]
        
        // Delete old value if exists
        SecItemDelete(query as CFDictionary)
        
        // Add new value
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            log.error("Failed to save UID to keychain: \(status)")
        }
    }
    
    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "currentUserUID",
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let uid = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return uid
    }
    
    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "currentUserUID"
        ]
        SecItemDelete(query as CFDictionary)
    }
}

@MainActor
final class UnifiedAuthService: ObservableObject {
    // MARK: - Published Properties
    @Published var currentUserProfile: UserProfile?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let db = Firestore.firestore()
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?
    
    // Apple Sign In support
    private var appleController: ASAuthorizationController?
    private var appleDelegate: AppleSignInDelegate?
    
    // Development mode bypass
    private let developmentMode = DevelopmentConfig.bypassAuthentication
    
    // MARK: - Initialization
    init() {
        setupAuthStateListener()
        
        if developmentMode {
            // Auto-authenticate in development mode
            let devUser = UserProfile(
                uid: "dev-user-123",
                email: "dev@urgood.com",
                displayName: "Dev User",
                isEmailVerified: true
            )
            self.currentUserProfile = devUser
            self.isAuthenticated = true
            log.info("🔧 Development mode: Auto-authenticated")
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
                guard let self = self else { return }
                
                if let user = user {
                    log.info("🔥 User signed in: \(user.uid)")
                    await self.handleUserSignIn(user: user)
                } else {
                    log.info("🔥 User signed out")
                    await self.handleUserSignOut()
                }
            }
        }
    }
    
    private func handleUserSignIn(user: FirebaseAuth.User) async {
        do {
            // Try to load existing profile
            let profileDoc = try await db.collection("users").document(user.uid).getDocument()
            
            if profileDoc.exists, let data = profileDoc.data() {
                // Parse existing profile
                currentUserProfile = try parseUserProfile(from: data, uid: user.uid)
                log.info("✅ Loaded existing user profile: \(user.uid)")
            } else {
                // Create new profile with atomic write
                let newProfile = UserProfile(
                    uid: user.uid,
                    email: user.email,
                    displayName: user.displayName ?? "User",
                    isEmailVerified: user.isEmailVerified
                )
                
                try await createUserProfile(profile: newProfile)
                currentUserProfile = newProfile
                log.info("✅ Created new user profile: \(user.uid)")
            }
            
            // Save UID to keychain
            KeychainHelper.save(uid: user.uid)
            
            // Set Firebase Analytics user ID
            Analytics.setUserID(user.uid)
            
            // Configure RevenueCat for this user
            await configureRevenueCat(uid: user.uid)
            
            isAuthenticated = true
            
        } catch {
            log.error("❌ Failed to load/create user profile: \(error.localizedDescription)")
            errorMessage = "Failed to load user profile: \(error.localizedDescription)"
        }
    }
    
    private func handleUserSignOut() async {
        // Clear keychain
        KeychainHelper.delete()
        
        // Clear Firebase Analytics user ID
        Analytics.setUserID(nil)
        
        // Logout RevenueCat
        await logoutRevenueCat()
        
        // Clear state
        currentUserProfile = nil
        isAuthenticated = false
        
        log.info("🚪 User signed out completely")
    }
    
    // MARK: - User Profile Management
    private func createUserProfile(profile: UserProfile) async throws {
        let data: [String: Any] = [
            "uid": profile.uid,
            "displayName": profile.displayName ?? "",
            "email": profile.email ?? "",
            "createdAt": Timestamp(date: profile.createdAt),
            "plan": profile.plan.rawValue,
            "settings": profile.preferences.map { encodableToDict($0) } ?? [:],
            "streakCount": profile.streakCount,
            "totalCheckins": profile.totalCheckins,
            "messagesThisWeek": profile.messagesThisWeek,
            "isEmailVerified": profile.isEmailVerified,
            "lastActiveAt": Timestamp(date: Date())
        ]
        
        // Atomic write - create if not exists
        try await db.collection("users").document(profile.uid).setData(data, merge: false)
    }
    
    func updateUserProfile(updates: [String: Any]) async throws {
        guard let uid = currentUserProfile?.uid else {
            throw UnifiedAuthError.notAuthenticated
        }
        
        var mutableUpdates = updates
        mutableUpdates["lastActiveAt"] = Timestamp(date: Date())
        
        try await db.collection("users").document(uid).updateData(mutableUpdates)
        
        // Reload profile
        let doc = try await db.collection("users").document(uid).getDocument()
        if let data = doc.data() {
            currentUserProfile = try parseUserProfile(from: data, uid: uid)
        }
    }
    
    private func parseUserProfile(from data: [String: Any], uid: String) throws -> UserProfile {
        let displayName = data["displayName"] as? String
        let email = data["email"] as? String
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let planRaw = data["plan"] as? String ?? "free"
        let plan = SubscriptionPlan(rawValue: planRaw) ?? .free
        
        let settingsDict = data["settings"] as? [String: Any] ?? [:]
        let settings = try? dictToDecodable(settingsDict, UserPreferences.self)
        
        let lastActiveAt = (data["lastActiveAt"] as? Timestamp)?.dateValue()
        let streakCount = data["streakCount"] as? Int ?? 0
        let totalCheckins = data["totalCheckins"] as? Int ?? 0
        let messagesThisWeek = data["messagesThisWeek"] as? Int ?? 0
        let isEmailVerified = data["isEmailVerified"] as? Bool ?? false
        
        return UserProfile(
            uid: uid,
            email: email,
            displayName: displayName,
            createdAt: createdAt,
            plan: plan,
            settings: settings,
            lastActiveAt: lastActiveAt,
            streakCount: streakCount,
            totalCheckins: totalCheckins,
            messagesThisWeek: messagesThisWeek,
            isEmailVerified: isEmailVerified
        )
    }
    
    // MARK: - Sign In Methods
    func signInWithApple() async throws {
        guard !developmentMode else {
            log.info("🔧 Development mode: Apple Sign In bypassed")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let nonce: String
        do {
            nonce = try SecureNonceGenerator.randomNonce()
        } catch {
            log.error("🍎 Failed to generate nonce: \(error.localizedDescription, privacy: .public)")
            throw UnifiedAuthError.nonceGenerationFailed
        }
        currentNonce = nonce
        
        guard let anchorWindow = WindowProvider.activeWindow() else {
            log.error("🍎 No window available for Apple Sign In")
            throw UnifiedAuthError.presentationAnchorUnavailable
        }
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let delegate = AppleSignInDelegate(anchorWindow: anchorWindow) { [weak self] result in
            Task { @MainActor in
                await self?.handleAppleSignInResult(result, nonce: nonce)
            }
        }
        
        self.appleDelegate = delegate
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = delegate
        controller.presentationContextProvider = delegate
        controller.performRequests()
        
        self.appleController = controller
    }
    
    private func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>, nonce: String) async {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                errorMessage = "Unable to fetch identity token"
                return
            }
            
            let credential = OAuthProvider.credential(
                providerID: AuthProviderID.apple,
                idToken: idTokenString,
                rawNonce: nonce
            )
            
            do {
                _ = try await Auth.auth().signIn(with: credential)
                log.info("✅ Apple Sign In successful")
            } catch {
                errorMessage = "Apple Sign In failed: \(error.localizedDescription)"
                log.error("❌ Apple Sign In failed: \(error.localizedDescription)")
            }
            
        case .failure(let error):
            errorMessage = "Apple Sign In failed: \(error.localizedDescription)"
            log.error("❌ Apple Sign In failed: \(error.localizedDescription)")
        }
    }
    
    func signInWithEmail(email: String, password: String) async throws {
        guard !developmentMode else {
            log.info("🔧 Development mode: Email Sign In bypassed")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        log.info("📧 Starting email sign in for: \(email)")
        
        _ = try await Auth.auth().signIn(withEmail: email, password: password)
        
        log.info("✅ Email sign in successful")
    }
    
    func signUpWithEmail(email: String, password: String, displayName: String?) async throws {
        guard !developmentMode else {
            log.info("🔧 Development mode: Email Sign Up bypassed")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        
        // Update display name if provided
        if let displayName = displayName {
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()
        }
        
        log.info("✅ Email sign up successful")
    }
    
    // MARK: - Sign Out
    func signOut() async throws {
        log.info("🚪 Signing out user")
        
        if !developmentMode {
            try Auth.auth().signOut()
        }
        
        // Clear local state
        await handleUserSignOut()
        
        log.info("✅ Sign out successful")
    }
    
    // MARK: - Delete Account
    func deleteAccount() async throws {
        guard let uid = currentUserProfile?.uid else {
            throw UnifiedAuthError.notAuthenticated
        }
        
        log.info("🗑️ Deleting account: \(uid)")
        
        // Delete all user data recursively
        try await deleteUserData(uid: uid)
        
        // Delete Firebase Auth account
        if !developmentMode {
            try await Auth.auth().currentUser?.delete()
        }
        
        // Clear local state
        await handleUserSignOut()
        
        log.info("✅ Account deleted successfully")
    }
    
    private func deleteUserData(uid: String) async throws {
        // Delete all subcollections
        let subcollections = ["sessions", "moods", "insights", "settings"]
        
        for subcollection in subcollections {
            let snapshot = try await db.collection("users").document(uid)
                .collection(subcollection).getDocuments()
            
            let batch = db.batch()
            for doc in snapshot.documents {
                batch.deleteDocument(doc.reference)
            }
            try await batch.commit()
        }
        
        // Delete user document
        try await db.collection("users").document(uid).delete()
    }
    
    // MARK: - RevenueCat Integration
    private func configureRevenueCat(uid: String) async {
        // Only configure RevenueCat if API key is available
        guard !ProductionConfig.revenueCatAPIKey.isEmpty else {
            log.info("⚠️ RevenueCat API key not configured, skipping login")
            return
        }
        
        do {
            // Log in RevenueCat with Firebase UID
            let (customerInfo, _) = try await Purchases.shared.logIn(uid)
            log.info("✅ RevenueCat login successful for user: \(uid)")
            
            // Log entitlements for debugging
            if customerInfo.entitlements.active.isEmpty {
                log.info("ℹ️ No active entitlements for user: \(uid)")
            } else {
                log.info("✅ Active entitlements: \(customerInfo.entitlements.active.keys.joined(separator: ", "))")
            }
        } catch {
            log.error("❌ RevenueCat login failed for user \(uid): \(error.localizedDescription)")
            // Don't fail auth if RevenueCat fails - just log it
        }
    }
    
    private func logoutRevenueCat() async {
        // Only logout if RevenueCat is configured
        guard !ProductionConfig.revenueCatAPIKey.isEmpty else {
            return
        }
        
        do {
            _ = try await Purchases.shared.logOut()
            log.info("✅ RevenueCat logout successful")
        } catch {
            log.error("❌ RevenueCat logout failed: \(error.localizedDescription)")
            // Don't fail logout if RevenueCat fails - just log it
        }
    }
    
    // MARK: - Helper Methods
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    private func encodableToDict<T: Encodable>(_ value: T) -> [String: Any] {
        guard let data = try? JSONEncoder().encode(value),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return dict
    }
    
    private func dictToDecodable<T: Decodable>(_ dict: [String: Any], _ type: T.Type) throws -> T? {
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Apple Sign In Delegate
private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
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
        log.error("🍎 Missing window for Apple Sign In; returning empty anchor")
        return UIWindow()
    }
}

// MARK: - Auth Errors
enum UnifiedAuthError: LocalizedError {
    case notAuthenticated
    case profileNotFound
    case invalidData
    case nonceGenerationFailed
    case presentationAnchorUnavailable
    case userCancelled
    case signInInProgress
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .profileNotFound:
            return "User profile not found"
        case .invalidData:
            return "Invalid user data"
        case .nonceGenerationFailed:
            return "Unable to securely prepare sign in. Please try again."
        case .presentationAnchorUnavailable:
            return "Unable to find a window to present Apple Sign In. Please try again when the app is active."
        case .userCancelled:
            return "Sign in was cancelled"
        case .signInInProgress:
            return "Sign in is already in progress"
        }
    }
}
