import SwiftUI

struct VoiceFocusedInsightsView: View {
    private let container: DIContainer
    @StateObject private var viewModel: InsightsViewModel
    @StateObject private var streaksViewModel: StreaksViewModel
    @State private var showVoiceChat = false
    @State private var selectedTimeframe: TimeFrame = .week
    @State private var showingMoodPicker = false
    @State private var selectedSession: InsightsChatSession?
    
    enum TimeFrame: String, CaseIterable {
        case week = "This Week"
        case month = "This Month"
        case all = "All Time"
        
        var subtitle: String {
            switch self {
            case .week:
                return "Past 7 days"
            case .month:
                return "Past 30 days"
            case .all:
                return "Lifetime"
            }
        }
        
        func dateInterval(referenceDate: Date = Date()) -> DateInterval? {
            let calendar = Calendar.current
            switch self {
            case .week:
                guard let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: referenceDate)) else { return nil }
                let end = calendar.date(byAdding: .day, value: 1, to: referenceDate) ?? referenceDate
                return DateInterval(start: start, end: end)
            case .month:
                guard let start = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: referenceDate)) else { return nil }
                let end = calendar.date(byAdding: .day, value: 1, to: referenceDate) ?? referenceDate
                return DateInterval(start: start, end: end)
            case .all:
                return nil
            }
        }
    }
    
    init(container: DIContainer) {
        self.container = container
        _viewModel = StateObject(wrappedValue: InsightsViewModel(
            checkinService: container.checkinService,
            chatService: container.chatService,
            localStore: container.localStore,
            billingService: container.billingService
        ))
        _streaksViewModel = StateObject(wrappedValue: StreaksViewModel(
            localStore: container.localStore,
            billingService: container.billingService,
            authService: container.authService
        ))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                headerSection
                voiceSessionSummary
                quickMoodSection
                progressInsights
                recentVoiceSessions
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 100)
        }
        .background(
            Color.background
                .ignoresSafeArea()
                .allowsHitTesting(false)
        )
        .fullScreenCover(isPresented: $showVoiceChat) {
            EnhancedVoiceChatView()
        }
        .sheet(isPresented: $showingMoodPicker) {
            QuickMoodPicker { mood, tags in
                viewModel.saveQuickCheckin(mood: mood, tags: tags)
                streaksViewModel.refreshStats()
                showingMoodPicker = false
            }
        }
        .sheet(item: $selectedSession) { session in
            SessionReviewView(session: session)
        }
        .sheet(isPresented: $viewModel.showPremiumUpgrade) {
            PaywallView(
                isPresented: $viewModel.showPremiumUpgrade,
                onUpgrade: { _ in
                    viewModel.showPremiumUpgrade = false
                },
                onDismiss: {
                    viewModel.showPremiumUpgrade = false
                },
                billingService: streaksViewModel.billingService
            )
        }
        .refreshable {
            reloadData()
        }
        .onAppear {
            reloadData()
        }
    }
    
    private func reloadData() {
        viewModel.refreshData()
        streaksViewModel.refreshStats()
    }
    
    // MARK: - Derived Data
    
    private var filteredSessions: [InsightsChatSession] {
        guard let interval = selectedTimeframe.dateInterval() else {
            return viewModel.recentSessions
        }
        return viewModel.recentSessions.filter { interval.contains($0.date) }
    }
    
    private var totalMessagesInSelectedTimeframe: Int {
        filteredSessions.reduce(0) { $0 + $1.messageCount }
    }
    
    private var averageMoodForSelectedTimeframe: Double {
        let moods = filteredSessions
            .map(\.moodRating)
            .filter { $0 > 0 }
        
        if !moods.isEmpty {
            return moods.reduce(0, +) / Double(moods.count)
        }
        
        if selectedTimeframe == .week {
            let moodValues = viewModel.weeklyMoods.map(\.value)
            guard !moodValues.isEmpty else { return viewModel.averageMood }
            return moodValues.reduce(0, +) / Double(moodValues.count)
        }
        
        return viewModel.averageMood
    }
    
    private var averageMoodLabel: String {
        moodDescription(for: averageMoodForSelectedTimeframe)
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Journey")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)
                    
                    if let name = viewModel.weeklyRecap?.insights.first {
                        Text(name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.textSecondary)
                    } else {
                    Text("Insights from your voice sessions with UrGood (\"your good\")")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    showVoiceChat = true
                }) {
                    Image(systemName: "waveform")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.brandPrimary)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Start a new voice session")
            }
            
            HStack(spacing: 0) {
                ForEach(TimeFrame.allCases, id: \.self) { timeframe in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTimeframe = timeframe
                        }
                    }) {
                        Text(timeframe.rawValue)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(selectedTimeframe == timeframe ? .white : .textSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedTimeframe == timeframe ? Color.brandPrimary : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.surfaceSecondary)
            )
        }
    }
    
    private var voiceSessionSummary: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Voice Sessions")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.textPrimary)
                
                Spacer()
            }
            
            HStack(spacing: 16) {
                InsightsStatCard(
                    title: "Sessions",
                    value: filteredSessions.isEmpty ? "—" : "\(filteredSessions.count)",
                    subtitle: selectedTimeframe.subtitle,
                    color: .brandPrimary,
                    icon: "waveform"
                )
                
                InsightsStatCard(
                    title: "Avg Mood",
                    value: averageMoodForSelectedTimeframe > 0 ? String(format: "%.1f", averageMoodForSelectedTimeframe) : "—",
                    subtitle: averageMoodLabel,
                    color: .brandSecondary,
                    icon: "heart.text.square.fill"
                )
                
                InsightsStatCard(
                    title: "Streak",
                    value: streaksViewModel.currentStreak > 0 ? "\(streaksViewModel.currentStreak)" : "0",
                    subtitle: "Active days",
                    color: .success,
                    icon: "flame.fill"
                )
            }
        }
    }
    
    private var quickMoodSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("How are you feeling?")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                Button("More options") {
                    showingMoodPicker = true
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.brandPrimary)
                .buttonStyle(.plain)
            }
            
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { mood in
                    Button(action: {
                        handleQuickMoodSelection(mood)
                    }) {
                        VStack(spacing: 8) {
                            Text(moodEmoji(for: mood))
                                .font(.system(size: 32))
                            
                            Text(moodLabel(for: mood))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.brandPrimary.opacity(0.1), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Log mood: \(moodLabel(for: mood))")
                }
            }
            
            if viewModel.hasCheckedInToday {
                Text("Nice work logging a mood today. Keep the streak strong! 🔥")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private var progressInsights: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Your Progress")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                if let recap = viewModel.weeklyRecap, recap.hasEnoughData {
                    Button("View recap") {
                        viewModel.upgradeToPremium()
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.brandPrimary)
                    .buttonStyle(.plain)
                }
            }
            
            if let recap = viewModel.weeklyRecap, recap.hasEnoughData {
                ProgressInsightCard(
                    title: "Average Mood",
                    progress: normalized(recap.averageMood / 5.0),
                    description: "Feelings trending \(recap.moodTrend.displayName.lowercased()). Avg mood \(String(format: "%.1f", recap.averageMood)).",
                    color: .brandPrimary
                )
                
                ProgressInsightCard(
                    title: "Mood Momentum",
                    progress: progressForTrend(recap.moodTrend),
                    description: trendDescription(for: recap),
                    color: colorForTrend(recap.moodTrend)
                )
                
                if let insight = recap.insights.first {
                    ProgressInsightCard(
                        title: "Weekly Insight",
                        progress: normalized(Double(recap.totalMessages) / 40.0),
                        description: insight,
                        color: .brandAccent
                    )
                } else {
                    ProgressInsightCard(
                        title: "Consistency",
                        progress: normalized(Double(streaksViewModel.currentStreak) / 30.0),
                        description: "You are on a \(streaksViewModel.currentStreak) day streak. Stay consistent for deeper insights.",
                        color: .success
                    )
                }
            } else {
                ProgressInsightCard(
                    title: "Build Your Insights",
                    progress: normalized(Double(streaksViewModel.totalCheckins) / 5.0),
                    description: "Log a few more moods and sessions to unlock personalized insights.",
                    color: .brandPrimary
                )
            }
        }
    }
    
    private var recentVoiceSessions: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Recent Sessions")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                Button(action: {
                    showVoiceChat = true
                }) {
                    Text("Start New")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.brandPrimary)
                }
                .buttonStyle(.plain)
            }
            
            if filteredSessions.isEmpty {
                VStack(spacing: 12) {
                    Text("Start your first voice session to see insights ✨")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Log a mood to begin") {
                        showingMoodPicker = true
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.brandPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.brandPrimary.opacity(0.1), lineWidth: 1)
                        )
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(filteredSessions) { session in
                        VoiceSessionCard(session: session, totalMessages: totalMessagesInSelectedTimeframe) {
                            selectedSession = session
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func handleQuickMoodSelection(_ mood: Int) {
        viewModel.saveQuickCheckin(mood: mood, tags: [])
        streaksViewModel.refreshStats()
        container.hapticService.playMoodFeedback(for: mood * 2)
    }
    
    private func moodEmoji(for mood: Int) -> String {
        switch mood {
        case 1: return "😔"
        case 2: return "😕"
        case 3: return "😐"
        case 4: return "😊"
        case 5: return "😄"
        default: return "😐"
        }
    }
    
    private func moodLabel(for mood: Int) -> String {
        switch mood {
        case 1: return "Very Low"
        case 2: return "Low"
        case 3: return "Okay"
        case 4: return "Good"
        case 5: return "Great"
        default: return "Okay"
        }
    }
    
    private func moodDescription(for value: Double) -> String {
        switch value {
        case 0..<1.5: return "Very Low"
        case 1.5..<2.5: return "Low"
        case 2.5..<3.5: return "Balanced"
        case 3.5..<4.5: return "Positive"
        case 4.5...5: return "Thriving"
        default: return "Balanced"
        }
    }
    
    private func normalized(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
    
    private func progressForTrend(_ trend: MoodTrend) -> Double {
        switch trend {
        case .up:
            return 0.85
        case .stable:
            return 0.55
        case .down:
            return 0.25
        }
    }
    
    private func colorForTrend(_ trend: MoodTrend) -> Color {
        switch trend {
        case .up:
            return .success
        case .stable:
            return .brandSecondary
        case .down:
            return .error
        }
    }
    
    private func trendDescription(for recap: WeeklyRecap) -> String {
        switch recap.moodTrend {
        case .up:
            return "Energy is lifting compared to last week. Keep the momentum going."
        case .stable:
            return "Mood is holding steady. Try a different check-in style to unlock more."
        case .down:
            return "Mood dipped a little this week. Review recent sessions for patterns."
        }
    }
}

// MARK: - Insights Stat Card
struct InsightsStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.textPrimary)
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Progress Insight Card
struct ProgressInsightCard: View {
    let title: String
    let progress: Double
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textPrimary)
                
                Text(description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.leading)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.surfaceSecondary)
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(width: geometry.size.width * CGFloat(min(max(progress, 0), 1)), height: 6)
                    }
                }
                .frame(height: 6)
            }
            
            Spacer()
            
            Text("\(Int(min(max(progress, 0), 1) * 100))%")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Voice Session Card
struct VoiceSessionCard: View {
    let session: InsightsChatSession
    let totalMessages: Int
    let action: () -> Void
    
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
    
    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.brandPrimary.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "waveform")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.brandPrimary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(session.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.textPrimary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(moodEmoji(for: session.moodRating))
                            .font(.system(size: 16))
                    }
                    
                    Text(Self.relativeFormatter.localizedString(for: session.date, relativeTo: Date()))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textTertiary)
                    
                    Text(session.insights ?? session.preview)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.brandPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "ellipsis.message.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.textTertiary)
                        
                        Text("\(session.messageCount) messages")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.textTertiary)
                        
                        if totalMessages > 0 {
                            let share = max(Double(session.messageCount) / Double(totalMessages), 0)
                            Text("\(Int(share * 100))% of timeframe")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.textTertiary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.textTertiary)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.brandPrimary.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens session review")
    }
    
    private func moodEmoji(for value: Double) -> String {
        switch value {
        case 0..<1.5: return "😔"
        case 1.5..<2.5: return "😕"
        case 2.5..<3.5: return "😐"
        case 3.5..<4.5: return "😊"
        default: return "😄"
        }
    }
}

#Preview {
    VoiceFocusedInsightsView(container: DIContainer.shared)
}
