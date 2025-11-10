import Foundation
import Combine

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isLoggedIn = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let coreDataManager = CoreDataManager.shared
    private let apiService = APIService.shared
    
    init() {
        checkLoginStatus()
    }
    
    private func checkLoginStatus() {
        if let user = coreDataManager.getCurrentUser(), user.isLoggedIn {
            self.currentUser = user
            self.isLoggedIn = true
        }
    }
    
    @MainActor
    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let (token, apiUser) = try await apiService.login(email: email, password: password)
            
            // Save user to Core Data
            coreDataManager.createOrUpdateUser(
                id: Int32(apiUser.id),
                email: apiUser.email,
                token: token
            )
            
            // Update UI state
            self.currentUser = coreDataManager.getCurrentUser()
            self.isLoggedIn = true
            
            // Trigger comprehensive login sync (notes + deleted notes)
            await SyncManager.shared.performLoginSync()
            
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    @MainActor
    func register(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let (token, apiUser) = try await apiService.register(email: email, password: password)
            
            // Save user to Core Data
            coreDataManager.createOrUpdateUser(
                id: Int32(apiUser.id),
                email: apiUser.email,
                token: token
            )
            
            // Update UI state
            self.currentUser = coreDataManager.getCurrentUser()
            self.isLoggedIn = true
            
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func logout() {
        coreDataManager.logoutUser()
        self.currentUser = nil
        self.isLoggedIn = false
        self.errorMessage = nil
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    func getToken() -> String? {
        return currentUser?.token
    }
    
    // MARK: - Password Reset Functions
    
    func requestPasswordReset(email: String) async -> (success: Bool, message: String) {
        do {
            return try await apiService.requestPasswordReset(email: email)
        } catch {
            return (success: false, message: error.localizedDescription)
        }
    }
    
    func verifyOTP(email: String, otp: String) async -> (success: Bool, message: String, resetToken: String?) {
        do {
            return try await apiService.verifyOTP(email: email, otp: otp)
        } catch {
            return (success: false, message: error.localizedDescription, resetToken: nil)
        }
    }
    
    func resetPassword(token: String, newPassword: String) async -> (success: Bool, message: String) {
        do {
            return try await apiService.resetPassword(token: token, newPassword: newPassword)
        } catch {
            return (success: false, message: error.localizedDescription)
        }
    }
}