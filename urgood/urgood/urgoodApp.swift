//
//  urgoodApp.swift
//  urgood
//
//  Created by Mustafa Yusuf on 8/29/25.
//

import SwiftUI
import AuthenticationServices

@main
struct urgoodApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, UIApplicationDelegate {
    private let crashlytics = CrashlyticsService.shared
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Print development mode status
        DevelopmentConfig.printStatus()
        
        // Print environment configuration
        EnvironmentConfig.printConfiguration()
        
        // Configure Firebase (standalone mode)
        FirebaseConfig.configure()
        
        // Initialize Crashlytics and start session
        crashlytics.recordAppLaunch()
        crashlytics.startSession(userId: nil, subscriptionStatus: nil)
        
        // Validate configuration in background
        Task {
            await ConfigurationValidationService.shared.validateConfiguration()
        }
        
        // Set up crash handler
        NSSetUncaughtExceptionHandler { exception in
            let error = NSError(domain: "UncaughtException", code: -1, userInfo: [
                NSLocalizedDescriptionKey: exception.reason ?? "Unknown exception"
            ])
            CrashlyticsService.shared.recordAppCrash(error: error)
        }
        
        return true
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        crashlytics.recordAppState(.background)
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        crashlytics.recordAppState(.active)
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        crashlytics.recordAppState(.terminated)
        crashlytics.endSession()
    }
    
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        crashlytics.recordMemoryWarning()
    }
}
