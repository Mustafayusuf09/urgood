import SwiftUI

struct FirstRunFlowView: View {
    let container: DIContainer
    @StateObject private var viewModel = FirstRunFlowViewModel()
    @Environment(\.dismiss) private var dismiss

    
    var body: some View {
        ZStack {
            // Simple background
            Color.black.ignoresSafeArea()
            
            // Content based on current step
            switch viewModel.currentStep {
            case .welcomeSplash:
                WelcomeSplashView(viewModel: viewModel)
            case .assessmentWelcome:
                AssessmentWelcomeView(viewModel: viewModel, container: container)
            case .quickQuiz:
                QuickQuizView(viewModel: viewModel, container: container, onComplete: {
                    viewModel.nextStep() // Go to calculating
                })
            case .calculating:
                CalculatingView(viewModel: viewModel, onComplete: {
                    viewModel.nextStep() // Go to sign-up wall
                })
            case .signUpWall:
                SignUpWallView(container: container, onComplete: {
                    // Complete the first run flow
                    container.localStore.markFirstRunComplete()
                    dismiss()
                })
            }
        }
        .animation(.easeInOut(duration: 0.5), value: viewModel.currentStep)
        .onAppear {
            // Check if user is authenticated
            if container.unifiedAuthService.isAuthenticated {
                // User is already authenticated, complete the flow
                container.localStore.markFirstRunComplete()
                dismiss()
            }
        }

    }
}

// MARK: - Welcome Splash Screen
struct WelcomeSplashView: View {
    @ObservedObject var viewModel: FirstRunFlowViewModel
    @State private var showText = false
    @State private var typewriterText = ""
    @State private var currentIndex = 0
    
    private let fullText = "Welcome to your journey"
    
    var body: some View {
        ZStack {
            // Beautiful calming gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.2, blue: 0.4),   // Deep blue
                    Color(red: 0.2, green: 0.4, blue: 0.8),   // Medium blue
                    Color(red: 0.4, green: 0.6, blue: 1.0),   // Light blue
                    Color(red: 0.6, green: 0.8, blue: 1.0)    // Very light blue
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Subtle floating orbs for visual interest
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 100, height: 100)
                .offset(x: -150, y: -200)
                .blur(radius: 20)
            
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 80, height: 80)
                .offset(x: 120, y: 250)
                .blur(radius: 15)
            
            VStack(spacing: 40) {
                Spacer()
                
                Text("urgood")
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .scaleEffect(showText ? 1.0 : 0.8)
                    .animation(.spring(response: 0.8, dampingFraction: 0.6), value: showText)
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                
                if showText {
                    Text(typewriterText)
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(.white.opacity(0.95))
                        .multilineTextAlignment(.center)
                        .transition(.opacity.combined(with: .scale))
                        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
                        .animation(.easeInOut(duration: 0.1), value: typewriterText)
                }
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            startAnimationSequence()
        }
    }
    
    private func startAnimationSequence() {
        // Start with logo animation
        withAnimation(.easeInOut(duration: 0.5).delay(0.3)) {
            showText = true
        }
        
        // Start typewriter effect after logo appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            startTypewriterEffect()
        }
    }
    
    private func startTypewriterEffect() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if currentIndex < fullText.count {
                let index = fullText.index(fullText.startIndex, offsetBy: currentIndex)
                typewriterText += String(fullText[index])
                currentIndex += 1
            } else {
                timer.invalidate()
                // Auto-continue after typewriter effect completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    viewModel.nextStep()
                }
            }
        }
    }
}

// MARK: - Assessment Welcome Screen
struct AssessmentWelcomeView: View {
    @ObservedObject var viewModel: FirstRunFlowViewModel
    let container: DIContainer
    @State private var showSignIn = false
    
    var body: some View {
        ZStack {
            // Beautiful gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.15, blue: 0.3),   // Deep blue
                    Color(red: 0.15, green: 0.25, blue: 0.5),   // Medium blue
                    Color(red: 0.25, green: 0.4, blue: 0.7),    // Light blue
                    Color(red: 0.35, green: 0.5, blue: 0.8)     // Very light blue
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Decorative elements
            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "star.fill")
                        .foregroundColor(.white.opacity(0.1))
                        .font(.title)
                        .offset(x: 20, y: 50)
                }
                Spacer()
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.white.opacity(0.08))
                        .font(.title2)
                        .offset(x: -30, y: -80)
                    Spacer()
                }
            }
            
            VStack(spacing: 40) {
                Spacer()
                
                Text("urgood")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                
                VStack(spacing: 20) {
                    Text("Welcome!")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
                    
                    Text("Let's get to know you better with a quick assessment")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button("Start Quick Quiz") {
                        viewModel.nextStep()
                    }
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: .blue.opacity(0.4), radius: 10, x: 0, y: 5)
                    
                    Button("Already joined on web?") {
                        showSignIn = true
                    }
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                    )
                    
                    Button("I have a code") {
                        // Handle code input
                    }
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .sheet(isPresented: $showSignIn) {
            SignInView()
        }
    }
}


// MARK: - Quick Quiz Screen
struct QuickQuizView: View {
    @ObservedObject var viewModel: FirstRunFlowViewModel
    let container: DIContainer
    let onComplete: () -> Void
    @State private var currentQuestionIndex = 0
    @State private var selectedAnswers: [QuizAnswer] = []
    
    var body: some View {
        ZStack {
            // Beautiful gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.1, blue: 0.2),   // Dark blue
                    Color(red: 0.1, green: 0.2, blue: 0.4),    // Medium dark blue
                    Color(red: 0.15, green: 0.3, blue: 0.6)    // Medium blue
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Subtle geometric patterns
            VStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { index in
                    Rectangle()
                        .fill(Color.white.opacity(0.03))
                        .frame(height: 1)
                        .offset(y: CGFloat(index * 100))
                }
            }
            
            VStack(spacing: 30) {
                // Progress indicator
                VStack(spacing: 8) {
                    HStack {
                        Text("Question \(currentQuestionIndex + 1) of \(QuizQuestion.sampleQuestions.count)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    ProgressView(value: Double(currentQuestionIndex + 1), total: Double(QuizQuestion.sampleQuestions.count))
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .padding(.horizontal)
                }
                
                // Question
                VStack(spacing: 20) {
                    Text(QuizQuestion.sampleQuestions[currentQuestionIndex].question)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 20)
                    
                    // Options
                    VStack(spacing: 12) {
                        ForEach(QuizQuestion.sampleQuestions[currentQuestionIndex].options.indices, id: \.self) { index in
                            QuizOptionButton(
                                option: QuizQuestion.sampleQuestions[currentQuestionIndex].options[index],
                                action: {
                                    let answer = QuizAnswer(
                                        questionIndex: currentQuestionIndex,
                                        selectedOptionIndex: index
                                    )
                                    selectedAnswers.append(answer)
                                    
                                    if currentQuestionIndex < QuizQuestion.sampleQuestions.count - 1 {
                                        currentQuestionIndex += 1
                                    } else {
                                        // Quiz completed - save answers but don't dismiss yet
                                        viewModel.saveQuizAnswers(selectedAnswers)
                                        // The parent view will handle showing authentication
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Complete button - always visible
                Button("✨ Complete Quiz") {
                    Task {
                        // TODO: Implement quiz answers saving when needed
                        // For now, just complete the flow
                        onComplete()
                    }
                }
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [Color.green, Color.green.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: .green.opacity(0.4), radius: 10, x: 0, y: 5)
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
            }
            .padding()
        }
        .animation(.easeInOut(duration: 0.3), value: currentQuestionIndex)
    }
}

// MARK: - Sign In View
struct SignInView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Sign In")
                .font(.title)
                .foregroundColor(.white)
            
            Text("This feature is coming soon!")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            
            Button("Close") {
                dismiss()
            }
            .font(.title2)
            .foregroundColor(.white)
            .padding()
            .background(Color.blue)
            .cornerRadius(12)
            
            Spacer()
        }
        .padding()
        .background(Color.black)
    }
}

// MARK: - Quiz Option Button
struct QuizOptionButton: View {
    let option: QuizOption
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(option.emoji)
                    .font(.title2)
                Text(option.text)
                    .font(.body)
                Spacer()
            }
            .foregroundColor(.white)
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

// MARK: - Quiz Answer Model

// MARK: - Calculating View
struct CalculatingView: View {
    @ObservedObject var viewModel: FirstRunFlowViewModel
    let onComplete: () -> Void
    @State private var showText = false
    @State private var showSpinner = false
    @State private var showComplete = false
    
    var body: some View {
        ZStack {
            // Beautiful gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.2, blue: 0.4),
                    Color(red: 0.2, green: 0.4, blue: 0.8),
                    Color(red: 0.4, green: 0.6, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Animated crystal ball
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .blur(radius: 20)
                    
                    Image(systemName: "crystal.ball.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                        .scaleEffect(showSpinner ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: showSpinner)
                }
                
                VStack(spacing: 20) {
                    Text("🔮 Calculating your roadmap...")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .opacity(showText ? 1.0 : 0.0)
                        .animation(.easeIn(duration: 0.8), value: showText)
                    
                    Text("Analyzing your responses and crafting a personalized journey just for you")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .opacity(showText ? 1.0 : 0.0)
                        .animation(.easeIn(duration: 0.8).delay(0.3), value: showText)
                }
                
                Spacer()
            }
            .padding(.horizontal, 40)
        }
        .onAppear {
            showText = true
            showSpinner = true
            
            // Auto-advance after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                showComplete = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onComplete()
                }
            }
        }
    }
}

// MARK: - Sign Up Wall View
struct SignUpWallView: View {
    let container: DIContainer
    let onComplete: () -> Void
    @State private var showEmailSignUp = false
    @State private var showEmailSignIn = false
    
    var body: some View {
        ZStack {
            // Beautiful gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.2, blue: 0.4),
                    Color(red: 0.2, green: 0.4, blue: 0.8),
                    Color(red: 0.4, green: 0.6, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Success icon
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.3))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                }
                
                VStack(spacing: 20) {
                    Text("🎉 We've built your roadmap!")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Sign up to unlock your personalized journey and start transforming your life")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                
                VStack(spacing: 16) {
                    // Apple Sign In Button
                    Button(action: {
                        Task {
                            do {
                                try await container.unifiedAuthService.signInWithApple()
                                onComplete()
                            } catch {
                                print("Apple Sign In failed: \(error)")
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "applelogo")
                                .font(.title2)
                            Text("Continue with Apple")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.black)
                        .cornerRadius(25)
                    }
                    
                    // Email Button
                    Button(action: {
                        showEmailSignUp = true
                    }) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .font(.title2)
                            Text("Continue with Email")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(25)
                    }
                    
                    // Sign In Link
                    Button(action: {
                        showEmailSignIn = true
                    }) {
                        Text("Already have an account? Sign In")
                            .foregroundColor(.white.opacity(0.8))
                            .underline()
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 40)
        }
        .sheet(isPresented: $showEmailSignUp) {
            EmailSignUpView(container: container, onSuccess: onComplete)
        }
        .sheet(isPresented: $showEmailSignIn) {
            EmailSignInView(container: container, onSuccess: onComplete)
        }
    }
}




#Preview {
    FirstRunFlowView(container: DIContainer.shared)
        .preferredColorScheme(.dark)
}
