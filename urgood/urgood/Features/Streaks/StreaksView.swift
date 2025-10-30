import SwiftUI

struct StreaksView: View {
    @StateObject private var viewModel: StreaksViewModel
    
    init(container: DIContainer) {
        self._viewModel = StateObject(wrappedValue: StreaksViewModel(
            localStore: container.localStore,
            billingService: container.billingService,
            authService: container.authService
        ))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    StreakSection(viewModel: viewModel)
                    StatsSection(viewModel: viewModel)
                    StreaksWeeklyMoodSection(viewModel: viewModel)
                    StreaksRecentSessionsSection(viewModel: viewModel)
                    PremiumOfferSection(viewModel: viewModel)
                }
                .padding(.vertical, Spacing.lg)
            }
            .navigationTitle("Your Progress")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                viewModel.refreshStats()
            }
        }
    }
}

// MARK: - Streak Section
struct StreakSection: View {
    let viewModel: StreaksViewModel
    
    var body: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                StreakRing(streak: viewModel.currentStreak)
                    .padding(.bottom, Spacing.sm)
                
                VStack(spacing: Spacing.xs) {
                    Text("\(viewModel.currentStreak) day streak")
                        .font(Typography.title3)
                        .foregroundColor(.textPrimary)
                    Text(viewModel.nextMilestone)
                        .font(Typography.caption)
                        .foregroundColor(.brandAccent)
                }
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .fill(Color.surfaceSecondary.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.lg)
                                .stroke(Color.brandPrimary.opacity(0.1), lineWidth: 1)
                        )
                )
                .offset(y: viewModel.currentStreak == 0 ? 0 : sizeOffset)
            }
            .padding(.top, Spacing.md)
            
            Text(viewModel.streakMessage)
                .font(Typography.title2)
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, Spacing.md)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.currentStreak)
        }
        .padding(.horizontal, Spacing.lg)
    }
    
    private var sizeOffset: CGFloat {
        return -StreakRing(streak: viewModel.currentStreak).size * 0.55
    }
}

// MARK: - Stats Section
struct StatsSection: View {
    let viewModel: StreaksViewModel
    
    var body: some View {
        VStack(spacing: Spacing.md) {
            Text("Your Progress")
                .font(Typography.title2)
                .foregroundColor(.textPrimary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: Spacing.md) {
                StatCard(
                    title: "Check-ins",
                    value: "\(viewModel.totalCheckins)",
                    icon: "heart.fill",
                    color: .green
                )
                
                StatCard(
                    title: "Total Sessions",
                    value: "\(viewModel.totalSessions)",
                    icon: "bubble.left.and.bubble.right.fill",
                    color: .brandPrimary
                )
                
                StatCard(
                    title: "Messages This Week",
                    value: "\(viewModel.messagesThisWeek)",
                    icon: "message.fill",
                    color: .brandSecondary
                )
                
                StatCard(
                    title: "Current Streak",
                    value: "\(viewModel.currentStreak) Days",
                    icon: "flame.fill",
                    color: .orange
                )
            }
        }
        .padding(.horizontal, Spacing.lg)
    }
}

// MARK: - Weekly Mood Section
struct StreaksWeeklyMoodSection: View {
    let viewModel: StreaksViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("This Week's Mood")
                .font(Typography.title3)
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)
            
            if viewModel.weeklyMoodData.isEmpty {
                EmptyState(
                    icon: "heart.text.square",
                    title: "No mood data yet",
                    subtitle: "Check in daily to track your mood patterns."
                )
            } else {
                WeeklyMoodChart(data: viewModel.weeklyMoodData)
            }
        }
        .padding(.horizontal, Spacing.lg)
    }
}

// MARK: - Recent Sessions Section
struct StreaksRecentSessionsSection: View {
    let viewModel: StreaksViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Recent Sessions")
                .font(Typography.title3)
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)
            
            if viewModel.recentSessions.isEmpty {
                EmptyState(
                    icon: "bubble.left.and.bubble.right",
                    title: "No sessions yet",
                    subtitle: "Start chatting to begin your mental wellness journey."
                )
            } else {
                LazyVStack(spacing: Spacing.sm) {
                    ForEach(viewModel.recentSessions) { session in
                        StreaksSessionCard(session: session)
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
    }
}

// MARK: - Premium Offer Section
struct PremiumOfferSection: View {
    let viewModel: StreaksViewModel
    
    var body: some View {
        if !viewModel.isPremium {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Daily sessions keep your streaks flowing ✨")
                    .font(Typography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)
                
                Card {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.brandAccent)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text("Core Plan")
                                    .font(Typography.headline)
                                    .foregroundColor(.textPrimary)

                                Text("Daily voice sessions and unlimited text conversations")
                                    .font(Typography.body)
                                    .foregroundColor(.textSecondary)
                            }
                            
                            Spacer()
                        }
                        
                        Button(action: {
                            viewModel.unlockPremium()
                        }) {
                            Text("Upgrade to Core")
                                .font(Typography.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.md)
                                .background(Color.brandAccent)
                                .cornerRadius(CornerRadius.md)
                        }
                    }
                    .padding(Spacing.lg)
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        Card {
            VStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(value)
                    .font(Typography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)
                
                Text(title)
                    .font(Typography.caption)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(Spacing.md)
        }
    }
}

// MARK: - Weekly Mood Chart
struct WeeklyMoodChart: View {
    let data: [ViewModelDailyMood]
    
    var body: some View {
        Card {
            HStack(spacing: Spacing.sm) {
                ForEach(data, id: \.date) { mood in
                    VStack(spacing: Spacing.xs) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(moodColor(for: Int(mood.value.rounded())))
                            .frame(width: 20, height: max(4, CGFloat(mood.value) * 4))
                        
                        Text(dayOfWeek(for: mood.date))
                            .font(Typography.caption)
                            .foregroundColor(.textSecondary)
                    }
                }
            }
            .padding(Spacing.md)
        }
    }
    
    private func moodColor(for mood: Int) -> Color {
        switch mood {
        case 1...2: return .red
        case 3: return .yellow
        case 4...5: return .green
        default: return .gray
        }
    }
    
    private func dayOfWeek(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
}

// MARK: - Session Card
struct StreaksSessionCard: View {
    let session: InsightsChatSession
    
    var body: some View {
        Card {
            HStack(spacing: Spacing.md) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundColor(.brandPrimary)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(session.title)
                        .font(Typography.headline)
                        .foregroundColor(.textPrimary)
                    
                    Text(session.preview)
                        .font(Typography.body)
                        .foregroundColor(.textSecondary)
                        .lineLimit(2)
                    
                    Text(session.date, style: .relative)
                        .font(Typography.caption)
                        .foregroundColor(.textTertiary)
                }
                
                Spacer()
            }
            .padding(Spacing.md)
        }
    }
}

#Preview {
    StreaksView(container: DIContainer())
}
