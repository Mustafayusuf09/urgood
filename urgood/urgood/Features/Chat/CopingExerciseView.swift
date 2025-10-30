import SwiftUI

struct CopingExerciseView: View {
    let exercise: TherapyKnowledgeService.CopingExercise
    let onDismiss: () -> Void
    
    @State private var currentStep = 0
    @State private var isCompleted = false
    @State private var moodBefore: Double = 5
    @State private var moodAfter: Double = 5
    @State private var showMoodRating = false
    @State private var timer: Timer?
    @State private var timeRemaining: Int = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text(exercise.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    Text(exercise.category)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding(.top)
                
                if !isCompleted {
                    // Exercise content
                    VStack(spacing: 20) {
                        // Prompt
                        Text(exercise.genZPrompt)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        
                        // Steps
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Steps:")
                                .font(.headline)
                            
                            ForEach(Array(exercise.steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 12) {
                                    Circle()
                                        .fill(index <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Text("\(index + 1)")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .foregroundColor(index <= currentStep ? .white : .gray)
                                        )
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(step)
                                            .font(.body)
                                            .foregroundColor(index <= currentStep ? .primary : .secondary)
                                        
                                        if index == currentStep && timeRemaining > 0 {
                                            Text("Time remaining: \(timeRemaining)s")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    
                                    Spacer()
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        
                        // Controls
                        VStack(spacing: 12) {
                            if currentStep < exercise.steps.count - 1 {
                                Button("Next Step") {
                                    nextStep()
                                }
                                .buttonStyle(PrimaryButtonStyle())
                            } else {
                                Button("Complete Exercise") {
                                    completeExercise()
                                }
                                .buttonStyle(PrimaryButtonStyle())
                            }
                            
                            if currentStep > 0 {
                                Button("Previous Step") {
                                    previousStep()
                                }
                                .buttonStyle(SecondaryButtonStyle())
                            }
                        }
                    }
                } else {
                    // Completion view
                    completionView
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        onDismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text(exercise.duration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private var completionView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            Text("Great job!")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("You completed the \(exercise.name) exercise.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            // Mood rating
            VStack(spacing: 16) {
                Text("How are you feeling now?")
                    .font(.headline)
                
                VStack(spacing: 12) {
                    Text("Rate your mood (1-10)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Slider(value: $moodAfter, in: 1...10, step: 1)
                        .accentColor(.blue)
                    
                    Text("\(Int(moodAfter))/10")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            Button("Save & Close") {
                saveMoodRating()
                onDismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }
    
    private func nextStep() {
        if currentStep < exercise.steps.count - 1 {
            currentStep += 1
            startTimer()
        }
    }
    
    private func previousStep() {
        if currentStep > 0 {
            currentStep -= 1
            startTimer()
        }
    }
    
    private func completeExercise() {
        isCompleted = true
        timer?.invalidate()
        
        // Track completion
        FirebaseConfig.logEvent("coping_exercise_completed", parameters: [
            "exercise_id": exercise.id,
            "exercise_name": exercise.name,
            "category": exercise.category
        ])
    }
    
    private func startTimer() {
        timer?.invalidate()
        
        // Set timer based on step (rough estimate)
        switch currentStep {
        case 0:
            timeRemaining = 30 // Setup time
        case 1:
            timeRemaining = 60 // Main exercise time
        case 2:
            timeRemaining = 45 // Practice time
        default:
            timeRemaining = 30 // Default
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                timer?.invalidate()
            }
        }
    }
    
    private func saveMoodRating() {
        // Save mood improvement to local store
        let localStore = EnhancedLocalStore.shared
        
        // Create a mood entry for the exercise completion
        let moodEntry = MoodEntry(
            mood: Int(moodAfter),
            tags: [MoodTag(name: "After \(exercise.name) exercise")]
        )
        
        localStore.addMoodEntry(moodEntry)
        
        // Track mood improvement
        let improvement = moodAfter - moodBefore
        FirebaseConfig.logEvent("coping_exercise_mood_change", parameters: [
            "exercise_id": exercise.id,
            "mood_before": moodBefore,
            "mood_after": moodAfter,
            "improvement": improvement
        ])
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    CopingExerciseView(
        exercise: TherapyKnowledgeService.CopingExercise(
            id: "box-breathing",
            name: "Box Breathing Reset",
            category: "DBT-TIPP",
            steps: [
                "Find a comfortable spot and close your eyes or soften your gaze",
                "Breathe in for 4 counts, hold for 4, out for 4, hold for 4",
                "Repeat 4-6 cycles, focusing only on the counting",
                "Notice how your body feels different now"
            ],
            duration: "60-90 seconds",
            triggers: ["anxiety", "panic", "overwhelm", "anger"],
            genZPrompt: "Your nervous system is in overdrive right now. This breathing drill comes from DBT—clinics use it to dial emotions down in under two minutes. Ready to try it?",
            evidenceSource: "Stewart et al. (2020) - TIPP effectiveness in adolescents"
        ),
        onDismiss: {}
    )
}
