import SwiftUI

enum AppRoute: Hashable, Identifiable {
    case paywall
    case crisisHelp
    case onboarding
    case firstRun
    
    var id: String {
        switch self {
        case .paywall:
            return "paywall"
        case .crisisHelp:
            return "crisisHelp"
        case .onboarding:
            return "onboarding"
        case .firstRun:
            return "firstRun"
        }
    }
}

class AppRouter: ObservableObject {
    @Published var presentedRoute: AppRoute?
    @Published var presentedSheet: AppRoute?
    
    func present(_ route: AppRoute, as sheet: Bool = false) {
        if sheet {
            presentedSheet = route
        } else {
            presentedRoute = route
        }
    }
    
    func dismiss() {
        presentedRoute = nil
        presentedSheet = nil
    }
}
