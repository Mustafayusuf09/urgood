import Foundation
import FirebaseCrashlytics
import FirebaseCore
import UIKit
import Network

class CrashlyticsService: ObservableObject {
    static let shared = CrashlyticsService()
    
    private var isInitialized = false
    private var networkMonitor: NWPathMonitor?
    private var monitorQueue = DispatchQueue(label: "NetworkMonitor")
    private var sessionStartTime: Date?
    
    private init() {
        initializeCrashlytics()
        setupNetworkMonitoring()
        setupMemoryMonitoring()
    }
    
    // MARK: - Initialization
    
    private func initializeCrashlytics() {
        // Initialize Firebase Crashlytics
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        // Set up custom keys for mental health app
        setCustomValue("urgood_ios", forKey: "app_platform")
        setCustomValue(Bundle.main.bundleIdentifier ?? "unknown", forKey: "bundle_id")
        setCustomValue(ProcessInfo.processInfo.operatingSystemVersionString, forKey: "os_version")
        
        isInitialized = true
        print("🔥 Firebase Crashlytics initialized successfully for UrGood")
        
        // Record successful initialization
        log("Crashlytics initialized for mental health app", level: .info)
    }
    
    // MARK: - Logging
    
    func log(_ message: String) {
        guard isInitialized else { return }
        
        Crashlytics.crashlytics().log(message)
        print("🔥 [Crashlytics] Log: \(message)")
    }
    
    func log(_ message: String, level: CrashlyticsLogLevel) {
        guard isInitialized else { return }
        
        let formattedMessage = "[\(level.rawValue.uppercased())] \(message)"
        Crashlytics.crashlytics().log(formattedMessage)
        print("🔥 [Crashlytics] \(formattedMessage)")
    }
    
    // MARK: - Custom Values
    
    func setCustomValue(_ value: Any, forKey key: String) {
        guard isInitialized else { return }
        
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
        print("🔥 [Crashlytics] Custom Value: \(key) = \(value)")
    }
    
    func setUserIdentifier(_ identifier: String) {
        guard isInitialized else { return }
        
        Crashlytics.crashlytics().setUserID(identifier)
        print("🔥 [Crashlytics] User ID: \(identifier)")
    }
    
    // MARK: - Error Reporting
    
    func recordError(_ error: Error) {
        guard isInitialized else { return }
        
        Crashlytics.crashlytics().record(error: error)
        print("🔥 [Crashlytics] Error Recorded: \(error.localizedDescription)")
    }
    
    func recordError(_ error: Error, userInfo: [String: Any]? = nil) {
        guard isInitialized else { return }
        
        if let userInfo = userInfo {
            for (key, value) in userInfo {
                setCustomValue(value, forKey: key)
            }
        }
        
        Crashlytics.crashlytics().record(error: error)
        print("🔥 [Crashlytics] Error Recorded with UserInfo: \(error.localizedDescription)")
    }
    
    // MARK: - Non-Fatal Errors
    
    func recordNonFatalError(_ error: Error, context: String? = nil) {
        guard isInitialized else { return }
        
        var userInfo: [String: Any] = [
            "error_type": "non_fatal",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let context = context {
            userInfo["context"] = context
        }
        
        recordError(error, userInfo: userInfo)
    }
    
    // MARK: - Performance Issues
    
    func recordPerformanceIssue(_ issue: String, details: [String: Any]? = nil) {
        guard isInitialized else { return }
        
        var userInfo: [String: Any] = [
            "issue_type": "performance",
            "issue_description": issue,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let details = details {
            userInfo.merge(details) { _, new in new }
        }
        
        let error = NSError(domain: "PerformanceIssue", code: -1, userInfo: [
            NSLocalizedDescriptionKey: issue
        ])
        
        recordError(error, userInfo: userInfo)
    }
    
    // MARK: - User Actions
    
    func recordUserAction(_ action: String, details: [String: Any]? = nil) {
        guard isInitialized else { return }
        
        var userInfo: [String: Any] = [
            "action_type": "user_action",
            "action": action,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let details = details {
            userInfo.merge(details) { _, new in new }
        }
        
        setCustomValue(userInfo, forKey: "last_user_action")
        log("User Action: \(action)", level: .info)
    }
    
    // MARK: - App State
    
    func recordAppState(_ state: AppState) {
        guard isInitialized else { return }
        
        setCustomValue(state.rawValue, forKey: "app_state")
        setCustomValue(Date().timeIntervalSince1970, forKey: "app_state_timestamp")
        log("App State: \(state.rawValue)", level: .info)
    }
    
    // MARK: - Network Issues
    
    func recordNetworkError(_ error: Error, url: String, method: String) {
        guard isInitialized else { return }
        
        let userInfo: [String: Any] = [
            "error_type": "network",
            "url": url,
            "method": method,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        recordError(error, userInfo: userInfo)
    }
    
    // MARK: - Memory Issues
    
    func recordMemoryWarning() {
        guard isInitialized else { return }
        
        let userInfo: [String: Any] = [
            "warning_type": "memory",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        let error = NSError(domain: "MemoryWarning", code: -2, userInfo: [
            NSLocalizedDescriptionKey: "Memory warning received"
        ])
        
        recordError(error, userInfo: userInfo)
    }
    
    // MARK: - Mental Health App Specific Features
    
    func recordTherapySessionError(_ error: Error, sessionId: String, sessionType: String) {
        guard isInitialized else { return }
        
        let userInfo: [String: Any] = [
            "error_type": "therapy_session",
            "session_id": sessionId,
            "session_type": sessionType,
            "timestamp": Date().timeIntervalSince1970,
            "priority": "high"
        ]
        
        recordError(error, userInfo: userInfo)
        log("Therapy session error: \(sessionType) - \(error.localizedDescription)", level: .error)
    }
    
    func recordVoiceChatError(_ error: Error, provider: String, duration: TimeInterval?) {
        guard isInitialized else { return }
        
        var userInfo: [String: Any] = [
            "error_type": "voice_chat",
            "provider": provider,
            "timestamp": Date().timeIntervalSince1970,
            "priority": "medium"
        ]
        
        if let duration = duration {
            userInfo["session_duration"] = duration
        }
        
        recordError(error, userInfo: userInfo)
        log("Voice chat error: \(provider) - \(error.localizedDescription)", level: .error)
    }
    
    func recordCrisisDetectionEvent(severity: String, confidence: Double, keywords: [String]) {
        guard isInitialized else { return }
        
        let userInfo: [String: Any] = [
            "event_type": "crisis_detection",
            "severity": severity,
            "confidence": confidence,
            "keyword_count": keywords.count,
            "timestamp": Date().timeIntervalSince1970,
            "priority": "critical"
        ]
        
        setCustomValue(userInfo, forKey: "crisis_event")
        log("Crisis detected: severity=\(severity), confidence=\(confidence)", level: .critical)
        
        // Create a custom error for crisis events
        let error = NSError(domain: "CrisisDetection", code: -100, userInfo: [
            NSLocalizedDescriptionKey: "Crisis situation detected with \(severity) severity"
        ])
        
        recordError(error, userInfo: userInfo)
    }
    
    func recordMoodEntryError(_ error: Error, moodScore: Int?) {
        guard isInitialized else { return }
        
        var userInfo: [String: Any] = [
            "error_type": "mood_entry",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let moodScore = moodScore {
            userInfo["mood_score"] = moodScore
        }
        
        recordError(error, userInfo: userInfo)
    }
    
    func recordSubscriptionError(_ error: Error, plan: String?, action: String) {
        guard isInitialized else { return }
        
        var userInfo: [String: Any] = [
            "error_type": "subscription",
            "action": action,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let plan = plan {
            userInfo["plan"] = plan
        }
        
        recordError(error, userInfo: userInfo)
    }
    
    // MARK: - Voice Activity Detection Errors
    
    func recordVADError(_ error: Error, context: [String: Any]? = nil) {
        guard isInitialized else { return }
        
        var userInfo: [String: Any] = [
            "error_type": "voice_activity_detection",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let context = context {
            userInfo.merge(context) { _, new in new }
        }
        
        recordError(error, userInfo: userInfo)
        log("VAD Error: \(error.localizedDescription)", level: .error)
    }
    
    func recordVADPerformanceIssue(falsePositives: Int, threshold: Double, backgroundNoise: Double) {
        guard isInitialized else { return }
        
        let details: [String: Any] = [
            "false_positives": falsePositives,
            "threshold": threshold,
            "background_noise": backgroundNoise,
            "vad_version": "enhanced_v2"
        ]
        
        recordPerformanceIssue("VAD False Positives Detected", details: details)
    }
    
    // MARK: - Session Management
    
    func startSession(userId: String?, subscriptionStatus: String?) {
        guard isInitialized else { return }
        
        sessionStartTime = Date()
        
        if let userId = userId {
            setUserIdentifier(userId)
        }
        
        setCustomValue(UIDevice.current.systemVersion, forKey: "ios_version")
        setCustomValue(UIDevice.current.model, forKey: "device_model")
        setCustomValue(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown", forKey: "app_version")
        
        if let subscriptionStatus = subscriptionStatus {
            setCustomValue(subscriptionStatus, forKey: "subscription_status")
        }
        
        log("Session started", level: .info)
    }
    
    func endSession() {
        guard isInitialized, let startTime = sessionStartTime else { return }
        
        let sessionDuration = Date().timeIntervalSince(startTime)
        setCustomValue(sessionDuration, forKey: "session_duration")
        
        log("Session ended - Duration: \(sessionDuration)s", level: .info)
        sessionStartTime = nil
    }
    
    // MARK: - Performance Monitoring
    
    func recordSlowOperation(_ operation: String, duration: TimeInterval, threshold: TimeInterval = 2.0) {
        guard isInitialized, duration > threshold else { return }
        
        let details: [String: Any] = [
            "operation": operation,
            "duration": duration,
            "threshold": threshold,
            "performance_category": "slow_operation"
        ]
        
        recordPerformanceIssue("Slow Operation: \(operation)", details: details)
    }
    
    func recordMemoryPressure(level: String, availableMemory: UInt64?) {
        guard isInitialized else { return }
        
        var details: [String: Any] = [
            "memory_pressure_level": level,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let availableMemory = availableMemory {
            details["available_memory_mb"] = availableMemory / 1024 / 1024
        }
        
        recordPerformanceIssue("Memory Pressure: \(level)", details: details)
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        networkMonitor = NWPathMonitor()
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.handleNetworkChange(path)
            }
        }
        networkMonitor?.start(queue: monitorQueue)
    }
    
    private func handleNetworkChange(_ path: NWPath) {
        let status = path.status == .satisfied ? "connected" : "disconnected"
        setCustomValue(status, forKey: "network_status")
        
        if path.status != .satisfied {
            log("Network disconnected", level: .warning)
        }
    }
    
    // MARK: - Memory Monitoring
    
    private func setupMemoryMonitoring() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.recordMemoryWarning()
        }
    }
    
    // MARK: - App Lifecycle Integration
    
    func recordAppLaunch() {
        guard isInitialized else { return }
        
        setCustomValue(Date().timeIntervalSince1970, forKey: "app_launch_time")
        recordAppState(.launching)
        log("App launched", level: .info)
    }
    
    func recordAppCrash(error: Error?) {
        guard isInitialized else { return }
        
        recordAppState(.crashed)
        
        if let error = error {
            recordError(error, userInfo: [
                "crash_type": "app_crash",
                "timestamp": Date().timeIntervalSince1970
            ])
        }
        
        log("App crashed", level: .critical)
    }
    
    // MARK: - Feature Usage Tracking
    
    func recordFeatureUsage(_ feature: String, success: Bool, metadata: [String: Any]? = nil) {
        guard isInitialized else { return }
        
        var userInfo: [String: Any] = [
            "feature": feature,
            "success": success,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let metadata = metadata {
            userInfo.merge(metadata) { _, new in new }
        }
        
        setCustomValue(userInfo, forKey: "last_feature_usage")
        
        if !success {
            let error = NSError(domain: "FeatureUsage", code: -200, userInfo: [
                NSLocalizedDescriptionKey: "Feature \(feature) failed"
            ])
            recordError(error, userInfo: userInfo)
        }
        
        log("Feature usage: \(feature) - Success: \(success)", level: success ? .info : .warning)
    }
    
    // MARK: - Debugging
    
    func enableDebugMode() {
        guard isInitialized else { return }
        
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        setCustomValue(true, forKey: "debug_mode")
        log("Debug mode enabled", level: .debug)
    }
    
    func disableDebugMode() {
        guard isInitialized else { return }
        
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
        setCustomValue(false, forKey: "debug_mode")
        log("Debug mode disabled", level: .debug)
    }
    
    // MARK: - Cleanup
    
    deinit {
        networkMonitor?.cancel()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Supporting Types

enum CrashlyticsLogLevel: String, CaseIterable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"
}

enum AppState: String, CaseIterable {
    case launching = "launching"
    case active = "active"
    case background = "background"
    case terminated = "terminated"
    case crashed = "crashed"
}

// MARK: - Crashlytics Extensions

extension CrashlyticsService {
    
    // Convenience methods for common mental health app scenarios
    
    func recordAuthenticationError(_ error: Error, method: String) {
        recordError(error, userInfo: [
            "error_type": "authentication",
            "auth_method": method,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func recordDataSyncError(_ error: Error, dataType: String) {
        recordError(error, userInfo: [
            "error_type": "data_sync",
            "data_type": dataType,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func recordUIError(_ error: Error, screen: String, action: String) {
        recordError(error, userInfo: [
            "error_type": "ui_error",
            "screen": screen,
            "action": action,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func recordAPIError(_ error: Error, endpoint: String, statusCode: Int?) {
        var userInfo: [String: Any] = [
            "error_type": "api_error",
            "endpoint": endpoint,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let statusCode = statusCode {
            userInfo["status_code"] = statusCode
        }
        
        recordError(error, userInfo: userInfo)
    }
}
