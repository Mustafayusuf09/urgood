import Foundation
import AVFoundation
import Combine

/// Centralized audio session manager to prevent conflicts between multiple audio services
/// Coordinates ElevenLabs, OpenAI Realtime, Recording, and Playback services
@MainActor
final class AudioSessionManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = AudioSessionManager()
    
    // MARK: - Published Properties
    @Published private(set) var isActive = false
    @Published private(set) var currentConfiguration: AudioConfiguration?
    @Published private(set) var activeServices: Set<AudioServiceType> = []
    
    // MARK: - Private Properties
    private let audioSession = AVAudioSession.sharedInstance()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration Types
    
    enum AudioServiceType: String, CaseIterable {
        case elevenLabs = "ElevenLabs"
        case openAIRealtime = "OpenAI Realtime"
        case recording = "Recording"
        case playback = "Playback"
        case voiceChat = "Voice Chat"
    }
    
    struct AudioConfiguration: Equatable {
        let category: AVAudioSession.Category
        let mode: AVAudioSession.Mode
        let options: AVAudioSession.CategoryOptions
        let priority: Int // Higher number = higher priority
        let serviceType: AudioServiceType
        
        static func == (lhs: AudioConfiguration, rhs: AudioConfiguration) -> Bool {
            return lhs.category == rhs.category &&
                   lhs.mode == rhs.mode &&
                   lhs.options == rhs.options &&
                   lhs.serviceType == rhs.serviceType
        }
    }
    
    // MARK: - Predefined Configurations
    
    private static let configurations: [AudioServiceType: AudioConfiguration] = [
        .voiceChat: AudioConfiguration(
            category: .playAndRecord,
            mode: .voiceChat,
            options: [.defaultToSpeaker, .allowBluetoothA2DP, .mixWithOthers],
            priority: 100, // Highest priority for voice chat
            serviceType: .voiceChat
        ),
        .elevenLabs: AudioConfiguration(
            category: .playAndRecord,
            mode: .voiceChat,
            options: [.defaultToSpeaker, .allowBluetoothA2DP, .mixWithOthers],
            priority: 90,
            serviceType: .elevenLabs
        ),
        .openAIRealtime: AudioConfiguration(
            category: .playAndRecord,
            mode: .voiceChat,
            options: [.defaultToSpeaker, .allowBluetoothA2DP, .mixWithOthers],
            priority: 85,
            serviceType: .openAIRealtime
        ),
        .recording: AudioConfiguration(
            category: .playAndRecord,
            mode: .default,
            options: [.defaultToSpeaker, .allowBluetoothHFP],
            priority: 70,
            serviceType: .recording
        ),
        .playback: AudioConfiguration(
            category: .playback,
            mode: .default,
            options: [.allowBluetoothA2DP, .mixWithOthers],
            priority: 50,
            serviceType: .playback
        )
    ]
    
    // MARK: - Init
    
    private init() {
        setupNotifications()
    }
    
    // MARK: - Public Methods
    
    /// Request audio session configuration for a service
    func requestConfiguration(for serviceType: AudioServiceType) async throws {
        print("🎵 [AudioSession] \(serviceType.rawValue) requesting configuration...")
        
        guard let config = Self.configurations[serviceType] else {
            throw AudioSessionError.unsupportedServiceType
        }
        
        // Add service to active set
        activeServices.insert(serviceType)
        
        // Determine if we need to reconfigure
        let shouldReconfigure = currentConfiguration == nil || 
                               config.priority > (currentConfiguration?.priority ?? 0) ||
                               currentConfiguration?.serviceType != serviceType
        
        if shouldReconfigure {
            try await applyConfiguration(config)
        }
        
        print("✅ [AudioSession] \(serviceType.rawValue) configuration active")
    }
    
    /// Release audio session configuration for a service
    func releaseConfiguration(for serviceType: AudioServiceType) async {
        print("🎵 [AudioSession] \(serviceType.rawValue) releasing configuration...")
        
        activeServices.remove(serviceType)
        
        // If this was the current configuration, find the next highest priority
        if currentConfiguration?.serviceType == serviceType {
            await reconfigureForRemainingServices()
        }
        
        print("✅ [AudioSession] \(serviceType.rawValue) configuration released")
    }
    
    /// Force deactivate audio session (for app backgrounding, etc.)
    func deactivateSession() async {
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            isActive = false
            print("✅ [AudioSession] Session deactivated")
        } catch {
            print("❌ [AudioSession] Failed to deactivate: \(error)")
        }
    }
    
    /// Get current audio route information
    func getCurrentAudioRoute() -> String {
        let route = audioSession.currentRoute
        let outputs = route.outputs.map { "\($0.portType.rawValue) - \($0.portName)" }
        let inputs = route.inputs.map { "\($0.portType.rawValue) - \($0.portName)" }
        return "Outputs: \(outputs), Inputs: \(inputs)"
    }
    
    // MARK: - Private Methods
    
    private func applyConfiguration(_ config: AudioConfiguration) async throws {
        do {
            print("🔧 [AudioSession] Applying configuration for \(config.serviceType.rawValue)")
            print("🔧 [AudioSession] Category: \(config.category), Mode: \(config.mode), Options: \(config.options)")
            
            try audioSession.setCategory(config.category, mode: config.mode, options: config.options)
            if let availableInputs = audioSession.availableInputs {
                let preferredInput = availableInputs.first(where: { $0.portType == .builtInMic }) ?? availableInputs.first
                if let preferredInput {
                    do {
                        try audioSession.setPreferredInput(preferredInput)
                        print("🎙️ [AudioSession] Preferred input set to: \(preferredInput.portType.rawValue) - \(preferredInput.portName)")
                    } catch {
                        print("⚠️ [AudioSession] Failed to set preferred input: \(error)")
                    }
                } else {
                    print("⚠️ [AudioSession] No available audio inputs")
                }
            }
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            if config.options.contains(.defaultToSpeaker) {
                do {
                    try audioSession.overrideOutputAudioPort(.speaker)
                } catch {
                    print("⚠️ [AudioSession] Failed to override to speaker: \(error)")
                }
            }
            
            currentConfiguration = config
            isActive = true
            
            // Log current route
            print("🔊 [AudioSession] Current route: \(getCurrentAudioRoute())")
            
        } catch {
            print("❌ [AudioSession] Failed to apply configuration: \(error)")
            throw AudioSessionError.configurationFailed(error)
        }
    }
    
    private func reconfigureForRemainingServices() async {
        guard !activeServices.isEmpty else {
            // No active services, deactivate session
            await deactivateSession()
            currentConfiguration = nil
            return
        }
        
        // Find highest priority remaining service
        let highestPriorityService = activeServices.max { service1, service2 in
            let priority1 = Self.configurations[service1]?.priority ?? 0
            let priority2 = Self.configurations[service2]?.priority ?? 0
            return priority1 < priority2
        }
        
        if let service = highestPriorityService,
           let config = Self.configurations[service] {
            do {
                try await applyConfiguration(config)
            } catch {
                print("❌ [AudioSession] Failed to reconfigure for \(service.rawValue): \(error)")
            }
        }
    }
    
    private func setupNotifications() {
        // Audio session interruption handling
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                Task { @MainActor [weak self] in
                    await self?.handleInterruption(notification)
                }
            }
            .store(in: &cancellables)
        
        // Audio route change handling
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .sink { [weak self] notification in
                Task { @MainActor [weak self] in
                    await self?.handleRouteChange(notification)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleInterruption(_ notification: Notification) async {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            print("🔇 [AudioSession] Interruption began")
            isActive = false
            
        case .ended:
            print("🔊 [AudioSession] Interruption ended")
            
            // Check if we should resume
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume), let config = currentConfiguration {
                    do {
                        try await applyConfiguration(config)
                    } catch {
                        print("❌ [AudioSession] Failed to resume after interruption: \(error)")
                    }
                }
            }
            
        @unknown default:
            break
        }
    }
    
    private func handleRouteChange(_ notification: Notification) async {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        print("🔄 [AudioSession] Route changed: \(reason)")
        print("🔊 [AudioSession] New route: \(getCurrentAudioRoute())")
        
        // Handle specific route changes that might require reconfiguration
        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable:
            // Device connected/disconnected - might need to reconfigure
            if let config = currentConfiguration {
                do {
                    try await applyConfiguration(config)
                } catch {
                    print("❌ [AudioSession] Failed to reconfigure after route change: \(error)")
                }
            }
        default:
            break
        }
    }
}

// MARK: - Error Types

enum AudioSessionError: Error, LocalizedError {
    case unsupportedServiceType
    case configurationFailed(Error)
    case sessionNotActive
    
    var errorDescription: String? {
        switch self {
        case .unsupportedServiceType:
            return "Unsupported audio service type"
        case .configurationFailed(let error):
            return "Audio session configuration failed: \(error.localizedDescription)"
        case .sessionNotActive:
            return "Audio session is not active"
        }
    }
}
