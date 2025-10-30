import SwiftUI
import OSLog
import AVFoundation

// MARK: - Audio Visualization Component

struct AudioVisualizationView: View {
    let audioLevel: Float
    let isRecording: Bool
    let isPlaying: Bool
    
    @State private var animationPhase: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var waveformBars: [Float] = Array(repeating: 0.1, count: 20)
    
    var body: some View {
        ZStack {
            if isRecording {
                recordingVisualization
            } else if isPlaying {
                playbackVisualization
            } else {
                idleVisualization
            }
        }
        .onAppear {
            startAnimations()
        }
        .onChange(of: audioLevel) { level in
            updateVisualization(level: level)
        }
    }
    
    // MARK: - Recording Visualization
    
    private var recordingVisualization: some View {
        ZStack {
            // Pulse rings
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.red.opacity(0.6), .red.opacity(0.1)],
                            startPoint: .center,
                            endPoint: .trailing
                        ),
                        lineWidth: 2
                    )
                    .scaleEffect(pulseScale + CGFloat(index) * 0.3)
                    .opacity(1.0 - CGFloat(index) * 0.3)
                    .animation(
                        .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2),
                        value: pulseScale
                    )
            }
            
            // Central microphone icon with level indicator
            ZStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 80, height: 80)
                    .scaleEffect(1.0 + CGFloat(audioLevel) * 0.5)
                    .animation(.easeInOut(duration: 0.1), value: audioLevel)
                
                Image(systemName: "mic.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
            
            // Waveform bars around the circle
            waveformBarsView
        }
        .frame(width: 200, height: 200)
    }
    
    // MARK: - Playback Visualization
    
    private var playbackVisualization: some View {
        ZStack {
            // Sound waves
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.blue.opacity(0.6), .blue.opacity(0.1)],
                            startPoint: .center,
                            endPoint: .trailing
                        ),
                        lineWidth: 3
                    )
                    .scaleEffect(1.0 + sin(animationPhase + Double(index) * 0.5) * 0.3)
                    .opacity(0.8 - CGFloat(index) * 0.15)
            }
            
            // Central speaker icon
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
            
            // Animated sound bars
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue)
                        .frame(width: 4)
                        .frame(height: CGFloat(20 + sin(animationPhase + Double(index)) * 15))
                        .animation(
                            .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.1),
                            value: animationPhase
                        )
                }
            }
            .offset(y: 50)
        }
        .frame(width: 200, height: 200)
    }
    
    // MARK: - Idle Visualization
    
    private var idleVisualization: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                .frame(width: 80, height: 80)
            
            Image(systemName: "waveform")
                .font(.system(size: 32))
                .foregroundColor(.gray)
        }
        .frame(width: 200, height: 200)
    }
    
    // MARK: - Waveform Bars
    
    private var waveformBarsView: some View {
        ZStack {
            ForEach(0..<waveformBars.count, id: \.self) { index in
                let angle = Double(index) * (360.0 / Double(waveformBars.count))
                let barHeight = CGFloat(waveformBars[index]) * 30 + 10
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.red.opacity(0.7))
                    .frame(width: 3, height: barHeight)
                    .offset(y: -60)
                    .rotationEffect(.degrees(angle))
            }
        }
    }
    
    // MARK: - Animation Control
    
    private func startAnimations() {
        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
            animationPhase = .pi * 2
        }
        
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.2
        }
    }
    
    private func updateVisualization(level: Float) {
        // Update waveform bars with audio level
        let normalizedLevel = min(1.0, max(0.0, level))
        
        // Shift existing bars and add new level
        waveformBars.removeFirst()
        waveformBars.append(normalizedLevel)
    }
}

// MARK: - Voice State Indicator

struct VoiceStateIndicator: View {
    let state: VoiceState
    let isListening: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            stateIcon
            stateText
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(stateColor.opacity(0.1))
        .foregroundColor(stateColor)
        .cornerRadius(20)
        .animation(.easeInOut(duration: 0.3), value: state)
    }
    
    private var stateIcon: some View {
        Group {
            switch state {
            case .idle:
                Image(systemName: "moon.zzz.fill")
            case .listening:
                Image(systemName: isListening ? "ear.fill" : "ear")
            case .processing:
                Image(systemName: "brain.head.profile")
            case .speaking:
                Image(systemName: "speaker.wave.2.fill")
            case .error:
                Image(systemName: "exclamationmark.triangle.fill")
            case .interrupted:
                Image(systemName: "pause.fill")
            }
        }
        .font(.system(size: 16, weight: .medium))
    }
    
    private var stateText: some View {
        Text(stateDescription)
            .font(.system(size: 14, weight: .medium))
    }
    
    private var stateDescription: String {
        switch state {
        case .idle:
            return "Ready"
        case .listening:
            return isListening ? "Listening..." : "Tap to speak"
        case .processing:
            return "Thinking..."
        case .speaking:
            return "Speaking"
        case .error:
            return "Error"
        case .interrupted:
            return "Interrupted"
        }
    }
    
    private var stateColor: Color {
        switch state {
        case .idle:
            return .gray
        case .listening:
            return isListening ? .red : .blue
        case .processing:
            return .orange
        case .speaking:
            return .green
        case .error:
            return .red
        case .interrupted:
            return .yellow
        }
    }
}

// MARK: - Haptic Feedback Manager

class HapticFeedbackManager {
    static let shared = HapticFeedbackManager()
    
    private init() {}
    
    func playRecordingStart() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    func playRecordingStop() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    func playVoiceDetected() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .rigid)
        impactFeedback.impactOccurred()
    }
    
    func playResponseReceived() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
    
    func playError() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
    }
    
    func playButtonTap() {
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }
}

// MARK: - Enhanced Voice Button

@MainActor
struct VoiceButton: View {
    let isRecording: Bool
    let isProcessing: Bool
    let audioLevel: Float
    let onTapDown: () -> Void
    let onTapUp: () -> Void
    
    @State private var isPressed = false
    @State private var pulseAnimation = false
    @State private var hasTriggeredTapDown = false
    
    private static let log = Logger(subsystem: "com.urgood.urgood", category: "VoiceButton")
    
    var body: some View {
        ZStack {
            // Background circle with gradient
            backgroundCircle
            
            // Pulse rings when recording
            if isRecording {
                ForEach(0..<2, id: \.self) { index in
                    Circle()
                        .stroke(Color.red.opacity(0.3), lineWidth: 2)
                        .frame(width: buttonSize + CGFloat(index * 20), height: buttonSize + CGFloat(index * 20))
                        .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                        .opacity(pulseAnimation ? 0.0 : 0.7)
                        .animation(
                            .easeOut(duration: 1.0)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.2),
                            value: pulseAnimation
                        )
                }
            }
            
            // Icon
            Image(systemName: buttonIcon)
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(.white)
                .scaleEffect(isPressed ? 0.9 : 1.0)
            
            // Processing indicator
            if isProcessing {
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 3)
                    .frame(width: buttonSize - 10, height: buttonSize - 10)
                    .overlay(
                        Circle()
                            .trim(from: 0, to: 0.3)
                            .stroke(Color.white, lineWidth: 3)
                            .rotationEffect(.degrees(pulseAnimation ? 360 : 0))
                            .animation(
                                .linear(duration: 1.0).repeatForever(autoreverses: false),
                                value: pulseAnimation
                            )
                    )
            }
        }
        .contentShape(Circle())
        .highPriorityGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    handlePressBegan(source: "gesture")
                }
                .onEnded { _ in
                    handlePressEnded(source: "gesture")
                }
        )
        .onAppear {
            pulseAnimation = true
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(.isButton)
        .onTapGesture {
            handleAccessibilityToggle()
        }
    }
    
    private var backgroundCircle: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: buttonColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: buttonSize, height: buttonSize)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .scaleEffect(isRecording ? (1.0 + CGFloat(audioLevel) * 0.2) : 1.0)
    }
    
    private var buttonSize: CGFloat {
        isRecording ? 100 : 80
    }
    
    private var buttonColors: [Color] {
        if isRecording {
            return [.red, .red.opacity(0.8)]
        } else if isProcessing {
            return [.orange, .orange.opacity(0.8)]
        } else {
            return [.blue, .blue.opacity(0.8)]
        }
    }
    
    private var buttonIcon: String {
        if isProcessing {
            return "brain.head.profile"
        } else if isRecording {
            return "stop.fill"
        } else {
            return "mic.fill"
        }
    }
    
    private var accessibilityLabel: String {
        if isRecording {
            return "Stop recording"
        } else if isProcessing {
            return "Processing voice"
        } else {
            return "Start voice recording"
        }
    }
    
    private var accessibilityHint: String {
        if isRecording {
            return "Tap to stop recording your voice message"
        } else if isProcessing {
            return "Please wait while your voice is being processed"
        } else {
            return "Hold to record a voice message"
        }
    }
    
    private func handlePressBegan(source: String) {
        guard !isProcessing else {
            Self.log.debug("⏳ Ignoring \(source) press while processing")
            return
        }
        guard !hasTriggeredTapDown else {
            isPressed = true
            return
        }
        isPressed = true
        if isRecording {
            Self.log.debug("🎙️ Press began (\(source)) while already recording — awaiting release")
            return
        }
        hasTriggeredTapDown = true
        Self.log.notice("🎙️ Press began (\(source))")
        HapticFeedbackManager.shared.playRecordingStart()
        onTapDown()
    }
    
    private func handlePressEnded(source: String) {
        let shouldTrigger = hasTriggeredTapDown || isRecording
        isPressed = false
        guard shouldTrigger else {
            Self.log.debug("⚠️ Ignoring \(source) press end; no active recording")
            return
        }
        hasTriggeredTapDown = false
        isPressed = false
        Self.log.notice("🛑 Press ended (\(source))")
        HapticFeedbackManager.shared.playRecordingStop()
        onTapUp()
    }
    
    private func handleAccessibilityToggle() {
        if isRecording {
            Self.log.notice("🧏 Accessibility toggle → stop")
            handlePressEnded(source: "accessibility")
        } else {
            Self.log.notice("🧏 Accessibility toggle → start")
            handlePressBegan(source: "accessibility")
        }
    }
}

// MARK: - Voice State Enum
// Note: VoiceState is defined in VoiceTransport.swift

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        AudioVisualizationView(
            audioLevel: 0.7,
            isRecording: true,
            isPlaying: false
        )
        
        VoiceStateIndicator(
            state: .listening,
            isListening: true
        )
        
        VoiceButton(
            isRecording: false,
            isProcessing: false,
            audioLevel: 0.5,
            onTapDown: {},
            onTapUp: {}
        )
    }
    .padding()
}
