import SwiftUI

struct DailyScreeningView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentQuestionIndex = 0
    @State private var responses: [Int] = []
    @State private var isCompleted = false
    @State private var screeningResult: ScreeningResult?
    
    let screeningType: ScreeningType
    let onComplete: (ScreeningResult) -> Void
    
    private let therapyService = TherapyKnowledgeService.shared
    
    enum ScreeningType: String, CaseIterable {
        case phq2 = "PHQ-2"
        case gad2 = "GAD-2"
        
        var title: String {
            switch self {
            case .phq2: return "Depression Screening"
            case .gad2: return "Anxiety Screening"
            }
        }
        
        var description: String {
            switch self {
            case .phq2: return "Quick check-in about your mood over the past 2 weeks"
            case .gad2: return "Quick check-in about your anxiety over the past 2 weeks"
            }
        }
        
        var icon: String {
            switch self {
            case .phq2: return "heart.circle.fill"
            case .gad2: return "brain.head.profile"
            }
        }
        
        var color: Color {
            switch self {
            case .phq2: return .blue
            case .gad2: return .green
            }
        }
    }
    
    struct ScreeningResult {
        let type: ScreeningType
        let score: Int
        let level: String
        let recommendation: String
        let responses: [Int]
        let date: Date
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                if !isCompleted {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: screeningType.icon)
                            .font(.system(size: 48))
                            .foregroundColor(screeningType.color)
                        
                        VStack(spacing: 8) {
                            Text(screeningType.title)
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text(screeningType.description)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top)
                    
                    // Progress indicator
                    ProgressView(value: Double(currentQuestionIndex), total: Double(questions.count))
                        .progressViewStyle(LinearProgressViewStyle(tint: screeningType.color))
                        .padding(.horizontal)
                    
                    Text("Question \(currentQuestionIndex + 1) of \(questions.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Question
                    if currentQuestionIndex < questions.count {
                        questionView
                    }
                    
                    Spacer()
                } else {
                    // Results view
                    resultsView
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var questions: [String] {
        return therapyService.getScreeningQuestions(type: screeningType.rawValue)
    }
    
    private var responseOptions: [String] {
        return ["Not at all", "Several days", "More than half the days", "Nearly every day"]
    }
    
    private var questionView: some View {
        VStack(spacing: 24) {
            // Question text
            Text(questions[currentQuestionIndex])
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            
            // Response options
            VStack(spacing: 12) {
                ForEach(Array(responseOptions.enumerated()), id: \.offset) { index, option in
                    Button(action: {
                        selectResponse(index)
                    }) {
                        HStack {
                            Text(option)
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("\(index)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray5))
                                .cornerRadius(8)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    private var resultsView: some View {
        VStack(spacing: 24) {
            // Results header
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)
                
                Text("Screening Complete")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            if let result = screeningResult {
                // Score display
                VStack(spacing: 16) {
                    HStack {
                        Text("Your Score:")
                            .font(.headline)
                        
                        Spacer()
                        
                        Text("\(result.score)/6")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(scoreColor(for: result.level))
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Level indicator
                    HStack {
                        Circle()
                            .fill(scoreColor(for: result.level))
                            .frame(width: 12, height: 12)
                        
                        Text(result.level.capitalized)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                    }
                    
                    // Recommendation
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recommendation:")
                            .font(.headline)
                        
                        Text(result.recommendation)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                }
            }
            
            // Action buttons
            VStack(spacing: 12) {
                Button("Save Results") {
                    if let result = screeningResult {
                        onComplete(result)
                    }
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                
                if let result = screeningResult, result.level == "HIGH" {
                    Button("Find Professional Help") {
                        // TODO: Open professional help resources
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            
            Spacer()
        }
    }
    
    private func selectResponse(_ response: Int) {
        responses.append(response)
        
        if currentQuestionIndex < questions.count - 1 {
            // Move to next question
            withAnimation(.easeInOut(duration: 0.3)) {
                currentQuestionIndex += 1
            }
        } else {
            // Complete screening
            completeScreening()
        }
    }
    
    private func completeScreening() {
        let totalScore = responses.reduce(0, +)
        let interpretation = therapyService.interpretScreeningScore(totalScore, type: screeningType.rawValue)
        
        screeningResult = ScreeningResult(
            type: screeningType,
            score: totalScore,
            level: interpretation.level,
            recommendation: interpretation.recommendation,
            responses: responses,
            date: Date()
        )
        
        withAnimation(.easeInOut(duration: 0.5)) {
            isCompleted = true
        }
        
        // Track completion
        FirebaseConfig.logEvent("screening_completed", parameters: [
            "type": screeningType.rawValue,
            "score": totalScore,
            "level": interpretation.level
        ])
    }
    
    private func scoreColor(for level: String) -> Color {
        switch level.uppercased() {
        case "LOW":
            return .green
        case "MODERATE":
            return .orange
        case "HIGH":
            return .red
        default:
            return .gray
        }
    }
}

// MARK: - Daily Check-in Integration

struct DailyCheckInView: View {
    @State private var showPHQ2 = false
    @State private var showGAD2 = false
    @State private var completedToday = false
    
    private let localStore = EnhancedLocalStore.shared
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text("Daily Check-In")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Quick mental health screening (2-3 minutes)")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if !completedToday {
                // Screening options
                VStack(spacing: 16) {
                    ScreeningOptionCard(
                        type: .phq2,
                        onTap: { showPHQ2 = true }
                    )
                    
                    ScreeningOptionCard(
                        type: .gad2,
                        onTap: { showGAD2 = true }
                    )
                }
            } else {
                // Completed state
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    
                    Text("Check-in Complete!")
                        .font(.headline)
                    
                    Text("Come back tomorrow for your next check-in.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding()
        .sheet(isPresented: $showPHQ2) {
            DailyScreeningView(
                screeningType: .phq2,
                onComplete: handleScreeningComplete
            )
        }
        .sheet(isPresented: $showGAD2) {
            DailyScreeningView(
                screeningType: .gad2,
                onComplete: handleScreeningComplete
            )
        }
        .onAppear {
            checkIfCompletedToday()
        }
    }
    
    private func handleScreeningComplete(_ result: DailyScreeningView.ScreeningResult) {
        // Save to local store
        let entry = MoodEntry(
            mood: 10 - result.score, // Invert score for mood (lower screening score = better mood)
            tags: [MoodTag(name: "\(result.type.title): \(result.level)")]
        )
        
        localStore.addMoodEntry(entry)
        completedToday = true
        
        // Show coping exercises if score is concerning
        if result.level == "HIGH" || result.level == "MODERATE" {
            // TODO: Suggest appropriate coping exercises
        }
    }
    
    private func checkIfCompletedToday() {
        let today = Calendar.current.startOfDay(for: Date())
        let todayEntries = localStore.moodEntries.filter { entry in
            Calendar.current.isDate(entry.date, inSameDayAs: today)
        }
        
        completedToday = !todayEntries.isEmpty
    }
}

struct ScreeningOptionCard: View {
    let type: DailyScreeningView.ScreeningType
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundColor(type.color)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(type.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    DailyCheckInView()
}
