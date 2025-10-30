import Foundation
import AVFoundation
import Combine

/// Voice chat service that manages the OpenAI Realtime client
@MainActor
final class VoiceChatService: ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var isActive = false
    @Published private(set) var isConnected = false
    @Published private(set) var isListening = false
    @Published private(set) var isSpeaking = false
    @Published private(set) var currentTranscript = ""
    @Published private(set) var statusMessage = "Tap to start voice chat"
    @Published private(set) var error: String?
    @Published var showPaywall = false
    @Published private(set) var softCapReached = false
    
    // MARK: - Private Properties
    private var realtimeClient: OpenAIRealtimeClient?
    private var apiKey: String?
    private let voiceAuthService = VoiceAuthService()
    private var cancellables = Set<AnyCancellable>()
    private let chatService: ChatService
    private let billingService: any BillingServiceProtocol
    private let localStore: EnhancedLocalStore
    private var lastStoredUserTranscript: (text: String, timestamp: Date)?
    private var lastStoredAssistantResponse: (text: String, timestamp: Date)?
    private var sessionStartTime: Date?
    private var sessionMessageCount: Int = 0
    
    convenience init() {
        self.init(container: DIContainer.shared)
    }

    init(container: DIContainer) {
        self.chatService = container.chatService
        self.billingService = container.billingService
        self.localStore = container.localStore
        self.statusMessage = quotaAppended(to: "Tap to start voice chat")
    }
    
    // MARK: - Public Methods
    
    func startVoiceChat() async {
        guard !isActive else { return }
        guard ensureMessageQuotaAvailable() else { return }
        error = nil

        // Request microphone permission first
        let permissionGranted = await requestMicrophonePermission()
        guard permissionGranted else {
            error = "Microphone permission is required for voice chat"
            return
        }
        
        // Start backend session tracking
        statusMessage = quotaAppended(to: "Getting ready...")
        do {
            let sessionId = try await voiceAuthService.startSession()
            print("✅ [VoiceChat] Backend session started: \(sessionId)")
            
            // Check soft cap status
            softCapReached = voiceAuthService.softCapReached
            if softCapReached {
                statusMessage = "Daily sessions reached. We'll do our best to keep going."
            }
            
            // Fetch API key from backend
            let fetchedKey = try await voiceAuthService.getVoiceChatAPIKey()
            apiKey = fetchedKey
            print("✅ [VoiceChat] API key authorized")
        } catch VoiceAuthError.premiumRequired {
            print("❌ [VoiceChat] Premium subscription required")
            self.error = "Voice chat requires premium subscription. Upgrade to continue."
            statusMessage = "Premium required"
            showPaywall = true
            return
        } catch {
            print("❌ [VoiceChat] Failed to authorize: \(error)")
            self.error = "Unable to start voice chat. Please try again."
            statusMessage = "Authorization failed"
            return
        }
        
        guard let apiKey = apiKey else {
            error = "API key not available"
            return
        }
        
        // Track session start time
        sessionStartTime = Date()
        sessionMessageCount = 0
        
        // Create and configure client
        realtimeClient = OpenAIRealtimeClient(apiKey: apiKey)
        setupClientObservers()
        
        do {
            statusMessage = softCapReached 
                ? "Connected (soft cap reached)..."
                : quotaAppended(to: "Connected! Start talking...")
            try await realtimeClient?.connect()
            isActive = true
            
            // Start listening automatically
            if ensureMessageQuotaAvailable() {
                realtimeClient?.startListening()
            }
        } catch {
            print("🎙️ [ERROR] Connection error: \(error)")
            self.error = "Failed to connect: \(error.localizedDescription)"
            statusMessage = "Connection failed"
        }
    }
    
    func stopVoiceChat() {
        // Calculate session duration and end backend session
        if let startTime = sessionStartTime {
            let duration = Date().timeIntervalSince(startTime)
            Task {
                await voiceAuthService.endSession(duration: duration, messageCount: sessionMessageCount)
            }
        }
        
        realtimeClient?.disconnect()
        realtimeClient = nil
        isActive = false
        isConnected = false
        isListening = false
        isSpeaking = false
        currentTranscript = ""
        statusMessage = quotaAppended(to: "Tap to start voice chat")
        error = nil
        softCapReached = false
        lastStoredUserTranscript = nil
        lastStoredAssistantResponse = nil
        sessionStartTime = nil
        sessionMessageCount = 0
    }
    
    func toggleListening() {
        guard let client = realtimeClient, isConnected else { return }
        
        if isListening {
            client.stopListening()
        } else {
            guard ensureMessageQuotaAvailable() else {
                stopVoiceChat()
                return
            }
            error = nil
            client.startListening()
        }
    }
    
    func clearError() {
        error = nil
    }
    
    // MARK: - Private Methods
    
    private func setupClientObservers() {
        guard let client = realtimeClient else { return }
        
        // Observe client state changes
        client.$isConnected
            .receive(on: DispatchQueue.main)
            .assign(to: &$isConnected)
        
        client.$isListening
            .receive(on: DispatchQueue.main)
            .assign(to: &$isListening)
        
        client.$isSpeaking
            .receive(on: DispatchQueue.main)
            .assign(to: &$isSpeaking)
        
        client.$currentTranscript
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentTranscript)
        
        client.$error
            .receive(on: DispatchQueue.main)
            .assign(to: &$error)
        
        // Update status message based on state
        Publishers.CombineLatest4(
            client.$isConnected,
            client.$isListening,
            client.$isSpeaking,
            client.$error
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] connected, listening, speaking, error in
            self?.updateStatusMessage(
                connected: connected,
                listening: listening,
                speaking: speaking,
                error: error
            )
        }
        .store(in: &cancellables)
        
        client.onUserTranscript = { [weak self] transcript in
            self?.recordUserTranscript(transcript)
            self?.sessionMessageCount += 1
        }
        client.onAssistantResponse = { [weak self] transcript in
            self?.recordAssistantResponse(transcript)
            self?.sessionMessageCount += 1
        }
    }
    
    private func updateStatusMessage(connected: Bool, listening: Bool, speaking: Bool, error: String?) {
        if let error = error {
            statusMessage = "Error: \(error)"
        } else if !connected {
            statusMessage = quotaAppended(to: "Connecting...")
        } else if speaking {
            statusMessage = softCapReached 
                ? "UrGood is speaking... (soft cap reached)"
                : "UrGood is speaking..."
        } else if listening {
            statusMessage = softCapReached
                ? "Listening... (soft cap reached)"
                : quotaAppended(to: "Listening... speak now")
        } else {
            statusMessage = softCapReached
                ? "Tap to talk (soft cap reached)"
                : quotaAppended(to: "Tap to talk with UrGood")
        }
    }
    
    private func ensureMessageQuotaAvailable() -> Bool {
        if billingService.isSubscribed() {
            if error != nil { error = nil }
            return true
        }
        if chatService.canSendMessage() {
            if error != nil { error = nil }
            return true
        }
        error = "Daily limit reached. Upgrade to keep chatting."
        statusMessage = "Daily limit reached"
        if !showPaywall {
            showPaywall = true
        }
        return false
    }
    
    private func quotaAppended(to base: String) -> String {
        guard let suffix = quotaSuffix() else { return base }
        return "\(base) \(suffix)"
    }
    
    private func quotaSuffix() -> String? {
        guard !billingService.isSubscribed() else { return nil }
        let remaining = chatService.getRemainingMessages()
        return "(\(remaining) left today)"
    }
    
    private func recordUserTranscript(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let last = lastStoredUserTranscript,
           last.text == trimmed,
           Date().timeIntervalSince(last.timestamp) < 1 {
            return
        }
        lastStoredUserTranscript = (trimmed, Date())
        let message = ChatMessage(role: .user, text: trimmed)
        localStore.addMessage(message)
    }
    
    private func recordAssistantResponse(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let last = lastStoredAssistantResponse,
           last.text == trimmed,
           Date().timeIntervalSince(last.timestamp) < 1 {
            return
        }
        lastStoredAssistantResponse = (trimmed, Date())
        let message = ChatMessage(role: .assistant, text: trimmed)
        localStore.addMessage(message)
    }
    
    private func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
