import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseCrashlytics
import GoogleSignIn
// import FirebasePerformance // Uncomment after adding to Package.swift

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

        // Enable Crashlytics
        setupCrashlytics()

        // Set up performance monitoring
        setupPerformanceMonitoring()

        return true
    }

    private func setupCrashlytics() {
        // Enable Crashlytics collection
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)

        // Set user identifier (after login)
        if let userId = Auth.auth().currentUser?.uid {
            Crashlytics.crashlytics().setUserID(userId)
        }

        // Log app version
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            Crashlytics.crashlytics().setCustomValue("\(version) (\(build))", forKey: "app_version")
        }

        // Set custom keys for debugging
        Crashlytics.crashlytics().setCustomValue(UIDevice.current.modelName, forKey: "device_model")
        Crashlytics.crashlytics().setCustomValue(UIDevice.current.systemVersion, forKey: "ios_version")

        #if DEBUG
        print("✅ Crashlytics configured (Debug mode)")
        #else
        print("✅ Crashlytics configured (Release mode)")
        #endif
    }

    private func setupPerformanceMonitoring() {
        // Performance monitoring setup - uncomment after adding Firebase Performance to Package.swift
        /*
        #if DEBUG
        Performance.sharedInstance().isDataCollectionEnabled = false
        Performance.sharedInstance().isInstrumentationEnabled = false
        #else
        Performance.sharedInstance().isDataCollectionEnabled = true
        Performance.sharedInstance().isInstrumentationEnabled = true
        #endif
        */
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

    // Handle URL callbacks for OAuth and Phone Auth reCAPTCHA
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        // Handle Google Sign-In callback
        if GIDSignIn.sharedInstance.handle(url) {
            return true
        }
        
        // Handle Firebase Auth reCAPTCHA callback for phone authentication
        if Auth.auth().canHandle(url) {
            return true
        }
        
        return false
    }
}

// MARK: - UIDevice Extension

extension UIDevice {
    var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return mapToDevice(identifier: identifier)
    }

    private func mapToDevice(identifier: String) -> String {
        // Return a readable device name
        switch identifier {
        case "iPhone15,2": return "iPhone 15 Pro"
        case "iPhone15,3": return "iPhone 15 Pro Max"
        case "iPhone14,2": return "iPhone 13 Pro"
        case "iPhone14,3": return "iPhone 13 Pro Max"
        case "iPhone13,2": return "iPhone 12"
        case "iPhone13,3": return "iPhone 12 Pro"
        case "iPhone13,4": return "iPhone 12 Pro Max"
        case "iPad13,1", "iPad13,2": return "iPad Air (4th gen)"
        case "iPad14,1", "iPad14,2": return "iPad mini (6th gen)"
        case "x86_64", "arm64": return "Simulator"
        default: return identifier
        }
    }
}
