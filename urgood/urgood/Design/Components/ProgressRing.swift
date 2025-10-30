import SwiftUI

struct ProgressRing: View {
    let progress: Double
    let total: Double
    let size: CGFloat
    let strokeWidth: CGFloat
    let primaryColor: Color
    let secondaryColor: Color
    
    init(
        progress: Double,
        total: Double = 100,
        size: CGFloat = 120,
        strokeWidth: CGFloat = 8,
        primaryColor: Color = .brandPrimary,
        secondaryColor: Color = .brandPrimary.opacity(0.2)
    ) {
        self.progress = progress
        self.total = total
        self.size = size
        self.strokeWidth = strokeWidth
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
    }
    
    private var progressPercentage: Double {
        min(max(progress / total, 0), 1)
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [secondaryColor.opacity(0.3), secondaryColor.opacity(0.1)]),
                        center: .center
                    ),
                    lineWidth: strokeWidth
                )
                .frame(width: size, height: size)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: progressPercentage)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [primaryColor, primaryColor.opacity(0.6), primaryColor]),
                        center: .center
                    ),
                    style: StrokeStyle(
                        lineWidth: strokeWidth,
                        lineCap: .round
                    )
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.0), value: progressPercentage)
            
            // Center content
            VStack(spacing: Spacing.xs) {
                Text("\(Int(progress))")
                    .font(Typography.title)
                    .fontWeight(.bold)
                    .foregroundColor(primaryColor)
                
                Text("days")
                    .font(Typography.footnote)
                    .foregroundColor(.textSecondary)
            }
        }
    }
}

struct StreakRing: View {
    let streak: Int
    let size: CGFloat
    
    init(streak: Int, size: CGFloat = 120) {
        self.streak = streak
        self.size = size
    }
    
    var body: some View {
        ProgressRing(
            progress: Double(streak),
            total: 30, // Show progress towards 30-day milestone
            size: size,
            primaryColor: .brandPrimary,
            secondaryColor: .brandPrimary.opacity(0.2)
        )
    }
}

#Preview {
    VStack(spacing: Spacing.lg) {
        ProgressRing(progress: 75, total: 100)
        
        StreakRing(streak: 7)
        
        ProgressRing(progress: 25, total: 50, size: 80, strokeWidth: 6)
    }
    .padding()
    .themeEnvironment()
}
