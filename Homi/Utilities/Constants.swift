import SwiftUI

struct Constants {
    // MARK: - Colors
    struct Colors {
        static let primary = Color(hex: "007AFF")
        static let success = Color(hex: "34C759")
        static let warning = Color(hex: "FF9500")
        static let danger = Color(hex: "FF3B30")
        static let background = Color(hex: "F2F2F7")
        static let textPrimary = Color.primary
        static let textSecondary = Color(hex: "8E8E93")
    }

    // MARK: - Typography
    struct Typography {
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title = Font.title.weight(.semibold)
        static let title2 = Font.title2.weight(.semibold)
        static let title3 = Font.title3.weight(.medium)
        static let headline = Font.headline
        static let body = Font.body
        static let callout = Font.callout
        static let subheadline = Font.subheadline
        static let footnote = Font.footnote
        static let caption = Font.caption
    }

    // MARK: - Spacing
    struct Spacing {
        static let xxSmall: CGFloat = 4
        static let xSmall: CGFloat = 8
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xLarge: CGFloat = 32
        static let xxLarge: CGFloat = 48
    }

    // MARK: - Corner Radius
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 24
        static let circular: CGFloat = 999
    }

    // MARK: - Animation
    struct Animation {
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
        static let spring = SwiftUI.Animation.spring()
    }

    // MARK: - Firebase Collections
    struct Collections {
        static let users = "users"
        static let houses = "houses"
        static let invites = "invites"
        static let members = "members"
        static let messages = "messages"
        static let expenses = "expenses"
        static let payments = "payments"
        static let chores = "chores"
        static let balances = "balances"
    }

    // MARK: - User Defaults Keys
    struct UserDefaults {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let currentUserId = "currentUserId"
        static let currentHouseId = "currentHouseId"
        static let appTheme = "appTheme"
    }

    // MARK: - Validation
    struct Validation {
        static let minPasswordLength = 8
        static let maxNameLength = 50
        static let inviteCodeLength = 6
        static let phoneNumberLength = 10
        static let otpCodeLength = 6
    }

    // MARK: - Error Messages
    struct ErrorMessages {
        static let genericError = "Something went wrong. Please try again."
        static let networkError = "Please check your internet connection."
        static let invalidEmail = "Please enter a valid email address."
        static let weakPassword = "Password must be at least 8 characters."
        static let passwordMismatch = "Passwords don't match."
        static let invalidPhoneNumber = "Please enter a valid phone number."
        static let invalidInviteCode = "Invalid invite code."
        static let userNotFound = "User not found."
        static let emailAlreadyInUse = "This email is already registered."
        static let invalidCredentials = "Invalid email or password."
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}