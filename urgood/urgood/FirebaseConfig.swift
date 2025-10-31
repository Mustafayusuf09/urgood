import Foundation
import FirebaseCore
import FirebaseAnalytics

struct FirebaseConfig {
    static func configure() {
        // Configure Firebase
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }
    
    // MARK: - Analytics Helpers
    
    static func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(name, parameters: parameters)
    }
    
    static func setUserProperty(_ value: String?, forName name: String) {
        Analytics.setUserProperty(value, forName: name)
    }
    
    static func setUserId(_ userId: String?) {
        Analytics.setUserID(userId)
    }
    
    // MARK: - Error Tracking Helpers
    
    static func log(_ message: String) {
        Analytics.logEvent("custom_log", parameters: [
            "message": message,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    static func setCustomValue(_ value: Any, forKey key: String) {
        Analytics.setUserProperty(String(describing: value), forName: key)
    }
    
    static func recordError(_ error: Error) {
        Analytics.logEvent("error_occurred", parameters: [
            "error_domain": (error as NSError).domain,
            "error_code": (error as NSError).code,
            "error_description": error.localizedDescription,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
}
