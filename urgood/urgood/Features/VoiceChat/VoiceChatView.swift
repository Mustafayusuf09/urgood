import SwiftUI

struct VoiceChatView: View {
    @EnvironmentObject private var container: DIContainer
    @Environment(\.dismiss) private var dismiss
    @StateObject private var voiceChatService = VoiceChatService()
    @State private var pulse = false
    
    var body: some View {
        ZStack {
            background
            
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
            Task { await voiceChatService.startVoiceChat() }
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
                .foregroundColor(.white)
            
            Text("Ready to chat with UrGood (\"your good\")?")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            
            if !voiceChatService.statusMessage.isEmpty {
                Text(voiceChatService.statusMessage)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            
            if let error = voiceChatService.error {
                Text(error)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.brandAccent)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
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
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 220, height: 220)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 2)
                    )
                
                Circle()
                    .stroke(Color.brandElectric.opacity(0.6), lineWidth: 12)
                    .frame(width: 200, height: 200)
                    .scaleEffect(voiceChatService.isListening ? 1.2 : 1.0)
                    .opacity(pulse ? 1 : 0.4)
                    .animation(.easeInOut(duration: 0.4), value: voiceChatService.isListening)
                
                Image(systemName: voiceChatService.isActive ? (voiceChatService.isListening ? "mic.fill" : "waveform") : "play.fill")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(voiceChatService.isActive ? "Toggle listening" : "Start voice chat")
    }
    
    
    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.07, green: 0.09, blue: 0.20),
                Color(red: 0.14, green: 0.07, blue: 0.25),
                Color(red: 0.03, green: 0.06, blue: 0.15)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.brandElectric.opacity(0.35),
                    Color.clear
                ]),
                center: .center,
                startRadius: 20,
                endRadius: 350
            )
            .blendMode(.plusLighter)
        )
    }
}

#Preview {
    VoiceChatView()
        .environmentObject(DIContainer.shared)
}
