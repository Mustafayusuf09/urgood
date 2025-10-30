import SwiftUI

struct CheckinView: View {
    @StateObject private var viewModel: CheckinViewModel
    
    init(container: DIContainer) {
        self._viewModel = StateObject(wrappedValue: CheckinViewModel(
            checkinService: container.checkinService,
            localStore: container.localStore
        ))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    HeaderSection()
                    MoodPickerSection(viewModel: viewModel)
                    
                    if viewModel.selectedMood > 0 {
                        TagsSection(viewModel: viewModel)
                        SaveButtonSection(viewModel: viewModel)
                    }
                    
                    if viewModel.hasCheckedInToday {
                        TodayStatusCard()
                    }
                    
                    if !viewModel.recentTrends.isEmpty {
                        TrendsMiniCard(trends: viewModel.recentTrends, averageMood: viewModel.averageMood)
                    }
                    
                    InsightsCard()
                }
                .padding(.bottom, Spacing.xl)
            }
            .navigationTitle("Check-in")
            .navigationBarTitleDisplayMode(.large)
            .background(Color.background)
        }
    }
}

// MARK: - Header Section
private struct HeaderSection: View {
    var body: some View {
        VStack(spacing: Spacing.sm) {
            Text("How are you feeling?")
                .font(Typography.title)
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)
            
            Text("Take a moment to check in with yourself")
                .font(Typography.body)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Spacing.lg)
    }
}

// MARK: - Mood Picker Section
private struct MoodPickerSection: View {
    let viewModel: CheckinViewModel
    
    var body: some View {
        VStack(spacing: Spacing.md) {
            Text("Select your mood")
                .font(Typography.headline)
                .foregroundColor(.textPrimary)
            
            HStack(spacing: Spacing.lg) {
                ForEach(1...5, id: \.self) { mood in
                    MoodButton(mood: mood, viewModel: viewModel)
                }
            }
            .padding(.vertical, Spacing.md)
        }
    }
}

// MARK: - Individual Mood Button
private struct MoodButton: View {
    let mood: Int
    let viewModel: CheckinViewModel
    
    var body: some View {
        VStack(spacing: Spacing.sm) {
            Button(action: {
                viewModel.selectedMood = mood
            }) {
                Text(viewModel.moodEmoji(for: mood))
                    .font(.system(size: 40))
                    .scaleEffect(viewModel.selectedMood == mood ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.selectedMood)
            }
            .buttonStyle(PlainButtonStyle())
            
            Text(viewModel.moodDescription(for: mood))
                .font(Typography.footnote)
                .foregroundColor(
                    viewModel.selectedMood == mood
                    ? viewModel.moodColor(for: mood)
                    : .textSecondary
                )
        }
    }
}

// MARK: - Tags Section
private struct TagsSection: View {
    let viewModel: CheckinViewModel
    
    var body: some View {
        VStack(spacing: Spacing.md) {
            Text("What's affecting your mood? (optional)")
                .font(Typography.headline)
                .foregroundColor(.textPrimary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: Spacing.sm) {
                ForEach(viewModel.availableTags) { tag in
                    Chip(
                        title: tag.name,
                        isSelected: viewModel.isTagSelected(tag)
                    ) {
                        viewModel.toggleTag(tag)
                    }
                }
            }
        }
    }
}

// MARK: - Save Button Section
private struct SaveButtonSection: View {
    let viewModel: CheckinViewModel
    
    var body: some View {
        PrimaryButton("Save Check-in") {
            viewModel.saveMoodEntry()
        }
        .padding(.horizontal, Spacing.xl)
    }
}

// MARK: - Today Status Card
private struct TodayStatusCard: View {
    var body: some View {
        Card {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.success)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Today's check-in complete!")
                        .font(Typography.headline)
                        .foregroundColor(.textPrimary)
                    
                    Text("Great job taking care of yourself")
                        .font(Typography.footnote)
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, Spacing.md)
    }
}

// MARK: - Insights Card
private struct InsightsCard: View {
    @EnvironmentObject private var router: AppRouter
    var body: some View {
        Card {
            VStack(spacing: Spacing.sm) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.brandPrimary)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Detailed Insights")
                            .font(Typography.headline)
                            .foregroundColor(.textPrimary)
                        
                        Text("Unlock Core to see detailed mood patterns and personalized recommendations")
                            .font(Typography.footnote)
                            .foregroundColor(.textSecondary)
                    }
                    
                    Spacer()
                    
                    Badge("Core", style: .primary, size: .small)
                }
                
                PrimaryButton("Unlock Core", style: .secondary) {
                    router.present(.paywall, as: true)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
    }
}

// MARK: - Trends Mini Card
struct TrendsMiniCard: View {
    let trends: [TrendPoint]
    let averageMood: Double
    
    var body: some View {
        Card {
            VStack(spacing: Spacing.md) {
                HStack {
                    Text("7-Day Trend")
                        .font(Typography.headline)
                        .foregroundColor(.textPrimary)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: Spacing.xs) {
                        Text("Average")
                            .font(Typography.footnote)
                            .foregroundColor(.textSecondary)
                        
                        Text(String(format: "%.1f", averageMood))
                            .font(Typography.title3)
                            .foregroundColor(.brandPrimary)
                    }
                }
                
                // Simple sparkline
                HStack(spacing: 2) {
                    ForEach(trends) { trend in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(trend.value > 0 ? Color.brandPrimary : Color.textSecondary.opacity(0.3))
                            .frame(height: max(4, CGFloat(trend.value) * 8))
                    }
                }
                .frame(height: 40)
            }
        }
        .padding(.horizontal, Spacing.md)
    }
}

#Preview {
    CheckinView(container: DIContainer.shared)
        .themeEnvironment()
        .environmentObject(DIContainer.shared)
        .environmentObject(AppRouter())
}
