import SwiftUI

struct InsightsView: View {
    @StateObject private var viewModel: InsightsViewModel
    @StateObject private var streaksViewModel: StreaksViewModel
    @State private var showingMoodPicker = false
    @State private var selectedSession: InsightsChatSession?
    @State private var showingSessionReview = false
    
    init(container: DIContainer) {
        self._viewModel = StateObject(wrappedValue: InsightsViewModel(
            checkinService: container.checkinService,
            chatService: container.chatService,
            localStore: container.localStore,
            billingService: container.billingService
        ))
        self._streaksViewModel = StateObject(wrappedValue: StreaksViewModel(
            localStore: container.localStore,
            billingService: container.billingService,
            authService: container.authService
        ))
    }
    
    var body: some View {
        ZStack {
            Color.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Streak Dashboard Section
                    StreakDashboardSection(
                        currentStreak: streaksViewModel.currentStreak,
                        streakMessage: streaksViewModel.streakMessage,
                        nextMilestone: streaksViewModel.nextMilestone,
                        progressToNextMilestone: streaksViewModel.progressToNextMilestone
                    )
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
                    
                    // Hero Check-in Section
                    HeroCheckinSection(
                        hasCheckedInToday: viewModel.hasCheckedInToday,
                        onTap: { showingMoodPicker = true }
                    )
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.xl)
                    
                    // Weekly Mood Tracker Section
                    if !viewModel.weeklyMoods.isEmpty {
                        WeeklyMoodSection(moods: viewModel.weeklyMoods)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.top, Spacing.xl)
                    }
                    
                    // Weekly Recap Section
                    if let weeklyRecap = viewModel.weeklyRecap {
                        WeeklyRecapSection(
                            recap: weeklyRecap,
                            isPremium: streaksViewModel.billingService.isSubscribed(),
                            onUpgrade: { viewModel.upgradeToPremium() }
                        )
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, Spacing.xl)
                    }
                    
                    // Progress Stats Section
                    ProgressStatsSection(
                        totalCheckins: streaksViewModel.totalCheckins,
                        messagesThisWeek: streaksViewModel.messagesThisWeek,
                        averageMood: viewModel.averageMood,
                        totalSessions: viewModel.totalSessions
                    )
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.xl)
                    
                    // Your Journey Section
                    YourJourneySection(
                        sessions: viewModel.recentSessions,
                        onSessionTap: { session in
                            selectedSession = session
                            showingSessionReview = true
                        }
                    )
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.xl)
                    .padding(.bottom, 100) // Space for FAB
                }
            }
            .refreshable {
                viewModel.refreshData()
                streaksViewModel.refreshStats()
            }
            
            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FloatingActionButton {
                        showingMoodPicker = true
                    }
                    .padding(.trailing, Spacing.lg)
                    .padding(.bottom, Spacing.lg)
                }
            }
        }
        .sheet(isPresented: $showingMoodPicker) {
            QuickMoodPicker(
                onMoodSelected: { mood, tags in
                    viewModel.saveQuickCheckin(mood: mood, tags: tags)
                    showingMoodPicker = false
                }
            )
        }
        .sheet(isPresented: $showingSessionReview) {
            if let session = selectedSession {
                SessionReviewView(session: session)
            }
        }
        .sheet(isPresented: $viewModel.showPremiumUpgrade) {
            PaywallView(
                isPresented: $viewModel.showPremiumUpgrade,
                onUpgrade: { _ in
                    viewModel.showPremiumUpgrade = false
                    // Upgrade flow handled by BillingService
                },
                onDismiss: {
                    viewModel.showPremiumUpgrade = false
                },
                billingService: streaksViewModel.billingService
            )
        }
    }
}

// MARK: - Streak Dashboard Section
struct StreakDashboardSection: View {
    let currentStreak: Int
    let streakMessage: String
    let nextMilestone: String
    let progressToNextMilestone: Double
    
    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Streak Ring and Message
            VStack(spacing: Spacing.md) {
                StreakRing(streak: currentStreak)
                
                VStack(spacing: Spacing.sm) {
                    Text(streakMessage)
                        .font(Typography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text(nextMilestone)
                        .font(Typography.body)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
                
                // Progress to next milestone
                if currentStreak > 0 {
                    VStack(spacing: Spacing.sm) {
                        HStack {
                            Text("Progress to next milestone")
                                .font(Typography.footnote)
                                .foregroundColor(.textSecondary)
                            
                            Spacer()
                            
                            Text("\(Int(progressToNextMilestone * 100))%")
                                .font(Typography.footnote)
                                .fontWeight(.medium)
                                .foregroundColor(.brandPrimary)
                        }
                        
                        ProgressView(value: progressToNextMilestone)
                            .progressViewStyle(LinearProgressViewStyle(tint: .brandPrimary))
                    }
                    .padding(.horizontal, Spacing.lg)
                }
            }
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.xl)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.brandPrimary.opacity(0.05),
                                Color.brandAccent.opacity(0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(
                        color: Color.brandPrimary.opacity(0.1),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
            )
        }
    }
}

// MARK: - Hero Check-in Section
struct HeroCheckinSection: View {
    let hasCheckedInToday: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Hero Card with Gradient Background
        Button(action: onTap) {
                VStack(spacing: Spacing.md) {
                    HStack {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text(hasCheckedInToday ? "Check-in complete! 🌱" : "How are you feeling today?")
                                .font(Typography.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)
                            
                            Text(hasCheckedInToday ? "Great job taking care of yourself" : "Take a quick moment to check in with yourself")
                                .font(Typography.body)
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.leading)
                        }
                        
                        Spacer()
                        
                        // Animated Icon
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 60, height: 60)
                            
                            if hasCheckedInToday {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                            } else {
                                Image(systemName: "heart.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .scaleEffect(hasCheckedInToday ? 1.0 : 1.1)
                                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: hasCheckedInToday)
                            }
                        }
                    }
                    
                    // CTA Button
                    HStack {
                        Text(hasCheckedInToday ? "View Progress" : "Check in now")
                            .font(Typography.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.brandPrimary)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right")
                            .font(.headline)
                            .foregroundColor(.brandPrimary)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .fill(Color.white)
                    )
                }
                .padding(Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.xl)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.brandPrimary,
                                    Color.brandAccent
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(
                            color: Color.brandPrimary.opacity(0.3),
                            radius: 12,
                            x: 0,
                            y: 6
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - Weekly Mood Section
struct WeeklyMoodSection: View {
    let moods: [InsightsViewDailyMood]
    @State private var animatedMoods: [Double] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Section Header
            HStack {
                Text("This Week")
                    .font(Typography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                Text("Mood Tracker")
                    .font(Typography.caption)
                    .foregroundColor(.textSecondary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .fill(Color.brandPrimary.opacity(0.1))
                    )
            }
            
            // Mood Chart with Gradient Bars
            VStack(spacing: Spacing.md) {
                HStack(alignment: .bottom, spacing: Spacing.sm) {
                    ForEach(Array(moods.enumerated()), id: \.element.id) { index, mood in
                        VStack(spacing: Spacing.sm) {
                            // Mood Bar with Gradient
                            ZStack(alignment: .bottom) {
                                // Background bar
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.surfaceSecondary)
                                    .frame(width: 40, height: 80)
                                
                                // Animated mood bar
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(moodGradient(for: mood.value))
                                    .frame(
                                        width: 40,
                                        height: animatedMoods.indices.contains(index) ? 
                                            max(8, CGFloat(animatedMoods[index]) * 12) : 8
                                    )
                                    .animation(
                                        .easeInOut(duration: 0.8)
                                        .delay(Double(index) * 0.1),
                                        value: animatedMoods
                                    )
                            }
                            
                            // Day Label
                            Text(mood.dayOfWeek)
                                .font(Typography.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.textSecondary)
                            
                            // Mood Emoji
                            Text(moodEmoji(for: mood.value))
                                .font(.title3)
                                .opacity(mood.value > 0 ? 1.0 : 0.3)
                        }
                    }
                }
                .frame(height: 120)
                
                // Average Mood Summary
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Weekly Average")
                            .font(Typography.caption)
                            .foregroundColor(.textSecondary)
                        
                        HStack(spacing: Spacing.xs) {
                            Text(String(format: "%.1f", averageMood))
                                .font(Typography.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.textPrimary)
                            
                            Text("/ 5.0")
                                .font(Typography.footnote)
                                .foregroundColor(.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Mood Trend Indicator
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: moodTrendIcon)
                    .font(.caption)
                            .foregroundColor(moodTrendColor)
                        
                        Text(moodTrendText)
                            .font(Typography.caption)
                            .foregroundColor(moodTrendColor)
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .fill(moodTrendColor.opacity(0.1))
                    )
                }
            }
        }
        .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(Color.surface)
                    .shadow(
                        color: Shadows.card.color,
                        radius: Shadows.card.radius,
                        x: Shadows.card.x,
                        y: Shadows.card.y
                    )
            )
        .onAppear {
            // Animate mood bars on appear
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                animatedMoods = moods.map { $0.value }
            }
        }
    }
    
    private var averageMood: Double {
        moods.isEmpty ? 0 : moods.map(\.value).reduce(0, +) / Double(moods.count)
    }
    
    private var moodTrendIcon: String {
        guard moods.count >= 2 else { return "minus" }
        let recent = moods.suffix(3).map(\.value)
        let trend = recent.last! - recent.first!
        
        if trend > 0.5 { return "arrow.up" }
        else if trend < -0.5 { return "arrow.down" }
        else { return "minus" }
    }
    
    private var moodTrendColor: Color {
        guard moods.count >= 2 else { return .textSecondary }
        let recent = moods.suffix(3).map(\.value)
        let trend = recent.last! - recent.first!
        
        if trend > 0.5 { return .success }
        else if trend < -0.5 { return .error }
        else { return .textSecondary }
    }
    
    private var moodTrendText: String {
        guard moods.count >= 2 else { return "Stable" }
        let recent = moods.suffix(3).map(\.value)
        let trend = recent.last! - recent.first!
        
        if trend > 0.5 { return "Improving" }
        else if trend < -0.5 { return "Declining" }
        else { return "Stable" }
    }
    
    private func moodGradient(for value: Double) -> LinearGradient {
        let colors = moodColors(for: value)
        return LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private func moodColors(for value: Double) -> [Color] {
        switch value {
        case 0..<1.5: return [Color.moodVeryLow, Color.moodVeryLow.opacity(0.7)]
        case 1.5..<2.5: return [Color.moodLow, Color.moodLow.opacity(0.7)]
        case 2.5..<3.5: return [Color.moodNeutral, Color.moodNeutral.opacity(0.7)]
        case 3.5..<4.5: return [Color.moodGood, Color.moodGood.opacity(0.7)]
        default: return [Color.moodGreat, Color.moodGreat.opacity(0.7)]
        }
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

// MARK: - Progress Stats Section
struct ProgressStatsSection: View {
    let totalCheckins: Int
    let messagesThisWeek: Int
    let averageMood: Double
    let totalSessions: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Your Progress")
                .font(Typography.title3)
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: Spacing.md) {
                ProgressStatCard(
                    title: "Check-ins",
                    value: "\(totalCheckins)",
                    icon: "heart.fill",
                    color: .success
                )
                
                
                ProgressStatCard(
                    title: "Messages This Week",
                    value: "\(messagesThisWeek)",
                    icon: "message.fill",
                    color: .brandSecondary
                )
                
                ProgressStatCard(
                    title: "Average Mood",
                    value: String(format: "%.1f", averageMood),
                    icon: "smile.fill",
                    color: .brandAccent
                )
                
                ProgressStatCard(
                    title: "Total Sessions",
                    value: "\(totalSessions)",
                    icon: "bubble.left.and.bubble.right.fill",
                    color: .brandPrimary
                )
            }
        }
    }
}

// MARK: - Progress Stat Card
struct ProgressStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(Typography.title2)
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)
            
            Text(title)
                    .font(Typography.footnote)
                    .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(Color.surface)
                .shadow(
                    color: Shadows.card.color,
                    radius: Shadows.card.radius,
                    x: Shadows.card.x,
                    y: Shadows.card.y
                )
        )
    }
}

// MARK: - Your Journey Section
struct YourJourneySection: View {
    let sessions: [InsightsChatSession]
    let onSessionTap: (InsightsChatSession) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack {
                Text("Recent Sessions")
                    .font(Typography.title3)
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)
                
                Spacer()
                
                if !sessions.isEmpty {
                    Text("\(sessions.count) sessions")
                        .font(Typography.caption)
                        .foregroundColor(.textSecondary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.sm)
                                .fill(Color.brandPrimary.opacity(0.1))
                        )
                }
            }
            
            if sessions.isEmpty {
                EmptyState(
                    icon: "heart.text.square",
                    title: "Day zero just means your streak is ready",
                    subtitle: "Tap in today to start the glow ✨"
                )
                .frame(height: 120)
            } else {
                LazyVStack(spacing: Spacing.md) {
                    ForEach(sessions) { session in
                        SessionCard(
                            session: session,
                            onTap: { onSessionTap(session) }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Session Card (Modern Design)
struct SessionCard: View {
    let session: InsightsChatSession
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.md) {
                // Session Type Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(sessionTypeColor.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: sessionTypeIcon)
                    .font(.title2)
                        .foregroundColor(sessionTypeColor)
                }
                
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    // Session Type and Date
                    HStack {
                        Text(sessionTypeTitle)
                            .font(Typography.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.textPrimary)
                        
                        Spacer()
                        
                        Text(session.dateString)
                            .font(Typography.caption)
                            .foregroundColor(.textSecondary)
                    }
                    
                    // Session Preview with Tags
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                    if !session.preview.isEmpty {
                        Text(session.preview)
                                .font(Typography.subheadline)
                            .foregroundColor(.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        }
                        
                        // Session Tags/Highlights
                        if let insights = session.insights, !insights.isEmpty {
                            HStack {
                                Text(insights)
                                    .font(Typography.caption)
                                    .foregroundColor(sessionTypeColor)
                                    .padding(.horizontal, Spacing.sm)
                                    .padding(.vertical, Spacing.xs)
                                    .background(
                                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                                            .fill(sessionTypeColor.opacity(0.1))
                                    )
                                
                                Spacer()
                            }
                        }
                        
                        // Mood and Progress Indicators
                        HStack {
                            // Mood Indicator
                            HStack(spacing: Spacing.xs) {
                                Text(moodEmoji)
                                    .font(.caption)
                                
                                Text(moodText)
                                    .font(Typography.caption)
                                    .foregroundColor(.textSecondary)
                            }
                            
                            Spacer()
                            
                            // Progress Level
                            HStack(spacing: 2) {
                                ForEach(0..<5) { index in
                                    Circle()
                                        .fill(index < session.progressLevel ? sessionTypeColor : Color.surfaceSecondary)
                                        .frame(width: 6, height: 6)
                                }
                            }
                        }
                    }
                }
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.textTertiary)
            }
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(Color.surface)
                    .shadow(
                        color: Shadows.card.color,
                        radius: Shadows.card.radius,
                        x: Shadows.card.x,
                        y: Shadows.card.y
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var sessionTypeIcon: String {
        let title = session.title.lowercased()
        
        if title.contains("anxiety") || title.contains("worried") || title.contains("nervous") {
            return "brain.head.profile"
        } else if title.contains("sad") || title.contains("depressed") || title.contains("down") {
            return "heart.fill"
        } else if title.contains("stress") || title.contains("overwhelmed") || title.contains("pressure") {
            return "wind"
        } else if title.contains("relationship") || title.contains("friend") || title.contains("family") {
            return "person.2.fill"
        } else if title.contains("work") || title.contains("career") || title.contains("job") {
            return "briefcase.fill"
        } else if title.contains("sleep") || title.contains("tired") || title.contains("rest") {
            return "moon.fill"
        } else if title.contains("goal") || title.contains("plan") || title.contains("future") {
            return "target"
        } else {
            return "message.fill"
        }
    }
    
    private var sessionTypeColor: Color {
        let title = session.title.lowercased()
        
        if title.contains("anxiety") || title.contains("worried") || title.contains("nervous") {
            return .brandPrimary
        } else if title.contains("sad") || title.contains("depressed") || title.contains("down") {
            return .brandAccent
        } else if title.contains("stress") || title.contains("overwhelmed") || title.contains("pressure") {
            return .warning
        } else if title.contains("relationship") || title.contains("friend") || title.contains("family") {
            return .success
        } else if title.contains("work") || title.contains("career") || title.contains("job") {
            return .brandSecondary
        } else if title.contains("sleep") || title.contains("tired") || title.contains("rest") {
            return .brandElectric
        } else if title.contains("goal") || title.contains("plan") || title.contains("future") {
            return .brandSecondary
        } else {
            return .textSecondary
        }
    }
    
    private var sessionTypeTitle: String {
        let title = session.title.lowercased()
        
        if title.contains("anxiety") || title.contains("worried") || title.contains("nervous") {
            return "Anxiety Support"
        } else if title.contains("sad") || title.contains("depressed") || title.contains("down") {
            return "Emotional Support"
        } else if title.contains("stress") || title.contains("overwhelmed") || title.contains("pressure") {
            return "Stress Relief"
        } else if title.contains("relationship") || title.contains("friend") || title.contains("family") {
            return "Relationships"
        } else if title.contains("work") || title.contains("career") || title.contains("job") {
            return "Career Guidance"
        } else if title.contains("sleep") || title.contains("tired") || title.contains("rest") {
            return "Sleep & Wellness"
        } else if title.contains("goal") || title.contains("plan") || title.contains("future") {
            return "Goal Setting"
        } else {
            return session.title
        }
    }
    
    private var moodEmoji: String {
        switch session.moodRating {
        case 0..<1.5: return "😔"
        case 1.5..<2.5: return "😕"
        case 2.5..<3.5: return "😐"
        case 3.5..<4.5: return "😊"
        default: return "😄"
        }
    }
    
    private var moodText: String {
        switch session.moodRating {
        case 0..<1.5: return "Very Low"
        case 1.5..<2.5: return "Low"
        case 2.5..<3.5: return "Neutral"
        case 3.5..<4.5: return "Good"
        default: return "Great"
        }
    }
}

// MARK: - Floating Action Button
struct FloatingActionButton: View {
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.brandPrimary,
                                Color.brandAccent
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .shadow(
                        color: Color.brandPrimary.opacity(0.3),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                    .scaleEffect(isPressed ? 0.95 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isPressed)
                
                Image(systemName: "plus")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Quick Mood Picker
struct QuickMoodPicker: View {
    let onMoodSelected: (Int, [String]) -> Void
    @State private var selectedMood: Int = 0
    @State private var selectedTags: Set<String> = []
    @Environment(\.dismiss) private var dismiss
    
    private let availableTags = ["Work", "Relationships", "Health", "Sleep", "Exercise", "Social", "Family", "Stress"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: Spacing.lg) {
                VStack(spacing: Spacing.md) {
                    Text("How are you feeling?")
                        .font(Typography.title2)
                        .foregroundColor(.textPrimary)
                    
                    // Mood picker
                    HStack(spacing: Spacing.lg) {
                        ForEach(1...5, id: \.self) { mood in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedMood = mood
                                }
                            }) {
                                VStack(spacing: Spacing.sm) {
                                    if selectedMood == mood {
                                        MoodAnimation(mood: mood)
                                    } else {
                                        Text(moodEmoji(for: mood))
                                            .font(.system(size: 40))
                                    }
                                    
                                    Text(moodDescription(for: mood))
                                        .font(Typography.caption)
                                        .foregroundColor(selectedMood == mood ? moodColor(for: mood) : .textSecondary)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.vertical, Spacing.md)
                }
                
                if selectedMood > 0 {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("What's affecting your mood? (optional)")
                            .font(Typography.headline)
                            .foregroundColor(.textPrimary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: Spacing.sm) {
                            ForEach(availableTags, id: \.self) { tag in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if selectedTags.contains(tag) {
                                            selectedTags.remove(tag)
                                        } else {
                                            selectedTags.insert(tag)
                                        }
                                    }
                                }) {
                                    Text(tag)
                                        .font(Typography.footnote)
                                        .foregroundColor(selectedTags.contains(tag) ? .white : .textSecondary)
                                        .padding(.horizontal, Spacing.md)
                                        .padding(.vertical, Spacing.sm)
                                        .background(
                                            RoundedRectangle(cornerRadius: CornerRadius.lg)
                                                .fill(selectedTags.contains(tag) ? Color.brandPrimary : Color.surfaceSecondary)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
                
                Spacer()
                
                if selectedMood > 0 {
                    PrimaryButton("Save Check-in") {
                        onMoodSelected(selectedMood, Array(selectedTags))
                    }
                    .padding(.horizontal, Spacing.xl)
                }
            }
            .padding(Spacing.lg)
            .navigationTitle("Quick Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
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
    
    private func moodDescription(for mood: Int) -> String {
        switch mood {
        case 1: return "Very Low"
        case 2: return "Low"
        case 3: return "Neutral"
        case 4: return "Good"
        case 5: return "Great"
        default: return "Neutral"
        }
    }
    
    private func moodColor(for mood: Int) -> Color {
        switch mood {
        case 1: return .moodVeryLow
        case 2: return .moodLow
        case 3: return .moodNeutral
        case 4: return .moodGood
        case 5: return .moodGreat
        default: return .moodNeutral
        }
    }
}

// MARK: - Data Models
struct InsightsViewDailyMood: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let dayOfWeek: String
}

struct InsightsChatSession: Identifiable {
    let id = UUID()
    let title: String
    let preview: String
    let date: Date
    let messageCount: Int
    let moodRating: Double
    let insights: String?
    let breakthrough: String?
    let progressLevel: Int
    
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}



#Preview {
    InsightsView(container: DIContainer.shared)
        .themeEnvironment()
}
