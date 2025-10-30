import Foundation
import RevenueCat

/// RevenueCat configuration and product setup for UrGood
class RevenueCatConfiguration {
    
    // MARK: - Product Configuration
    
    /// Product identifiers that match App Store Connect configuration
    struct ProductIdentifiers {
        static let coreSubscription = "urgood_core_monthly"
        
        static let allProducts = [coreSubscription]
    }
    
    /// Entitlement identifiers that match RevenueCat dashboard configuration
    struct Entitlements {
        static let premium = "premium"
    }
    
    /// Offering identifiers for RevenueCat dashboard
    struct Offerings {
        static let main = "main_offering"
    }
    
    // MARK: - Configuration Methods
    
    /// Configure RevenueCat with proper settings for production
    static func configure(apiKey: String) {
        // Set log level based on build configuration
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .warn
        #endif
        
        // Configure RevenueCat
        Purchases.configure(withAPIKey: apiKey)
        
        // Set user attributes for better analytics
        setUserAttributes()
        
        print("✅ RevenueCat configured successfully")
    }
    
    /// Set user attributes for RevenueCat analytics
    private static func setUserAttributes() {
        // Set app version
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            Purchases.shared.attribution.setAttributes(["app_version": appVersion])
        }
        
        // Set platform
        Purchases.shared.attribution.setAttributes(["platform": "iOS"])
        
        // Set app install date (approximate)
        if let installDate = getAppInstallDate() {
            let formatter = ISO8601DateFormatter()
            Purchases.shared.attribution.setAttributes(["install_date": formatter.string(from: installDate)])
        }
    }
    
    /// Get approximate app install date
    private static func getAppInstallDate() -> Date? {
        if let documentsFolder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last {
            if let installDate = try? FileManager.default.attributesOfItem(atPath: documentsFolder.path)[.creationDate] as? Date {
                return installDate
            }
        }
        return nil
    }
    
    // MARK: - Product Validation
    
    /// Validate that all required products are configured
    static func validateProductConfiguration() async -> Bool {
        do {
            let offerings = try await Purchases.shared.offerings()
            
            guard let currentOffering = offerings.current else {
                print("❌ No current offering found in RevenueCat")
                return false
            }
            
            let availableProductIds = currentOffering.availablePackages.map { $0.storeProduct.productIdentifier }
            
            for productId in ProductIdentifiers.allProducts {
                if !availableProductIds.contains(productId) {
                    print("❌ Product \(productId) not found in RevenueCat offering")
                    return false
                }
            }
            
            print("✅ All products validated successfully")
            return true
            
        } catch {
            print("❌ Failed to validate product configuration: \(error)")
            return false
        }
    }
    
    // MARK: - Subscription Management
    
    /// Check if user has active premium subscription
    static func hasActivePremiumSubscription() async -> Bool {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            return customerInfo.entitlements[Entitlements.premium]?.isActive == true
        } catch {
            print("❌ Failed to check subscription status: \(error)")
            return false
        }
    }
    
    /// Get subscription expiration date
    static func getSubscriptionExpirationDate() async -> Date? {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            return customerInfo.entitlements[Entitlements.premium]?.expirationDate
        } catch {
            print("❌ Failed to get expiration date: \(error)")
            return nil
        }
    }
    
    /// Get subscription renewal status
    static func willSubscriptionRenew() async -> Bool {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            return customerInfo.entitlements[Entitlements.premium]?.willRenew == true
        } catch {
            print("❌ Failed to check renewal status: \(error)")
            return false
        }
    }
    
    // MARK: - Analytics Integration
    
    /// Log subscription event to analytics
    static func logSubscriptionEvent(_ event: String, parameters: [String: Any] = [:]) {
        var eventParameters = parameters
        eventParameters["revenuecat_user_id"] = Purchases.shared.appUserID
        
        // Log to Firebase Analytics
        FirebaseConfig.logEvent("revenuecat_\(event)", parameters: eventParameters)
        
        print("📊 RevenueCat event logged: \(event)")
    }
    
    // MARK: - Error Handling
    
    /// Convert RevenueCat error to user-friendly message
    static func getUserFriendlyErrorMessage(for error: Error) -> String {
        // Check for RevenueCat specific errors
        let errorCode = (error as NSError).code
        let domain = (error as NSError).domain
        
        if domain == "RevenueCat.ErrorCode" {
            switch errorCode {
            case 1: // purchaseCancelledError
                return "Purchase was cancelled"
            case 2: // storeProblemError
                return "There was a problem with the App Store. Please try again later."
            case 3: // purchaseNotAllowedError
                return "Purchases are not allowed on this device"
            case 4: // purchaseInvalidError
                return "This purchase is invalid"
            case 5: // productNotAvailableForPurchaseError
                return "This product is not available for purchase"
            case 6: // networkError
                return "Network error. Please check your connection and try again."
            case 7: // receiptAlreadyInUseError
                return "This purchase has already been used"
            case 8: // missingReceiptFileError
                return "Receipt not found. Please try restoring purchases."
            default:
                return "An unexpected error occurred. Please try again."
            }
        }
        
        return error.localizedDescription
    }
}

// MARK: - RevenueCat Extensions

extension SubscriptionType {
    /// Get the corresponding RevenueCat package for this subscription type
    func getRevenueCatPackage(from offerings: Offerings) -> Package? {
        return offerings.current?.availablePackages.first { package in
            package.storeProduct.productIdentifier == self.productId
        }
    }
}

extension CustomerInfo {
    /// Check if user has any active subscription
    var hasActiveSubscription: Bool {
        return entitlements.active.count > 0
    }
    
    /// Get the active subscription product identifier
    var activeSubscriptionProductId: String? {
        return entitlements.active.first?.value.productIdentifier
    }
    
    /// Get subscription type from active entitlements
    var subscriptionType: SubscriptionType? {
        guard let productId = activeSubscriptionProductId else { return nil }
        
        switch productId {
        case RevenueCatConfiguration.ProductIdentifiers.coreSubscription:
            return .core
        default:
            return nil
        }
    }
}
