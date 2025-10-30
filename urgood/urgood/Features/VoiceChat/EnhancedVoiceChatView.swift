import SwiftUI

struct EnhancedVoiceChatView: View {
    @EnvironmentObject private var container: DIContainer
    @Environment(\.dismiss) private var dismiss
    @StateObject private var voiceChatService = VoiceChatService()
    @State private var pulseAnimation = false
    @State private var breathingAnimation = false
    @State private var waveAnimation = false
    @State private var showTranscript = false
    
    var body: some View {
        ZStack {
            // Dynamic background
            dynamicBackground
            
            VStack(spacing: 0) {
                // Header with status
                headerSection
                    .padding(.top, 60)
                
                Spacer()
                
                // Main voice visualization
                mainVoiceVisualization
                
                // Transcript section
                if showTranscript && !voiceChatService.currentTranscript.isEmpty {
                    transcriptSection
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                Spacer()
                
                // Control buttons
                controlButtons
                    .padding(.bottom, 100)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            startAnimations()
            Task { await voiceChatService.startVoiceChat() }
        }
        .onDisappear {
            voiceChatService.stopVoiceChat()
        }
        .onChange(of: voiceChatService.currentTranscript) { transcript in
            withAnimation(.easeInOut(duration: 0.3)) {
                showTranscript = !transcript.isEmpty
            }
        }
        .sheet(isPresented: $voiceChatService.showPaywall) {
            PaywallView(
                isPresented: $voiceChatService.showPaywall,
                onUpgrade: { _ in
                    Task {
                        await container.billingService.refreshSubscriptionStatus()
                        voiceChatService.showPaywall = false
                    }
                },
                onDismiss: {
                    voiceChatService.showPaywall = false
                },
                billingService: container.billingService
            )
        }
    }
    
    // MARK: - Dynamic Background
    private var dynamicBackground: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color.background,
                    Color.brandPrimary.opacity(0.05),
                    Color.brandSecondary.opacity(0.03),
                    Color.background
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Animated overlay for listening state
            if voiceChatService.isListening {
                RadialGradient(
                    colors: [
                        Color.brandElectric.opacity(0.1),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 100,
                    endRadius: 400
                )
                .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulseAnimation)
                .ignoresSafeArea()
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: {
                    voiceChatService.stopVoiceChat()
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.textSecondary)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                }
                
                Spacer()
                
                // Connection status indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(voiceChatService.isConnected ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                        .scaleEffect(voiceChatService.isConnected ? 1.0 : 0.8)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: voiceChatService.isConnected)
                    
                    Text(voiceChatService.isConnected ? "Connected" : "Connecting...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )
            }
            
            VStack(spacing: 8) {
                Text("UrGood is listening (\"your good\")")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(.textPrimary)
                
                Text(voiceChatService.statusMessage)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut(duration: 0.3), value: voiceChatService.statusMessage)
            }
        }
    }
    
    // MARK: - Main Voice Visualization
    private var mainVoiceVisualization: some View {
        ZStack {
            // Outer breathing ring
            Circle()
                .stroke(Color.brandPrimary.opacity(0.2), lineWidth: 2)
                .frame(width: 320, height: 320)
                .scaleEffect(breathingAnimation ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: breathingAnimation)
            
            // Middle pulse ring
            Circle()
                .stroke(Color.brandElectric.opacity(0.4), lineWidth: 3)
                .frame(width: 280, height: 280)
                .scaleEffect(voiceChatService.isListening ? 1.1 : 1.0)
                .opacity(voiceChatService.isListening ? 1.0 : 0.3)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: voiceChatService.isListening)
            
            // Inner glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.brandPrimary.opacity(0.3),
                            Color.brandPrimary.opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 120
                    )
                )
                .frame(width: 240, height: 240)
                .scaleEffect(voiceChatService.isSpeaking ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.6), value: voiceChatService.isSpeaking)
            
            // Central button
            Button(action: {
                if voiceChatService.isActive {
                    voiceChatService.toggleListening()
                } else {
                    Task {
                        await voiceChatService.startVoiceChat()
                    }
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.brandPrimary)
                        .frame(width: 140, height: 140)
                        .shadow(color: Color.brandPrimary.opacity(0.4), radius: 20, x: 0, y: 10)
                    
                    // Dynamic icon based on state
                    Group {
                        if voiceChatService.isListening {
                            WaveformView()
                        } else if voiceChatService.isSpeaking {
                            Image(systemName: "speaker.wave.3.fill")
                                .font(.system(size: 40, weight: .medium))
                        } else {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 40, weight: .medium))
                        }
                    }
                    .foregroundColor(.white)
                    .animation(.easeInOut(duration: 0.3), value: voiceChatService.isListening)
                }
            }
            .buttonStyle(VoiceChatButtonStyle())
        }
    }
    
    // MARK: - Transcript Section
    private var transcriptSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Transcript")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textSecondary)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showTranscript = false
                    }
                }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textSecondary)
                }
            }
            
            ScrollView {
                Text(voiceChatService.currentTranscript)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .frame(maxHeight: 120)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.brandPrimary.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Control Buttons
    private var controlButtons: some View {
        HStack(spacing: 24) {
            // Mute button
            Button(action: {
                // Handle mute toggle
            }) {
                Image(systemName: "mic.slash.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.textSecondary)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // End call button
            Button(action: {
                voiceChatService.stopVoiceChat()
                dismiss()
            }) {
                Image(systemName: "phone.down.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(Color.red)
                    )
            }
            .buttonStyle(.plain)
        }
    }
    
    private func startAnimations() {
        withAnimation {
            pulseAnimation = true
            breathingAnimation = true
            waveAnimation = true
        }
    }
}

// MARK: - Waveform View
struct WaveformView: View {
    @State private var animationPhase: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: 4, height: CGFloat.random(in: 20...40))
                    .scaleEffect(y: 0.5 + 0.5 * sin(animationPhase + Double(index) * 0.5))
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.1),
                        value: animationPhase
                    )
            }
        }
        .onAppear {
            animationPhase = .pi
        }
    }
}

// MARK: - Voice Chat Button Style
struct VoiceChatButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    EnhancedVoiceChatView()
        .environmentObject(DIContainer.shared)
}
