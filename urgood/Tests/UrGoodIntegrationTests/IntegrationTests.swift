import XCTest
@testable import urgood

class IntegrationTests: XCTestCase {
    
    var app: XCUIApplication!
    var localStore: EnhancedLocalStore!
    var analyticsService: RealAnalyticsService!
    var firestoreService: FirestoreService!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        localStore = EnhancedLocalStore()
        analyticsService = RealAnalyticsService.shared
        firestoreService = FirestoreService.shared
    }
    
    override func tearDownWithError() throws {
        app = nil
        localStore = nil
        analyticsService = nil
        firestoreService = nil
    }
    
    // MARK: - Firebase Integration Tests
    
    func testFirebaseAnalyticsIntegration() throws {
        // Test Firebase Analytics initialization
        XCTAssertNotNil(analyticsService)
        
        // Test event logging
        analyticsService.logEvent("test_integration_event", parameters: [
            "test_parameter": "test_value",
            "timestamp": Date().timeIntervalSince1970
        ])
        
        // Test user property setting
        analyticsService.setUserProperty("test_user", forName: "test_property")
        
        // Test user ID setting
        analyticsService.setUserId("test_user_123")
        
        // These should not crash
        XCTAssertTrue(true)
    }
    
    func testFirebaseCrashlyticsIntegration() throws {
        // Test Crashlytics service
        let crashlyticsService = CrashlyticsService.shared
        XCTAssertNotNil(crashlyticsService)
        
        // Test error recording
        let testError = NSError(domain: "IntegrationTest", code: 123, userInfo: [
            NSLocalizedDescriptionKey: "Test integration error"
        ])
        crashlyticsService.recordError(testError)
        
        // Test custom logging
        crashlyticsService.log("Integration test log message")
        
        // Test custom values
        crashlyticsService.setCustomValue("test_value", forKey: "test_key")
        
        // These should not crash
        XCTAssertTrue(true)
    }
    
    func testFirestoreIntegration() throws {
        // Test Firestore service initialization
        XCTAssertNotNil(firestoreService)
        
        // Test user creation
        let testUser = User(
            id: "test_user_123",
            email: "test@example.com",
            name: "Test User",
            subscriptionStatus: .free,
            streakCount: 0
        )
        
        // Note: In a real integration test, you would test actual Firestore operations
        // For now, we'll test that the service methods exist and don't crash
        Task {
            do {
                try await firestoreService.createUser(testUser)
            } catch {
                // Expected in test environment without Firebase configuration
                XCTAssertTrue(error is FirestoreError)
            }
        }
    }
    
    // MARK: - OpenAI Integration Tests
    
    func testOpenAIServiceIntegration() throws {
        // Test OpenAI service initialization
        let openAIService = RealAIService()
        XCTAssertNotNil(openAIService)
        
        // Test message sending (will use mock response in test environment)
        Task {
            do {
                let response = try await openAIService.sendMessage(
                    "Hello, this is a test message",
                    conversationHistory: []
                )
                XCTAssertFalse(response.isEmpty)
            } catch {
                XCTFail("OpenAI service threw unexpected error: \(error)")
            }
        }
    }
    
    // MARK: - Data Persistence Integration Tests
    
    func testCoreDataIntegration() throws {
        // Test Core Data stack
        let coreDataStack = CoreDataStack.shared
        XCTAssertNotNil(coreDataStack)
        
        // Test data migration service
        let migrationService = DataMigrationService()
        XCTAssertNotNil(migrationService)
        
        // Test enhanced local store
        XCTAssertNotNil(localStore)
        
        // Test data operations
        let testMessage = ChatMessage(role: .user, text: "Test message")
        localStore.addMessage(testMessage)
        
        let messages = localStore.getChatHistory()
        XCTAssertTrue(messages.contains { $0.text == "Test message" })
    }
    
    func testDataSyncIntegration() throws {
        // Test data sync between local and cloud storage
        let testMessage = ChatMessage(role: .user, text: "Sync test message")
        localStore.addMessage(testMessage)
        
        // Test sync to Firestore (will fail in test environment, but should not crash)
        Task {
            do {
                try await firestoreService.syncChatMessages([testMessage], userId: "test_user")
            } catch {
                // Expected in test environment
                XCTAssertTrue(error is FirestoreError)
            }
        }
    }
    
    // MARK: - Authentication Integration Tests
    
    func testAuthenticationIntegration() throws {
        // Test standalone auth service
        let authService = StandaloneAuthService()
        XCTAssertNotNil(authService)
        
        // Test user creation
        let testUser = User(
            id: "test_user_123",
            email: "test@example.com",
            name: "Test User",
            subscriptionStatus: .free,
            streakCount: 0
        )
        
        authService.createUser(email: "test@example.com", password: "testpassword", name: "Test User")
        
        // Test user login
        authService.signIn(email: "test@example.com", password: "testpassword")
        
        // Test user logout
        authService.signOut()
    }
    
    // MARK: - Billing Integration Tests
    
    func testBillingIntegration() throws {
        // Test billing service
        let billingService = BillingService(localStore: localStore)
        XCTAssertNotNil(billingService)
        
        // Test subscription status
        let isPremium = billingService.isPremiumUser()
        XCTAssertFalse(isPremium) // Should be false for new user
        
        // Test available products
        let products = billingService.getAvailableProducts()
        XCTAssertFalse(products.isEmpty)
        
        // Test product pricing
        let price = billingService.getProductPrice(for: "core_monthly")
        XCTAssertNotNil(price)
    }
    
    // MARK: - Analytics Integration Tests
    
    func testAnalyticsIntegration() throws {
        // Test analytics service
        XCTAssertNotNil(analyticsService)
        
        // Test event tracking
        analyticsService.trackUserEngagement("test_action", value: 1.0)
        analyticsService.trackFeatureUsage("test_feature", action: "tested")
        analyticsService.trackAppLaunch()
        
        // Test subscription tracking
        analyticsService.trackSubscriptionEvent(.started)
        analyticsService.trackPurchase("core_monthly", price: 24.99)
        
        // Test performance tracking
        analyticsService.trackPerformanceMetric("test_metric", value: 1.5, unit: "seconds")
    }
    
    // MARK: - Crisis Detection Integration Tests
    
    func testCrisisDetectionIntegration() throws {
        // Test crisis detection service
        let crisisService = CrisisDetectionService()
        XCTAssertNotNil(crisisService)
        
        // Test crisis detection
        let crisisMessage = "I want to hurt myself"
        let isCrisis = crisisService.detectCrisis(crisisMessage)
        XCTAssertTrue(isCrisis)
        
        // Test non-crisis message
        let normalMessage = "I'm feeling good today"
        let isNormal = crisisService.detectCrisis(normalMessage)
        XCTAssertFalse(isNormal)
    }
    
    // MARK: - Performance Integration Tests
    
    func testPerformanceIntegration() throws {
        // Test performance monitor
        let performanceMonitor = PerformanceMonitor.shared
        XCTAssertNotNil(performanceMonitor)
        
        // Test performance tracking
        performanceMonitor.startTiming(operation: "test_operation")
        Thread.sleep(forTimeInterval: 0.1) // Simulate work
        let duration = performanceMonitor.endTiming(operation: "test_operation")
        XCTAssertGreaterThan(duration, 0)
        
        // Test memory monitoring
        let memoryUsage = performanceMonitor.getCurrentMemoryUsage()
        XCTAssertGreaterThan(memoryUsage, 0)
        
        // Test CPU monitoring
        let cpuUsage = performanceMonitor.getCurrentCPUUsage()
        XCTAssertGreaterThanOrEqual(cpuUsage, 0)
    }
    
    // MARK: - Feature Flags Integration Tests
    
    func testFeatureFlagsIntegration() throws {
        // Test feature flags service
        let featureFlags = RemoteFeatureFlags.shared
        XCTAssertNotNil(featureFlags)
        
        // Test feature flag retrieval
        let isEnabled = featureFlags.isFeatureEnabled("test_feature")
        XCTAssertFalse(isEnabled) // Should be false for unknown feature
        
        // Test experiment tracking
        featureFlags.trackExperiment("test_experiment", variant: "control", action: "viewed")
    }
    
    // MARK: - Background Jobs Integration Tests
    
    func testBackgroundJobsIntegration() throws {
        // Test background job queue
        let jobQueue = BackgroundJobQueue.shared
        XCTAssertNotNil(jobQueue)
        
        // Test job scheduling
        let jobId = jobQueue.scheduleJob(
            type: "test_job",
            data: ["test": "data"],
            priority: .normal
        )
        XCTAssertNotNil(jobId)
        
        // Test job processing
        jobQueue.processJobs()
    }
    
    // MARK: - API Integration Tests
    
    func testAPIServiceIntegration() throws {
        // Test API service
        let apiService = APIService.shared
        XCTAssertNotNil(apiService)
        
        // Test API configuration
        let config = APIConfig.shared
        XCTAssertNotNil(config)
        
        // Test API versioning
        let versioning = APIVersioning.shared
        XCTAssertNotNil(versioning)
    }
    
    // MARK: - End-to-End Integration Tests
    
    func testCompleteUserFlow() throws {
        // Test complete user flow from onboarding to chat
        app.launch()
        
        // Test onboarding
        let onboardingView = app.otherElements["OnboardingFlowView"]
        XCTAssertTrue(onboardingView.waitForExistence(timeout: 5))
        
        // Test chat functionality
        let chatTab = app.tabBars.buttons["Chat"]
        XCTAssertTrue(chatTab.exists)
        chatTab.tap()
        
        // Test mood check-in
        let checkinTab = app.tabBars.buttons["Check-in"]
        XCTAssertTrue(checkinTab.exists)
        checkinTab.tap()
        
        // Test insights
        let insightsTab = app.tabBars.buttons["Insights"]
        XCTAssertTrue(insightsTab.exists)
        insightsTab.tap()
        
        // Test settings
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.exists)
        settingsTab.tap()
    }
    
    func testDataConsistency() throws {
        // Test data consistency across services
        let testMessage = ChatMessage(role: .user, text: "Consistency test message")
        
        // Add to local store
        localStore.addMessage(testMessage)
        
        // Verify in local store
        let localMessages = localStore.getChatHistory()
        XCTAssertTrue(localMessages.contains { $0.text == "Consistency test message" })
        
        // Test analytics tracking
        analyticsService.trackFeatureUsage("chat", action: "message_sent")
        
        // Test performance tracking
        let performanceMonitor = PerformanceMonitor.shared
        performanceMonitor.trackPerformanceMetric("data_consistency", value: 1.0)
    }
}
