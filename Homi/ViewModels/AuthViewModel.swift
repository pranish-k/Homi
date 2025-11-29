import SwiftUI
import Combine
import AuthenticationServices
import FirebaseAuth

@MainActor
class AuthViewModel: ObservableObject {
    @Published var currentAuthStep: AuthStep = .welcome
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    // Phone auth properties
    @Published var phoneNumber = ""
    @Published var countryCode = "+1"
    @Published var verificationCode = ""
    @Published var verificationID: String?

    // Email auth properties
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var fullName = ""

    // Profile setup properties
    @Published var displayName = ""
    @Published var profileImage: UIImage?

    private let authService = AuthService.shared
    private let firestoreService = FirestoreService.shared

    enum AuthStep {
        case welcome
        case authOptions
        case phoneEntry
        case phoneVerification
        case emailSignUp
        case emailSignIn
        case profileSetup
        case complete
    }

    // MARK: - Email Authentication

    func signUpWithEmail() async {
        guard validateEmailSignUp() else { return }

        isLoading = true
        errorMessage = nil

        do {
            try await authService.signUp(
                email: email,
                password: password,
                displayName: fullName
            )

            currentAuthStep = .complete
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }

    func signInWithEmail() async {
        guard validateEmailSignIn() else { return }

        isLoading = true
        errorMessage = nil

        do {
            try await authService.signIn(email: email, password: password)
            currentAuthStep = .complete
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }

    // MARK: - Phone Authentication

    func sendPhoneVerification() async {
        guard validatePhoneNumber() else { return }

        isLoading = true
        errorMessage = nil

        do {
            let fullPhoneNumber = "\(countryCode)\(phoneNumber)"
            verificationID = try await authService.sendVerificationCode(phoneNumber: fullPhoneNumber)
            currentAuthStep = .phoneVerification
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }

    func verifyPhoneCode() async {
        guard let verificationID = verificationID,
              !verificationCode.isEmpty else {
            errorMessage = "Please enter the verification code"
            showError = true
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await authService.verifyPhoneNumber(
                verificationID: verificationID,
                verificationCode: verificationCode
            )

            // Check if profile needs setup
            if authService.userProfile?.displayName.isEmpty ?? true {
                currentAuthStep = .profileSetup
            } else {
                currentAuthStep = .complete
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }

    // MARK: - Apple Sign In

    func handleSignInWithAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = authService.generateNonce()
        request.requestedScopes = [.fullName, .email]
        request.nonce = authService.sha256(nonce)
    }

    func handleSignInWithAppleCompletion(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            isLoading = true
            errorMessage = nil

            do {
                try await authService.handleSignInWithApple(authorization: authorization)

                // Check if profile needs setup
                if authService.userProfile?.displayName.isEmpty ?? true {
                    currentAuthStep = .profileSetup
                } else {
                    currentAuthStep = .complete
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }

            isLoading = false

        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    // MARK: - Google Sign In

    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil

        do {
            try await authService.signInWithGoogle()
 
            // Check if profile needs setup
            if authService.userProfile?.displayName.isEmpty ?? true {
                currentAuthStep = .profileSetup
            } else {
                currentAuthStep = .complete
            }
        } catch {
            if case AuthError.notImplemented = error {
                errorMessage = "Google Sign-In will be available soon"
            } else {
                errorMessage = error.localizedDescription
            }
            showError = true
        }

        isLoading = false
    }

    // MARK: - Profile Setup

    func completeProfileSetup() async {
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter your name"
            showError = true
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // TODO: Handle profile image upload if needed
            try await authService.updateUserProfile(displayName: displayName)
            currentAuthStep = .complete
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }

    // MARK: - Password Reset

    func sendPasswordReset() async {
        guard !email.isEmpty else {
            errorMessage = "Please enter your email address"
            showError = true
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await authService.sendPasswordReset(email: email)
            errorMessage = "Password reset email sent. Please check your inbox."
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }

    // MARK: - Validation

    private func validateEmailSignUp() -> Bool {
        if fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Please enter your name"
            showError = true
            return false
        }

        if !isValidEmail(email) {
            errorMessage = Constants.ErrorMessages.invalidEmail
            showError = true
            return false
        }

        if password.count < Constants.Validation.minPasswordLength {
            errorMessage = Constants.ErrorMessages.weakPassword
            showError = true
            return false
        }

        if password != confirmPassword {
            errorMessage = Constants.ErrorMessages.passwordMismatch
            showError = true
            return false
        }

        return true
    }

    private func validateEmailSignIn() -> Bool {
        if !isValidEmail(email) {
            errorMessage = Constants.ErrorMessages.invalidEmail
            showError = true
            return false
        }

        if password.isEmpty {
            errorMessage = "Please enter your password"
            showError = true
            return false
        }

        return true
    }

    private func validatePhoneNumber() -> Bool {
        let cleanedNumber = phoneNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)

        if cleanedNumber.count != Constants.Validation.phoneNumberLength {
            errorMessage = Constants.ErrorMessages.invalidPhoneNumber
            showError = true
            return false
        }

        phoneNumber = cleanedNumber
        return true
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }

    // MARK: - Navigation

    func navigateToAuthOptions() {
        currentAuthStep = .authOptions
    }

    func navigateToPhoneAuth() {
        currentAuthStep = .phoneEntry
    }

    func navigateToEmailSignUp() {
        currentAuthStep = .emailSignUp
    }

    func navigateToEmailSignIn() {
        currentAuthStep = .emailSignIn
    }

    func navigateBack() {
        switch currentAuthStep {
        case .welcome:
            break
        case .authOptions:
            currentAuthStep = .welcome
        case .phoneEntry, .emailSignUp, .emailSignIn:
            currentAuthStep = .authOptions
        case .phoneVerification:
            currentAuthStep = .phoneEntry
        case .profileSetup:
            // Can't go back from profile setup
            break
        case .complete:
            break
        }

        // Clear any error messages when navigating
        errorMessage = nil
        showError = false
    }

    func reset() {
        currentAuthStep = .welcome
        phoneNumber = ""
        verificationCode = ""
        verificationID = nil
        email = ""
        password = ""
        confirmPassword = ""
        fullName = ""
        displayName = ""
        profileImage = nil
        errorMessage = nil
        showError = false
    }
}