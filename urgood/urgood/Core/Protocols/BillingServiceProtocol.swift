import Foundation

@MainActor
protocol BillingServiceProtocol: ObservableObject {
    var isInitialized: Bool { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    
    func getSubscriptionStatus() -> SubscriptionStatus
    func upgradeToPremium(subscriptionType: SubscriptionType) async -> Bool
    func restorePurchases() async -> Bool
    func getPremiumPrice(for subscriptionType: SubscriptionType) -> String
    func getAllSubscriptionTypes() -> [SubscriptionType]
    func getPremiumFeatures() -> [String]
    func isFeaturePremium(_ feature: String) -> Bool
    func presentPaywall() async
    func isSubscribed() -> Bool
    func refreshSubscriptionStatus() async
    func handlePurchaseSuccess()
    func handleSubscriptionExpired()
    func resetUser()
}
