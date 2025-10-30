import Foundation
import SwiftUI

@MainActor
class PaywallViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var showSuccess = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    let billingService: BillingService
    
    init(billingService: BillingService) {
        self.billingService = billingService
    }
    
    var premiumPrice: String {
        billingService.getPremiumPrice()
    }
    
    var allSubscriptionTypes: [SubscriptionType] {
        billingService.getAllSubscriptionTypes()
    }
    
    func getPremiumPrice(for subscriptionType: SubscriptionType) -> String {
        billingService.getPremiumPrice(for: subscriptionType)
    }
    
    var premiumFeatures: [String] {
        billingService.getPremiumFeatures()
    }
    
    func upgradeToPremium(subscriptionType: SubscriptionType = .core) async {
        isLoading = true
        
        // Simulate purchase process
        let success = await billingService.upgradeToPremium(subscriptionType: subscriptionType)
        
        if success {
            showSuccess = true
        } else {
            errorMessage = "Purchase failed. Please try again."
            showError = true
        }
        
        isLoading = false
    }
    
    func restorePurchases() async {
        isLoading = true
        
        let success = await billingService.restorePurchases()
        
        if success {
            showSuccess = true
        } else {
            errorMessage = "No purchases found to restore."
            showError = true
        }
        
        isLoading = false
    }
    
    func dismissSuccess() {
        showSuccess = false
    }
    
    func dismissError() {
        showError = false
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var isPresented = true
        
        var body: some View {
            PaywallView(
                isPresented: $isPresented,
                onUpgrade: { subscriptionType in },
                onDismiss: {},
                billingService: BillingService(localStore: EnhancedLocalStore.shared)
            )
        }
    }
    
    return PreviewWrapper()
}
