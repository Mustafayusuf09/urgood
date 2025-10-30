import Foundation
@preconcurrency import AVFoundation
import Combine

// Modern audio buffer scheduling extension
extension AVAudioPlayerNode {
    func scheduleBufferAsync(_ buffer: AVAudioPCMBuffer) async {
        return await withCheckedContinuation { continuation in
            self.scheduleBuffer(buffer) {
                continuation.resume()
            }
        }
    }
}

/// OpenAI Realtime API client for speech-to-speech conversations
/// Implements WebSocket connection to gpt-4o-realtime-preview
@MainActor
final class OpenAIRealtimeClient: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var isConnected = false
    @Published private(set) var isListening = false
    @Published private(set) var isSpeaking = false
    @Published private(set) var currentTranscript = ""
    @Published private(set) var error: String?
    
    // MARK: - Event Callbacks
    var onUserTranscript: ((String) -> Void)?
    var onAssistantResponse: ((String) -> Void)?
    
    // MARK: - Private Properties
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private let apiKey: String
    private let voiceAuthService = VoiceAuthService()
    
    // ElevenLabs Integration
    private let elevenLabsService = ElevenLabsService()
    private var useElevenLabs = APIConfig.useElevenLabs
    private var currentResponseText = ""
    
    // Crashlytics Integration
    private let crashlytics = CrashlyticsService.shared
    
    // Audio Session Management
    private let audioSessionManager = AudioSessionManager.shared
    
    // Audio Engine
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioPlayer: AVAudioPlayerNode?
    private var playerOutputFormat: AVAudioFormat?
    private var audioFormat: AVAudioFormat?
    
    // State
    private var isRecording = false
    private var openAIAudioBuffer = Data()
    private var cancellables = Set<AnyCancellable>()
    
    // VAD State
    private var isSpeechActive = false
    private let noiseGateThreshold: Float = -35.0 // Tightened from -40 dB to reduce false positives
    
    // Enhanced VAD parameters
    private var backgroundNoiseLevel: Float = -60.0 // Adaptive background noise baseline
    private var speechContinuityBuffer: [Bool] = [] // Track speech continuity
    private let speechContinuityWindowSize = 5 // Number of buffers to analyze
    private let speechContinuityThreshold = 3 // Minimum buffers with speech to confirm activity
    private var noiseCalibrationSamples: [Float] = [] // For adaptive threshold
    private let maxNoiseCalibrationSamples = 50 // Samples for noise floor estimation
    
    // VAD Performance Tracking
    private var vadFalsePositiveCount = 0
    private var lastVADDecision = false
    private var vadSessionStartTime: Date?
    private var pendingResponseDebounceTask: Task<Void, Never>?
    private let speechStopDebounceNanoseconds: UInt64 = 350_000_000 // 0.35s guard before replying
    
    // Session configuration
    private let realtimeAPIURL = "wss://api.openai.com/v1/realtime?model=gpt-4o-mini-realtime-preview-2024-10-01"
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 3
    private var shouldReconnect = true
    
    // MARK: - Init
    
    init(apiKey: String) {
        self.apiKey = apiKey
        super.init()
        
        // Setup audio engine asynchronously
        Task {
            await setupAudioEngine()
        }
        
        // Log voice synthesis method
        if useElevenLabs {
            print("✅ [Realtime] Using ElevenLabs for voice output")
        } else {
            print("ℹ️ [Realtime] ElevenLabs not configured, will use fallback synthesis")
        }
    }
    
    deinit {
        // Cleanup is handled by disconnect() being called explicitly
        // Cannot call MainActor methods from deinit
        shouldReconnect = false
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }
    
    // MARK: - Public Methods
    
    func connect() async throws {
        guard !isConnected else { return }
        
        print("🔌 [Realtime] Connecting to OpenAI Realtime API...")
        
        // Get API key from Firebase Functions (production-safe)
        let actualAPIKey: String
        do {
            actualAPIKey = try await voiceAuthService.getVoiceChatAPIKey()
            print("✅ [Realtime] Got API key from Firebase Functions")
        } catch {
            print("❌ [Realtime] Firebase authorization failed: \(error)")
            
            // Track authentication error in Crashlytics
            crashlytics.recordAuthenticationError(error, method: "firebase_voice_auth")
            throw error
        }
        
        // Create URL request
        guard let urlComponents = URLComponents(string: realtimeAPIURL),
              let url = urlComponents.url else {
            throw RealtimeError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(actualAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")
        
        // Create session and WebSocket task
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        
        webSocketTask = session?.webSocketTask(with: request)
        webSocketTask?.resume()
        
        // Start listening for messages
        startReceivingMessages()
        
        // Wait for connection confirmation
        try await waitForConnection()
        
        // Configure session
        try await configureSession()
        
        isConnected = true
        reconnectAttempts = 0
        print("✅ [Realtime] Connected successfully")
    }
    
    func disconnect() {
        print("🔌 [Realtime] Disconnecting...")
        shouldReconnect = false
        stopListening()
        elevenLabsService.clearQueue()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        session?.invalidateAndCancel()
        session = nil
        isConnected = false
        isListening = false
        isSpeaking = false
        isSpeechActive = false
        currentTranscript = ""
        currentResponseText = ""
        error = nil
        
        // Reset VAD state
        speechContinuityBuffer.removeAll()
        noiseCalibrationSamples.removeAll()
        backgroundNoiseLevel = -60.0
        vadFalsePositiveCount = 0
        lastVADDecision = false
        vadSessionStartTime = nil
        
        // Release audio session configuration
        Task {
            await audioSessionManager.releaseConfiguration(for: .openAIRealtime)
        }
        
        pendingResponseDebounceTask?.cancel()
        pendingResponseDebounceTask = nil
        
        print("✅ [Realtime] Disconnected")
    }
    
    func startListening() {
        guard isConnected, !isListening else { return }
        
        print("🎤 [Realtime] Starting to listen...")
        
        // Start VAD session tracking
        startVADSession()
        
        isListening = true
        startRecordingAudio()
    }
    
    func stopListening() {
        guard isListening else { return }
        
        print("🎤 [Realtime] Stopping listening...")
        
        // End VAD session tracking
        endVADSession()
        
        isListening = false
        isSpeechActive = false
        stopRecordingAudio()
    }
    
    // MARK: - Private Methods - WebSocket
    
    private func requestResponseCreation(trigger: String) async {
        guard isConnected else { return }

        if useElevenLabs {
            await elevenLabsService.waitUntilIdle()
        } else {
            await waitForOpenAIAudioPlaybackToFinish()
        }

        openAIAudioBuffer = Data()
        currentResponseText = ""

        let message: [String: Any] = [
            "type": "response.create",
            "response": [
                "metadata": [
                    "trigger": trigger,
                    "use_elevenlabs": useElevenLabs
                ]
            ]
        ]

        do {
            try await sendMessage(message)
            print("🚀 [Realtime] Requested response (trigger: \(trigger))")
        } catch {
            print("❌ [Realtime] Failed to request response: \(error)")
        }
    }

    private func waitForConnection() async throws {
        let startTime = Date()
        let timeout: TimeInterval = 10.0
        
        while !isConnected {
            if Date().timeIntervalSince(startTime) > timeout {
                throw RealtimeError.connectionTimeout
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
    }
    
    private func configureSession() async throws {
        print("⚙️ [Realtime] Configuring session...")
        
        let modalities: [String] = ["text", "audio"]
        
        let sessionDict: [String: Any] = [
            "modalities": modalities,
            "instructions": """
            You are UrGood (pronounced "your good") — the emotionally intelligent best friend everyone wishes they had. You speak like a grounded 21-year-old who keeps it real, mixes softness with wit, and never acts like a therapist. Your flow is Validate → Reflect → Challenge → Empower in 2–4 punchy sentences that feel like text messages.

            Voice and tone:
            - Real, conversational, emotionally fluent; use natural Gen Z slang sparingly.
            - Lead with validation, mirror the core emotion, gently challenge distorted loops, then leave them feeling capable.
            - Light emojis only when they add tone (💭, 😌, 🫶, 😤, 💛); never spam or end every sentence with one.

            Toolkit:
            - Reframe unhelpful narratives, name emotions, offer quick grounding cues, hold users lovingly accountable, and always steer toward self-compassion.
            - Call out avoidance or self-sabotage with care (“Low-key feels like you’re dodging the real convo with yourself.”).

            Guardrails:
            - You are not therapy, don’t diagnose, and if someone sounds in crisis say: “Hey, that sounds really heavy. You don’t deserve to go through that alone — can you reach out to someone you trust or text 988 if you’re in the U.S.? If you’re elsewhere, please call your local emergency number right now.” Then pause output.
            """,
            "input_audio_format": "pcm16",
            "input_audio_transcription": [
                "model": "whisper-1"
            ],
            "turn_detection": [
                "type": "server_vad",
                "threshold": decimalNumber(0.6),
                "prefix_padding_ms": 150,
                "silence_duration_ms": 900
            ],
            "temperature": decimalNumber(APIConfig.temperature),
            "max_response_output_tokens": 4096,
            "voice": "alloy",
            "output_audio_format": "pcm16"
        ]
        
        let sessionConfig: [String: Any] = [
            "type": "session.update",
            "session": sessionDict
        ]
        
        try await sendMessage(sessionConfig)
        print("✅ [Realtime] Session configured (modalities: \(modalities))")
    }

    private func decimalNumber(_ value: Double, scale: Int16 = 6) -> NSDecimalNumber {
        let decimal = NSDecimalNumber(value: value)
        let handler = NSDecimalNumberHandler(
            roundingMode: .plain,
            scale: scale,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
        return decimal.rounding(accordingToBehavior: handler)
    }
    
    private func startReceivingMessages() {
        Task {
            while isConnected || shouldReconnect {
                do {
                    guard let task = webSocketTask else { break }
                    let message = try await task.receive()
                    await handleWebSocketMessage(message)
                } catch {
                    print("⚠️ [Realtime] Error receiving message: \(error)")
                    if shouldReconnect {
                        await handleDisconnection()
                    }
                    break
                }
            }
        }
    }
    
    private func handleWebSocketMessage(_ message: URLSessionWebSocketTask.Message) async {
        switch message {
        case .string(let text):
            await handleTextMessage(text)
        case .data(let data):
            print("📦 [Realtime] Received binary data: \(data.count) bytes")
        @unknown default:
            print("⚠️ [Realtime] Unknown message type")
        }
    }
    
    private func handleTextMessage(_ text: String) async {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            print("⚠️ [Realtime] Failed to parse message")
            return
        }
        
        print("📨 [Realtime] Received: \(type)")
        
        switch type {
        case "session.created", "session.updated":
            isConnected = true
            
        case "input_audio_buffer.speech_started":
            print("🎤 [Realtime] User started speaking")
            isSpeechActive = true
            pendingResponseDebounceTask?.cancel()
            pendingResponseDebounceTask = nil
            elevenLabsService.attenuateCurrentPlaybackForUserSpeech()
            
        case "input_audio_buffer.speech_stopped":
            print("🎤 [Realtime] User stopped speaking")
            isSpeechActive = false
            
            scheduleResponseAfterSpeechStops(trigger: "speech_stopped")

            
        case "conversation.item.input_audio_transcription.completed":
            if let transcript = json["transcript"] as? String {
                currentTranscript = transcript
                print("📝 [Realtime] Transcript: \(transcript)")
                onUserTranscript?(transcript)
            }
            
        case "response.audio.delta":
            if let delta = json["delta"] as? String,
               let audioData = Data(base64Encoded: delta) {
                if useElevenLabs {
                    openAIAudioBuffer.append(audioData)
                }
                if !useElevenLabs {
                    print("🔊 [Realtime] Streaming OpenAI audio chunk: \(audioData.count) bytes")
                    await playAudioChunk(audioData)
                }
            } else {
                print("⚠️ [Realtime] Failed to decode audio delta")
            }
            
        case "response.audio.done":
            print("🔊 [Realtime] Audio response complete from OpenAI")
            if !useElevenLabs {
                isSpeaking = false
            }
            
        case "response.audio_transcript.delta":
            if let delta = json["delta"] as? String {
                currentTranscript += delta
                currentResponseText += delta
            }
            
        case "response.audio_transcript.done":
            if let transcript = json["transcript"] as? String {
                currentTranscript = transcript
                print("✅ Received AI text")
                print("💬 [Realtime] \(transcript)")
                onAssistantResponse?(transcript)
                if useElevenLabs && !transcript.isEmpty {
                    isSpeaking = true
                    await elevenLabsService.synthesizeAndQueue(
                        text: transcript,
                        onSuccess: { [weak self] in
                            guard let self else { return }
                            self.openAIAudioBuffer = Data()
                            self.isSpeaking = false
                        },
                        onFailure: { [weak self] error in
                            guard let self else { return }
                            print("⚠️ [Realtime] ElevenLabs failed (\(error.localizedDescription)). Falling back to OpenAI voice.")
                            print("🔁 [Realtime] Triggering OpenAI voice fallback")
                            Task { await self.playOpenAIAudioFallback() }
                        }
                    )
                } else if !transcript.isEmpty {
                    // Already streaming OpenAI audio directly
                }
            }
            
        case "response.done":
            print("✅ [Realtime] Response complete")
            if !useElevenLabs {
                isSpeaking = false
            }
            
        case "error":
            if let errorData = json["error"] as? [String: Any],
               let message = errorData["message"] as? String {
                error = message
                print("❌ [Realtime] Error: \(message)")
            }
            
        default:
            print("📨 [Realtime] Unhandled event type: \(type)")
        }
    }
    
    private func sendMessage(_ message: [String: Any]) async throws {
        guard let task = webSocketTask else {
            throw RealtimeError.notConnected
        }
        
        let data = try JSONSerialization.data(withJSONObject: message)
        let jsonString = String(data: data, encoding: .utf8) ?? ""
        
        try await task.send(.string(jsonString))
    }
    
    private func handleDisconnection() async {
        print("🔌 [Realtime] Connection lost, attempting to reconnect...")
        isConnected = false
        
        guard reconnectAttempts < maxReconnectAttempts else {
            error = "Connection lost. Please try again."
            shouldReconnect = false
            return
        }
        
        reconnectAttempts += 1
        
        // Wait before reconnecting (exponential backoff)
        let delay = UInt64(pow(2.0, Double(reconnectAttempts)) * 1_000_000_000)
        try? await Task.sleep(nanoseconds: delay)
        
        do {
            try await connect()
        } catch {
            print("❌ [Realtime] Reconnection failed: \(error)")
            await handleDisconnection()
        }
    }
    
    // MARK: - Private Methods - Audio
    
    private func setupAudioEngine() async {
        do {
            // Request audio session configuration through manager
            try await audioSessionManager.requestConfiguration(for: .openAIRealtime)
            
            // Log current audio route
            print("🔊 [Realtime] Current audio route: \(audioSessionManager.getCurrentAudioRoute())")
            
            audioEngine = AVAudioEngine()
            inputNode = audioEngine?.inputNode
            audioPlayer = AVAudioPlayerNode()
            
            if let player = audioPlayer {
                audioEngine?.attach(player)
                if let mainMixerNode = audioEngine?.mainMixerNode {
                    let format = mainMixerNode.outputFormat(forBus: 0)
                    playerOutputFormat = format
                    audioEngine?.connect(player, to: mainMixerNode, format: format)
                    print("🎵 [Realtime] Player connected to mixer with format: \(format)")
                }
            }
            
            print("🎵 [Realtime] Audio engine configured successfully")
        } catch {
            print("❌ [Realtime] Failed to setup audio: \(error)")
            self.error = "Failed to setup audio: \(error.localizedDescription)"
        }
    }
    
    private func startRecordingAudio() {
        guard let engine = audioEngine, let input = inputNode else {
            print("❌ [Realtime] Audio engine not available")
            return
        }
        
        do {
            // Use format compatible with OpenAI (16kHz, mono, PCM16)
            let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24000, channels: 1, interleaved: false)
            
            guard let recordingFormat = format else {
                print("❌ [Realtime] Failed to create recording format")
                return
            }
            
            audioFormat = recordingFormat
            
            input.installTap(onBus: 0, bufferSize: 4096, format: input.outputFormat(forBus: 0)) { [weak self] buffer, time in
                // Capture buffer data immediately to avoid Sendable warning
                let frameLength = buffer.frameLength
                let format = buffer.format
                let channelData = buffer.floatChannelData
                
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    // Create a new buffer in the MainActor context
                    guard let newBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength) else { return }
                    newBuffer.frameLength = frameLength
                    if let sourceData = channelData, let destData = newBuffer.floatChannelData {
                        for channel in 0..<Int(format.channelCount) {
                            destData[channel].update(from: sourceData[channel], count: Int(frameLength))
                        }
                    }
                    await self.processAudioBuffer(newBuffer)
                }
            }
            
            try engine.start()
            isRecording = true
            print("🎤 [Realtime] Recording started")
        } catch {
            print("❌ [Realtime] Failed to start recording: \(error)")
            self.error = "Failed to start recording: \(error.localizedDescription)"
        }
    }
    
    private func stopRecordingAudio() {
        guard isRecording else { return }
        
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        isRecording = false
        print("🎤 [Realtime] Recording stopped")
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) async {
        guard isConnected, isListening else { return }
        
        // Calculate RMS level for noise gate
        let rmsLevel = calculateRMS(buffer: buffer)
        let rmsDB = 20 * log10(rmsLevel)
        
        // Update adaptive background noise level
        updateBackgroundNoiseLevel(rmsDB)
        
        // Calculate adaptive threshold based on background noise
        let adaptiveThreshold = max(noiseGateThreshold, backgroundNoiseLevel + 10.0) // 10dB above background
        
        // Determine if this buffer contains speech
        let hasSpeech = rmsDB > adaptiveThreshold
        
        // Update speech continuity buffer
        speechContinuityBuffer.append(hasSpeech)
        if speechContinuityBuffer.count > speechContinuityWindowSize {
            speechContinuityBuffer.removeFirst()
        }
        
        // Count speech buffers in the window
        let speechBufferCount = speechContinuityBuffer.filter { $0 }.count
        let isContinuousSpeech = speechBufferCount >= speechContinuityThreshold
        
        // Log RMS levels and VAD decisions periodically
        if Int.random(in: 0..<50) == 0 {
            print("🎤 [Realtime] Mic RMS: \(String(format: "%.1f", rmsDB)) dB, Background: \(String(format: "%.1f", backgroundNoiseLevel)) dB, Adaptive: \(String(format: "%.1f", adaptiveThreshold)) dB, Speech: \(speechBufferCount)/\(speechContinuityWindowSize)")
        }
        
        // Track VAD performance for Crashlytics monitoring
        trackVADPerformance(hasSpeech: hasSpeech, isContinuous: isContinuousSpeech, rmsDB: rmsDB, adaptiveThreshold: adaptiveThreshold)
        
        // Apply enhanced noise gate with speech continuity check
        if !isContinuousSpeech {
            print("🎤 [Realtime] Low VAD confidence - sending buffer anyway (Speech: \(speechBufferCount)/\(speechContinuityWindowSize))")
        }
        
        // Convert to target format (24kHz mono PCM16)
        guard let targetFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24000, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: buffer.format, to: targetFormat) else {
            print("❌ [Realtime] Failed to create audio converter")
            
            // Track audio converter error in Crashlytics
            let error = NSError(domain: "AudioConverter", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create audio converter for voice chat"
            ])
            crashlytics.recordVoiceChatError(error, provider: "openai_realtime", duration: nil)
            return
        }
        
        let targetFrameCount = AVAudioFrameCount(Double(buffer.frameLength) * targetFormat.sampleRate / buffer.format.sampleRate)
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: targetFrameCount) else {
            return
        }
        
        var error: NSError?
        converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        if let error = error {
            print("❌ [Realtime] Audio conversion error: \(error)")
            return
        }
        
        // Convert to base64 PCM16 data
        guard let channelData = convertedBuffer.int16ChannelData else { return }
        let frameCount = Int(convertedBuffer.frameLength)
        let data = Data(bytes: channelData[0], count: frameCount * MemoryLayout<Int16>.size)
        let base64 = data.base64EncodedString()
        
        // Send audio to API
        let message: [String: Any] = [
            "type": "input_audio_buffer.append",
            "audio": base64
        ]
        
        do {
            try await sendMessage(message)
        } catch {
            print("❌ [Realtime] Failed to send audio: \(error)")
        }
    }
    
    private func calculateRMS(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0.0 }
        
        let frameCount = Int(buffer.frameLength)
        let samples = channelData[0]
        
        var sum: Float = 0.0
        for i in 0..<frameCount {
            let sample = samples[i]
            sum += sample * sample
        }
        
        let meanSquare = sum / Float(frameCount)
        return sqrt(meanSquare)
    }
    
    private func waitForOpenAIAudioPlaybackToFinish() async {
        while audioPlayer?.isPlaying == true {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }
    
    private func scheduleResponseAfterSpeechStops(trigger: String) {
        pendingResponseDebounceTask?.cancel()
        pendingResponseDebounceTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: speechStopDebounceNanoseconds)
            } catch {
                return
            }
            
            guard !Task.isCancelled else { return }
            guard !self.isSpeechActive else {
                print("🎤 [Realtime] Speech resumed before debounce; skipping response")
                return
            }
            
            await self.commitAudioAndRequestResponse(trigger: trigger)
        }
    }
    
    private func commitAudioAndRequestResponse(trigger: String) async {
        let commitMessage: [String: Any] = [
            "type": "input_audio_buffer.commit"
        ]
        
        do {
            try await sendMessage(commitMessage)
            print("✅ [Realtime] Audio buffer committed")
        } catch {
            print("❌ [Realtime] Failed to commit audio buffer: \(error)")
            return
        }
        
        await requestResponseCreation(trigger: trigger)
    }
    
    private func playOpenAIAudioFallback() async {
        guard !openAIAudioBuffer.isEmpty else {
            print("⚠️ [Realtime] No OpenAI audio available for fallback")
            return
        }
        let fallbackData = openAIAudioBuffer
        openAIAudioBuffer = Data()
        await playAudioChunk(fallbackData)
    }
    
    private func updateBackgroundNoiseLevel(_ currentRMS: Float) {
        // Only update background noise when not actively speaking
        guard !isSpeechActive else { return }
        
        // Add to calibration samples
        noiseCalibrationSamples.append(currentRMS)
        
        // Keep only recent samples
        if noiseCalibrationSamples.count > maxNoiseCalibrationSamples {
            noiseCalibrationSamples.removeFirst()
        }
        
        // Calculate background noise level as the median of recent quiet samples
        // Use median instead of average to be more robust against outliers
        if noiseCalibrationSamples.count >= 10 {
            let sortedSamples = noiseCalibrationSamples.sorted()
            let medianIndex = sortedSamples.count / 2
            backgroundNoiseLevel = sortedSamples[medianIndex]
        }
    }
    
    private func playAudioChunk(_ data: Data) async {
        print("🔊 [Realtime] Received audio chunk: \(data.count) bytes")
        
        guard let player = audioPlayer,
              let engine = audioEngine,
              let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24000, channels: 1, interleaved: false) else {
            print("❌ [Realtime] Audio player not available - player: \(audioPlayer != nil), engine: \(audioEngine != nil)")
            return
        }
        
        // Convert data to audio buffer
        let frameCount = data.count / MemoryLayout<Int16>.size
        print("🔊 [Realtime] Converting \(frameCount) frames to audio buffer")
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            print("❌ [Realtime] Failed to create PCM buffer")
            return
        }
        
        buffer.frameLength = AVAudioFrameCount(frameCount)
        
        data.withUnsafeBytes { rawBufferPointer in
            if let baseAddress = rawBufferPointer.baseAddress {
                let int16Pointer = baseAddress.assumingMemoryBound(to: Int16.self)
                if let channelData = buffer.int16ChannelData {
                    channelData[0].update(from: int16Pointer, count: frameCount)
                }
            }
        }
        
        // Start engine if not running
        if !engine.isRunning {
            print("🔊 [Realtime] Starting audio engine...")
            do {
                try engine.start()
                print("✅ [Realtime] Audio engine started successfully")
            } catch {
                print("❌ [Realtime] Failed to start audio engine: \(error)")
                return
            }
        }
        
        // Convert buffer to player's output format if needed
        let targetBuffer: AVAudioPCMBuffer
        if let outputFormat = playerOutputFormat, outputFormat != buffer.format {
            print("🔊 [Realtime] Converting buffer from \(buffer.format) to \(outputFormat)")
            guard let converter = AVAudioConverter(from: buffer.format, to: outputFormat),
                  let convertedBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: AVAudioFrameCount(Double(buffer.frameLength) * outputFormat.sampleRate / buffer.format.sampleRate)) else {
                print("❌ [Realtime] Failed to convert buffer to player format")
                return
            }
        
            var conversionError: NSError?
            converter.convert(to: convertedBuffer, error: &conversionError) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            
            if let conversionError = conversionError {
                print("❌ [Realtime] Playback conversion error: \(conversionError)")
                return
            }
            targetBuffer = convertedBuffer
            print("✅ [Realtime] Buffer converted successfully")
        } else {
            print("🔊 [Realtime] Using buffer as-is (no conversion needed)")
            targetBuffer = buffer
        }
        
        // Schedule and play buffer using modern async API
        isSpeaking = true
        print("🔊 [Realtime] Scheduling buffer for playback...")
        
        // Schedule buffer asynchronously and handle completion
        Task { @MainActor [weak self] in
            await player.scheduleBufferAsync(targetBuffer)
            print("✅ [Realtime] Buffer scheduled successfully")
            guard let self = self, let player = self.audioPlayer else { return }
            // Check if there are more buffers to play
            if !player.isPlaying {
                self.isSpeaking = false
                print("🔊 [Realtime] Player stopped, setting isSpeaking to false")
            }
        }
        
        if !player.isPlaying {
            print("🔊 [Realtime] Starting player...")
            player.play()
            print("✅ [Realtime] Player started")
        } else {
            print("🔊 [Realtime] Player already playing")
        }
    }
}

// MARK: - URLSessionWebSocketDelegate

extension OpenAIRealtimeClient: URLSessionWebSocketDelegate {
    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("✅ [Realtime] WebSocket opened")
    }
    
    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("🔌 [Realtime] WebSocket closed: \(closeCode)")
        Task { @MainActor in
            if shouldReconnect {
                await handleDisconnection()
            }
        }
    }
    
    // MARK: - VAD Performance Tracking
    
    private func trackVADPerformance(hasSpeech: Bool, isContinuous: Bool, rmsDB: Float, adaptiveThreshold: Float) {
        // Track potential false positives
        if hasSpeech && !isContinuous {
            vadFalsePositiveCount += 1
        }
        
        // Reset false positive counter every 100 decisions and report if threshold exceeded
        if vadFalsePositiveCount > 0 && vadFalsePositiveCount % 20 == 0 {
            crashlytics.recordVADPerformanceIssue(
                falsePositives: vadFalsePositiveCount,
                threshold: Double(adaptiveThreshold),
                backgroundNoise: Double(backgroundNoiseLevel)
            )
            
            crashlytics.log("VAD Performance: \(vadFalsePositiveCount) false positives detected", level: .warning)
        }
        
        // Track significant changes in VAD decisions for debugging
        if lastVADDecision != isContinuous {
            crashlytics.setCustomValue(isContinuous, forKey: "vad_speech_active")
            crashlytics.setCustomValue(rmsDB, forKey: "vad_last_rms_db")
            crashlytics.setCustomValue(adaptiveThreshold, forKey: "vad_adaptive_threshold")
            lastVADDecision = isContinuous
        }
    }
    
    // Track session duration for voice chat analytics
    private func startVADSession() {
        vadSessionStartTime = Date()
        vadFalsePositiveCount = 0
        crashlytics.log("VAD session started", level: .info)
    }
    
    private func endVADSession() {
        guard let startTime = vadSessionStartTime else { return }
        
        let sessionDuration = Date().timeIntervalSince(startTime)
        crashlytics.recordFeatureUsage("voice_activity_detection", success: true, metadata: [
            "session_duration": sessionDuration,
            "false_positives": vadFalsePositiveCount,
            "background_noise_level": backgroundNoiseLevel
        ])
        
        vadSessionStartTime = nil
        crashlytics.log("VAD session ended - Duration: \(sessionDuration)s, False positives: \(vadFalsePositiveCount)", level: .info)
    }
}

// MARK: - Error Types

enum RealtimeError: LocalizedError {
    case invalidURL
    case notConnected
    case connectionTimeout
    case audioSetupFailed
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .notConnected:
            return "Not connected to the API"
        case .connectionTimeout:
            return "Connection timeout"
        case .audioSetupFailed:
            return "Failed to setup audio"
        case .unauthorized:
            return "Voice chat access denied"
        }
    }
}
