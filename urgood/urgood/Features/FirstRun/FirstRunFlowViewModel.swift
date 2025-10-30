import SwiftUI

class FirstRunFlowViewModel: ObservableObject {
    @Published var currentStep: FirstRunStep = .welcomeSplash
    @Published var quizAnswers: [QuizAnswer] = []
    
    func nextStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if let currentIndex = FirstRunStep.allCases.firstIndex(of: currentStep),
               currentIndex + 1 < FirstRunStep.allCases.count {
                currentStep = FirstRunStep.allCases[currentIndex + 1]
            }
        }
    }
    
    func previousStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if let currentIndex = FirstRunStep.allCases.firstIndex(of: currentStep),
               currentIndex > 0 {
                currentStep = FirstRunStep.allCases[currentIndex - 1]
            }
        }
    }
    
    func saveQuizAnswers(_ answers: [QuizAnswer]) {
        quizAnswers = answers
        // Note: Quiz answers are now saved directly to Firebase via AuthenticationService
    }
    
    func reset() {
        currentStep = .welcomeSplash
        quizAnswers = []
    }
}

// MARK: - First Run Steps
enum FirstRunStep: CaseIterable {
    case welcomeSplash
    case assessmentWelcome
    case quickQuiz
    case calculating
    case signUpWall
}

// MARK: - Quiz Models
struct QuizQuestion {
    let question: String
    let options: [QuizOption]
    
    static let sampleQuestions: [QuizQuestion] = [
        QuizQuestion(
            question: "What's the main thing you want to work on right now?",
            options: [
                QuizOption(text: "Focus better", emoji: "🎯"),
                QuizOption(text: "Feel healthier", emoji: "💪"),
                QuizOption(text: "Improve relationships", emoji: "❤️"),
                QuizOption(text: "Reduce stress", emoji: "🧘")
            ]
        ),
        QuizQuestion(
            question: "How often do your habits get in the way of your goals?",
            options: [
                QuizOption(text: "Rarely", emoji: "😊"),
                QuizOption(text: "Sometimes", emoji: "🤔"),
                QuizOption(text: "Often", emoji: "😅"),
                QuizOption(text: "Most days", emoji: "😰")
            ]
        ),
        QuizQuestion(
            question: "When you try to cut back, how tough does it feel?",
            options: [
                QuizOption(text: "Easy", emoji: "😎"),
                QuizOption(text: "Manageable", emoji: "👍"),
                QuizOption(text: "Hard", emoji: "😤"),
                QuizOption(text: "Very hard", emoji: "😫")
            ]
        ),
        QuizQuestion(
            question: "How much time do you want to commit each day?",
            options: [
                QuizOption(text: "5-10 min", emoji: "⏰"),
                QuizOption(text: "10-20 min", emoji: "⏱️"),
                QuizOption(text: "20-30 min", emoji: "⏳"),
                QuizOption(text: "I'll decide later", emoji: "🤷")
            ]
        ),
        QuizQuestion(
            question: "What would a win look like in 30 days?",
            options: [
                QuizOption(text: "Fewer urges", emoji: "🎉"),
                QuizOption(text: "Better routines", emoji: "📅"),
                QuizOption(text: "More control", emoji: "🎯"),
                QuizOption(text: "Not sure yet", emoji: "🤔")
            ]
        )
    ]
}

struct QuizOption {
    let text: String
    let emoji: String
}


