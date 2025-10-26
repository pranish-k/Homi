import SwiftUI

struct Constants {
    // MARK: - Colors (Theme-aware)
    struct Colors {
        // Dynamic colors that change based on selected theme
        static var primary: Color {
            ThemeManager.shared.currentTheme.primaryColor
        }

        static var primaryLight: Color {
            ThemeManager.shared.currentTheme.primaryColor.opacity(0.1)
        }

        static var primaryDark: Color {
            ThemeManager.shared.currentTheme.primaryDarkColor
        }

        // Semantic colors (consistent across themes)
        static let success = Color(hex: "34C759")
        static let warning = Color(hex: "FF9500")
        static let danger = Color(hex: "FF3B30")
        static let error = Color(hex: "FF3B30") // Same as danger

        // Background colors
        static let background = Color(uiColor: .systemBackground)
        static let secondaryBackground = Color(uiColor: .secondarySystemBackground)
        static let tertiaryBackground = Color(uiColor: .tertiarySystemBackground)
        static let groupedBackground = Color(uiColor: .systemGroupedBackground)

        // Text colors
        static let textPrimary = Color.primary
        static let textSecondary = Color(hex: "8E8E93")
        static let textTertiary = Color(hex: "C7C7CC")

        // Card colors
        static let cardBackground = Color(uiColor: .secondarySystemBackground)
        static let cardBorder = Color(hex: "E5E5EA")
    }

    // MARK: - Typography (Semantic Styles)
    struct Typography {
        // Display styles
        static let display = Font.system(size: 34, weight: .bold)
        static let displayLarge = Font.system(size: 48, weight: .bold)

        // Title styles
        static let title1 = Font.system(size: 28, weight: .bold)
        static let title2 = Font.system(size: 22, weight: .semibold)
        static let title3 = Font.system(size: 20, weight: .semibold)

        // Headline styles
        static let headline = Font.system(size: 17, weight: .semibold)
        static let headlineMedium = Font.system(size: 17, weight: .medium)

        // Body styles
        static let body = Font.system(size: 17, weight: .regular)
        static let bodyMedium = Font.system(size: 17, weight: .medium)
        static let bodySemibold = Font.system(size: 17, weight: .semibold)

        // Supporting styles
        static let callout = Font.system(size: 16, weight: .regular)
        static let subheadline = Font.system(size: 15, weight: .regular)
        static let footnote = Font.system(size: 13, weight: .regular)
        static let caption1 = Font.system(size: 12, weight: .regular)
        static let caption2 = Font.system(size: 11, weight: .regular)
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

        // Padding presets
        static let cardPadding: CGFloat = 16
        static let screenPadding: CGFloat = 16
        static let sectionSpacing: CGFloat = 24
    }

    // MARK: - Corner Radius
    struct CornerRadius {
        static let xSmall: CGFloat = 6
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 24
        static let circular: CGFloat = 999

        // Component-specific
        static let button: CGFloat = 12
        static let card: CGFloat = 16
        static let badge: CGFloat = 8
    }

    // MARK: - Shadows
    struct Shadow {
        // Subtle shadow for cards
        static let subtle = ShadowStyle(
            color: Color.black.opacity(0.04),
            radius: 8,
            x: 0,
            y: 2
        )

        // Medium shadow for elevated elements
        static let medium = ShadowStyle(
            color: Color.black.opacity(0.08),
            radius: 12,
            x: 0,
            y: 4
        )

        // Elevated shadow for modals
        static let elevated = ShadowStyle(
            color: Color.black.opacity(0.12),
            radius: 20,
            x: 0,
            y: 8
        )
    }

    // Shadow style structure
    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    // MARK: - Animation
    struct Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
        static let spring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)

        // Button press animation
        static let buttonPress = SwiftUI.Animation.easeInOut(duration: 0.15)
    }

    // MARK: - Button Styles
    struct ButtonStyle {
        static let height: CGFloat = 50
        static let minTouchTarget: CGFloat = 44
        static let iconSize: CGFloat = 20
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
        static let conversations = "conversations"
        static let directMessages = "directMessages"
        static let nudges = "nudges"
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
        static let inviteCodeLength = 8  // Increased from 6 to 8 for better security
        static let phoneNumberLength = 10
        static let otpCodeLength = 6
        static let maxExpenseAmount = 1000000.0  // Max $1M
        static let maxChorePoints = 1000
        static let maxHouseNameLength = 100
        static let maxDescriptionLength = 500
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