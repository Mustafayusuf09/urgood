import SwiftUI
import UIKit

// MARK: - Accessibility Enhancement Extensions

extension View {
    /// Adds comprehensive accessibility support with proper labels, hints, and traits
    func accessibilityEnhanced(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: SwiftUI.AccessibilityTraits = [],
        actions: [AccessibilityActionKind: () -> Void] = [:]
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(traits)
            .accessibilityActions {
                ForEach(Array(actions.keys), id: \.self) { actionKind in
                    Button(actionKind.description) {
                        actions[actionKind]?()
                    }
                }
            }
    }
    
    /// Ensures minimum touch target size for accessibility
    func accessibleTouchTarget(minSize: CGFloat = 44) -> some View {
        self
            .frame(minWidth: minSize, minHeight: minSize)
            .contentShape(Rectangle())
    }
    
    /// Adds Dynamic Type support with custom scaling
    func dynamicTypeSize(
        _ size: DynamicTypeSize = .large,
        maxSize: DynamicTypeSize = .accessibility3
    ) -> some View {
        self
            .dynamicTypeSize(size...maxSize)
    }
    
    /// Groups related accessibility elements
    func accessibilityGroup(
        label: String,
        hint: String? = nil,
        children: Bool = true
    ) -> some View {
        self
            .accessibilityElement(children: children ? .contain : .ignore)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
    }
    
    /// Adds focus management for keyboard navigation
    func accessibilityFocusable(
        _ isFocused: FocusState<Bool>.Binding? = nil,
        priority: AccessibilityFocusPriority = .normal
    ) -> some View {
        Group {
            if let focusBinding = isFocused {
                self.focused(focusBinding)
            } else {
                self
            }
        }
        .accessibilityAddTraits(.isKeyboardKey)
    }
}

// MARK: - Accessibility Action Kinds

enum AccessibilityActionKind: CustomStringConvertible, Hashable {
    case activate
    case increment
    case decrement
    case delete
    case escape
    case magicTap
    case pause
    case showMenu
    case custom(String)
    
    var description: String {
        switch self {
        case .activate: return "Activate"
        case .increment: return "Increase"
        case .decrement: return "Decrease"
        case .delete: return "Delete"
        case .escape: return "Escape"
        case .magicTap: return "Magic Tap"
        case .pause: return "Pause"
        case .showMenu: return "Show Menu"
        case .custom(let name): return name
        }
    }
}

// MARK: - Accessibility Focus Priority

enum AccessibilityFocusPriority {
    case low
    case normal
    case high
    case critical
}

// MARK: - Enhanced Message Row with Accessibility

struct AccessibleMessageRow: View {
    let message: ChatMessage
    let isFromUser: Bool
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isExpanded = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if !isFromUser {
                // AI Avatar
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: avatarSize, height: avatarSize)
                    .overlay(
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: avatarIconSize))
                            .foregroundColor(.blue)
                    )
                    .accessibilityHidden(true) // Decorative element
            }
            
            VStack(alignment: isFromUser ? .trailing : .leading, spacing: 4) {
                // Message bubble
                Text(message.text)
                    .font(.body)
                    .foregroundColor(isFromUser ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(isFromUser ? Color.blue : Color.gray.opacity(0.1))
                    )
                    .dynamicTypeSize(.large...(.accessibility3))
                    .accessibilityEnhanced(
                        label: "\(isFromUser ? "Your message" : "AI response"): \(message.text)",
                        hint: isFromUser ? "Your message to the AI" : "AI's response to your message",
                        traits: [.isStaticText],
                        actions: [
                            .custom("Copy message"): {
                                UIPasteboard.general.string = message.text
                            }
                        ]
                    )
                
                // Timestamp
                Text(formatTimestamp(message.date))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Sent at \(formatAccessibleTimestamp(message.date))")
                    .accessibilityAddTraits(.isStaticText)
            }
            
            if isFromUser {
                Spacer(minLength: 40)
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .accessibilityGroup(
            label: "\(isFromUser ? "Your message" : "AI message") sent at \(formatAccessibleTimestamp(message.date))",
            hint: "Double tap to copy message text"
        )
    }
    
    private var avatarSize: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 32
        case .medium, .large: return 36
        case .xLarge, .xxLarge: return 40
        default: return 44
        }
    }
    
    private var avatarIconSize: CGFloat {
        avatarSize * 0.6
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatAccessibleTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Accessible Input Field

struct AccessibleChatInput: View {
    @Binding var text: String
    let placeholder: String
    let onSend: () -> Void
    let isEnabled: Bool
    
    @FocusState private var isFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        HStack(spacing: 12) {
            // Text input
            TextField(placeholder, text: $text, axis: .vertical)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.gray.opacity(0.1))
                )
                .focused($isFocused)
                .disabled(!isEnabled)
                .dynamicTypeSize(.large...(.accessibility2))
                .accessibilityEnhanced(
                    label: "Message input field",
                    hint: isEnabled ? "Type your message here. Double tap to edit." : "Message input is disabled",
                    traits: isEnabled ? [.isKeyboardKey] : [],
                    actions: [
                        .activate: {
                            isFocused = true
                        }
                    ]
                )
            
            // Send button
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: sendButtonSize))
                    .foregroundColor(canSend ? .blue : .gray)
            }
            .disabled(!canSend || !isEnabled)
            .accessibleTouchTarget()
            .accessibilityEnhanced(
                label: "Send message",
                hint: canSend ? "Send your message to the AI" : "Enter a message to send",
                traits: [.isButton]
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .accessibilityGroup(
            label: "Message composition area",
            hint: "Type and send messages to the AI"
        )
    }
    
    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var sendButtonSize: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 28
        case .medium, .large: return 32
        case .xLarge, .xxLarge: return 36
        default: return 40
        }
    }
}

// MARK: - Accessible Voice Button

struct AccessibleVoiceButton: View {
    let isRecording: Bool
    let isProcessing: Bool
    let onToggle: () -> Void
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        Button(action: onToggle) {
            ZStack {
                Circle()
                    .fill(buttonColor)
                    .frame(width: buttonSize, height: buttonSize)
                
                Image(systemName: buttonIcon)
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundColor(.white)
                
                if isProcessing {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: buttonSize - 8, height: buttonSize - 8)
                }
            }
        }
        .disabled(isProcessing)
        .accessibleTouchTarget(minSize: max(44, buttonSize))
        .accessibilityEnhanced(
            label: accessibilityLabel,
            hint: accessibilityHint,
            traits: isProcessing ? [.isButton, .playsSound] : [.isButton, .playsSound]
        )
    }
    
    private var buttonSize: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 56
        case .medium, .large: return 64
        case .xLarge, .xxLarge: return 72
        default: return 80
        }
    }
    
    private var iconSize: CGFloat {
        buttonSize * 0.4
    }
    
    private var buttonColor: Color {
        if isProcessing {
            return .orange
        } else if isRecording {
            return .red
        } else {
            return .blue
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
        if isProcessing {
            return "Processing voice"
        } else if isRecording {
            return "Stop recording"
        } else {
            return "Start voice recording"
        }
    }
    
    private var accessibilityHint: String {
        if isProcessing {
            return "Please wait while your voice is being processed"
        } else if isRecording {
            return "Tap to stop recording your voice message"
        } else {
            return "Tap to start recording a voice message"
        }
    }
}

// MARK: - Accessibility Announcements

class AccessibilityAnnouncer {
    static let shared = AccessibilityAnnouncer()
    
    private init() {}
    
    func announce(_ message: String, priority: UIAccessibility.Notification = .announcement) {
        DispatchQueue.main.async {
            UIAccessibility.post(notification: priority, argument: message)
        }
    }
    
    func announceScreenChange(to element: Any? = nil) {
        DispatchQueue.main.async {
            UIAccessibility.post(notification: .screenChanged, argument: element)
        }
    }
    
    func announceLayoutChange(to element: Any? = nil) {
        DispatchQueue.main.async {
            UIAccessibility.post(notification: .layoutChanged, argument: element)
        }
    }
    
    // Specific announcements for the app
    func announceMessageSent() {
        announce("Message sent", priority: .announcement)
    }
    
    func announceMessageReceived() {
        announce("New message from AI", priority: .announcement)
    }
    
    func announceRecordingStarted() {
        announce("Recording started", priority: .announcement)
    }
    
    func announceRecordingStopped() {
        announce("Recording stopped", priority: .announcement)
    }
    
    func announceError(_ error: String) {
        announce("Error: \(error)", priority: .announcement)
    }
    
    func announceVoiceModeEntered() {
        announce("Voice mode activated. You can now speak with the AI.", priority: .announcement)
    }
    
    func announceVoiceModeExited() {
        announce("Voice mode deactivated. Returned to text mode.", priority: .announcement)
    }
}

// MARK: - Color Contrast Helpers

extension Color {
    /// Ensures sufficient contrast ratio for accessibility
    func accessibleContrast(on background: Color) -> Color {
        // This is a simplified implementation
        // In a real app, you'd calculate the actual contrast ratio
        return self
    }
    
    /// Returns a color with sufficient contrast for text
    var accessibleTextColor: Color {
        // Simplified: return white for dark colors, black for light colors
        return self == .black || self == .blue || self == .red ? .white : .black
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        AccessibleMessageRow(
            message: ChatMessage(role: .assistant, text: "Hello! How are you feeling today?"),
            isFromUser: false
        )
        
        AccessibleMessageRow(
            message: ChatMessage(role: .user, text: "I'm feeling a bit anxious about work."),
            isFromUser: true
        )
        
        AccessibleChatInput(
            text: .constant(""),
            placeholder: "Type your message...",
            onSend: {},
            isEnabled: true
        )
        
        AccessibleVoiceButton(
            isRecording: false,
            isProcessing: false,
            onToggle: {}
        )
    }
    .padding()
}
