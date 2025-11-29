import Foundation
import FirebaseFirestore

struct House: Codable, Identifiable {
    let id: String
    var name: String
    var address: String?
    let inviteCode: String
    let createdBy: String
    let createdAt: Date
    var memberCount: Int
    var memberIds: [String]
    var settings: HouseSettings

    init(
        id: String,
        name: String,
        address: String? = nil,
        inviteCode: String,
        createdBy: String,
        createdAt: Date = Date(),
        memberCount: Int = 1,
        memberIds: [String] = [],
        settings: HouseSettings = HouseSettings()
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.inviteCode = inviteCode
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.memberCount = memberCount
        self.memberIds = memberIds
        self.settings = settings
    }

    // Firestore conversion helpers
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }

        self.id = document.documentID
        self.name = data["name"] as? String ?? ""
        self.address = data["address"] as? String
        self.inviteCode = data["inviteCode"] as? String ?? ""
        self.createdBy = data["createdBy"] as? String ?? ""
        self.memberCount = data["memberCount"] as? Int ?? 0
        self.memberIds = data["memberIds"] as? [String] ?? []

        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = Date()
        }

        if let settingsData = data["settings"] as? [String: Any] {
            self.settings = HouseSettings(
                quietHoursStart: settingsData["quietHoursStart"] as? String,
                quietHoursEnd: settingsData["quietHoursEnd"] as? String,
                currency: settingsData["currency"] as? String ?? "USD",
                requirePaymentConfirmation: settingsData["requirePaymentConfirmation"] as? Bool ?? false,
                autoConfirmAfterHours: settingsData["autoConfirmAfterHours"] as? Int ?? 48
            )
        } else {
            self.settings = HouseSettings()
        }
    }

    var toFirestore: [String: Any] {
        var data: [String: Any] = [
            "name": name,
            "inviteCode": inviteCode,
            "createdBy": createdBy,
            "createdAt": Timestamp(date: createdAt),
            "memberCount": memberCount,
            "memberIds": memberIds
        ]

        // Build settings dictionary
        var settingsDict: [String: Any] = [
            "currency": settings.currency,
            "requirePaymentConfirmation": settings.requirePaymentConfirmation,
            "autoConfirmAfterHours": settings.autoConfirmAfterHours
        ]

        if let quietHoursStart = settings.quietHoursStart {
            settingsDict["quietHoursStart"] = quietHoursStart
        }

        if let quietHoursEnd = settings.quietHoursEnd {
            settingsDict["quietHoursEnd"] = quietHoursEnd
        }

        data["settings"] = settingsDict

        if let address = address {
            data["address"] = address
        }

        return data
    }
}

struct HouseSettings: Codable {
    var quietHoursStart: String?
    var quietHoursEnd: String?
    var currency: String
    var requirePaymentConfirmation: Bool  // Default: OFF (trusted roommates)
    var autoConfirmAfterHours: Int  // Auto-confirm pending payments after this time

    init(
        quietHoursStart: String? = nil,
        quietHoursEnd: String? = nil,
        currency: String = "USD",
        requirePaymentConfirmation: Bool = false,
        autoConfirmAfterHours: Int = 48
    ) {
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
        self.currency = currency
        self.requirePaymentConfirmation = requirePaymentConfirmation
        self.autoConfirmAfterHours = autoConfirmAfterHours
    }

    // Computed property
    var autoConfirmEnabled: Bool {
        return requirePaymentConfirmation && autoConfirmAfterHours > 0
    }
}

struct HouseMember: Codable, Identifiable {
    var id: String { userId }
    let userId: String
    var displayName: String
    var profilePhotoUrl: String?
    var role: MemberRole
    let joinedAt: Date
    var locationSharing: Bool
    var lastLocation: LocationInfo?

    enum MemberRole: String, Codable {
        case admin = "admin"
        case member = "member"
    }
}

struct LocationInfo: Codable {
    let latitude: Double
    let longitude: Double
    let timestamp: Date
}