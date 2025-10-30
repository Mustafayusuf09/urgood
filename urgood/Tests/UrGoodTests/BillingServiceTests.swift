import XCTest
@testable import urgood

class BillingServiceTests: XCTestCase {
    
    var billingService: BillingService!
    var mockLocalStore: MockLocalStore!
    
    override func setUpWithError() throws {
        mockLocalStore = MockLocalStore()
        billingService = BillingService(localStore: mockLocalStore)
    }
    
    override func tearDownWithError() throws {
        billingService = nil
        mockLocalStore = nil
    }
    
    func testInitialization() {
        // Then
        XCTAssertNotNil(billingService)
        XCTAssertEqual(billingService.subscriptionStatus, .free)
    }
    
    func testIsPremiumUser() {
        // Given
        mockLocalStore.user = User(
            id: "test_user",
            email: "test@example.com",
            name: "Test User",
            subscriptionStatus: .premium,
            streakCount: 0
        )
        
        // When
        let isPremium = billingService.isPremiumUser()
        
        // Then
        XCTAssertTrue(isPremium)
    }
    
    func testIsPremiumUserWithFreeSubscription() {
        // Given
        mockLocalStore.user = User(
            id: "test_user",
            email: "test@example.com",
            name: "Test User",
            subscriptionStatus: .free,
            streakCount: 0
        )
        
        // When
        let isPremium = billingService.isPremiumUser()
        
        // Then
        XCTAssertFalse(isPremium)
    }
    
    func testGetSubscriptionStatus() {
        // Given
        mockLocalStore.user = User(
            id: "test_user",
            email: "test@example.com",
            name: "Test User",
            subscriptionStatus: .premium,
            streakCount: 0
        )
        
        // When
        let status = billingService.getSubscriptionStatus()
        
        // Then
        XCTAssertEqual(status, .premium)
    }
    
    func testGetAvailableProducts() {
        // When
        let products = billingService.getAvailableProducts()
        
        // Then
        XCTAssertFalse(products.isEmpty)
        XCTAssertTrue(products.contains { $0.id == "core_monthly" })
    }
    
    func testGetProductPrice() {
        // Given
        let productId = "core_monthly"
        
        // When
        let price = billingService.getProductPrice(for: productId)
        
        // Then
        XCTAssertNotNil(price)
        XCTAssertGreaterThan(price!, 0)
    }
    
    func testGetProductPriceForInvalidProduct() {
        // Given
        let productId = "invalid_product"
        
        // When
        let price = billingService.getProductPrice(for: productId)
        
        // Then
        XCTAssertNil(price)
    }
    
    func testPurchaseProduct() async {
        // Given
        let productId = "core_monthly"
        
        // When
        let result = await billingService.purchaseProduct(productId)
        
        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(billingService.subscriptionStatus, .premium)
    }
    
    func testPurchaseInvalidProduct() async {
        // Given
        let productId = "invalid_product"
        
        // When
        let result = await billingService.purchaseProduct(productId)
        
        // Then
        XCTAssertFalse(result)
        XCTAssertEqual(billingService.subscriptionStatus, .free)
    }
    
    func testRestorePurchases() async {
        // Given
        mockLocalStore.user = User(
            id: "test_user",
            email: "test@example.com",
            name: "Test User",
            subscriptionStatus: .premium,
            streakCount: 0
        )
        
        // When
        let result = await billingService.restorePurchases()
        
        // Then
        XCTAssertTrue(result)
    }
    
    func testCancelSubscription() async {
        // Given
        mockLocalStore.user = User(
            id: "test_user",
            email: "test@example.com",
            name: "Test User",
            subscriptionStatus: .premium,
            streakCount: 0
        )
        
        // When
        let result = await billingService.cancelSubscription()
        
        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(billingService.subscriptionStatus, .free)
    }
    
    func testPresentPaywall() async {
        // When
        await billingService.presentPaywall()
        
        // Then
        // This should not crash
        // In a real test, you might want to verify that the paywall was presented
    }
    
    func testGetSubscriptionInfo() {
        // Given
        mockLocalStore.user = User(
            id: "test_user",
            email: "test@example.com",
            name: "Test User",
            subscriptionStatus: .premium,
            streakCount: 0
        )
        
        // When
        let info = billingService.getSubscriptionInfo()
        
        // Then
        XCTAssertNotNil(info)
        XCTAssertEqual(info?.status, .premium)
    }
    
    func testGetSubscriptionInfoForFreeUser() {
        // Given
        mockLocalStore.user = User(
            id: "test_user",
            email: "test@example.com",
            name: "Test User",
            subscriptionStatus: .free,
            streakCount: 0
        )
        
        // When
        let info = billingService.getSubscriptionInfo()
        
        // Then
        XCTAssertNotNil(info)
        XCTAssertEqual(info?.status, .free)
    }
    
    func testCheckSubscriptionStatus() async {
        // Given
        mockLocalStore.user = User(
            id: "test_user",
            email: "test@example.com",
            name: "Test User",
            subscriptionStatus: .premium,
            streakCount: 0
        )
        
        // When
        let status = await billingService.checkSubscriptionStatus()
        
        // Then
        XCTAssertEqual(status, .premium)
    }
    
    func testGetTrialInfo() {
        // When
        let trialInfo = billingService.getTrialInfo()
        
        // Then
        XCTAssertNotNil(trialInfo)
        XCTAssertEqual(trialInfo?.isEligible, true)
        XCTAssertEqual(trialInfo?.durationDays, 7)
    }
    
    func testIsTrialActive() {
        // Given
        mockLocalStore.user = User(
            id: "test_user",
            email: "test@example.com",
            name: "Test User",
            subscriptionStatus: .free,
            streakCount: 0
        )
        
        // When
        let isActive = billingService.isTrialActive()
        
        // Then
        XCTAssertFalse(isActive) // No trial active for free users
    }
    
    func testGetFeatureAccess() {
        // Given
        mockLocalStore.user = User(
            id: "test_user",
            email: "test@example.com",
            name: "Test User",
            subscriptionStatus: .premium,
            streakCount: 0
        )
        
        // When
        let hasAccess = billingService.hasFeatureAccess(.unlimitedMessages)
        
        // Then
        XCTAssertTrue(hasAccess)
    }
    
    func testGetFeatureAccessForFreeUser() {
        // Given
        mockLocalStore.user = User(
            id: "test_user",
            email: "test@example.com",
            name: "Test User",
            subscriptionStatus: .free,
            streakCount: 0
        )
        
        // When
        let hasAccess = billingService.hasFeatureAccess(.unlimitedMessages)
        
        // Then
        XCTAssertFalse(hasAccess)
    }
}
