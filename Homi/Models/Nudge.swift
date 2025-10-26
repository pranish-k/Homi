import Foundation
import FirebaseFirestore

// MARK: - Nudge Type

enum NudgeType: String, Codable {
    case choreOverdue = "chore_overdue"
    case paymentOverdue = "payment_overdue"
}

// MARK: - Nudge Model

struct Nudge: Identifiable, Codable {
    let id: String
    let houseId: String
    let fromUserId: String
    let fromUserName: String
    let toUserId: String
    let toUserName: String
    let type: NudgeType
    let itemId: String // choreId or expenseId
    let itemTitle: String
    let timestamp: Date

    init(
        id: String = UUID().uuidString,
        houseId: String,
        fromUserId: String,
        fromUserName: String,
        toUserId: String,
        toUserName: String,
        type: NudgeType,
        itemId: String,
        itemTitle: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.houseId = houseId
        self.fromUserId = fromUserId
        self.fromUserName = fromUserName
        self.toUserId = toUserId
        self.toUserName = toUserName
        self.type = type
        self.itemId = itemId
        self.itemTitle = itemTitle
        self.timestamp = timestamp
    }

    // MARK: - Firestore Conversion

    var asDictionary: [String: Any] {
        return [
            "id": id,
            "houseId": houseId,
            "fromUserId": fromUserId,
            "fromUserName": fromUserName,
            "toUserId": toUserId,
            "toUserName": toUserName,
            "type": type.rawValue,
            "itemId": itemId,
            "itemTitle": itemTitle,
            "timestamp": Timestamp(date: timestamp)
        ]
    }

    static func fromFirestore(_ data: [String: Any]) -> Nudge? {
        guard let id = data["id"] as? String,
              let houseId = data["houseId"] as? String,
              let fromUserId = data["fromUserId"] as? String,
              let fromUserName = data["fromUserName"] as? String,
              let toUserId = data["toUserId"] as? String,
              let toUserName = data["toUserName"] as? String,
              let typeString = data["type"] as? String,
              let type = NudgeType(rawValue: typeString),
              let itemId = data["itemId"] as? String,
              let itemTitle = data["itemTitle"] as? String,
              let timestamp = data["timestamp"] as? Timestamp else {
            return nil
        }

        return Nudge(
            id: id,
            houseId: houseId,
            fromUserId: fromUserId,
            fromUserName: fromUserName,
            toUserId: toUserId,
            toUserName: toUserName,
            type: type,
            itemId: itemId,
            itemTitle: itemTitle,
            timestamp: timestamp.dateValue()
        )
    }

    // MARK: - Notification Message

    var notificationMessage: String {
        switch type {
        case .choreOverdue:
            return "👋 \(fromUserName) nudged you about: \(itemTitle)"
        case .paymentOverdue:
            return "💰 \(fromUserName) sent a friendly reminder about your balance"
        }
    }

    // MARK: - Cooldown Check

    static let cooldownHours: Double = 12

    var isWithinCooldown: Bool {
        let cooldownInterval = Nudge.cooldownHours * 3600 // hours to seconds
        return Date().timeIntervalSince(timestamp) < cooldownInterval
    }
}
