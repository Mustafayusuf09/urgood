import SwiftUI
import AVFoundation

// MARK: - Voice Waveform View

struct VoiceWaveformView: View {
    let audioLevel: Float
    let isActive: Bool
    
    @State private var animationPhase: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<20, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(isActive ? Color.red : Color.gray.opacity(0.3))
                    .frame(width: 3, height: barHeight(for: index))
                    .animation(.easeInOut(duration: 0.1), value: audioLevel)
            }
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let normalizedLevel = CGFloat(audioLevel)
        let baseHeight: CGFloat = 2
        let maxHeight: CGFloat = 24 // Increased for better visibility
        
        // Create a more dynamic wave pattern
        let waveOffset = sin(CGFloat(index) * 0.4 + animationPhase) * 0.6 + 0.4
        let height = baseHeight + (maxHeight - baseHeight) * normalizedLevel * waveOffset
        
        // Add some randomness for more natural movement
        let randomFactor = 0.8 + 0.4 * sin(CGFloat(index) * 0.7 + animationPhase * 1.5)
        
        return max(baseHeight, height * randomFactor)
    }
    
    private func startAnimation() {
        withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
            animationPhase = .pi * 2
        }
    }
}

// MARK: - Voice Captions View

struct VoiceCaptionsView: View {
    let transcript: String
    let isPartial: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !transcript.isEmpty {
                HStack {
                    Text(transcript)
                        .font(.body)
                        .foregroundColor(isPartial ? .secondary : .primary)
                        .multilineTextAlignment(.leading)
                    
                    if isPartial {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: transcript)
    }
}

// MARK: - Voice State Chip

struct VoiceStateChip: View {
    let state: VoiceState
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(stateColor)
                .frame(width: 8, height: 8)
                .scaleEffect(isPulsing ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isPulsing)
            
            Text(stateText)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(stateColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(stateColor.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var stateColor: Color {
        switch state {
        case .idle:
            return .gray
        case .listening:
            return .blue
        case .processing:
            return .orange
        case .speaking:
            return .green
        case .interrupted:
            return .red
        case .error:
            return .red
        }
    }
    
    private var stateText: String {
        switch state {
        case .idle:
            return "Ready"
        case .listening:
            return "Listening"
        case .processing:
            return "Processing"
        case .speaking:
            return "Speaking"
        case .interrupted:
            return "Interrupted"
        case .error:
            return "Error"
        }
    }
    
    private var isPulsing: Bool {
        switch state {
        case .listening, .processing:
            return true
        default:
            return false
        }
    }
}

// MARK: - Voice Control Button

struct VoiceControlButton: View {
    let state: VoiceState
    let isListening: Bool
    let isSpeaking: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    @State private var isPressed = false
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background circle
                Circle()
                    .fill(buttonColor)
                    .frame(width: 80, height: 80)
                    .scaleEffect(isPressed ? 0.95 : 1.0)
                
                // Pulse ring for active states
                if isListening || isSpeaking {
                    Circle()
                        .stroke(buttonColor, lineWidth: 3)
                        .frame(width: 100, height: 100)
                        .scaleEffect(pulseScale)
                        .opacity(0.6)
                    
                    // Additional outer ring for listening state
                    if isListening {
                        Circle()
                            .stroke(buttonColor.opacity(0.3), lineWidth: 2)
                            .frame(width: 120, height: 120)
                            .scaleEffect(pulseScale * 1.1)
                            .opacity(0.4)
                    }
                }
                
                // Icon
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0.1) {
            onLongPress()
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .onAppear {
            startPulseAnimation()
        }
        .onChange(of: state) { newState in
            // Add haptic feedback for state changes
            if newState == .listening {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            } else if newState == .speaking {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
        }
    }
    
    private var buttonColor: Color {
        switch state {
        case .idle:
            return .blue
        case .listening:
            return .red
        case .processing:
            return .orange
        case .speaking:
            return .green
        case .interrupted:
            return .red
        case .error:
            return .red
        }
    }
    
    private var iconName: String {
        switch state {
        case .idle:
            return "mic.fill"
        case .listening:
            return "stop.fill"
        case .processing:
            return "brain.head.profile"
        case .speaking:
            return "speaker.wave.2.fill"
        case .interrupted:
            return "exclamationmark.triangle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private func startPulseAnimation() {
        guard isListening || isSpeaking else { return }
        
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.2
        }
    }
}

// MARK: - Voice Settings Model

struct VoiceSettings {
    var selectedVoice: ElevenLabsVoice = .nova
    var audioQuality: AudioQuality = .balanced
    var enableHaptics: Bool = true
    var enableAutoListen: Bool = true
    var enableBargeIn: Bool = false
    var enableCaptions: Bool = false
    var enableLowLatency: Bool = false
    var stability: Double = 0.35
    var similarityBoost: Double = 0.85
    
    enum AudioQuality: String, CaseIterable {
        case lowLatency = "low"
        case balanced = "balanced"
        case highQuality = "high"
    }
}

// MARK: - Voice Settings View (ElevenLabs Only)

struct VoiceSettingsView: View {
    @Binding var settings: VoiceSettings
    @State private var showingVoicePicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Voice Settings")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Powered by ElevenLabs")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Voice Selection - ElevenLabs voices only
            VStack(alignment: .leading, spacing: 8) {
                Text("Voice")
                    .font(.headline)
                
                Button(action: { showingVoicePicker = true }) {
                    HStack {
                        Text("\(settings.selectedVoice.icon) \(settings.selectedVoice.displayName)")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(settings.selectedVoice.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            
            // Voice Stability
            VStack(alignment: .leading, spacing: 8) {
                Text("Voice Stability")
                    .font(.headline)
                
                HStack {
                    Text("Variable")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(value: $settings.stability, in: 0.0...1.0, step: 0.05)
                        .accentColor(.brandPrimary)
                    
                    Text("Stable")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("\(settings.stability, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Voice Similarity Boost
            VStack(alignment: .leading, spacing: 8) {
                Text("Voice Clarity")
                    .font(.headline)
                
                HStack {
                    Text("Low")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(value: $settings.similarityBoost, in: 0.0...1.0, step: 0.05)
                        .accentColor(.brandPrimary)
                    
                    Text("High")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("\(settings.similarityBoost, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Audio Quality
            VStack(alignment: .leading, spacing: 8) {
                Text("Audio Quality")
                    .font(.headline)
                
                Picker("Quality", selection: $settings.audioQuality) {
                    Text("Low Latency").tag(VoiceSettings.AudioQuality.lowLatency)
                    Text("Balanced").tag(VoiceSettings.AudioQuality.balanced)
                    Text("High Quality").tag(VoiceSettings.AudioQuality.highQuality)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            // Toggle Options
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Enable Barge-in", isOn: $settings.enableBargeIn)
                    .toggleStyle(SwitchToggleStyle(tint: .brandPrimary))
                
                Toggle("Show Captions", isOn: $settings.enableCaptions)
                    .toggleStyle(SwitchToggleStyle(tint: .brandPrimary))
                
                Toggle("Haptic Feedback", isOn: $settings.enableHaptics)
                    .toggleStyle(SwitchToggleStyle(tint: .brandPrimary))
                
                Toggle("Low Latency Mode", isOn: $settings.enableLowLatency)
                    .toggleStyle(SwitchToggleStyle(tint: .brandPrimary))
            }
        }
        .padding()
        .sheet(isPresented: $showingVoicePicker) {
            ElevenLabsVoicePickerView(selectedVoice: $settings.selectedVoice)
        }
    }
}

// MARK: - ElevenLabs Voice Picker View

struct ElevenLabsVoicePickerView: View {
    @Binding var selectedVoice: ElevenLabsVoice
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(ElevenLabsVoice.allCases, id: \.rawValue) { voice in
                Button(action: {
                    selectedVoice = voice
                    UserDefaults.standard.selectedVoice = voice
                    dismiss()
                }) {
                    HStack(spacing: 12) {
                        Text(voice.icon)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(voice.displayName)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(voice.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if selectedVoice == voice {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.brandPrimary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Select Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Voice Error View

struct VoiceErrorView: View {
    let error: Error
    let onRetry: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.red)
            
            Text("Voice Chat Error")
                .font(.headline)
                .fontWeight(.bold)
            
            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 12) {
                Button("Retry") {
                    onRetry()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Dismiss") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 10)
    }
}
