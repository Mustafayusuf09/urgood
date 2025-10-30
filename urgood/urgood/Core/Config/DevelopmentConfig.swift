import Foundation

/// Development configuration for bypassing authentication and paywall restrictions
struct DevelopmentConfig {
    /// Set to true to bypass all authentication requirements
    static let bypassAuthentication = false
    
    /// Set to true to bypass all paywall restrictions and give premium access
    static let bypassPaywall = false
    
    /// Set to true to bypass onboarding and first run flows
    static let bypassOnboarding = false
    
    /// Development mode indicator - true if any bypass is enabled
    static var isDevelopmentMode: Bool {
        return bypassAuthentication || bypassPaywall || bypassOnboarding
    }
    
    /// Print development mode status
    static func printStatus() {
        if isDevelopmentMode {
            print("🔧 DEVELOPMENT MODE ENABLED:")
            if bypassAuthentication {
                print("  ✅ Authentication bypassed")
            }
            if bypassPaywall {
                print("  ✅ Paywall restrictions bypassed")
            }
            if bypassOnboarding {
                print("  ✅ Onboarding flows bypassed")
            }
        } else {
            print("🚀 Production mode - all restrictions active")
        }
    }
}
