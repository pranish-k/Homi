//
//  Conversation.swift
//  Homi
//
//  Created for direct messaging feature
//

import Foundation
import FirebaseFirestore

struct Conversation: Identifiable, Codable, Hashable {
    let id: String // Format: "userId1_userId2" (alphabetically sorted)
    let participantIds: [String]
    var participantNames: [String: String] // userId -> displayName
    var participantPhotos: [String: String] // userId -> photoUrl
    var lastMessage: String?
    var lastMessageTime: Date?
    var lastMessageSenderId: String?
    var unreadCounts: [String: Int] // userId -> unread count

    init(id: String, participantIds: [String], participantNames: [String: String] = [:], participantPhotos: [String: String] = [:], lastMessage: String? = nil, lastMessageTime: Date? = nil, lastMessageSenderId: String? = nil, unreadCounts: [String: Int] = [:]) {
        self.id = id
        self.participantIds = participantIds
        self.participantNames = participantNames
        self.participantPhotos = participantPhotos
        self.lastMessage = lastMessage
        self.lastMessageTime = lastMessageTime
        self.lastMessageSenderId = lastMessageSenderId
        self.unreadCounts = unreadCounts
    }

    init?(document: DocumentSnapshot) {
        guard let data = document.data(),
              let participantIds = data["participantIds"] as? [String] else {
            return nil
        }

        self.id = document.documentID
        self.participantIds = participantIds
        self.participantNames = data["participantNames"] as? [String: String] ?? [:]
        self.participantPhotos = data["participantPhotos"] as? [String: String] ?? [:]
        self.lastMessage = data["lastMessage"] as? String
        self.lastMessageTime = (data["lastMessageTime"] as? Timestamp)?.dateValue()
        self.lastMessageSenderId = data["lastMessageSenderId"] as? String
        self.unreadCounts = data["unreadCounts"] as? [String: Int] ?? [:]
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "participantIds": participantIds,
            "participantNames": participantNames,
            "participantPhotos": participantPhotos,
            "unreadCounts": unreadCounts
        ]

        if let lastMessage = lastMessage {
            dict["lastMessage"] = lastMessage
        }

        if let lastMessageTime = lastMessageTime {
            dict["lastMessageTime"] = Timestamp(date: lastMessageTime)
        }

        if let lastMessageSenderId = lastMessageSenderId {
            dict["lastMessageSenderId"] = lastMessageSenderId
        }

        return dict
    }

    // Helper methods
    func getOtherParticipantId(currentUserId: String) -> String? {
        return participantIds.first { $0 != currentUserId }
    }

    func getOtherParticipantName(currentUserId: String) -> String? {
        guard let otherUserId = getOtherParticipantId(currentUserId: currentUserId) else {
            return nil
        }
        return participantNames[otherUserId]
    }

    func getOtherParticipantPhoto(currentUserId: String) -> String? {
        guard let otherUserId = getOtherParticipantId(currentUserId: currentUserId) else {
            return nil
        }
        return participantPhotos[otherUserId]
    }

    func getUnreadCount(for userId: String) -> Int {
        return unreadCounts[userId] ?? 0
    }

    var formattedLastMessageTime: String {
        guard let time = lastMessageTime else { return "" }

        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(time) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: time)
        } else if calendar.isDateInYesterday(time) {
            return "Yesterday"
        } else if calendar.isDate(time, equalTo: now, toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            return formatter.string(from: time)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: time)
        }
    }

    // Generate conversation ID from two user IDs
    static func generateConversationId(user1: String, user2: String) -> String {
        let sorted = [user1, user2].sorted()
        return "\(sorted[0])_\(sorted[1])"
    }
}
