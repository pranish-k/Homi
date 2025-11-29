import SwiftUI
import Combine

// MARK: - Theme Mode

enum ThemeMode: String, Codable, CaseIterable {
    case light = "Light"
    case dark = "Dark"

    var displayName: String {
        return self.rawValue
    }
}

// MARK: - Theme Manager

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var currentTheme: AppTheme {
        didSet {
            saveTheme()
        }
    }

    @Published var themeMode: ThemeMode {
        didSet {
            saveThemeMode()
        }
    }

    private let themeKey = Constants.UserDefaults.appTheme
    private let themeModeKey = "appThemeMode"

    private init() {
        // Load saved theme or default to Ocean Blue
        if let savedThemeId = UserDefaults.standard.string(forKey: themeKey) {
            self.currentTheme = AppTheme.theme(withId: savedThemeId)
        } else {
            self.currentTheme = .oceanBlue
        }

        // Load saved theme mode or default to Light
        if let savedMode = UserDefaults.standard.string(forKey: themeModeKey),
           let mode = ThemeMode(rawValue: savedMode) {
            self.themeMode = mode
        } else {
            self.themeMode = .light
        }
    }

    func setTheme(_ theme: AppTheme) {
        withAnimation(Constants.Animation.quick) {
            currentTheme = theme
        }
    }

    func setThemeMode(_ mode: ThemeMode) {
        withAnimation(Constants.Animation.quick) {
            themeMode = mode
        }
    }

    private func saveTheme() {
        UserDefaults.standard.set(currentTheme.id, forKey: themeKey)
    }

    private func saveThemeMode() {
        UserDefaults.standard.set(themeMode.rawValue, forKey: themeModeKey)
    }
}
