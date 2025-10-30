import XCTest
@testable import urgood

class AnalyticsServiceTests: XCTestCase {
    
    var analyticsService: RealAnalyticsService!
    
    override func setUpWithError() throws {
        analyticsService = RealAnalyticsService.shared
    }
    
    override func tearDownWithError() throws {
        analyticsService = nil
    }
    
    func testLogEvent() {
        // Given
        let eventName = "test_event"
        let parameters = ["key": "value", "number": 123]
        
        // When & Then
        // This should not crash
        analyticsService.logEvent(eventName, parameters: parameters)
    }
    
    func testLogEventWithoutParameters() {
        // Given
        let eventName = "simple_event"
        
        // When & Then
        // This should not crash
        analyticsService.logEvent(eventName)
    }
    
    func testSetUserProperty() {
        // Given
        let propertyName = "test_property"
        let propertyValue = "test_value"
        
        // When & Then
        // This should not crash
        analyticsService.setUserProperty(propertyValue, forName: propertyName)
    }
    
    func testSetUserId() {
        // Given
        let userId = "test_user_123"
        
        // When & Then
        // This should not crash
        analyticsService.setUserId(userId)
    }
    
    func testTrackSubscriptionEvent() {
        // Given
        let event = SubscriptionEvent.started
        
        // When & Then
        // This should not crash
        analyticsService.trackSubscriptionEvent(event)
    }
    
    func testTrackUserEngagement() {
        // Given
        let action = "button_click"
        let value = 5.0
        
        // When & Then
        // This should not crash
        analyticsService.trackUserEngagement(action, value: value)
    }
    
    func testTrackVoiceChatSession() {
        // Given
        let duration: TimeInterval = 120.0
        let messageCount = 15
        
        // When & Then
        // This should not crash
        analyticsService.trackVoiceChatSession(duration: duration, messageCount: messageCount)
    }
    
    func testTrackCrisisDetection() {
        // Given
        let severity = CrisisSeverity.high
        let action = "escalated"
        
        // When & Then
        // This should not crash
        analyticsService.trackCrisisDetection(severity: severity, action: action)
    }
    
    func testTrackExperiment() {
        // Given
        let experimentId = "test_experiment"
        let variant = "control"
        let action = "viewed"
        
        // When & Then
        // This should not crash
        analyticsService.trackExperiment(experimentId, variant: variant, action: action)
    }
    
    func testTrackPerformanceMetric() {
        // Given
        let metric = "load_time"
        let value = 1.5
        let unit = "seconds"
        
        // When & Then
        // This should not crash
        analyticsService.trackPerformanceMetric(metric, value: value, unit: unit)
    }
    
    func testRecordError() {
        // Given
        let error = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        
        // When & Then
        // This should not crash
        analyticsService.recordError(error)
    }
    
    func testTrackUserOnboarding() {
        // Given
        let step = "welcome"
        let completed = true
        
        // When & Then
        // This should not crash
        analyticsService.trackUserOnboarding(step: step, completed: completed)
    }
    
    func testTrackUserRetention() {
        // Given
        let daysSinceInstall = 7
        
        // When & Then
        // This should not crash
        analyticsService.trackUserRetention(daysSinceInstall: daysSinceInstall)
    }
    
    func testTrackFeatureUsage() {
        // Given
        let feature = "voice_chat"
        let action = "started"
        
        // When & Then
        // This should not crash
        analyticsService.trackFeatureUsage(feature, action: action)
    }
    
    func testTrackRevenue() {
        // Given
        let amount = 24.99
        let currency = "USD"
        let product = "core_monthly"
        
        // When & Then
        // This should not crash
        analyticsService.trackRevenue(amount: amount, currency: currency, product: product)
    }
    
    func testTrackPurchase() {
        // Given
        let productId = "core_monthly"
        let price = 24.99
        let currency = "USD"
        
        // When & Then
        // This should not crash
        analyticsService.trackPurchase(productId, price: price, currency: currency)
    }
    
    func testTrackAppLifecycle() {
        // When & Then
        // These should not crash
        analyticsService.trackAppLaunch()
        analyticsService.trackAppBackground()
        analyticsService.trackAppForeground()
    }
}
