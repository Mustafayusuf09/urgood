import Foundation

@MainActor
protocol AuthServiceProtocol: ObservableObject {
    var isAuthenticated: Bool { get }
    var currentUser: Any? { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    
    func signInWithApple() async throws
    func signUp(email: String, password: String, name: String) async throws
    func signIn(email: String, password: String) async throws
    func signOut() async throws
    func resetPassword(email: String) async throws
    func resendEmailVerification() async throws
}
