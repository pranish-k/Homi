import SwiftUI
import FirebaseCore
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()

        // Configure Auth settings for testing
        #if targetEnvironment(simulator)
        // Disable app verification for testing on simulator
        // This allows phone auth to work with test numbers
        Auth.auth().settings?.isAppVerificationDisabledForTesting = true
        #endif

        return true
    }

    // Handle phone auth verification
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if Auth.auth().canHandleNotification(userInfo) {
            completionHandler(.noData)
            return
        }
        completionHandler(.newData)
    }

    // Handle URL callbacks for OAuth (Google Sign-In, etc.)
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        // This will be used when Google Sign-In is implemented
        return false
    }
}
