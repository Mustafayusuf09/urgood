import Foundation
import AVFoundation
import Combine
import FirebaseAuth
import FirebaseFunctions

/// Service for managing ElevenLabs text-to-speech synthesis and playback.
@MainActor
final class ElevenLabsService: ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var isSynthesizing = false
    @Published private(set) var error: String?
    @Published private(set) var isProcessingQueue = false
    
    // MARK: - Private Properties
    private let apiKey: String?
    private let baseURL = "https://api.elevenlabs.io/v1/text-to-speech"
    private let functions = Functions.functions()
    private let audioSessionManager = AudioSessionManager.shared
    
    private var audioQueue: [AudioQueueItem] = []
    private var currentPlayer: AVAudioPlayer?
    private let useProductionMode: Bool
    
    // MARK: - Init
    init() {
        #if DEBUG
        self.useProductionMode = false
        self.apiKey = ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"]
        if let key = apiKey, !key.isEmpty {
            print("✅ [ElevenLabs] Using direct API (development mode)")
        } else {
            print("⚠️ [ElevenLabs] ELEVENLABS_API_KEY not set. ElevenLabs synthesis will be skipped and OpenAI fallback will be used.")
        }
        #else
        self.useProductionMode = true
        self.apiKey = nil
        print("✅ [ElevenLabs] Initialized for production (Firebase Functions)")
        #endif
        print("🎯 [ElevenLabs] Active voice ID: \(currentVoiceId)")
    }
    
    // MARK: - Public API
    
    /// Enqueues text for ElevenLabs synthesis and playback.
    func synthesizeAndQueue(
        text: String,
        onSuccess: (() -> Void)? = nil,
        onFailure: ((Error) -> Void)? = nil
    ) async {
        print("🎙️ Sending to ElevenLabs")
        print("📝 [ElevenLabs] Text preview: \(text.prefix(60))…")
        
        do {
            try await audioSessionManager.requestConfiguration(for: .elevenLabs)
        } catch {
            print("⚠️ [ElevenLabs] Audio session configuration failed: \(error)")
        }
        
        audioQueue.append(AudioQueueItem(text: text, onSuccess: onSuccess, onFailure: onFailure))
        await processQueueIfNeeded()
    }
    
    /// Clears the queue and stops playback.
    func clearQueue() {
        audioQueue.removeAll()
        currentPlayer?.stop()
        currentPlayer = nil
        isProcessingQueue = false
        Task { await audioSessionManager.releaseConfiguration(for: .elevenLabs) }
        print("🧹 [ElevenLabs] Queue cleared")
    }
    
    /// Softly mutes active playback so user speech is never interrupted.
    func attenuateCurrentPlaybackForUserSpeech() {
        guard let player = currentPlayer, player.isPlaying else { return }
        player.setVolume(0.0, fadeDuration: 0.2)
        print("🔇 [ElevenLabs] Muting playback due to user speech")
    }
    
    /// Waits until all queued audio has completed playback.
    func waitUntilIdle() async {
        while isProcessingQueue || (currentPlayer?.isPlaying ?? false) {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }
    
    // MARK: - Helpers
    
    private var currentVoiceId: String {
        UserDefaults.standard.selectedVoice.rawValue
    }
    
    private func processQueueIfNeeded() async {
        guard !isProcessingQueue else { return }
        guard !audioQueue.isEmpty else { return }
        
        isProcessingQueue = true
        defer {
            isProcessingQueue = false
            if audioQueue.isEmpty {
                Task { await audioSessionManager.releaseConfiguration(for: .elevenLabs) }
            }
        }
        
        while !audioQueue.isEmpty {
            let item = audioQueue.removeFirst()
            do {
                let audioData = try await fetchAudioData(for: item.text)
                try await playAudio(data: audioData)
                await MainActor.run { item.onSuccess?() }
            } catch {
                await MainActor.run { item.onFailure?(error) }
            }
        }
    }
    
    private func fetchAudioData(for text: String) async throws -> Data {
        isSynthesizing = true
        defer { isSynthesizing = false }
        if useProductionMode {
            return try await synthesizeWithFirebase(text: text)
        }
        
        guard let apiKey, !apiKey.isEmpty else {
            throw ElevenLabsError.missingAPIKey
        }
        
        var request = URLRequest(url: URL(string: "\(baseURL)/\(currentVoiceId)")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let body: [String: Any] = [
            "text": text,
            "model_id": APIConfig.elevenLabsModel,
            "voice_settings": [
                "stability": APIConfig.elevenLabsStability,
                "similarity_boost": APIConfig.elevenLabsSimilarityBoost
            ],
            "output_format": "mp3_44100_128"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ElevenLabsError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            switch httpResponse.statusCode {
            case 401: throw ElevenLabsError.unauthorized
            case 429: throw ElevenLabsError.rateLimitExceeded
            default: throw ElevenLabsError.serverError(httpResponse.statusCode)
            }
        }
        
        print("✅ [ElevenLabs] Received audio bytes: \(data.count)")
        return data
    }
    
    private func synthesizeWithFirebase(text: String) async throws -> Data {
        guard Auth.auth().currentUser != nil else {
            throw ElevenLabsError.unauthorized
        }
        
        let result = try await functions.httpsCallable("synthesizeSpeech").call([
            "text": text,
            "voiceId": currentVoiceId,
            "modelId": "eleven_multilingual_v2"
        ])
        
        guard let payload = result.data as? [String: Any],
              let audioBase64 = payload["audioData"] as? String,
              let audioData = Data(base64Encoded: audioBase64) else {
            throw ElevenLabsError.invalidResponse
        }
        
        print("✅ [ElevenLabs] Received audio from Firebase: \(audioData.count)")
        return audioData
    }
    
    private func playAudio(data: Data) async throws {
        try await withCheckedThrowingContinuation { continuation in
            do {
                let player = try AVAudioPlayer(data: data)
                player.prepareToPlay()
                player.setVolume(1.0, fadeDuration: 0.0)
                
                let delegate = AudioPlayerDelegate { [weak self] success in
                    guard let self else { return }
                    self.currentPlayer = nil
                    if success {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: ElevenLabsError.playbackFailed)
                    }
                }
                
                player.delegate = delegate
                objc_setAssociatedObject(player, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
                currentPlayer = player
                
                print("🔊 ElevenLabs audio playing (duration: \(String(format: "%.2f", player.duration))s)")
                
                guard player.play() else {
                    continuation.resume(throwing: ElevenLabsError.playbackFailed)
                    return
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

// MARK: - Supporting Types
private struct AudioQueueItem {
    let text: String
    let onSuccess: (() -> Void)?
    let onFailure: ((Error) -> Void)?
}

private class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    private let completion: (Bool) -> Void
    
    init(completion: @escaping (Bool) -> Void) {
        self.completion = completion
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        completion(flag)
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        completion(false)
    }
}


enum ElevenLabsError: LocalizedError {
    case missingAPIKey
    case unauthorized
    case rateLimitExceeded
    case invalidResponse
    case serverError(Int)
    case playbackFailed

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "ElevenLabs API key is missing"
        case .unauthorized: return "ElevenLabs authorization failed"
        case .rateLimitExceeded: return "ElevenLabs rate limit exceeded"
        case .invalidResponse: return "ElevenLabs returned an invalid response"
        case .serverError(let code): return "ElevenLabs server error (code: \(code))"
        case .playbackFailed: return "Failed to play synthesized audio"
        }
    }
}
