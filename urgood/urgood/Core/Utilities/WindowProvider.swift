import UIKit
import OSLog

enum WindowProvider {
    private static let log = Logger(subsystem: "com.urgood.urgood", category: "WindowProvider")
    
    static func activeWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
        
        if let window = scenes
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) {
            return window
        }
        
        if let fallback = scenes
            .flatMap({ $0.windows })
            .first {
            return fallback
        }
        
        log.error("🚪 No active window available")
        return nil
    }
}
