import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseCore
import AuthenticationServices
import CryptoKit
import GoogleSignIn
import OSLog

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
    private let logger = Logger(subsystem: "com.homi.app", category: "AuthService")

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
            logger.info("Starting sign up for email: \(email)")
            let result = try await auth.createUser(withEmail: email, password: password)
            logger.info("Firebase Auth user created with ID: \(result.user.uid)")

            // Create user profile
            let newUser = User(
                id: result.user.uid,
                email: email,
                displayName: displayName,
                authProviders: ["password"]
            )

            try await createUserProfile(user: newUser)

            // Send verification email
            do {
                try await result.user.sendEmailVerification()
                logger.info("Verification email sent to: \(email)")
            } catch {
                // Log but don't fail signup if email verification fails
                logger.error("Failed to send verification email: \(error.localizedDescription)")
                // User is still created, they can request verification later
            }

            isLoading = false
        } catch {
            logger.error("Sign up error: \(error.localizedDescription)")
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil

        do {
            logger.info("Signing in with email: \(email)")
            let result = try await auth.signIn(withEmail: email, password: password)
            logger.info("Auth successful for user ID: \(result.user.uid)")

            // Check if user profile exists, create if not
            let userDoc = try await db.collection(Constants.Collections.users)
                .document(result.user.uid)
                .getDocument()

            if !userDoc.exists {
                logger.info("User profile doesn't exist, creating one")
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
            logger.error("Sign in error: \(error.localizedDescription)")
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
            logger.error("Phone auth error: \(error.localizedDescription)")
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
            let userDoc = try await db.collection(Constants.Collections.users)
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
            let userDoc = try await db.collection(Constants.Collections.users)
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
                    logger.error("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                    // Return a default nonce instead of crashing
                    return 0
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
        // Get the client ID from GoogleService-Info.plist
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            logger.error("Google Sign-In: Missing client ID")
            throw AuthError.configurationError("Missing Google client ID")
        }
        
        // Get the root view controller
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = await windowScene.windows.first?.rootViewController else {
            logger.error("Google Sign-In: No root view controller")
            throw AuthError.configurationError("Unable to get root view controller")
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Create Google Sign-In configuration
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config
            
            // Perform sign-in on main thread
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.missingToken
            }
            
            let accessToken = result.user.accessToken.tokenString
            
            // Create Firebase credential
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            
            // Sign in to Firebase
            let authResult = try await auth.signIn(with: credential)
            logger.info("Google Sign-In successful for user: \(authResult.user.uid)")
            
            // Check if user profile exists
            let userDoc = try await db.collection(Constants.Collections.users)
                .document(authResult.user.uid)
                .getDocument()
            
            if !userDoc.exists {
                // Create new user profile
                let displayName = result.user.profile?.name ?? authResult.user.displayName ?? ""
                let email = result.user.profile?.email ?? authResult.user.email
                
                let newUser = User(
                    id: authResult.user.uid,
                    email: email,
                    displayName: displayName,
                    profilePhotoUrl: result.user.profile?.imageURL(withDimension: 200)?.absoluteString,
                    authProviders: ["google.com"]
                )
                
                try await createUserProfile(user: newUser)
            } else {
                await fetchUserProfile(userId: authResult.user.uid)
            }
            
            isLoading = false
        } catch let error as GIDSignInError where error.code == .canceled {
            isLoading = false
            logger.info("Google Sign-In cancelled by user")
            // Don't throw for user cancellation
            return
        } catch {
            isLoading = false
            logger.error("Google Sign-In error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - User Profile Management

    func createUserProfile(user: User) async throws {
        do {
            logger.info("Creating user profile for ID: \(user.id)")
            logger.debug("User data: \(user.toFirestore.description)")

            try await db.collection(Constants.Collections.users)
                .document(user.id)
                .setData(user.toFirestore)

            logger.info("User profile created successfully")
            self.userProfile = user
        } catch {
            logger.error("Error creating user profile: \(error.localizedDescription)")
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
            try await db.collection(Constants.Collections.users)
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
            let document = try await db.collection(Constants.Collections.users)
                .document(userId)
                .getDocument()

            if let user = User(document: document) {
                self.userProfile = user
            }
        } catch {
            logger.error("Error fetching user profile: \(error.localizedDescription)")
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
    case configurationError(String)

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
            return "Google Sign-In coming soon"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        }
    }
}