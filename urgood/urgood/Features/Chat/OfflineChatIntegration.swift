import SwiftUI
import Combine

/// Example integration showing how to use offline mode in chat features
/// Demonstrates proper error handling and user feedback for offline scenarios
struct OfflineChatView: View {
    @StateObject private var offlineAPI = OfflineAwareAPIService.shared
    @StateObject private var localStore = EnhancedLocalStore.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    @State private var messageText = ""
    @State private var showOfflineAlert = false
    @State private var lastError: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Offline status bar
            if !networkMonitor.isConnected || offlineAPI.queuedOperationsCount > 0 {
                OfflineStatusView()
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
            
            // Chat messages
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(localStore.chatMessages) { message in
                        ChatMessageRow(message: message)
                    }
                }
                .padding()
            }
            
            // Message input
            messageInputView
        }
        .navigationTitle("Chat")
        .alert("Message Queued", isPresented: $showOfflineAlert) {
            Button("OK") { }
        } message: {
            Text("Your message has been queued and will be sent when connection is restored.")
        }
    }
    
    private var messageInputView: some View {
        VStack(spacing: 8) {
            // Connection status indicator
            if !networkMonitor.isConnected {
                HStack {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(.orange)
                    Text("Offline - messages will be queued")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                }
                .padding(.horizontal)
            }
            
            HStack(spacing: 12) {
                TextField("Type a message...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(messageText.isEmpty ? Color.gray : Color.blue)
                        .clipShape(Circle())
                }
                .disabled(messageText.isEmpty)
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator)),
            alignment: .top
        )
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = ChatMessage(role: .user, text: messageText)
        
        // Always save locally first for immediate UI feedback
        localStore.addMessage(userMessage)
        
        // Clear input
        let messageToSend = messageText
        messageText = ""
        
        // Try to send via offline-aware API
        Task {
            do {
                _ = try await offlineAPI.sendChatMessage(userMessage, userId: getCurrentUserId())
                
                // If successful, generate AI response
                await generateAIResponse(for: messageToSend)
                
            } catch OfflineAPIError.queuedForLater {
                // Message was queued for later - show user feedback
                await MainActor.run {
                    showOfflineAlert = true
                }
                
                // Still generate AI response if possible (cached/offline AI)
                await generateOfflineAIResponse(for: messageToSend)
                
            } catch {
                // Handle other errors
                await MainActor.run {
                    lastError = error.localizedDescription
                }
            }
        }
    }
    
    private func generateAIResponse(for message: String) async {
        do {
            let openAIService = OpenAIService()
            let response = try await openAIService.sendMessage(message, conversationHistory: localStore.chatMessages)
            
            let aiMessage = ChatMessage(role: .assistant, text: response)
            
            await MainActor.run {
                localStore.addMessage(aiMessage)
            }
            
            // Queue AI response for sync if offline
            if !networkMonitor.canPerformNetworkOperation() {
                _ = try await offlineAPI.sendChatMessage(aiMessage, userId: getCurrentUserId())
            }
            
        } catch {
            print("❌ Failed to generate AI response: \(error)")
            
            // Fallback to offline response
            await generateOfflineAIResponse(for: message)
        }
    }
    
    private func generateOfflineAIResponse(for message: String) async {
        // Generate a simple offline response
        let offlineResponses = [
            "I understand you're trying to reach out. I'll be able to provide a more detailed response once we're back online.",
            "Thank you for sharing. Your message is important to me, and I'll respond fully when our connection is restored.",
            "I'm here with you, even offline. Let's continue our conversation when we're connected again.",
            "Your thoughts and feelings matter. I'll give you my full attention once we're back online."
        ]
        
        let response = offlineResponses.randomElement() ?? offlineResponses[0]
        let aiMessage = ChatMessage(role: .assistant, text: response)
        
        await MainActor.run {
            localStore.addMessage(aiMessage)
        }
        
        // Queue for sync when online
        do {
            _ = try await offlineAPI.sendChatMessage(aiMessage, userId: getCurrentUserId())
        } catch {
            print("❌ Failed to queue offline AI response: \(error)")
        }
    }
    
    private func getCurrentUserId() -> String {
        // Get current user ID from auth service
        if let user = DIContainer.shared.authService.currentUser as? StandaloneAuthService.StandaloneUser {
            return user.id
        } else if let user = DIContainer.shared.authService.currentUser as? ProductionAuthService.ProductionUser {
            return user.id
        }
        return "anonymous"
    }
}

// MARK: - Chat Message Row

struct ChatMessageRow: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
                
                Text(message.text)
                    .padding(12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .trailing)
            } else {
                Text(message.text)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .foregroundColor(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .leading)
                
                Spacer()
            }
        }
    }
}

// MARK: - Offline Chat Settings

struct OfflineChatSettings: View {
    @StateObject private var offlineSync = OfflineDataSync.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    var body: some View {
        List {
            Section("Offline Status") {
                HStack {
                    Text("Network Status")
                    Spacer()
                    Text(networkMonitor.isConnected ? "Connected" : "Offline")
                        .foregroundColor(networkMonitor.isConnected ? .green : .red)
                }
                
                HStack {
                    Text("Connection Type")
                    Spacer()
                    Text(networkMonitor.connectionType.rawValue.capitalized)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Pending Operations")
                    Spacer()
                    Text("\(offlineSync.pendingOperationsCount)")
                        .foregroundColor(offlineSync.pendingOperationsCount > 0 ? .orange : .green)
                }
                
                if let lastSync = offlineSync.lastSyncDate {
                    HStack {
                        Text("Last Sync")
                        Spacer()
                        Text(formatDate(lastSync))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Actions") {
                if networkMonitor.canPerformNetworkOperation() && offlineSync.pendingOperationsCount > 0 {
                    Button("Force Sync Now") {
                        Task {
                            await offlineSync.forcSync()
                        }
                    }
                }
                
                Button("Clear Pending Operations", role: .destructive) {
                    offlineSync.clearPendingOperations()
                }
            }
            
            Section("Settings") {
                Toggle("Auto-sync when connected", isOn: .constant(true))
                    .disabled(true) // Always enabled for now
                
                Toggle("Queue messages when offline", isOn: .constant(true))
                    .disabled(true) // Always enabled for now
            }
        }
        .navigationTitle("Offline Settings")
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview

struct OfflineChatView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            OfflineChatView()
        }
    }
}

