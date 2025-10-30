import SwiftUI

struct VoicePickerView: View {
    @Binding var selectedVoice: ElevenLabsVoice
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 12) {
                        Text("Choose UrGood's Voice (\"your good\")")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.textPrimary)
                        
                        Text("Select the voice that feels right for you")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 24)
                    
                    // Voice options
                    VStack(spacing: 12) {
                        ForEach(ElevenLabsVoice.allCases, id: \.self) { voice in
                            VoiceOptionCard(
                                voice: voice,
                                isSelected: selectedVoice == voice,
                                onSelect: {
                                    selectedVoice = voice
                                    UserDefaults.standard.selectedVoice = voice
                                    
                                    // Haptic feedback
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                    
                                    // Dismiss after short delay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        dismiss()
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .background(Color.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.textTertiary)
                    }
                }
            }
        }
    }
}

// MARK: - Voice Option Card

struct VoiceOptionCard: View {
    let voice: ElevenLabsVoice
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            isSelected
                            ? LinearGradient(
                                colors: [Color.brandPrimary, Color.brandSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.surface, Color.surface],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .overlay(
                            Circle()
                                .stroke(
                                    isSelected ? Color.clear : Color.brandPrimary.opacity(0.2),
                                    lineWidth: 2
                                )
                        )
                    
                    Text(voice.icon)
                        .font(.system(size: 28))
                }
                
                // Voice info
                VStack(alignment: .leading, spacing: 4) {
                    Text(voice.displayName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    
                    Text(voice.description)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textSecondary)
                    
                    // Gender tag
                    HStack(spacing: 6) {
                        Image(systemName: voice.isFemale ? "person.fill" : "person.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.brandPrimary)
                        
                        Text(voice.isFemale ? "Female" : "Male")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.brandPrimary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.brandPrimary.opacity(0.1))
                    )
                }
                
                Spacer()
                
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(
                            isSelected ? Color.brandPrimary : Color.textTertiary.opacity(0.3),
                            lineWidth: 2
                        )
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.brandPrimary)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected
                                ? Color.brandPrimary
                                : Color.brandPrimary.opacity(0.1),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                    .shadow(
                        color: isSelected
                        ? Color.brandPrimary.opacity(0.2)
                        : Color.clear,
                        radius: 12,
                        x: 0,
                        y: 4
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

struct VoicePickerView_Previews: PreviewProvider {
    static var previews: some View {
        VoicePickerView(selectedVoice: .constant(.nova))
    }
}
