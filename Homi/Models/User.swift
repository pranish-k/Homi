import Foundation
import FirebaseFirestore

struct User: Codable, Identifiable {
    let id: String
    var email: String?
    var phoneNumber: String?
    var displayName: String
    var profilePhotoUrl: String?
    var authProviders: [String]
    var currentHouseId: String?
    var fcmToken: String?
    let createdAt: Date
    var lastSeen: Date
    var settings: UserSettings

    init(
        id: String,
        email: String? = nil,
        phoneNumber: String? = nil,
        displayName: String,
        profilePhotoUrl: String? = nil,
        authProviders: [String] = [],
        currentHouseId: String? = nil,
        fcmToken: String? = nil,
        createdAt: Date = Date(),
        lastSeen: Date = Date(),
        settings: UserSettings = UserSettings()
    ) {
        self.id = id
        self.email = email
        self.phoneNumber = phoneNumber
        self.displayName = displayName
        self.profilePhotoUrl = profilePhotoUrl
        self.authProviders = authProviders
        self.currentHouseId = currentHouseId
        self.fcmToken = fcmToken
        self.createdAt = createdAt
        self.lastSeen = lastSeen
        self.settings = settings
    }

    // Firestore conversion helpers
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }

        self.id = document.documentID
        self.email = data["email"] as? String
        self.phoneNumber = data["phoneNumber"] as? String
        self.displayName = data["displayName"] as? String ?? ""
        self.profilePhotoUrl = data["profilePhotoUrl"] as? String
        self.authProviders = data["authProviders"] as? [String] ?? []
        self.currentHouseId = data["currentHouseId"] as? String
        self.fcmToken = data["fcmToken"] as? String

        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = Date()
        }

        if let timestamp = data["lastSeen"] as? Timestamp {
            self.lastSeen = timestamp.dateValue()
        } else {
            self.lastSeen = Date()
        }

        if let settingsData = data["settings"] as? [String: Any] {
            self.settings = UserSettings(
                notificationsEnabled: settingsData["notificationsEnabled"] as? Bool ?? true,
                locationSharingEnabled: settingsData["locationSharingEnabled"] as? Bool ?? false,
                quietHoursEnabled: settingsData["quietHoursEnabled"] as? Bool ?? false
            )
        } else {
            self.settings = UserSettings()
        }
    }

    var toFirestore: [String: Any] {
        var data: [String: Any] = [
            "displayName": displayName,
            "authProviders": authProviders,
            "createdAt": Timestamp(date: createdAt),
            "lastSeen": Timestamp(date: lastSeen),
            "settings": [
                "notificationsEnabled": settings.notificationsEnabled,
                "locationSharingEnabled": settings.locationSharingEnabled,
                "quietHoursEnabled": settings.quietHoursEnabled
            ]
        ]

        if let email = email {
            data["email"] = email
        }

        if let phoneNumber = phoneNumber {
            data["phoneNumber"] = phoneNumber
        }

        if let profilePhotoUrl = profilePhotoUrl {
            data["profilePhotoUrl"] = profilePhotoUrl
        }

        if let currentHouseId = currentHouseId {
            data["currentHouseId"] = currentHouseId
        }

        if let fcmToken = fcmToken {
            data["fcmToken"] = fcmToken
        }

        return data
    }
}

struct UserSettings: Codable {
    var notificationsEnabled: Bool
    var locationSharingEnabled: Bool
    var quietHoursEnabled: Bool

    init(
        notificationsEnabled: Bool = true,
        locationSharingEnabled: Bool = false,
        quietHoursEnabled: Bool = false
    ) {
        self.notificationsEnabled = notificationsEnabled
        self.locationSharingEnabled = locationSharingEnabled
        self.quietHoursEnabled = quietHoursEnabled
    }
}