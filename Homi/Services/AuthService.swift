import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices
import CryptoKit

@MainActor
class AuthService: NSObject, ObservableObject {
    static let shared = AuthService()

    @Published var user: FirebaseAuth.User?
    @Published var userProfile: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var authStateHandler: AuthStateDidChangeListenerHandle?
    private let auth = Auth.auth()
    private let db = Firestore.firestore()

    // For Sign in with Apple
    private var currentNonce: String?

    override init() {
        super.init()
        setupAuthStateListener()
    }

    private func setupAuthStateListener() {
        authStateHandler = auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
                self?.isAuthenticated = user != nil

                if let user = user {
                    await self?.fetchUserProfile(userId: user.uid)
                } else {
                    self?.userProfile = nil
                }
            }
        }
    }

    // MARK: - Email Authentication

    func signUp(email: String, password: String, displayName: String) async throws {
        isLoading = true
        errorMessage = nil

        do {
            print("Starting sign up for email: \(email)")
            let result = try await auth.createUser(withEmail: email, password: password)
            print("Firebase Auth user created with ID: \(result.user.uid)")

            // Create user profile
            let newUser = User(
                id: result.user.uid,
                email: email,
                displayName: displayName,
                authProviders: ["password"]
            )

            try await createUserProfile(user: newUser)

            // Send verification email
            try await result.user.sendEmailVerification()
            print("Verification email sent")

            isLoading = false
        } catch {
            print("Sign up error: \(error)")
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil

        do {
            print("Signing in with email: \(email)")
            let result = try await auth.signIn(withEmail: email, password: password)
            print("Auth successful for user ID: \(result.user.uid)")

            // Check if user profile exists, create if not
            let userDoc = try await db.collection(Constants.Firebase.usersCollection)
                .document(result.user.uid)
                .getDocument()

            if !userDoc.exists {
                print("User profile doesn't exist, creating one")
                let newUser = User(
                    id: result.user.uid,
                    email: result.user.email ?? email,
                    displayName: result.user.displayName ?? email.components(separatedBy: "@").first ?? "User",
                    authProviders: ["password"]
                )
                try await createUserProfile(user: newUser)
            } else {
                await fetchUserProfile(userId: result.user.uid)
            }

            isLoading = false
        } catch {
            print("Sign in error: \(error)")
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - Phone Authentication

    func sendVerificationCode(phoneNumber: String) async throws -> String {
        isLoading = true
        errorMessage = nil

        do {
            // Note: For simulator testing, add test phone numbers in Firebase Console
            // Example: +15551234567 with verification code: 123456
            let verificationID = try await PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil)
            isLoading = false
            return verificationID
        } catch {
            isLoading = false
            errorMessage = "Phone authentication error: \(error.localizedDescription)"
            print("Phone auth error: \(error)")
            throw error
        }
    }

    func verifyPhoneNumber(verificationID: String, verificationCode: String) async throws {
        isLoading = true
        errorMessage = nil

        do {
            let credential = PhoneAuthProvider.provider().credential(
                withVerificationID: verificationID,
                verificationCode: verificationCode
            )

            let result = try await auth.signIn(with: credential)

            // Check if user profile exists
            let userDoc = try await db.collection(Constants.Firebase.usersCollection)
                .document(result.user.uid)
                .getDocument()

            if !userDoc.exists {
                // Create new user profile
                let newUser = User(
                    id: result.user.uid,
                    phoneNumber: result.user.phoneNumber,
                    displayName: "",  // Will be set in profile setup
                    authProviders: ["phone"]
                )

                try await createUserProfile(user: newUser)
            } else {
                await fetchUserProfile(userId: result.user.uid)
            }

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - Apple Sign In

    func handleSignInWithApple(authorization: ASAuthorization) async throws {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthError.invalidCredential
        }

        guard let nonce = currentNonce else {
            throw AuthError.missingNonce
        }

        guard let appleIDToken = appleIDCredential.identityToken else {
            throw AuthError.missingToken
        }

        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthError.invalidToken
        }

        // Create Firebase credential
        let credential = OAuthProvider.appleCredential(withIDToken: idTokenString,
                                                       rawNonce: nonce,
                                                       fullName: appleIDCredential.fullName)

        isLoading = true
        errorMessage = nil

        do {
            let result = try await auth.signIn(with: credential)

            // Check if user profile exists
            let userDoc = try await db.collection(Constants.Firebase.usersCollection)
                .document(result.user.uid)
                .getDocument()

            if !userDoc.exists {
                // Get the display name from Apple
                let fullName = [appleIDCredential.fullName?.givenName, appleIDCredential.fullName?.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")

                let displayName = fullName.isEmpty ? (result.user.displayName ?? "") : fullName

                // Create new user profile
                let newUser = User(
                    id: result.user.uid,
                    email: result.user.email,
                    displayName: displayName,
                    authProviders: ["apple.com"]
                )

                try await createUserProfile(user: newUser)
            } else {
                await fetchUserProfile(userId: result.user.uid)
            }

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func generateNonce() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return nonce
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()

        return hashString
    }

    // MARK: - Google Sign In

    func signInWithGoogle() async throws {
        // This would require Google Sign-In SDK setup
        // For now, we'll provide a placeholder
        throw AuthError.notImplemented
    }

    // MARK: - User Profile Management

    func createUserProfile(user: User) async throws {
        do {
            print("Creating user profile for ID: \(user.id)")
            print("User data: \(user.toFirestore)")

            try await db.collection(Constants.Firebase.usersCollection)
                .document(user.id)
                .setData(user.toFirestore)

            print("User profile created successfully")
            self.userProfile = user
        } catch {
            print("Error creating user profile: \(error)")
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func updateUserProfile(displayName: String? = nil, profilePhotoUrl: String? = nil) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw AuthError.noUser
        }

        var updateData: [String: Any] = [:]

        if let displayName = displayName {
            updateData["displayName"] = displayName
        }

        if let profilePhotoUrl = profilePhotoUrl {
            updateData["profilePhotoUrl"] = profilePhotoUrl
        }

        updateData["lastSeen"] = Timestamp(date: Date())

        do {
            try await db.collection(Constants.Firebase.usersCollection)
                .document(userId)
                .updateData(updateData)

            await fetchUserProfile(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    private func fetchUserProfile(userId: String) async {
        do {
            let document = try await db.collection(Constants.Firebase.usersCollection)
                .document(userId)
                .getDocument()

            if let user = User(document: document) {
                self.userProfile = user
            }
        } catch {
            print("Error fetching user profile: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sign Out

    func signOut() throws {
        do {
            try auth.signOut()
            userProfile = nil
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - Password Reset

    func sendPasswordReset(email: String) async throws {
        do {
            try await auth.sendPasswordReset(withEmail: email)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    deinit {
        if let handler = authStateHandler {
            auth.removeStateDidChangeListener(handler)
        }
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case invalidCredential
    case missingNonce
    case missingToken
    case invalidToken
    case noUser
    case notImplemented

    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Invalid credentials"
        case .missingNonce:
            return "Missing nonce"
        case .missingToken:
            return "Missing authentication token"
        case .invalidToken:
            return "Invalid authentication token"
        case .noUser:
            return "No user logged in"
        case .notImplemented:
            return "This feature is not yet implemented"
        }
    }
}