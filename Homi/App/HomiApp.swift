import SwiftUI

@main
struct HomiApp: App {
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    handleScenePhaseChange(oldPhase: oldPhase, newPhase: newPhase)
                }
        }
    }

    private func handleScenePhaseChange(oldPhase: ScenePhase, newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            // Stop all listeners to save battery
            stopAllListeners()

        case .inactive:
            // App is transitioning, prepare to stop
            break

        case .active:
            // Restart listeners when app becomes active
            if oldPhase == .background {
                restartListeners()
            }

        @unknown default:
            break
        }
    }

    private func stopAllListeners() {
        print("App entering background - stopping all listeners")

        // Stop expense listeners
        ExpenseService.shared.stopListening()
        CentralExpenseStore.shared.stopListening()

        // Stop other service listeners
        // MessagingService.shared.stopListening()
        // ChoreService.shared.stopListening()
        // LocationService.shared.stopListening()

        // Clear in-memory cache to reduce memory pressure
        ExpenseCacheService.shared.invalidateCache()

        // Post notification
        NotificationCenter.default.post(name: .appDidEnterBackground, object: nil)
    }

    private func restartListeners() {
        print("App entering foreground - restarting listeners")

        // Listeners will be restarted by their respective views
        // This is handled automatically when views appear

        // Trigger a refresh notification
        NotificationCenter.default.post(name: .appDidBecomeActive, object: nil)
    }
}

// Add notification name extension
extension Notification.Name {
    static let appDidBecomeActive = Notification.Name("appDidBecomeActive")
    static let appDidEnterBackground = Notification.Name("appDidEnterBackground")
}
