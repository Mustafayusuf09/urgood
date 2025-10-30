//
//  MultiUserInsightsViewModel.swift
//  urgood
//
//  Example of a ViewModel updated to use the new multi-user architecture
//  This shows the pattern for migrating existing ViewModels
//

import SwiftUI
import Combine

/// Example: Insights ViewModel using new multi-user repositories
/// 
/// MIGRATION PATTERN:
/// 1. Replace LocalStore with user-scoped repositories
/// 2. Inject repositories from AppSession
/// 3. Use repository methods instead of LocalStore
/// 4. Handle nil repositories gracefully (user not authenticated)
@MainActor
class MultiUserInsightsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var sessions: [ChatSession] = []
    @Published var moods: [MoodEntry] = []
    @Published var hasCheckedInToday = false
    @Published var averageMood: Double = 0.0
    @Published var totalSessions: Int = 0
    @Published var hasData = false
    @Published var toast: ToastData?
    @Published var isLoading = false
    
    // MARK: - Dependencies (NEW: User-scoped repositories)
    private let sessionsRepo: SessionsRepository
    private let moodsRepo: MoodsRepository
    private let billingService: any BillingServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(
        sessionsRepo: SessionsRepository,
        moodsRepo: MoodsRepository,
        billingService: any BillingServiceProtocol
    ) {
        self.sessionsRepo = sessionsRepo
        self.moodsRepo = moodsRepo
        self.billingService = billingService
        
        setupObservers()
        loadData()
    }
    
    // MARK: - Setup
    private func setupObservers() {
        // Observe sessions from repository
        sessionsRepo.$sessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                self?.sessions = sessions
                self?.updateMetrics()
            }
            .store(in: &cancellables)
        
        // Observe moods from repository
        moodsRepo.$moods
            .receive(on: DispatchQueue.main)
            .sink { [weak self] moods in
                self?.moods = moods
                self?.updateMetrics()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Loading
    func loadData() {
        Task {
            isLoading = true
            defer { isLoading = false }
            
            do {
                // Fetch data from repositories
                let fetchedSessions = try await sessionsRepo.fetchSessions(limit: 50)
                let fetchedMoods = try await moodsRepo.fetchMoods(limit: 100)
                
                // Update UI
                await MainActor.run {
                    self.sessions = fetchedSessions
                    self.moods = fetchedMoods
                    self.updateMetrics()
                }
            } catch {
                print("❌ Failed to load data: \(error.localizedDescription)")
                toast = ToastData(message: "Failed to load data", type: .error)
            }
        }
    }
    
    func refreshData() {
        loadData()
    }
    
    // MARK: - Metrics
    private func updateMetrics() {
        // Calculate metrics from loaded data
        totalSessions = sessions.count
        
        // Calculate average mood from recent entries
        let recentMoods = moods.prefix(30)
        if !recentMoods.isEmpty {
            averageMood = Double(recentMoods.map { $0.mood }.reduce(0, +)) / Double(recentMoods.count)
        } else {
            averageMood = 0
        }
        
        // Check if checked in today
        let today = Calendar.current.startOfDay(for: Date())
        hasCheckedInToday = moods.contains { mood in
            Calendar.current.startOfDay(for: mood.date) == today
        }
        
        hasData = !sessions.isEmpty || !moods.isEmpty
    }
    
    // MARK: - Actions
    func saveQuickCheckin(mood: Int, tags: [String]) {
        Task {
            do {
                let moodTags = tags.map { MoodTag(name: $0) }
                let entry = MoodEntry(mood: mood, tags: moodTags)
                
                try await moodsRepo.saveMoodEntry(entry: entry)
                
                toast = ToastData(message: "Mood logged! 🔥", type: .success)
            } catch {
                print("❌ Failed to save mood: \(error.localizedDescription)")
                toast = ToastData(message: "Failed to save mood", type: .error)
            }
        }
    }
    
    // MARK: - Weekly Trends
    var weeklyMoods: [ViewModelDailyMood] {
        // Get last 7 days
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return (0..<7).compactMap { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            let dayMoods = moods.filter { mood in
                calendar.startOfDay(for: mood.date) == date
            }
            
            guard !dayMoods.isEmpty else { return nil }
            
            let avgMood = Double(dayMoods.map { $0.mood }.reduce(0, +)) / Double(dayMoods.count)
            
            return ViewModelDailyMood(
                date: date,
                mood: avgMood,
                count: dayMoods.count
            )
        }.reversed()
    }
    
    var recentSessions: [ChatSession] {
        Array(sessions.prefix(10))
    }
}

// MARK: - Supporting Models
struct ViewModelDailyMood: Identifiable {
    let id = UUID()
    let date: Date
    let mood: Double
    let count: Int
    
    var value: Double { mood } // Compatibility alias
    
    var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

// MARK: - Usage Example
extension MultiUserInsightsViewModel {
    /// Example of how to create this ViewModel from a View
    /// 
    /// ```swift
    /// struct InsightsView: View {
    ///     @Environment(\.appSession) var appSession
    ///     @StateObject private var viewModel: MultiUserInsightsViewModel
    ///     
    ///     init() {
    ///         // This will be recreated when user changes
    ///         _viewModel = StateObject(wrappedValue: MultiUserInsightsViewModel(
    ///             sessionsRepo: appSession.sessionsRepo!,
    ///             moodsRepo: appSession.moodsRepo!,
    ///             billingService: DIContainer.shared.billingService
    ///         ))
    ///     }
    /// }
    /// ```
    static func exampleUsage() {
        print("""
        MIGRATION CHECKLIST FOR VIEWMODELS:
        
        ✅ Replace LocalStore dependency with user-scoped repositories
        ✅ Inject repositories from AppSession in View's init
        ✅ Use repository methods (fetchSessions, saveMoodEntry, etc.)
        ✅ Observe repository @Published properties for real-time updates
        ✅ Handle async/await for repository operations
        ✅ Show loading states and error messages
        ✅ Remove direct Firestore or global collection access
        ✅ Test with Demo Switcher to verify data isolation
        
        NOTES:
        - ViewModels are now truly user-scoped (recreated on user change)
        - No manual listener cleanup needed (handled by repositories)
        - Type-safe data access (no raw Firestore documents)
        - Automatic migration ensures backward compatibility
        """)
    }
}

