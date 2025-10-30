//
//  DemoSwitcher.swift
//  urgood
//
//  Debug tool for testing multi-user isolation
//

import SwiftUI
import FirebaseAuth

#if DEBUG

@MainActor
class DemoSwitcherViewModel: ObservableObject {
    @Published var currentUserEmail: String = ""
    @Published var availableUsers: [DemoUser] = []
    @Published var isCreatingUser = false
    @Published var errorMessage: String?
    
    private let authService: UnifiedAuthService
    private let appSession: AppSession
    
    var uid: String? {
        appSession.currentUser?.uid
    }
    
    struct DemoUser: Identifiable {
        let id: String
        let email: String
        let displayName: String
        
        var initial: String {
            String(displayName.prefix(1))
        }
    }
    
    init(authService: UnifiedAuthService, appSession: AppSession) {
        self.authService = authService
        self.appSession = appSession
        
        // Pre-populate with demo users
        availableUsers = [
            DemoUser(id: "user-a", email: "demo-a@urgood.test", displayName: "Demo User A"),
            DemoUser(id: "user-b", email: "demo-b@urgood.test", displayName: "Demo User B")
        ]
        
        updateCurrentUser()
    }
    
    func updateCurrentUser() {
        if let user = appSession.currentUser {
            currentUserEmail = user.email ?? "Unknown"
        } else {
            currentUserEmail = "Not signed in"
        }
    }
    
    func switchToUser(_ user: DemoUser) async {
        isCreatingUser = true
        errorMessage = nil
        
        do {
            // Sign out current user
            try await authService.signOut()
            
            // Wait a moment for cleanup
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Try to sign in with existing account
            do {
                try await authService.signInWithEmail(
                    email: user.email,
                    password: "DemoPassword123!"
                )
            } catch {
                // If sign in fails, create the account
                try await authService.signUpWithEmail(
                    email: user.email,
                    password: "DemoPassword123!",
                    displayName: user.displayName
                )
            }
            
            updateCurrentUser()
            
        } catch {
            errorMessage = "Failed to switch user: \(error.localizedDescription)"
            print("❌ Demo switcher error: \(error)")
        }
        
        isCreatingUser = false
    }
    
    func signOut() async {
        do {
            try await authService.signOut()
            updateCurrentUser()
        } catch {
            errorMessage = "Failed to sign out: \(error.localizedDescription)"
        }
    }
    
    func createSessionsForTesting(count: Int) async {
        guard let sessionsRepo = appSession.sessionsRepo else { return }
        
        do {
            for i in 1...count {
                let session = ChatSession(
                    startTime: Date().addingTimeInterval(-Double(i) * 3600),
                    endTime: Date().addingTimeInterval(-Double(i) * 3600 + 1800),
                    messageCount: Int.random(in: 5...20),
                    moodBefore: Int.random(in: 1...5),
                    moodAfter: Int.random(in: 1...5),
                    summary: "Test session \(i)",
                    insights: "Test insights for session \(i)"
                )
                try await sessionsRepo.createSession(session: session)
            }
            print("✅ Created \(count) test sessions")
        } catch {
            errorMessage = "Failed to create sessions: \(error.localizedDescription)"
        }
    }
    
    func createMoodsForTesting(count: Int) async {
        guard let moodsRepo = appSession.moodsRepo else { return }
        
        do {
            for i in 1...count {
                let entry = MoodEntry(
                    id: UUID(),
                    date: Date().addingTimeInterval(-Double(i) * 86400),
                    mood: Int.random(in: 1...5),
                    tags: [MoodTag(name: "test-tag-\(i)")]
                )
                try await moodsRepo.saveMoodEntry(entry: entry)
            }
            print("✅ Created \(count) test mood entries")
        } catch {
            errorMessage = "Failed to create moods: \(error.localizedDescription)"
        }
    }
}

struct DemoSwitcherView: View {
    @StateObject private var viewModel: DemoSwitcherViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(authService: UnifiedAuthService, appSession: AppSession) {
        _viewModel = StateObject(wrappedValue: DemoSwitcherViewModel(
            authService: authService,
            appSession: appSession
        ))
    }
    
    var body: some View {
        NavigationView {
            List {
                Section("Current User") {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text(viewModel.currentUserEmail)
                                .font(.headline)
                            if let uid = viewModel.uid {
                                Text("UID: \(uid.prefix(8))...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section("Switch User") {
                    ForEach(viewModel.availableUsers) { user in
                        Button {
                            Task {
                                await viewModel.switchToUser(user)
                            }
                        } label: {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(Color.accentColor)
                                        .frame(width: 40, height: 40)
                                    Text(user.initial)
                                        .foregroundColor(.white)
                                        .font(.headline)
                                }
                                
                                VStack(alignment: .leading) {
                                    Text(user.displayName)
                                        .font(.headline)
                                    Text(user.email)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if viewModel.isCreatingUser {
                                    ProgressView()
                                } else {
                                    Image(systemName: "arrow.right.circle")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .disabled(viewModel.isCreatingUser)
                    }
                }
                
                Section("Test Data") {
                    Button("Create 5 Test Sessions") {
                        Task {
                            await viewModel.createSessionsForTesting(count: 5)
                        }
                    }
                    
                    Button("Create 7 Test Moods") {
                        Task {
                            await viewModel.createMoodsForTesting(count: 7)
                        }
                    }
                }
                
                Section("Actions") {
                    Button("Sign Out", role: .destructive) {
                        Task {
                            await viewModel.signOut()
                        }
                    }
                }
                
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                Section {
                    Text("⚠️ Debug Tool Only")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("This feature is only available in DEBUG builds for testing multi-user isolation.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Demo Switcher")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Floating Button to Access Demo Switcher
struct DemoSwitcherButton: View {
    @State private var showingDemoSwitcher = false
    let authService: UnifiedAuthService
    let appSession: AppSession
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    showingDemoSwitcher = true
                } label: {
                    Image(systemName: "person.2.circle.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.purple)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingDemoSwitcher) {
            DemoSwitcherView(authService: authService, appSession: appSession)
        }
    }
}

// MARK: - View Extension for Easy Integration
extension View {
    func withDemoSwitcher(authService: UnifiedAuthService, appSession: AppSession) -> some View {
        self.overlay(
            DemoSwitcherButton(authService: authService, appSession: appSession)
        )
    }
}

#endif

