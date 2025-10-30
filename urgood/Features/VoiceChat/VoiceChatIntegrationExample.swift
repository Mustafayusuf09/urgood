import SwiftUI

// MARK: - Voice Chat Integration Example
// This shows how to integrate the rebuilt VoiceChatView into your app

struct VoiceChatIntegrationExample: View {
    @State private var showVoiceChat = false
    @State private var container = DIContainer()
    
    var body: some View {
        VStack(spacing: Spacing.lg) {
            Text("Voice Chat Experience")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)
            
        Text("UrGood (\"your good\") will listen, reflect, and respond in real-time.")
                .font(.subheadline)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: Spacing.md) {
            FeatureRow(icon: "waveform", title: "Live captions", description: "Every response streams in as text while UrGood speaks.")
                FeatureRow(icon: "mic.fill.badge.plus", title: "Push-to-talk", description: "Tap the mic to pause or resume the realtime session.")
                FeatureRow(icon: "sparkles", title: "Rebuilt audio engine", description: "New AVAudioEngine + WebSocket pipeline for lower latency.")
                FeatureRow(icon: "shield", title: "Safety-first", description: "Crisis footer is always visible underneath the chat.")
            }
            .padding(.horizontal, Spacing.lg)
            
            Spacer()
            
            PrimaryButton("Start Voice Chat") {
                showVoiceChat = true
            }
            .padding(.horizontal, Spacing.lg)
        }
        .padding(.vertical, Spacing.xl)
        .fullScreenCover(isPresented: $showVoiceChat) {
            VoiceChatView()
                .environmentObject(container)
                .environmentObject(AppRouter())
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.brandPrimary.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.brandPrimary)
            }
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.textPrimary)
                
                Text(description)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
    }
}

// MARK: - Navigation Integration
// Add this to your main navigation or ContentView to integrate the new voice chat

extension ContentView {
    func addVoiceChatNavigation() -> some View {
        self
            .onAppear {
                // You can add navigation logic here if needed
                // For example, deep linking to voice chat
            }
    }
}

// MARK: - Usage Instructions
/*
 
 INTEGRATION STEPS:
 
 1. Add VoiceChatView to your navigation:
    - Use fullScreenCover for full-screen experience
    - Or embed in NavigationView for integrated experience
 
 2. Pass DIContainer:
    - Ensure your DIContainer has OpenAIService and ChatService
    - The view model will handle all voice chat logic
 
 3. Customize if needed:
    - Modify colors in Theme.swift
    - Adjust animations in the view components
    - Add additional features as needed
 
 4. Test thoroughly:
    - Microphone permissions
    - Audio playback
    - Network connectivity
    - Error handling
 
 DESIGN FEATURES IMPLEMENTED:
 
 ✅ Soft navy → indigo gradient background
 ✅ Streaming transcript feed
 ✅ Central mic button with audio-reactive ring
 ✅ Safety footer + close affordance
 ✅ Modular controller/service layers for easier testing
 
 */

#Preview {
    VoiceChatIntegrationExample()
        .environmentObject(DIContainer.shared)
        .environmentObject(AppRouter())
}
