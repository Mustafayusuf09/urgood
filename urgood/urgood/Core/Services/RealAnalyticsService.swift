import Foundation
import FirebaseAnalytics
import FirebaseCore

class RealAnalyticsService: ObservableObject {
    static let shared = RealAnalyticsService()
    
    private var isInitialized = false
    
    private init() {
        initializeAnalytics()
    }
    
    // MARK: - Initialization
    
    private func initializeAnalytics() {
        // Initialize Firebase Analytics
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        isInitialized = true
        print("📊 Firebase Analytics initialized successfully")
    }
    
    // MARK: - Event Tracking
    
    func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        guard isInitialized else { return }
        
        // Convert parameters to Firebase Analytics format
        var firebaseParams: [String: Any] = [:]
        if let parameters = parameters {
            for (key, value) in parameters {
                // Firebase Analytics has specific parameter requirements
                if let stringValue = value as? String {
                    firebaseParams[key] = stringValue
                } else if let numberValue = value as? NSNumber {
                    firebaseParams[key] = numberValue
                } else if let boolValue = value as? Bool {
                    firebaseParams[key] = boolValue
                } else {
                    firebaseParams[key] = String(describing: value)
                }
            }
        }
        
        Analytics.logEvent(name, parameters: firebaseParams)
        print("📊 [Firebase Analytics] Event: \(name), Parameters: \(firebaseParams)")
    }
    
    func setUserProperty(_ value: String?, forName name: String) {
        guard isInitialized else { return }
        
        Analytics.setUserProperty(value, forName: name)
        print("📊 [Firebase Analytics] User Property: \(name) = \(value ?? "nil")")
    }
    
    func setUserId(_ userId: String?) {
        guard isInitialized else { return }
        
        Analytics.setUserID(userId)
        print("📊 [Firebase Analytics] User ID: \(userId ?? "nil")")
    }
    
    // MARK: - Business Metrics
    
    func trackSubscriptionEvent(_ event: SubscriptionEvent) {
        logEvent("subscription_\(event.rawValue)", parameters: [
            "subscription_type": event.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackUserEngagement(_ action: String, value: Double? = nil) {
        var parameters: [String: Any] = [
            "action": action,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let value = value {
            parameters["value"] = value
        }
        
        logEvent("user_engagement", parameters: parameters)
    }
    
    func trackVoiceChatSession(duration: TimeInterval, messageCount: Int) {
        logEvent("voice_chat_session", parameters: [
            "duration": duration,
            "message_count": messageCount,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackCrisisDetection(severity: CrisisSeverity, action: String) {
        logEvent("crisis_detection", parameters: [
            "severity": severity.rawValue,
            "action": action,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - A/B Testing
    
    func trackExperiment(_ experimentId: String, variant: String, action: String) {
        logEvent("experiment_\(action)", parameters: [
            "experiment_id": experimentId,
            "variant": variant,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Performance Metrics
    
    func trackPerformanceMetric(_ metric: String, value: Double, unit: String? = nil) {
        var parameters: [String: Any] = [
            "metric": metric,
            "value": value,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let unit = unit {
            parameters["unit"] = unit
        }
        
        logEvent("performance_metric", parameters: parameters)
    }
    
    // MARK: - Error Tracking
    
    func log(_ message: String) {
        guard isInitialized else { return }
        
        // Use Firebase Analytics for custom logs
        Analytics.logEvent("custom_log", parameters: [
            "message": message,
            "timestamp": Date().timeIntervalSince1970
        ])
        print("📊 [Firebase Analytics] Log: \(message)")
    }
    
    func setCustomValue(_ value: Any, forKey key: String) {
        guard isInitialized else { return }
        
        // Use Firebase Analytics for custom values
        Analytics.setUserProperty(String(describing: value), forName: key)
        print("📊 [Firebase Analytics] Custom Value: \(key) = \(value)")
    }
    
    func recordError(_ error: Error) {
        guard isInitialized else { return }
        
        // Use Firebase Analytics for error tracking
        Analytics.logEvent("error_occurred", parameters: [
            "error_domain": (error as NSError).domain,
            "error_code": (error as NSError).code,
            "error_description": error.localizedDescription,
            "timestamp": Date().timeIntervalSince1970
        ])
        print("📊 [Firebase Analytics] Error: \(error.localizedDescription)")
    }
    
    // MARK: - User Analytics
    
    func trackUserOnboarding(step: String, completed: Bool) {
        logEvent("onboarding_step", parameters: [
            "step": step,
            "completed": completed,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackUserRetention(daysSinceInstall: Int) {
        logEvent("user_retention", parameters: [
            "days_since_install": daysSinceInstall,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackFeatureUsage(_ feature: String, action: String) {
        logEvent("feature_usage", parameters: [
            "feature": feature,
            "action": action,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Revenue Analytics
    
    func trackRevenue(amount: Double, currency: String = "USD", product: String) {
        logEvent("revenue", parameters: [
            "amount": amount,
            "currency": currency,
            "product": product,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackPurchase(_ productId: String, price: Double, currency: String = "USD") {
        logEvent("purchase", parameters: [
            "product_id": productId,
            "price": price,
            "currency": currency,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - App Lifecycle
    
    func trackAppLaunch() {
        logEvent("app_launch", parameters: [
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackAppBackground() {
        logEvent("app_background", parameters: [
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackAppForeground() {
        logEvent("app_foreground", parameters: [
            "timestamp": Date().timeIntervalSince1970
        ])
    }
}

// MARK: - Supporting Types

enum SubscriptionEvent: String, CaseIterable {
    case started = "started"
    case renewed = "renewed"
    case cancelled = "cancelled"
    case expired = "expired"
    case upgraded = "upgraded"
    case downgraded = "downgraded"
}
