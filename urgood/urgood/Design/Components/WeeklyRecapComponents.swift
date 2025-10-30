import SwiftUI

// MARK: - Weekly Recap Section
struct WeeklyRecapSection: View {
    let recap: WeeklyRecap
    let isPremium: Bool
    let onUpgrade: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Section Header
            HStack {
                Text("Weekly Recap")
                    .font(Typography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                Text("This Week")
                    .font(Typography.caption)
                    .foregroundColor(.textSecondary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .fill(Color.brandPrimary.opacity(0.1))
                    )
            }
            
            if recap.hasEnoughData {
                WeeklyRecapContent(recap: recap, isPremium: isPremium, onUpgrade: onUpgrade)
            } else {
                WeeklyRecapEmptyState()
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
    }
}

// MARK: - Weekly Recap Content
struct WeeklyRecapContent: View {
    let recap: WeeklyRecap
    let isPremium: Bool
    let onUpgrade: () -> Void
    
    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Mood Summary Row
            HStack(spacing: Spacing.lg) {
                // Average Mood
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Average Mood")
                        .font(Typography.caption)
                        .foregroundColor(.textSecondary)
                    
                    HStack(spacing: Spacing.xs) {
                        Text(String(format: "%.1f", recap.averageMood))
                            .font(Typography.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.textPrimary)
                        
                        Text("/ 5.0")
                            .font(Typography.footnote)
                            .foregroundColor(.textSecondary)
                    }
                }
                
                Spacer()
                
                // Mood Trend
                VStack(alignment: .trailing, spacing: Spacing.xs) {
                    Text("Trend")
                        .font(Typography.caption)
                        .foregroundColor(.textSecondary)
                    
                    HStack(spacing: Spacing.xs) {
                        Text(recap.moodTrend.emoji)
                            .font(.title3)
                        
                        Text(recap.moodTrend.displayName)
                            .font(Typography.footnote)
                            .fontWeight(.medium)
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
            
            // Top Tags
            if !recap.topTags.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Top Themes")
                        .font(Typography.caption)
                        .foregroundColor(.textSecondary)
                    
                    HStack(spacing: Spacing.sm) {
                        ForEach(recap.topTags.prefix(3)) { tag in
                            TagChip(tag: tag.tag, frequency: tag.frequency)
                        }
                        
                        Spacer()
                    }
                }
            }
            
            // Activity Stats
            HStack(spacing: Spacing.lg) {
                ActivityStat(
                    icon: "heart.fill",
                    title: "Check-ins",
                    value: "\(recap.totalCheckins)",
                    color: .success
                )
                
                Spacer()
                
                ActivityStat(
                    icon: "message.fill",
                    title: "Messages",
                    value: "\(recap.totalMessages)",
                    color: .brandPrimary
                )
            }
            
            // Insights (Premium Feature)
            if !recap.insights.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Insights")
                        .font(Typography.caption)
                        .foregroundColor(.textSecondary)
                    
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        ForEach(recap.insights.prefix(2), id: \.self) { insight in
                            HStack(alignment: .top, spacing: Spacing.sm) {
                                Text("•")
                                    .font(Typography.body)
                                    .foregroundColor(.brandPrimary)
                                
                                Text(insight)
                                    .font(Typography.body)
                                    .foregroundColor(.textPrimary)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                            }
                        }
                    }
                    .padding(Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .fill(Color.brandPrimary.opacity(0.05))
                    )
                    .overlay(
                        // Premium overlay for free users
                        Group {
                            if !isPremium {
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .fill(Color.black.opacity(0.7))
                                    .overlay(
                                        VStack(spacing: Spacing.sm) {
                                            Text("Unlock deeper insights with Premium ✨")
                                                .font(Typography.footnote)
                                                .fontWeight(.medium)
                                                .foregroundColor(.white)
                                                .multilineTextAlignment(.center)
                                            
                                            Button("Upgrade") {
                                                onUpgrade()
                                            }
                                            .font(Typography.caption)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, Spacing.md)
                                            .padding(.vertical, Spacing.xs)
                                            .background(Color.brandPrimary)
                                            .cornerRadius(CornerRadius.sm)
                                        }
                                    )
                            }
                        }
                    )
                }
            }
        }
    }
    
    private var moodTrendColor: Color {
        switch recap.moodTrend {
        case .up: return .success
        case .down: return .error
        case .stable: return .textSecondary
        }
    }
}

// MARK: - Weekly Recap Empty State
struct WeeklyRecapEmptyState: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.brandPrimary.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "calendar.badge.clock")
                    .font(.title2)
                    .foregroundColor(.brandPrimary)
            }
            
            VStack(spacing: Spacing.sm) {
                Text("Your first weekly recap arrives once you've logged a few days ✨")
                    .font(Typography.body)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Keep checking in to unlock your weekly insights!")
                    .font(Typography.caption)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Spacing.lg)
    }
}

// MARK: - Supporting Views
struct TagChip: View {
    let tag: String
    let frequency: Int
    
    var body: some View {
        HStack(spacing: Spacing.xs) {
            Text(tag)
                .font(Typography.caption)
                .foregroundColor(.brandPrimary)
            
            Text("(\(frequency))")
                .font(Typography.caption)
                .foregroundColor(.textSecondary)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .fill(Color.brandPrimary.opacity(0.1))
        )
    }
}

struct ActivityStat: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(Typography.title3)
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)
            
            Text(title)
                .font(Typography.caption)
                .foregroundColor(.textSecondary)
        }
    }
}
