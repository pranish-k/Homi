import SwiftUI

// MARK: - Theme Definition

struct AppTheme: Identifiable, Codable {
    let id: String
    let name: String
    let primaryColorHex: String
    let primaryDarkColorHex: String

    var primaryColor: Color {
        Color(hex: primaryColorHex)
    }

    var primaryDarkColor: Color {
        Color(hex: primaryDarkColorHex)
    }
}

// MARK: - Available Themes

extension AppTheme {
    static let oceanBlue = AppTheme(
        id: "oceanBlue",
        name: "Ocean Blue",
        primaryColorHex: "007AFF",
        primaryDarkColorHex: "0051D5"
    )

    static let royalPurple = AppTheme(
        id: "royalPurple",
        name: "Royal Purple",
        primaryColorHex: "AF52DE",
        primaryDarkColorHex: "8E44AD"
    )

    static let freshMint = AppTheme(
        id: "freshMint",
        name: "Fresh Mint",
        primaryColorHex: "00C7BE",
        primaryDarkColorHex: "00A19A"
    )

    static let sunsetOrange = AppTheme(
        id: "sunsetOrange",
        name: "Sunset Orange",
        primaryColorHex: "FF6B35",
        primaryDarkColorHex: "E55A2B"
    )

    static let cherryPink = AppTheme(
        id: "cherryPink",
        name: "Cherry Pink",
        primaryColorHex: "FF2D55",
        primaryDarkColorHex: "D91E46"
    )

    static let allThemes: [AppTheme] = [
        .oceanBlue,
        .royalPurple,
        .freshMint,
        .sunsetOrange,
        .cherryPink
    ]

    static func theme(withId id: String) -> AppTheme {
        allThemes.first { $0.id == id } ?? .oceanBlue
    }
}
