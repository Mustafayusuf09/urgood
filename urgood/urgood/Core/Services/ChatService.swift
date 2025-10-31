import Foundation

class ChatService {
    private let localStore: EnhancedLocalStore
    private let openAIService: OpenAIService
    
    init(localStore: EnhancedLocalStore, openAIService: OpenAIService) {
        self.localStore = localStore
        self.openAIService = openAIService
    }
    
    // MARK: - Voice-first Chat
    
    func sendMessage(_ message: String) async -> ChatMessage {
        do {
            // Get conversation history for context
            let conversationHistory = localStore.chatMessages
            
            print("🤖 Sending message to OpenAI: \(message)")
            print("📚 Conversation history: \(conversationHistory.count) messages")
            
            // Send to OpenAI
            let aiResponse = try await openAIService.sendMessage(message, conversationHistory: conversationHistory)
            
            print("✅ Received AI response: \(aiResponse)")
            
            // Create AI response message
            let responseMessage = ChatMessage(role: .assistant, text: aiResponse)
            
            // Save both messages to local storage
            localStore.addMessage(ChatMessage(role: .user, text: message))
            localStore.addMessage(responseMessage)
            
            // Track chat message sent
            FirebaseConfig.logEvent("chat_message_sent", parameters: [
                "message_type": "voice",
                "message_length": message.count,
                "daily_count": localStore.getDailyMessageCount()
            ])
            
            return responseMessage
            
        } catch {
            print("❌ OpenAI API Error: \(error)")
            
            // Handle errors gracefully
            let errorMessage = ChatMessage(
                role: .assistant,
                text: "I'm having trouble connecting right now. Please try again in a moment. If the problem persists, check your internet connection."
            )
            
            // Still save the user message
            localStore.addMessage(ChatMessage(role: .user, text: message))
            localStore.addMessage(errorMessage)
            
            return errorMessage
        }
    }
    
    // MARK: - Voice Chat
    
    func processVoiceMessage(audioURL: URL) async -> ChatMessage {
        do {
            print("🎤 Starting voice message processing...")
            
            // Check if audio file exists and has content
            let audioData = try Data(contentsOf: audioURL)
            guard !audioData.isEmpty else {
                throw NSError(domain: "VoiceProcessing", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Audio file is empty"])
            }
            
            print("📁 Audio file size: \(audioData.count) bytes")
            
            // Transcribe audio to text
            print("🔄 Transcribing audio...")
            let transcribedText = try await openAIService.transcribeAudio(from: audioURL)
            
            guard !transcribedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw NSError(domain: "VoiceProcessing", code: 1002, userInfo: [NSLocalizedDescriptionKey: "No speech detected in audio"])
            }
            
            print("✅ Transcription successful: \(transcribedText)")
            
            // Create user message from transcription
            let userMessage = ChatMessage(role: .user, text: transcribedText)
            localStore.addMessage(userMessage)
            
            // Get AI response
            print("🤖 Getting AI response...")
            let conversationHistory = localStore.chatMessages
            let aiResponse = try await openAIService.sendMessage(transcribedText, conversationHistory: conversationHistory)
            
            // Create AI response message
            let responseMessage = ChatMessage(role: .assistant, text: aiResponse)
            localStore.addMessage(responseMessage)
            
            // Track voice message sent
            FirebaseConfig.logEvent("chat_message_sent", parameters: [
                "message_type": "voice",
                "transcription_length": transcribedText.count,
                "daily_count": localStore.getDailyMessageCount()
            ])
            
            print("✅ Voice message processing completed successfully")
            return responseMessage
            
        } catch {
            print("❌ Voice message processing failed: \(error)")
            
            // Handle specific error types
            let errorMessage: ChatMessage
            if let nsError = error as NSError? {
                switch nsError.code {
                case 1001:
                    errorMessage = ChatMessage(
                        role: .assistant,
                        text: "I didn't detect any audio. Please try speaking again."
                    )
                case 1002:
                    errorMessage = ChatMessage(
                        role: .assistant,
                        text: "I couldn't detect any speech in your message. Please try speaking more clearly."
                    )
                default:
                    errorMessage = ChatMessage(
                        role: .assistant,
                        text: "I had trouble processing your voice message. Please try speaking again in a quieter spot."
                    )
                }
            } else {
                errorMessage = ChatMessage(
                    role: .assistant,
                    text: "I couldn't understand your voice message clearly. Please try speaking again."
                )
            }
            
            // Save error message
            localStore.addMessage(errorMessage)
            
            return errorMessage
        }
    }
    
    // MARK: - Text-to-Speech
    
    func synthesizeSpeech(from text: String) async -> Data? {
        do {
            print("🔊 Starting speech synthesis for: \(text.prefix(50))...")
            
            // Limit text length for TTS to avoid issues
            let maxTTSLength = 1000
            let textToSynthesize = text.count > maxTTSLength ? String(text.prefix(maxTTSLength)) + "..." : text
            
            let audioData = try await openAIService.synthesizeSpeech(from: textToSynthesize)
            
            print("✅ Speech synthesis successful, audio data size: \(audioData.count) bytes")
            return audioData
            
        } catch {
            print("❌ Speech synthesis failed: \(error)")
            return nil
        }
    }
    
    // MARK: - Session Management
    
    func generateSessionSummary(for messages: [ChatMessage]) async -> SessionSummary? {
        do {
            return try await openAIService.generateSessionSummary(from: messages)
        } catch {
            print("Failed to generate session summary: \(error)")
            return nil
        }
    }
    
    func endSession() async -> SessionSummary? {
        // Get today's messages for this session
        let today = Calendar.current.startOfDay(for: Date())
        let todaysMessages = localStore.chatMessages.filter { 
            Calendar.current.isDate($0.date, inSameDayAs: today) 
        }
        
        guard todaysMessages.count >= 2 else { return nil } // Need at least user + AI message
        
        return await generateSessionSummary(for: todaysMessages)
    }
    
    // MARK: - Rate Limiting
    
    func canSendMessage() -> Bool {
        #if DEBUG
        // Development bypass - unlimited messages for testing
        return true
        #else
        let dailyCount = getDailyMessageCount()
        return dailyCount < APIConfig.dailyMessageLimit
        #endif
    }
    
    func getRemainingMessages() -> Int {
        let dailyCount = getDailyMessageCount()
        return max(0, APIConfig.dailyMessageLimit - dailyCount)
    }
    
    // MARK: - Local Storage
    
    func getDailyMessageCount() -> Int {
        return localStore.getDailyMessageCount()
    }
    
    func resetDailyMessageCount() {
        localStore.resetDailyMessageCount()
    }
    

}
