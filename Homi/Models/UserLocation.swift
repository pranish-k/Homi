import Foundation
import FirebaseFirestore
import CoreLocation

// MARK: - User Location Model

struct UserLocation: Identifiable, Codable {
    let id: String
    let userId: String
    let userName: String
    let userPhotoURL: String?
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let isSharingEnabled: Bool

    // Computed property for CLLocationCoordinate2D
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    // Computed property for CLLocation
    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    // Time since last update
    var lastSeenText: String {
        let now = Date()
        let interval = now.timeIntervalSince(timestamp)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }

    // Check if location is recent (within last 15 minutes)
    var isRecent: Bool {
        Date().timeIntervalSince(timestamp) < 900 // 15 minutes
    }

    // Check if location is stale (older than 1 hour)
    var isStale: Bool {
        Date().timeIntervalSince(timestamp) > 3600 // 1 hour
    }

    // Initialize from current location
    init(
        id: String = UUID().uuidString,
        userId: String,
        userName: String,
        userPhotoURL: String? = nil,
        latitude: Double,
        longitude: Double,
        timestamp: Date = Date(),
        isSharingEnabled: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.userName = userName
        self.userPhotoURL = userPhotoURL
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.isSharingEnabled = isSharingEnabled
    }

    // Initialize from CLLocation
    init(
        userId: String,
        userName: String,
        userPhotoURL: String? = nil,
        location: CLLocation,
        isSharingEnabled: Bool = false
    ) {
        self.id = userId // Use userId as document ID
        self.userId = userId
        self.userName = userName
        self.userPhotoURL = userPhotoURL
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.timestamp = location.timestamp
        self.isSharingEnabled = isSharingEnabled
    }
}

// MARK: - Firestore Conversion

extension UserLocation {
    // Convert to Firestore dictionary
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "userId": userId,
            "userName": userName,
            "latitude": latitude,
            "longitude": longitude,
            "timestamp": Timestamp(date: timestamp),
            "isSharingEnabled": isSharingEnabled
        ]

        if let photoURL = userPhotoURL {
            data["userPhotoURL"] = photoURL
        }

        return data
    }

    // Initialize from Firestore document
    init?(document: DocumentSnapshot) {
        guard let data = document.data(),
              let userId = data["userId"] as? String,
              let userName = data["userName"] as? String,
              let latitude = data["latitude"] as? Double,
              let longitude = data["longitude"] as? Double,
              let timestamp = data["timestamp"] as? Timestamp,
              let isSharingEnabled = data["isSharingEnabled"] as? Bool else {
            return nil
        }

        self.id = document.documentID
        self.userId = userId
        self.userName = userName
        self.userPhotoURL = data["userPhotoURL"] as? String
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp.dateValue()
        self.isSharingEnabled = isSharingEnabled
    }
}

// MARK: - Sample Data

extension UserLocation {
    static var sample: UserLocation {
        UserLocation(
            userId: "user1",
            userName: "John Doe",
            userPhotoURL: nil,
            latitude: 37.7749,
            longitude: -122.4194,
            timestamp: Date(),
            isSharingEnabled: true
        )
    }

    static var samples: [UserLocation] {
        [
            UserLocation(
                userId: "user1",
                userName: "John Doe",
                latitude: 37.7749,
                longitude: -122.4194,
                timestamp: Date().addingTimeInterval(-300), // 5 min ago
                isSharingEnabled: true
            ),
            UserLocation(
                userId: "user2",
                userName: "Jane Smith",
                latitude: 37.7849,
                longitude: -122.4094,
                timestamp: Date().addingTimeInterval(-1800), // 30 min ago
                isSharingEnabled: true
            ),
            UserLocation(
                userId: "user3",
                userName: "Bob Johnson",
                latitude: 37.7649,
                longitude: -122.4294,
                timestamp: Date().addingTimeInterval(-7200), // 2 hours ago
                isSharingEnabled: true
            )
        ]
    }
}
