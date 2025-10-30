import Foundation

enum SubscriptionType: String, CaseIterable {
    case core = "core"
    
    var productId: String {
        switch self {
        case .core: return "urgood_core_monthly"
        }
    }
    
    var price: Double {
        switch self {
        case .core: return 24.99
        }
    }
    
    var displayPrice: String {
        switch self {
        case .core: return "$24.99/month"
        }
    }
    
    var displayName: String {
        switch self {
        case .core: return "Core"
        }
    }
    
    var highlight: String {
        switch self {
        case .core: return "Daily voice sessions + unlimited text"
        }
    }
    
    var monthlyEquivalent: Double {
        switch self {
        case .core: return 24.99
        }
    }
    
    var savings: String {
        switch self {
        case .core: return ""
        }
    }
}

class BillingService: ObservableObject, BillingServiceProtocol {
    private let localStore: EnhancedLocalStore
    
    // Development mode - set to true to bypass paywall restrictions
    private let developmentMode = DevelopmentConfig.bypassPaywall
    
    @Published var isInitialized = true
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init(localStore: EnhancedLocalStore) {
        self.localStore = localStore
        
        if developmentMode {
            // Set user to premium in development mode
            localStore.user.subscriptionStatus = .premium
            print("🔧 Development mode: Paywall restrictions bypassed - user set to premium")
        }
    }
    
    func getSubscriptionStatus() -> SubscriptionStatus {
        if developmentMode {
            return .premium
        }
        
        // Return local subscription status (standalone mode)
        return localStore.user.subscriptionStatus
    }
    
    func upgradeToPremium(subscriptionType: SubscriptionType = .core) async -> Bool {
        if developmentMode {
            return true
        }
        
        // Simulate successful purchase in standalone mode
        print("💳 Simulating premium upgrade...")
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        localStore.user.subscriptionStatus = .premium
        FirebaseConfig.logEvent("purchase_completed", parameters: [
            "product_id": subscriptionType.productId,
            "revenue": subscriptionType.price,
            "currency": "USD",
            "subscription_type": subscriptionType.rawValue
        ])
        
        return true
    }
    
    func restorePurchases() async -> Bool {
        if developmentMode {
            return true
        }
        
        print("🔄 Simulating restore purchases...")
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        // In standalone mode, just return current status
        FirebaseConfig.logEvent("purchases_restored", parameters: [
            "has_active_subscription": localStore.user.subscriptionStatus == .premium
        ])
        
        return localStore.user.subscriptionStatus == .premium
    }
    
    func getPremiumPrice(for subscriptionType: SubscriptionType = .core) -> String {
        return subscriptionType.displayPrice
    }
    
    func getAllSubscriptionTypes() -> [SubscriptionType] {
        return SubscriptionType.allCases
    }
    
    func getPremiumFeatures() -> [String] {
        return [
            "Daily voice sessions",
            "Unlimited text conversations",
            "Priority support"
        ]
    }
    
    func isFeaturePremium(_ feature: String) -> Bool {
        if developmentMode {
            return false // All features are free in development mode
        }
        
        let premiumFeatures = [
            "unlimited chat",
            "voice chat",
            "advanced insights",
            "detailed insights",
            "premium support"
        ]
        
        return premiumFeatures.contains { feature.lowercased().contains($0) }
    }
    
    // MARK: - RevenueCat Methods (Placeholder)
    
    func presentPaywall() async {
        // RevenueCat integration will be added when Apple Developer membership is available
        print("🔄 Present paywall - RevenueCat integration pending Apple Developer membership")
        
        #if DEBUG
        print("🔧 Development mode: Simulating successful purchase")
        handlePurchaseSuccess()
        #else
        print("❌ Production mode: RevenueCat integration required for real purchases")
        #endif
    }
    
    func isSubscribed() -> Bool {
        if developmentMode {
            return true
        }
        
        return localStore.user.subscriptionStatus == .premium
    }
    
    func refreshSubscriptionStatus() async {
        if developmentMode {
            return
        }
        
        // In standalone mode, just refresh local status
        print("🔄 Refreshing subscription status...")
        FirebaseConfig.logEvent("subscription_status_refreshed", parameters: [
            "current_status": localStore.user.subscriptionStatus == .premium ? "premium" : "free"
        ])
    }
    
    func handlePurchaseSuccess() {
        // Update local subscription status
        localStore.user.subscriptionStatus = .premium
        print("✅ Purchase success handled - user upgraded to premium")
        
        // Notify observers of subscription status change
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    func handleSubscriptionExpired() {
        // Update local subscription status
        localStore.user.subscriptionStatus = .free
        print("⚠️ Subscription expired - user downgraded to free")
        
        // Notify observers of subscription status change
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    // MARK: - RevenueCat User Management (Placeholder)
    
    func resetUser() {
        if developmentMode {
            return
        }
        
        // In standalone mode, just reset local subscription
        localStore.user.subscriptionStatus = .free
        print("🔄 User reset - subscription cleared")
    }
}
