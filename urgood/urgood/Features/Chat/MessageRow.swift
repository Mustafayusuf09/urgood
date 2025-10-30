import SwiftUI

struct MessageRow: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.sm) {
            if message.role == .assistant {
                // Assistant message (left side)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        // Avatar
                        Circle()
                            .fill(Color.brandPrimary)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "brain.head.profile")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            )
                        
                        // Message bubble
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(message.text)
                                .font(Typography.body)
                                .foregroundColor(.textPrimary)
                                .padding(.horizontal, Spacing.md)
                                .padding(.vertical, Spacing.sm)
                                .background(
                                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                                        .fill(Color.surface)
                                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                                )
                            
                            // Timestamp
                            Text(formatTime(message.date))
                                .font(Typography.caption)
                                .foregroundColor(.textSecondary)
                                .padding(.leading, Spacing.md)
                        }
                        
                        Spacer(minLength: 60)
                    }
                }
            } else {
                // User message (right side)
                Spacer(minLength: 60)
                
                VStack(alignment: .trailing, spacing: Spacing.xs) {
                    // Message bubble
                    VStack(alignment: .trailing, spacing: Spacing.xs) {
                        Text(message.text)
                            .font(Typography.body)
                            .foregroundColor(.white)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.lg)
                                    .fill(Color.brandPrimary)
                            )
                        
                        // Timestamp
                        Text(formatTime(message.date))
                            .font(Typography.caption)
                            .foregroundColor(.textSecondary)
                            .padding(.trailing, Spacing.md)
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct SuggestedToolCard: View {
    let tool: Tool
    let onTryNow: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            // Tool icon
            Image(systemName: iconForToolKind(tool.kind))
                .font(.title2)
                .foregroundColor(.brandPrimary)
                .frame(width: 40, height: 40)
                .background(Color.brandPrimary.opacity(0.1))
                .cornerRadius(CornerRadius.md)
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(tool.title)
                    .font(Typography.headline)
                    .foregroundColor(.textPrimary)
                
                Text("\(tool.durationMin) min")
                    .font(Typography.footnote)
                    .foregroundColor(.textSecondary)
                
                HStack(spacing: Spacing.sm) {
                    PrimaryButton("Try now", style: .primary) {
                        onTryNow()
                    }
                    .frame(height: 32)
                    
                    Button("Dismiss") {
                        onDismiss()
                    }
                    .font(Typography.footnote)
                    .foregroundColor(.textSecondary)
                }
            }
            
            Spacer()
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(Color.brandSecondary.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .stroke(Color.brandSecondary.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
    }
    
    private func iconForToolKind(_ kind: ToolKind) -> String {
        switch kind {
        case .breathe:
            return "lungs.fill"
        case .ground:
            return "leaf.fill"
        case .reframe:
            return "lightbulb.fill"
        case .sleep:
            return "moon.fill"
        }
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        MessageRow(message: ChatMessage(
            role: .assistant,
            text: "I hear you, and that sounds really challenging. What's one small step you could take right now to help yourself feel a bit better?"
        ))
        
        MessageRow(message: ChatMessage(
            role: .user,
            text: "I'm feeling really anxious about my exam tomorrow"
        ))
        
        SuggestedToolCard(
            tool: Tool(
                title: "4-7-8 Breathing",
                kind: .breathe,
                durationMin: 2,
                summary: "Calm your nervous system"
            ),
            onTryNow: { print("Try now tapped") },
            onDismiss: { print("Dismiss tapped") }
        )
    }
    .themeEnvironment()
}
