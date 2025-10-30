import Foundation
import AVFoundation
@preconcurrency import AVFAudio
import Combine

@MainActor
class AudioPlaybackService: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var playbackProgress: Double = 0.0
    @Published var playbackDuration: TimeInterval = 0.0
    @Published var errorMessage: String?
    
    private var audioPlayer: AVAudioPlayer?
    private var playbackTimer: Timer?
    
    // Audio session management
    private let audioSessionManager = AudioSessionManager.shared
    
    override init() {
        super.init()
    }
    
    // MARK: - Playback Control
    
    func playAudio(from data: Data) async throws {
        // Request audio session configuration
        try await audioSessionManager.requestConfiguration(for: .playback)
        
        // Stop any existing playback
        stopPlayback()
        
        // Create audio player
        audioPlayer = try AVAudioPlayer(data: data)
        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()
        
        // Start playback
        guard audioPlayer?.play() == true else {
            throw AudioPlaybackError.playbackFailed
        }
        
        // Update state
        isPlaying = true
        playbackDuration = audioPlayer?.duration ?? 0.0
        playbackProgress = 0.0
        errorMessage = nil
        
        // Start progress timer
        startProgressTimer()
        
        print("🔊 Started playing audio, duration: \(playbackDuration)s")
    }
    
    func playAudio(from url: URL) async throws {
        // Stop any existing playback
        stopPlayback()
        
        // Create audio player
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()
        
        // Start playback
        guard audioPlayer?.play() == true else {
            throw AudioPlaybackError.playbackFailed
        }
        
        // Update state
        isPlaying = true
        playbackDuration = audioPlayer?.duration ?? 0.0
        playbackProgress = 0.0
        errorMessage = nil
        
        // Start progress timer
        startProgressTimer()
        
        print("🔊 Started playing audio from URL: \(url.lastPathComponent), duration: \(playbackDuration)s")
    }
    
    func pausePlayback() {
        audioPlayer?.pause()
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    func resumePlayback() {
        audioPlayer?.play()
        isPlaying = true
        startProgressTimer()
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        playbackTimer?.invalidate()
        playbackTimer = nil
        
        isPlaying = false
        playbackProgress = 0.0
        playbackDuration = 0.0
        
        // Release audio session configuration
        Task {
            await audioSessionManager.releaseConfiguration(for: .playback)
        }
        
        print("🔇 Stopped audio playback")
    }
    
    func seekToProgress(_ progress: Double) {
        guard let player = audioPlayer, playbackDuration > 0 else { return }
        
        let targetTime = progress * playbackDuration
        player.currentTime = targetTime
        playbackProgress = progress
    }
    
    // MARK: - Progress Tracking
    
    private func startProgressTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard let player = self.audioPlayer, self.playbackDuration > 0 else { return }
                self.playbackProgress = player.currentTime / self.playbackDuration
            }
        }
    }
    
    // MARK: - Volume Control
    
    func setVolume(_ volume: Float) {
        audioPlayer?.volume = max(0.0, min(1.0, volume))
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        stopPlayback()
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlaybackService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            isPlaying = false
            playbackProgress = 1.0
            playbackTimer?.invalidate()
            playbackTimer = nil
            
            if !flag {
                errorMessage = "Playback completed with errors"
            }
            
            print("🔊 Audio playback finished successfully: \(flag)")
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            if let error = error {
                errorMessage = "Playback error: \(error.localizedDescription)"
            }
            isPlaying = false
            playbackTimer?.invalidate()
            playbackTimer = nil
            
            print("❌ Audio playback error: \(error?.localizedDescription ?? "Unknown error")")
        }
    }
}

// MARK: - Audio Playback Errors

enum AudioPlaybackError: LocalizedError {
    case playbackFailed
    case fileNotFound
    case invalidAudioData
    case sessionConfigurationFailed
    
    var errorDescription: String? {
        switch self {
        case .playbackFailed:
            return "Failed to start audio playback"
        case .fileNotFound:
            return "Audio file not found"
        case .invalidAudioData:
            return "Invalid audio data format"
        case .sessionConfigurationFailed:
            return "Failed to configure audio session for playback"
        }
    }
}
