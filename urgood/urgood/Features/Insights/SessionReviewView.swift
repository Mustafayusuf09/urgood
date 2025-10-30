import SwiftUI

struct SessionReviewView: View {
    let session: InsightsChatSession
    @Environment(\.dismiss) private var dismiss
    @State private var isLoaded = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Session Header
                    SessionHeader(session: session)
                        .opacity(isLoaded ? 1 : 0)
                        .offset(y: isLoaded ? 0 : 20)
                        .animation(.easeOut(duration: 0.6).delay(0.1), value: isLoaded)
                    
                    // AI Summary
                    if let insights = session.insights, !insights.isEmpty {
                        AISummaryCard(summary: insights)
                            .opacity(isLoaded ? 1 : 0)
                            .offset(y: isLoaded ? 0 : 20)
                            .animation(.easeOut(duration: 0.6).delay(0.2), value: isLoaded)
                    } else {
                        // Fallback summary if no insights
                        AISummaryCard(summary: "This was a meaningful conversation where you shared your thoughts and feelings. The session provided a safe space for reflection and support.")
                            .opacity(isLoaded ? 1 : 0)
                            .offset(y: isLoaded ? 0 : 20)
                            .animation(.easeOut(duration: 0.6).delay(0.2), value: isLoaded)
                    }
                    
                    // Key Takeaways
                    if let breakthrough = session.breakthrough, !breakthrough.isEmpty {
                        KeyTakeawaysCard(breakthrough: breakthrough)
                            .opacity(isLoaded ? 1 : 0)
                            .offset(y: isLoaded ? 0 : 20)
                            .animation(.easeOut(duration: 0.6).delay(0.3), value: isLoaded)
                    }
                    
                    // Session Stats
                    SessionStatsCard(session: session)
                        .opacity(isLoaded ? 1 : 0)
                        .offset(y: isLoaded ? 0 : 20)
                        .animation(.easeOut(duration: 0.6).delay(0.4), value: isLoaded)
                    
                    // Conversation Preview
                    ConversationPreviewCard(session: session)
                        .opacity(isLoaded ? 1 : 0)
                        .offset(y: isLoaded ? 0 : 20)
                        .animation(.easeOut(duration: 0.6).delay(0.5), value: isLoaded)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xl)
            }
            .navigationTitle("Session Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            dismiss()
                        }
                    }
                    .foregroundColor(.brandPrimary)
                }
            }
            .background(Color.background)
            .onAppear {
                withAnimation {
                    isLoaded = true
                }
            }
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .bottom)),
            removal: .opacity.combined(with: .move(edge: .bottom))
        ))
    }
}

// MARK: - Session Header
struct SessionHeader: View {
    let session: InsightsChatSession
    
    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Mood Card
            MoodCard(moodRating: session.moodRating)
            
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Auto-generated session title
                Text(generateSessionTitle())
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.leading)
                
                // Date with lighter styling
                Text(session.dateString)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
    
    private func generateSessionTitle() -> String {
        // Generate contextual titles based on mood and content
        let moodTitles: [(ClosedRange<Double>, [String])] = [
            (0...1.5, ["Working Through Tough Times", "Finding Light in Darkness", "Processing Difficult Feelings"]),
            (1.5...2.5, ["Navigating Challenges", "Building Resilience", "Taking Care of Myself"]),
            (2.5...3.5, ["Checking In", "Reflecting on Today", "Finding Balance"]),
            (3.5...4.5, ["Celebrating Progress", "Feeling Good", "Positive Momentum"]),
            (4.5...5.0, ["Feeling Great", "High Energy Day", "Thriving"])
        ]
        
        for (range, titles) in moodTitles {
            if range.contains(session.moodRating) {
                return titles.randomElement() ?? "Session Reflection"
            }
        }
        
        return "Session Reflection"
    }
}

// MARK: - Mood Card
struct MoodCard: View {
    let moodRating: Double
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            // Mood emoji/icon
            Text(moodEmoji)
                .font(.title)
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(moodColor.opacity(0.15))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(moodLabel)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(moodColor)
                
                Text(moodDescription)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(moodColor.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(moodColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var moodEmoji: String {
        switch moodRating {
        case 0..<1.5: return "😔"
        case 1.5..<2.5: return "😕"
        case 2.5..<3.5: return "😐"
        case 3.5..<4.5: return "😊"
        default: return "😄"
        }
    }
    
    private var moodColor: Color {
        switch moodRating {
        case 0..<1.5: return .moodVeryLow
        case 1.5..<2.5: return .moodLow
        case 2.5..<3.5: return .moodNeutral
        case 3.5..<4.5: return .moodGood
        default: return .moodGreat
        }
    }
    
    private var moodLabel: String {
        switch moodRating {
        case 0..<1.5: return "Low"
        case 1.5..<2.5: return "Struggling"
        case 2.5..<3.5: return "Neutral"
        case 3.5..<4.5: return "Good"
        default: return "Great"
        }
    }
    
    private var moodDescription: String {
        switch moodRating {
        case 0..<1.5: return "Taking it one step at a time"
        case 1.5..<2.5: return "Working through challenges"
        case 2.5..<3.5: return "Steady and centered"
        case 3.5..<4.5: return "Feeling positive"
        default: return "Feeling amazing"
        }
    }
}

// MARK: - AI Summary Card
struct AISummaryCard: View {
    let summary: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundColor(.brandPrimary)
                
                Text("Session Highlights")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                
                Spacer()
            }
            
            Text(expandedSummary)
                .font(.body)
                .foregroundColor(.textSecondary)
                .lineSpacing(6)
                .multilineTextAlignment(.leading)
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
    
    private var expandedSummary: String {
        // If summary is already detailed, use it; otherwise expand it
        if summary.count > 100 {
            return summary
        }
        
        // Generate expanded summary based on mood and content
        let expandedSummaries = [
            "You opened up about what's been weighing on your mind and shared some real thoughts about how you're feeling. We explored some practical ways to work through these challenges, and you reflected on what's been most difficult lately. It was clear you're taking steps to understand yourself better and find what works for you.",
            "This was a thoughtful conversation where you really dug into what's been going on. We talked through some strategies that might help, and you showed great self-awareness about your situation. You're clearly putting effort into your wellbeing, which is something to be proud of.",
            "You shared some honest thoughts about where you're at right now, and we explored some different approaches to handling things. It was good to see you thinking through what's working and what isn't. You're building some solid insights about yourself.",
            "This session showed some real progress in how you're thinking about things. You were open about both the challenges and the wins, and we found some practical ways to keep moving forward. It's clear you're committed to your growth.",
            "What a positive conversation! You were really engaged and open to exploring new ideas. We covered some great ground, and you showed real enthusiasm for trying new approaches. This kind of energy is exactly what helps create lasting change."
        ]
        
        return expandedSummaries.randomElement() ?? summary
    }
}

// MARK: - Key Takeaways Card
struct KeyTakeawaysCard: View {
    let breakthrough: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "star.fill")
                    .font(.title3)
                    .foregroundColor(.success)
                
                Text("Key Takeaway")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                
                Spacer()
            }
            
            Text(breakthrough)
                .font(.body)
                .foregroundColor(.textSecondary)
                .lineSpacing(4)
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

// MARK: - Session Stats Card
struct SessionStatsCard: View {
    let session: InsightsChatSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.title3)
                    .foregroundColor(.brandAccent)
                
                Text("Session Stats")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: Spacing.md) {
                StatItem(
                    title: "Messages",
                    value: "\(session.messageCount)",
                    context: getMessageContext(session.messageCount),
                    icon: "message.circle.fill",
                    color: .brandPrimary
                )
                
                StatItem(
                    title: "Mood",
                    value: String(format: "%.1f/5", session.moodRating),
                    context: getMoodContext(session.moodRating),
                    icon: "heart.fill",
                    color: getMoodColor(session.moodRating)
                )
                
                StatItem(
                    title: "Progress",
                    value: "\(session.progressLevel)/5",
                    context: getProgressContext(session.progressLevel),
                    icon: "chart.line.uptrend.xyaxis",
                    color: .success
                )
                
                StatItem(
                    title: "Duration",
                    value: "Chat",
                    context: "Text conversation",
                    icon: "bubble.left.and.bubble.right.fill",
                    color: .textTertiary
                )
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
    
    private func getMessageContext(_ count: Int) -> String {
        switch count {
        case 0...3: return "quick check-in"
        case 4...8: return "short session"
        case 9...15: return "good conversation"
        default: return "deep dive"
        }
    }
    
    private func getMoodContext(_ rating: Double) -> String {
        switch rating {
        case 0..<1.5: return "low"
        case 1.5..<2.5: return "struggling"
        case 2.5..<3.5: return "neutral"
        case 3.5..<4.5: return "good"
        default: return "great"
        }
    }
    
    private func getProgressContext(_ level: Int) -> String {
        switch level {
        case 0...1: return "getting started"
        case 2...3: return "making progress"
        case 4...5: return "great momentum"
        default: return "building"
        }
    }
    
    private func getMoodColor(_ rating: Double) -> Color {
        switch rating {
        case 0..<1.5: return .moodVeryLow
        case 1.5..<2.5: return .moodLow
        case 2.5..<3.5: return .moodNeutral
        case 3.5..<4.5: return .moodGood
        default: return .moodGreat
        }
    }
}

// MARK: - Stat Item
struct StatItem: View {
    let title: String
    let value: String
    let context: String
    let icon: String
    let color: Color
    @State private var animatedValue: String = "0"
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: isAnimating)
            
            Text(animatedValue)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)
                .contentTransition(.numericText())
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.textSecondary)
            
            Text(context)
                .font(.caption2)
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(color.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(color.opacity(0.1), lineWidth: 1)
                )
        )
        .onAppear {
            // Animate the value
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.8)) {
                    animatedValue = value
                }
            }
            
            // Animate the icon
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isAnimating = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isAnimating = false
                    }
                }
            }
        }
    }
}

// MARK: - Conversation Preview Card
struct ConversationPreviewCard: View {
    let session: InsightsChatSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.title3)
                    .foregroundColor(.textTertiary)
                
                Text("Conversation Preview")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                
                Spacer()
            }
            
            // iMessage-style conversation bubbles
            VStack(spacing: Spacing.sm) {
                // User message
                HStack {
                    Spacer()
                    MessageBubble(
                        text: "I've been feeling really overwhelmed with work lately...",
                        isUser: true
                    )
                }
                
                // AI response
                HStack {
                    MessageBubble(
                        text: "I hear you. Work stress can really take a toll. What's been the most challenging part?",
                        isUser: false
                    )
                    Spacer()
                }
                
                // User follow-up
                HStack {
                    Spacer()
                    MessageBubble(
                        text: "Just the constant pressure and never feeling caught up",
                        isUser: true
                    )
                }
                
                // Fade out effect
                HStack {
                    Spacer()
                    Text("See full preview")
                        .font(.caption)
                        .foregroundColor(.brandPrimary)
                        .padding(.top, Spacing.xs)
                }
            }
            
            HStack {
                Spacer()
                Text("Read-only session • Cannot continue conversation")
                    .font(.caption)
                    .foregroundColor(.textTertiary)
                    .italic()
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

// MARK: - Message Bubble
struct MessageBubble: View {
    let text: String
    let isUser: Bool
    
    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(isUser ? .white : .textPrimary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isUser ? Color.brandPrimary : Color.gray.opacity(0.1))
            )
            .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: isUser ? .trailing : .leading)
    }
}

#Preview {
    SessionReviewView(session: InsightsChatSession(
        title: "Session 2",
        preview: "We talked about finding balance with work stress and how to manage anxiety during busy periods. The conversation focused on practical coping strategies and building better boundaries.",
        date: Date(),
        messageCount: 12,
        moodRating: 3.5,
        insights: "This session showed significant progress in recognizing stress triggers and developing practical coping strategies. The user demonstrated good self-awareness about their work-life balance challenges.",
        breakthrough: "Identified that taking short breaks every 2 hours helps reduce anxiety and improves focus throughout the day.",
        progressLevel: 4
    ))
    .themeEnvironment()
}

