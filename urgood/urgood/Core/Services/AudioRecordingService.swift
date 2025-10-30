import Foundation
import AVFoundation
import Combine
import UIKit

@MainActor
class AudioRecordingService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var hasPermission = false
    @Published var errorMessage: String?
    @Published var audioSessionState: AudioSessionState = .inactive
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var currentRecordingURL: URL?
    
    // Audio session management
    private let audioSessionManager = AudioSessionManager.shared
    
    // Session state management
    enum AudioSessionState: Equatable {
        case inactive
        case configuring
        case active
        case interrupted
        case error(String)
        
        static func == (lhs: AudioSessionState, rhs: AudioSessionState) -> Bool {
            switch (lhs, rhs) {
            case (.inactive, .inactive),
                 (.configuring, .configuring),
                 (.active, .active),
                 (.interrupted, .interrupted):
                return true
            case (.error(let lhsMessage), .error(let rhsMessage)):
                return lhsMessage == rhsMessage
            default:
                return false
            }
        }
    }
    
    // Recovery and error handling
    private var sessionInterruptionCount = 0
    private var lastInterruptionTime: Date?
    private let maxRecoveryAttempts = 3
    private var isRecovering = false
    
    // Recording settings for optimal Whisper compatibility
    private let recordingSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 16000.0, // Whisper's preferred sample rate
        AVNumberOfChannelsKey: 1, // Mono for better Whisper processing
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]
    
    override init() {
        super.init()
        checkMicrophonePermission()
        setupAudioSessionObservers()
    }
    
    // MARK: - Permission Management
    
    func checkMicrophonePermission() {
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                hasPermission = true
            case .denied, .undetermined:
                hasPermission = false
            @unknown default:
                hasPermission = false
            }
        } else {
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted:
                hasPermission = true
            case .denied, .undetermined:
                hasPermission = false
            @unknown default:
                hasPermission = false
            }
        }
    }
    
    func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        self.hasPermission = granted
                        continuation.resume(returning: granted)
                    }
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        self.hasPermission = granted
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }
    
    // MARK: - Recording Control
    
    func startRecording() async throws {
        // Reset error state
        errorMessage = nil
        audioSessionState = .configuring
        
        if !hasPermission {
            let granted = await requestMicrophonePermission()
            if !granted {
                audioSessionState = .error("Microphone permission denied")
                throw AudioError.permissionDenied
            }
        }
        
        // Stop any existing recording
        stopRecording()
        
        do {
            // Configure audio session with error recovery
            try await configureAudioSessionWithRetry()
            
            // Create recording URL
            let recordingURL = getRecordingURL()
            currentRecordingURL = recordingURL
            
            // Initialize recorder with error handling
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: recordingSettings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            // Start recording with validation
            guard audioRecorder?.record() == true else {
                audioSessionState = .error("Failed to start recording")
                throw AudioError.recordingFailed
            }
            
            // Update state
            isRecording = true
            recordingStartTime = Date()
            audioSessionState = .active
            
            // Start timer
            startRecordingTimer()
            
            print("🎤 Recording started successfully")
            
        } catch {
            audioSessionState = .error(error.localizedDescription)
            throw error
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        isRecording = false
        recordingStartTime = nil
        recordingDuration = 0
        
        // Deactivate audio session safely
        deactivateAudioSession()
        
        print("🛑 Stopped recording")
    }
    
    func getCurrentRecordingURL() -> URL? {
        return currentRecordingURL
    }
    
    func getRecordingURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "voice_message_\(Date().timeIntervalSince1970).m4a"
        return documentsPath.appendingPathComponent(fileName)
    }
    
    // MARK: - Audio Session Configuration
    
    private func configureAudioSession() async throws {
        // Audio session configuration is now handled by AudioSessionManager
        try await audioSessionManager.requestConfiguration(for: .recording)
    }
    
    // MARK: - Duration Tracking
    
    private func startDurationTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if let startTime = self.recordingStartTime {
                    self.recordingDuration = Date().timeIntervalSince(startTime)
                }
            }
        }
    }
    
    // MARK: - Audio Level Monitoring
    
    func getCurrentAudioLevel() -> Float {
        guard let recorder = audioRecorder, recorder.isRecording else { return 0.0 }
        
        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)
        
        // Convert dB to 0-1 range
        let normalizedLevel = pow(10, averagePower / 20)
        return max(0.0, min(1.0, normalizedLevel))
    }
    
    // MARK: - Audio Session Management
    
    private func setupAudioSessionObservers() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleAudioSessionInterruption(notification)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleAudioRouteChange(notification)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleAppBackgrounding()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleAppForegrounding()
            }
        }
    }
    
    private func configureAudioSessionWithRetry() async throws {
        var lastError: Error?
        
        for attempt in 1...maxRecoveryAttempts {
            do {
                try await audioSessionManager.requestConfiguration(for: .recording)
                audioSessionState = .active
                sessionInterruptionCount = 0
                return
            } catch {
                lastError = error
                print("🔄 Audio session configuration failed (attempt \(attempt)): \(error)")
                
                if attempt < maxRecoveryAttempts {
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
                }
            }
        }
        
        audioSessionState = .error("Failed to configure audio session after \(maxRecoveryAttempts) attempts")
        throw lastError ?? AudioError.sessionConfigurationFailed
    }
    
    private func deactivateAudioSession() {
        Task {
            await audioSessionManager.releaseConfiguration(for: .recording)
            audioSessionState = .inactive
        }
    }
    
    private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            print("🔇 Audio session interrupted")
            audioSessionState = .interrupted
            sessionInterruptionCount += 1
            lastInterruptionTime = Date()
            
            if isRecording {
                stopRecording()
            }
            
        case .ended:
            print("🔊 Audio session interruption ended")
            
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    Task {
                        await attemptSessionRecovery()
                    }
                }
            }
            
        @unknown default:
            break
        }
    }
    
    private func handleAudioRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .newDeviceAvailable:
            print("🎧 New audio device connected")
            
        case .oldDeviceUnavailable:
            print("🎧 Audio device disconnected")
            if isRecording {
                stopRecording()
                errorMessage = "Recording stopped due to audio device change"
            }
            
        case .categoryChange:
            print("🎧 Audio category changed")
            
        default:
            break
        }
    }
    
    private func handleAppBackgrounding() {
        if isRecording {
            print("📱 App backgrounded - stopping recording")
            stopRecording()
        }
    }
    
    private func handleAppForegrounding() {
        print("📱 App foregrounded")
        checkMicrophonePermission()
        
        if audioSessionState == AudioSessionState.interrupted {
            Task {
                await attemptSessionRecovery()
            }
        }
    }
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let recorder = self.audioRecorder else { return }
                self.recordingDuration = recorder.currentTime
            }
        }
    }
    
    private func attemptSessionRecovery() async {
        guard !isRecovering else { return }
        
        isRecovering = true
        defer { isRecovering = false }
        
        print("🔄 Attempting audio session recovery...")
        
        do {
            try await configureAudioSessionWithRetry()
            print("✅ Audio session recovered successfully")
        } catch {
            print("❌ Audio session recovery failed: \(error)")
            audioSessionState = .error("Recovery failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        stopRecording()
        deactivateAudioSession()
        NotificationCenter.default.removeObserver(self)
    }
    
    deinit {
        // Synchronous cleanup for deinit
        recordingTimer?.invalidate()
        recordingTimer = nil
        audioRecorder?.stop()
        audioRecorder = nil
        
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecordingService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                errorMessage = "Recording failed to complete successfully"
                audioSessionState = .error("Recording completion failed")
            } else {
                audioSessionState = .inactive
            }
            isRecording = false
            recordingTimer?.invalidate()
            recordingTimer = nil
            recordingDuration = 0
        }
    }
    
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            let errorMsg = error?.localizedDescription ?? "Unknown recording error"
            errorMessage = "Recording error: \(errorMsg)"
            audioSessionState = .error(errorMsg)
            
            isRecording = false
            recordingTimer?.invalidate()
            recordingTimer = nil
            recordingDuration = 0
            
            // Attempt recovery if not too many recent failures
            if sessionInterruptionCount < maxRecoveryAttempts {
                await attemptSessionRecovery()
            }
        }
    }
}

// MARK: - Audio Errors

enum AudioError: LocalizedError {
    case permissionDenied
    case recordingFailed
    case sessionConfigurationFailed
    case fileNotFound
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission is required for voice chat"
        case .recordingFailed:
            return "Failed to start recording"
        case .sessionConfigurationFailed:
            return "Failed to configure audio session"
        case .fileNotFound:
            return "Recording file not found"
        }
    }
}
