import SwiftUI
import Combine

// MARK: - Theme Manager

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var currentTheme: AppTheme {
        didSet {
            saveTheme()
        }
    }

    private let themeKey = Constants.UserDefaults.appTheme

    private init() {
        // Load saved theme or default to Ocean Blue
        if let savedThemeId = UserDefaults.standard.string(forKey: themeKey) {
            self.currentTheme = AppTheme.theme(withId: savedThemeId)
        } else {
            self.currentTheme = .oceanBlue
        }
    }

    func setTheme(_ theme: AppTheme) {
        withAnimation(Constants.Animation.quick) {
            currentTheme = theme
        }
    }

    private func saveTheme() {
        UserDefaults.standard.set(currentTheme.id, forKey: themeKey)
    }
}
