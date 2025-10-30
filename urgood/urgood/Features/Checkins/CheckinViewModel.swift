import Foundation
import SwiftUI

@MainActor
class CheckinViewModel: ObservableObject {
    @Published var selectedMood: Int = 0
    @Published var selectedTags: Set<MoodTag> = []
    @Published var toast: ToastData?
    
    private let checkinService: CheckinService
    private let localStore: LocalStore
    
    init(checkinService: CheckinService, localStore: LocalStore) {
        self.checkinService = checkinService
        self.localStore = localStore
    }
    
    var availableTags: [MoodTag] {
        checkinService.getAvailableTags()
    }
    
    var currentStreak: Int {
        checkinService.getCurrentStreak()
    }
    
    var recentTrends: [TrendPoint] {
        checkinService.getRecentTrends()
    }
    
    var hasCheckedInToday: Bool {
        checkinService.hasCheckedInToday()
    }
    
    var averageMood: Double {
        let recentMoods = recentTrends.filter { $0.value > 0 }
        guard !recentMoods.isEmpty else { return 0 }
        return recentMoods.map { $0.value }.reduce(0, +) / Double(recentMoods.count)
    }
    
    func saveMoodEntry() {
        guard selectedMood > 0 else { return }
        
        let entry = MoodEntry(mood: selectedMood, tags: Array(selectedTags))
        checkinService.saveMoodEntry(entry)
        
        // Show success toast
        toast = ToastData(message: "Mood logged! 🔥", type: .success)
        
        // Reset selection
        selectedMood = 0
        selectedTags.removeAll()
        
        // Trigger haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    func toggleTag(_ tag: MoodTag) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
    
    func isTagSelected(_ tag: MoodTag) -> Bool {
        selectedTags.contains(tag)
    }
    
    var canSave: Bool {
        selectedMood > 0
    }
    
    func moodEmoji(for mood: Int) -> String {
        switch mood {
        case 1: return "😢"
        case 2: return "😕"
        case 3: return "😐"
        case 4: return "🙂"
        case 5: return "😊"
        default: return "😐"
        }
    }
    
    func moodDescription(for mood: Int) -> String {
        switch mood {
        case 1: return "Awful"
        case 2: return "Bad"
        case 3: return "Okay"
        case 4: return "Good"
        case 5: return "Great"
        default: return "Select mood"
        }
    }
    
    func moodColor(for mood: Int) -> Color {
        switch mood {
        case 1: return .error
        case 2: return .warning
        case 3: return .textSecondary
        case 4: return .success
        case 5: return .brandPrimary
        default: return .textSecondary
        }
    }
}

#Preview {
    CheckinView(container: DIContainer.shared)
        .themeEnvironment()
}
