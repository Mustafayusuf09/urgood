import SwiftUI

struct CopingExerciseSuggestionView: View {
    let exercise: TherapyKnowledgeService.CopingExercise
    let onStart: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "heart.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Suggested Coping Exercise")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(exercise.category)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
            }
            
            // Exercise info
            VStack(alignment: .leading, spacing: 12) {
                Text(exercise.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text(exercise.genZPrompt)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                
                HStack {
                    Label(exercise.duration, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Text("\(exercise.steps.count) steps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Start Exercise") {
                    onStart()
                }
                .buttonStyle(PrimaryCTAButtonStyle())
                
                Button("Maybe Later") {
                    onDismiss()
                }
                .buttonStyle(SecondaryCTAButtonStyle())
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

// MARK: - Button Styles

struct PrimaryCTAButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.blue)
            .cornerRadius(20)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryCTAButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .foregroundColor(.blue)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(20)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    CopingExerciseSuggestionView(
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
        onStart: {},
        onDismiss: {}
    )
    .padding()
}
