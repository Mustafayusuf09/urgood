import SwiftUI

// MARK: - Animation Extensions
extension View {
    /// Adds a subtle bounce animation when tapped
    func bounceOnTap() -> some View {
        self.scaleEffect(1.0)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.1)) {
                    // This would be handled by the button's own animation
                }
            }
    }
    
    /// Adds a gentle pulse animation
    func pulseAnimation() -> some View {
        self.overlay(
            Circle()
                .stroke(Color.brandPrimary.opacity(0.3), lineWidth: 2)
                .scaleEffect(1.0)
                .opacity(0.0)
                .animation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: false),
                    value: UUID()
                )
        )
    }
    
    /// Adds a subtle glow effect
    func glowEffect(color: Color = .brandPrimary, radius: CGFloat = 8) -> some View {
        self.overlay(
            self
                .blur(radius: radius)
                .opacity(0.3)
                .blendMode(.overlay)
        )
    }
}

// MARK: - Custom Button Styles
// Note: ButtonStyle implementations removed due to compilation issues
// These can be re-added later when the SwiftUI import issues are resolved

// MARK: - Loading Animations
struct LoadingDots: View {
    @State private var isAnimating = false
    let colors: [Color]
    let dotSize: CGFloat
    let spacing: CGFloat
    let speed: Double
    
    init(colors: [Color] = [.brandPrimary, .brandAccent, .brandElectric], dotSize: CGFloat = 10, spacing: CGFloat = 6, speed: Double = 0.6) {
        self.colors = colors
        self.dotSize = dotSize
        self.spacing = spacing
        self.speed = speed
    }
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(colors.indices, id: \.self) { index in
                Circle()
                    .fill(colors[index])
                    .frame(width: dotSize, height: dotSize)
                    .scaleEffect(isAnimating ? 1.0 : 0.6)
                    .animation(
                        .easeInOut(duration: speed)
                        .repeatForever()
                        .delay(Double(index) * (speed / 2)),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct BreathingCircle: View {
    @State private var isBreathing = false
    let color: Color
    let size: CGFloat
    let glowColor: Color
    let gradient: [Color]
    
    init(color: Color = .brandPrimary, size: CGFloat = 100, glowColor: Color = .brandAccent, gradient: [Color] = [.brandPrimary.opacity(0.4), .brandAccent.opacity(0.25), .brandElectric.opacity(0.4)]) {
        self.color = color
        self.size = size
        self.glowColor = glowColor
        self.gradient = gradient
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: gradient),
                        center: .center,
                        startRadius: size * 0.1,
                        endRadius: size * 0.6
                    )
                )
                .frame(width: size, height: size)
                .blur(radius: size * 0.15)
                .opacity(0.5)
                .blendMode(.screen)
            
            Circle()
                .stroke(glowColor.opacity(0.6), lineWidth: size * 0.03)
                .frame(width: size * 0.9, height: size * 0.9)
                .blur(radius: size * 0.05)
            
            Circle()
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [color, glowColor, color]),
                        center: .center
                    ),
                    lineWidth: size * 0.04
                )
                .frame(width: size, height: size)
        }
        .scaleEffect(isBreathing ? 1.1 : 0.95)
        .animation(
            .easeInOut(duration: 2.6)
            .repeatForever(autoreverses: true),
            value: isBreathing
        )
        .onAppear {
            isBreathing = true
        }
    }
}

// MARK: - Mood Animation
struct MoodAnimation: View {
    let mood: Int
    @State private var isAnimating = false
    
    var body: some View {
        Text(moodEmoji)
            .font(.system(size: 40))
            .scaleEffect(isAnimating ? 1.2 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: isAnimating)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.3).delay(0.1)) {
                    isAnimating = true
                }
            }
    }
    
    private var moodEmoji: String {
        switch mood {
        case 1: return "😔"
        case 2: return "😕"
        case 3: return "😐"
        case 4: return "😊"
        case 5: return "😄"
        default: return "😐"
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        LoadingDots()
        
        BreathingCircle()
        
        MoodAnimation(mood: 4)
        
        Button("Animated Button") {
            // Action
        }
        .buttonStyle(PlainButtonStyle())
        .padding()
        .background(Color.brandPrimary)
        .foregroundColor(.white)
        .cornerRadius(12)
    }
    .padding()
    .themeEnvironment()
}
