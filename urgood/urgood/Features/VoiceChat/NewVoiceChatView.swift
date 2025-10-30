import SwiftUI

struct NewVoiceChatView: View {
    @EnvironmentObject private var container: DIContainer
    @StateObject private var voiceChatService = VoiceChatService()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.2, green: 0.1, blue: 0.3),
                    Color(red: 0.1, green: 0.2, blue: 0.4)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Header
                VStack(spacing: 16) {
                    Text("Voice Chat with UrGood (\"your good\")")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(voiceChatService.statusMessage)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut(duration: 0.3), value: voiceChatService.statusMessage)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Voice visualization
                VoiceVisualizationView(
                    isListening: voiceChatService.isListening,
                    isSpeaking: voiceChatService.isSpeaking,
                    isConnected: voiceChatService.isConnected
                )
                
                // Transcript display
                if !voiceChatService.currentTranscript.isEmpty {
                    ScrollView {
                        Text(voiceChatService.currentTranscript)
                            .font(.body)
                            .foregroundColor(.white)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.ultraThinMaterial)
                            )
                            .padding(.horizontal)
                    }
                    .frame(maxHeight: 120)
                }
                
                Spacer()
                
                // Control buttons
                HStack(spacing: 30) {
                    // Close button
                    Button(action: {
                        voiceChatService.stopVoiceChat()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                            )
                    }
                    
                    // Main voice button
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
                                .fill(voiceChatService.isListening ? .red : .blue)
                                .frame(width: 80, height: 80)
                                .scaleEffect(voiceChatService.isListening ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: voiceChatService.isListening)
                            
                            Image(systemName: voiceChatService.isActive ? "mic.fill" : "mic")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(voiceChatService.isConnected && !voiceChatService.isActive)
                    
                    // Settings/info button
                    Button(action: {
                        // Could show voice chat info/settings
                    }) {
                        Image(systemName: "info.circle")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                            )
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .navigationBarHidden(true)
        .alert(
            "Voice Chat Error",
            isPresented: Binding(
                get: { voiceChatService.error != nil },
                set: { isPresented in
                    if !isPresented {
                        voiceChatService.clearError()
                    }
                }
            )
        ) {
            Button("OK") {
                voiceChatService.clearError()
            }
        } message: {
            Text(voiceChatService.error ?? "Something went wrong.")
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
}

struct VoiceVisualizationView: View {
    let isListening: Bool
    let isSpeaking: Bool
    let isConnected: Bool
    
    @State private var animationAmount = 1.0
    
    var body: some View {
        ZStack {
            // Outer rings
            ForEach(0..<3) { i in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 200 + CGFloat(i * 40))
                    .scaleEffect(animationAmount + Double(i) * 0.1)
                    .opacity(isListening || isSpeaking ? 0.6 - Double(i) * 0.2 : 0.2)
                    .animation(
                        .easeInOut(duration: 1.5 + Double(i) * 0.2)
                        .repeatForever(autoreverses: true),
                        value: animationAmount
                    )
            }
            
            // Center circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            isSpeaking ? .green : isListening ? .blue : .gray,
                            isSpeaking ? .green.opacity(0.3) : isListening ? .blue.opacity(0.3) : .gray.opacity(0.3)
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
                .scaleEffect(isSpeaking ? 1.2 : isListening ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: isSpeaking)
                .animation(.easeInOut(duration: 0.3), value: isListening)
            
            // Status icon
            Image(systemName: isSpeaking ? "speaker.wave.3.fill" : isListening ? "mic.fill" : "waveform")
                .font(.system(size: 40))
                .foregroundColor(.white)
                .scaleEffect(isSpeaking || isListening ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isSpeaking)
                .animation(.easeInOut(duration: 0.2), value: isListening)
        }
        .onAppear {
            animationAmount = 1.2
        }
    }
}

#Preview {
    NewVoiceChatView()
        .environmentObject(DIContainer.shared)
}
