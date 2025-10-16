import Foundation
import FirebaseFirestore

struct Message: Identifiable, Codable {
    let id: String
    let content: String
    let senderId: String
    let senderName: String
    let senderPhoto: String?
    let timestamp: Date
    let type: MessageType
    let imageUrl: String?
    var readBy: [String]

    enum MessageType: String, Codable {
        case text
        case image
        case system
    }

    init(id: String = UUID().uuidString,
         content: String,
         senderId: String,
         senderName: String,
         senderPhoto: String? = nil,
         timestamp: Date = Date(),
         type: MessageType = .text,
         imageUrl: String? = nil,
         readBy: [String] = []) {
        self.id = id
        self.content = content
        self.senderId = senderId
        self.senderName = senderName
        self.senderPhoto = senderPhoto
        self.timestamp = timestamp
        self.type = type
        self.imageUrl = imageUrl
        self.readBy = readBy
    }

    // Initialize from Firestore document
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }

        self.id = document.documentID
        self.content = data["content"] as? String ?? ""
        self.senderId = data["senderId"] as? String ?? ""
        self.senderName = data["senderName"] as? String ?? ""
        self.senderPhoto = data["senderPhoto"] as? String

        if let timestamp = data["timestamp"] as? Timestamp {
            self.timestamp = timestamp.dateValue()
        } else {
            self.timestamp = Date()
        }

        if let typeString = data["type"] as? String,
           let messageType = MessageType(rawValue: typeString) {
            self.type = messageType
        } else {
            self.type = .text
        }

        self.imageUrl = data["imageUrl"] as? String
        self.readBy = data["readBy"] as? [String] ?? []
    }

    // Convert to Firestore format
    var toFirestore: [String: Any] {
        var data: [String: Any] = [
            "content": content,
            "senderId": senderId,
            "senderName": senderName,
            "timestamp": Timestamp(date: timestamp),
            "type": type.rawValue,
            "readBy": readBy
        ]

        if let senderPhoto = senderPhoto {
            data["senderPhoto"] = senderPhoto
        }

        if let imageUrl = imageUrl {
            data["imageUrl"] = imageUrl
        }

        return data
    }

    // Check if message is from current user
    func isFromCurrentUser(userId: String) -> Bool {
        return senderId == userId
    }

    // Check if message has been read by user
    func isReadBy(userId: String) -> Bool {
        return readBy.contains(userId)
    }

    // Format timestamp
    var formattedTime: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(timestamp) {
            formatter.dateFormat = "h:mm a"
        } else if calendar.isDateInYesterday(timestamp) {
            return "Yesterday"
        } else if calendar.isDate(timestamp, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE"
        } else {
            formatter.dateFormat = "MMM d"
        }

        return formatter.string(from: timestamp)
    }

    var detailedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: timestamp)
    }
}

// MARK: - Sample Data for Previews
extension Message {
    static let sampleMessages: [Message] = [
        Message(
            content: "Hey everyone! Just wanted to remind you about the house meeting tonight at 7 PM.",
            senderId: "user1",
            senderName: "John Doe",
            timestamp: Date().addingTimeInterval(-3600)
        ),
        Message(
            content: "Thanks for the reminder! I'll be there.",
            senderId: "user2",
            senderName: "Jane Smith",
            timestamp: Date().addingTimeInterval(-3500)
        ),
        Message(
            content: "Can we also discuss the cleaning schedule?",
            senderId: "user3",
            senderName: "Bob Johnson",
            timestamp: Date().addingTimeInterval(-3400)
        ),
        Message(
            content: "Good idea! Let's add that to the agenda.",
            senderId: "user1",
            senderName: "John Doe",
            timestamp: Date().addingTimeInterval(-3300)
        ),
        Message(
            content: "I might be 10 minutes late, is that okay?",
            senderId: "user2",
            senderName: "Jane Smith",
            timestamp: Date().addingTimeInterval(-60)
        )
    ]
}
