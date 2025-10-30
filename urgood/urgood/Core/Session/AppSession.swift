//
//  AppSession.swift
//  urgood
//
//  Central session manager for multi-user support with uid-scoped repositories
//

import Foundation
import SwiftUI
import Combine
import os.log

private let log = Logger(subsystem: "com.urgood.urgood", category: "AppSession")

@MainActor
class AppSession: ObservableObject {
    // MARK: - Published Properties
    @Published var currentUser: UserProfile?
    @Published var sessionsRepo: SessionsRepository?
    @Published var moodsRepo: MoodsRepository?
    @Published var insightsRepo: InsightsRepository?
    @Published var settingsRepo: SettingsRepository?
    
    // MARK: - Private Properties
    private let authService: UnifiedAuthService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(authService: UnifiedAuthService) {
        self.authService = authService
        
        // Observe auth state changes
        setupAuthObserver()
        
        // Initialize with current user if authenticated
        if let currentUser = authService.currentUserProfile {
            setupRepositories(for: currentUser)
        }
    }
    
    // MARK: - Setup
    private func setupAuthObserver() {
        authService.$currentUserProfile
            .sink { [weak self] userProfile in
                guard let self = self else { return }
                
                Task { @MainActor in
                    if let userProfile = userProfile {
                        // User logged in or switched
                        await self.handleUserChange(to: userProfile)
                    } else {
                        // User logged out
                        await self.handleLogout()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleUserChange(to userProfile: UserProfile) async {
        log.info("🔄 User change detected: \(userProfile.uid)")
        
        // Cancel all existing listeners first
        await cleanupRepositories()
        
        // Update current user
        currentUser = userProfile
        
        // Setup new repositories for this user
        setupRepositories(for: userProfile)
        
        log.info("✅ AppSession updated for user: \(userProfile.uid)")
    }
    
    private func handleLogout() async {
        log.info("🚪 Handling logout in AppSession")
        
        // Cancel all listeners
        await cleanupRepositories()
        
        // Clear state
        currentUser = nil
        sessionsRepo = nil
        moodsRepo = nil
        insightsRepo = nil
        settingsRepo = nil
        
        log.info("✅ AppSession cleared")
    }
    
    private func setupRepositories(for userProfile: UserProfile) {
        let uid = userProfile.uid
        
        // Create user-scoped repositories
        let sessions = SessionsRepository(uid: uid)
        let moods = MoodsRepository(uid: uid)
        let insights = InsightsRepository(uid: uid)
        let settings = SettingsRepository(uid: uid)
        
        // Start listeners
        sessions.listenToSessions()
        moods.listenToMoods()
        insights.listenToInsights()
        
        // Assign to published properties
        sessionsRepo = sessions
        moodsRepo = moods
        insightsRepo = insights
        settingsRepo = settings
        
        log.info("📦 Repositories initialized and listening for user: \(uid)")
    }
    
    private func cleanupRepositories() async {
        sessionsRepo?.cancelAllListeners()
        moodsRepo?.cancelAllListeners()
        insightsRepo?.cancelAllListeners()
        settingsRepo?.cancelAllListeners()
        
        log.info("🧹 Repositories cleaned up")
    }
    
    // MARK: - Convenience Methods
    var isAuthenticated: Bool {
        currentUser != nil
    }
    
    var uid: String? {
        currentUser?.uid
    }
    
    var isPremium: Bool {
        currentUser?.plan == .premium
    }
    
    // MARK: - User Actions
    func updateUserStats(streakCount: Int? = nil, totalCheckins: Int? = nil, messagesThisWeek: Int? = nil) async throws {
        guard currentUser != nil else {
            throw AppSessionError.notAuthenticated
        }
        
        var updates: [String: Any] = [:]
        
        if let streakCount = streakCount {
            updates["streakCount"] = streakCount
        }
        if let totalCheckins = totalCheckins {
            updates["totalCheckins"] = totalCheckins
        }
        if let messagesThisWeek = messagesThisWeek {
            updates["messagesThisWeek"] = messagesThisWeek
        }
        
        try await authService.updateUserProfile(updates: updates)
        
        // Update local state
        if let updated = authService.currentUserProfile {
            self.currentUser = updated
        }
    }
    
    func updateUserPlan(plan: SubscriptionPlan) async throws {
        try await authService.updateUserProfile(updates: ["plan": plan.rawValue])
        
        // Update local state
        if let updated = authService.currentUserProfile {
            self.currentUser = updated
        }
        
        log.info("✅ User plan updated to: \(plan.displayName)")
    }
    
    func updateUserSettings(settings: UserPreferences) async throws {
        guard let settingsRepo = settingsRepo else {
            throw AppSessionError.notInitialized
        }
        
        try await settingsRepo.saveSettings(settings: settings)
        try await authService.updateUserProfile(updates: ["settings": encodableToDict(settings)])
        
        // Update local state
        if let updated = authService.currentUserProfile {
            self.currentUser = updated
        }
        
        log.info("✅ User settings updated")
    }
    
    // MARK: - Helper Methods
    private func encodableToDict<T: Encodable>(_ value: T) -> [String: Any] {
        guard let data = try? JSONEncoder().encode(value),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return dict
    }
}

// MARK: - Environment Key
struct AppSessionKey: EnvironmentKey {
    static let defaultValue: AppSession? = nil
}

extension EnvironmentValues {
    var appSession: AppSession? {
        get { self[AppSessionKey.self] }
        set { self[AppSessionKey.self] = newValue }
    }
}

// MARK: - View Extension
extension View {
    func withAppSession(_ session: AppSession) -> some View {
        self.environment(\.appSession, session)
    }
}

// MARK: - Errors
enum AppSessionError: LocalizedError {
    case notAuthenticated
    case notInitialized
    case repositoryUnavailable
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .notInitialized:
            return "App session not initialized"
        case .repositoryUnavailable:
            return "Repository not available"
        }
    }
}

