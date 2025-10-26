//
//  DirectMessage.swift
//  Homi
//
//  Created for direct messaging feature
//

import Foundation
import FirebaseFirestore

struct DirectMessage: Identifiable, Codable {
    let id: String
    let conversationId: String
    let content: String
    let senderId: String
    let senderName: String
    let senderPhoto: String?
    let timestamp: Date
    let type: MessageType
    var imageUrl: String?
    var readBy: [String]

    enum MessageType: String, Codable {
        case text
        case image
        case system
    }

    // Firestore conversion
    init(id: String, conversationId: String, content: String, senderId: String, senderName: String, senderPhoto: String? = nil, timestamp: Date = Date(), type: MessageType = .text, imageUrl: String? = nil, readBy: [String] = []) {
        self.id = id
        self.conversationId = conversationId
        self.content = content
        self.senderId = senderId
        self.senderName = senderName
        self.senderPhoto = senderPhoto
        self.timestamp = timestamp
        self.type = type
        self.imageUrl = imageUrl
        self.readBy = readBy
    }

    init?(document: DocumentSnapshot) {
        guard let data = document.data(),
              let conversationId = data["conversationId"] as? String,
              let content = data["content"] as? String,
              let senderId = data["senderId"] as? String,
              let senderName = data["senderName"] as? String,
              let timestamp = (data["timestamp"] as? Timestamp)?.dateValue(),
              let typeString = data["type"] as? String,
              let type = MessageType(rawValue: typeString) else {
            return nil
        }

        self.id = document.documentID
        self.conversationId = conversationId
        self.content = content
        self.senderId = senderId
        self.senderName = senderName
        self.senderPhoto = data["senderPhoto"] as? String
        self.timestamp = timestamp
        self.type = type
        self.imageUrl = data["imageUrl"] as? String
        self.readBy = data["readBy"] as? [String] ?? []
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "conversationId": conversationId,
            "content": content,
            "senderId": senderId,
            "senderName": senderName,
            "timestamp": Timestamp(date: timestamp),
            "type": type.rawValue,
            "readBy": readBy
        ]

        if let senderPhoto = senderPhoto {
            dict["senderPhoto"] = senderPhoto
        }

        if let imageUrl = imageUrl {
            dict["imageUrl"] = imageUrl
        }

        return dict
    }

    // Helper methods
    func isFromCurrentUser(currentUserId: String) -> Bool {
        return senderId == currentUserId
    }

    func isReadBy(userId: String) -> Bool {
        return readBy.contains(userId)
    }

    var formattedTime: String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(timestamp) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: timestamp)
        } else if calendar.isDateInYesterday(timestamp) {
            return "Yesterday"
        } else if calendar.isDate(timestamp, equalTo: now, toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: timestamp)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: timestamp)
        }
    }
}
