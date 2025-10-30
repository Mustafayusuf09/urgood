import Foundation
import RevenueCat

// SubscriptionType is defined in BillingService.swift to avoid duplication

@MainActor
class ProductionBillingService: NSObject, ObservableObject, BillingServiceProtocol, PurchasesDelegate {
    private let localStore: EnhancedLocalStore
    
    // Development mode - set to true to bypass paywall restrictions
    private let developmentMode = DevelopmentConfig.bypassPaywall
    
    // RevenueCat configuration
    private let revenueCatAPIKey = ProcessInfo.processInfo.environment["REVENUECAT_API_KEY"] ?? ProductionConfig.revenueCatAPIKey
    private let entitlementId = RevenueCatConfiguration.Entitlements.premium
    
    @Published var isInitialized = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init(localStore: EnhancedLocalStore) {
        self.localStore = localStore
        super.init()
        
        if developmentMode {
            // Set user to premium in development mode
            localStore.user.subscriptionStatus = .premium
            print("🔧 Development mode: Paywall restrictions bypassed - user set to premium")
        } else {
            if revenueCatAPIKey.isEmpty {
                print("⚠️ RevenueCat API key missing. Skipping RevenueCat configuration and granting premium access for development builds.")
                localStore.user.subscriptionStatus = .premium
                return
            }
            // Initialize RevenueCat
            configureRevenueCat()
        }
    }
    
    private func configureRevenueCat() {
        // Use RevenueCatConfiguration for proper setup
        RevenueCatConfiguration.configure(apiKey: revenueCatAPIKey)
        
        // Set up delegate for subscription status changes
        Purchases.shared.delegate = self
        
        isInitialized = true
        
        // Validate product configuration and check subscription status
        Task {
            let isValid = await RevenueCatConfiguration.validateProductConfiguration()
            if !isValid {
                print("⚠️ RevenueCat product configuration validation failed")
            }
            
            await checkSubscriptionStatus()
        }
    }
    
    func getSubscriptionStatus() -> SubscriptionStatus {
        if developmentMode {
            return .premium
        }
        
        return localStore.user.subscriptionStatus
    }
    
    func upgradeToPremium(subscriptionType: SubscriptionType = .core) async -> Bool {
        if developmentMode {
            return true
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            guard let package = await getPackage(for: subscriptionType) else {
                errorMessage = "Product not available for purchase"
                isLoading = false
                return false
            }
            
            let result = try await Purchases.shared.purchase(package: package)
            
            if result.customerInfo.entitlements[entitlementId]?.isActive == true {
                localStore.user.subscriptionStatus = .premium
                FirebaseConfig.logEvent("subscription_purchased", parameters: [
                    "subscription_type": subscriptionType.rawValue,
                    "price": subscriptionType.price
                ])
                isLoading = false
                return true
            } else {
                errorMessage = "Purchase completed but subscription not active"
                isLoading = false
                return false
            }
        } catch {
            errorMessage = RevenueCatConfiguration.getUserFriendlyErrorMessage(for: error)
            isLoading = false
            
            // Log error for analytics
            RevenueCatConfiguration.logSubscriptionEvent("purchase_failed", parameters: [
                "error": error.localizedDescription,
                "subscription_type": subscriptionType.rawValue
            ])
            
            return false
        }
    }
    
    func restorePurchases() async -> Bool {
        if developmentMode {
            return true
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            
            if customerInfo.entitlements[entitlementId]?.isActive == true {
                localStore.user.subscriptionStatus = .premium
                FirebaseConfig.logEvent("purchases_restored", parameters: [
                    "has_active_subscription": true
                ])
                isLoading = false
                return true
            } else {
                localStore.user.subscriptionStatus = .free
                FirebaseConfig.logEvent("purchases_restored", parameters: [
                    "has_active_subscription": false
                ])
                isLoading = false
                return false
            }
        } catch {
            errorMessage = RevenueCatConfiguration.getUserFriendlyErrorMessage(for: error)
            isLoading = false
            
            // Log error for analytics
            RevenueCatConfiguration.logSubscriptionEvent("restore_failed", parameters: [
                "error": error.localizedDescription
            ])
            
            return false
        }
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
    
    // MARK: - RevenueCat Methods
    
    func presentPaywall() async {
        if developmentMode {
            print("🔧 Development mode: Simulating successful purchase")
            handlePurchaseSuccess()
            return
        }
        
        // This will be handled by the PaywallView
        print("🔄 Present paywall - handled by PaywallView")
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
        
        await checkSubscriptionStatus()
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
    
    // MARK: - RevenueCat User Management
    
    func resetUser() {
        if developmentMode {
            return
        }
        
        Purchases.shared.logOut { customerInfo, error in
            if let error = error {
                print("❌ Failed to reset user: \(error)")
            } else {
                print("🔄 User reset - subscription status cleared")
            }
        }
        localStore.user.subscriptionStatus = .free
    }
    
    // MARK: - Private Methods
    
    private func checkSubscriptionStatus() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            
            if customerInfo.entitlements[entitlementId]?.isActive == true {
                localStore.user.subscriptionStatus = .premium
            } else {
                localStore.user.subscriptionStatus = .free
            }
            
            print("✅ Subscription status updated: \(localStore.user.subscriptionStatus)")
        } catch {
            print("❌ Failed to check subscription status: \(error)")
        }
    }
    
    private func getPackage(for subscriptionType: SubscriptionType) async -> Package? {
        do {
            let offerings = try await Purchases.shared.offerings()
            
            // Use current offering (default) or fallback to main_offering if specified
            var offering = offerings.current
            if offering == nil, let mainOffering = offerings.offering(identifier: RevenueCatConfiguration.Offerings.main) {
                offering = mainOffering
            }
            
            guard let currentOffering = offering else {
                print("❌ No current offering found. Please ensure 'main_offering' is set as current in RevenueCat dashboard.")
                return nil
            }
            
            // Find package matching product ID
            let package = currentOffering.availablePackages.first { package in
                package.storeProduct.productIdentifier == subscriptionType.productId
            }
            
            if package == nil {
                print("❌ Product \(subscriptionType.productId) not found in offering. Available products: \(currentOffering.availablePackages.map { $0.storeProduct.productIdentifier })")
            }
            
            return package
        } catch {
            print("❌ Failed to get package: \(error)")
            return nil
        }
    }
    
    // MARK: - PurchasesDelegate
    
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        // Update subscription status when RevenueCat detects changes
        let isActive = customerInfo.entitlements[entitlementId]?.isActive == true
        
        Task { @MainActor in
            if isActive {
                if localStore.user.subscriptionStatus != .premium {
                    localStore.user.subscriptionStatus = .premium
                    print("✅ Subscription activated via delegate")
                    FirebaseConfig.logEvent("subscription_activated", parameters: [
                        "source": "revenuecat_delegate"
                    ])
                }
            } else {
                if localStore.user.subscriptionStatus != .free {
                    localStore.user.subscriptionStatus = .free
                    print("⚠️ Subscription expired via delegate")
                    FirebaseConfig.logEvent("subscription_expired", parameters: [
                        "source": "revenuecat_delegate"
                    ])
                }
            }
            
            // Notify observers of subscription status change
            objectWillChange.send()
        }
    }
}
