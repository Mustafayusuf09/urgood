import SwiftUI

struct VoiceChatView: View {
    @EnvironmentObject private var container: DIContainer
    @Environment(\.dismiss) private var dismiss
    @StateObject private var voiceChatService = VoiceChatService()
    @State private var pulse = false
    
    var body: some View {
        ZStack {
            Color.background
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                statusHeader
                Spacer()
                micControl
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            .padding(.bottom, 120)
        }
        .onAppear {
            // Initialize pulse animation only, don't auto-start voice chat
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .onDisappear {
            voiceChatService.stopVoiceChat()
        }
        .accessibilityIdentifier("VoiceChatView")
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
    
    // MARK: - Subviews
    
    private var statusHeader: some View {
            VStack(spacing: 12) {
            Text("Hey there! 👋")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(Color.textPrimary)
            
            Text("Ready to chat with UrGood (\"your good\")?")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(Color.textSecondary)
                .multilineTextAlignment(.center)
            
            // Only show status message when active or when there's an error
            if voiceChatService.isActive || voiceChatService.error != nil {
                if !voiceChatService.statusMessage.isEmpty {
                    Text(voiceChatService.statusMessage)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
                
                if let error = voiceChatService.error {
                    Text(error)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(Color.brandSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                
                // Manual commit button
                if voiceChatService.isListening {
                    Button("Done Speaking") {
                        voiceChatService.manualCommit()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(25)
                    .padding(.bottom, 20)
                }
                
                micControl
                    .padding(.bottom, 80)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var micControl: some View {
        Button {
            if voiceChatService.isActive {
                voiceChatService.toggleListening()
            } else {
                Task {
                    await voiceChatService.startVoiceChat()
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color(red: 1.0, green: 0.73, blue: 0.59).opacity(0.12))
                    .frame(width: 220, height: 220)
                    .overlay(
                        Circle()
                            .stroke(Color(red: 1.0, green: 0.73, blue: 0.59).opacity(0.25), lineWidth: 2)
                    )
                
                Circle()
                    .stroke(Color(red: 1.0, green: 0.73, blue: 0.59).opacity(0.8), lineWidth: 12)
                    .frame(width: 200, height: 200)
                    .scaleEffect(voiceChatService.isListening ? 1.2 : 1.0)
                    .opacity(pulse ? 1 : 0.4)
                    .animation(.easeInOut(duration: 0.4), value: voiceChatService.isListening)
                
                Image(systemName: voiceChatService.isActive ? (voiceChatService.isListening ? "mic.fill" : "waveform") : "play.fill")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundColor(Color(red: 1.0, green: 0.73, blue: 0.59))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(voiceChatService.isActive ? "Toggle listening" : "Start voice chat")
    }
    
}

#Preview {
    VoiceChatView()
        .environmentObject(DIContainer.shared)
}
