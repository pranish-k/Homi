import Foundation
import FirebaseFirestore
import SwiftUI

// MARK: - Chore Model

struct Chore: Identifiable, Codable {
    let id: String
    let houseId: String
    let title: String
    let description: String?
    let assignedTo: String
    let assignedToName: String
    let createdBy: String
    let createdAt: Date
    let dueDate: Date
    let frequency: ChoreFrequency
    let category: ChoreCategory
    var isCompleted: Bool
    var completedAt: Date?
    var completedBy: String?
    var completedByName: String?
    let points: Int
    let rotationEnabled: Bool
    let rotationOrder: [String]?

    init(id: String = UUID().uuidString,
         houseId: String,
         title: String,
         description: String? = nil,
         assignedTo: String,
         assignedToName: String,
         createdBy: String,
         createdAt: Date = Date(),
         dueDate: Date,
         frequency: ChoreFrequency = .once,
         category: ChoreCategory = .other,
         isCompleted: Bool = false,
         completedAt: Date? = nil,
         completedBy: String? = nil,
         completedByName: String? = nil,
         points: Int = 0,
         rotationEnabled: Bool = false,
         rotationOrder: [String]? = nil) {
        self.id = id
        self.houseId = houseId
        self.title = title
        self.description = description
        self.assignedTo = assignedTo
        self.assignedToName = assignedToName
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.dueDate = dueDate
        self.frequency = frequency
        self.category = category
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.completedBy = completedBy
        self.completedByName = completedByName
        self.points = points
        self.rotationEnabled = rotationEnabled
        self.rotationOrder = rotationOrder
    }

    // Firestore conversion
    var asDictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "houseId": houseId,
            "title": title,
            "assignedTo": assignedTo,
            "assignedToName": assignedToName,
            "createdBy": createdBy,
            "createdAt": Timestamp(date: createdAt),
            "dueDate": Timestamp(date: dueDate),
            "frequency": frequency.rawValue,
            "category": category.rawValue,
            "isCompleted": isCompleted,
            "points": points,
            "rotationEnabled": rotationEnabled
        ]

        if let description = description {
            dict["description"] = description
        }

        if let completedAt = completedAt {
            dict["completedAt"] = Timestamp(date: completedAt)
        }

        if let completedBy = completedBy {
            dict["completedBy"] = completedBy
        }

        if let completedByName = completedByName {
            dict["completedByName"] = completedByName
        }

        if let rotationOrder = rotationOrder {
            dict["rotationOrder"] = rotationOrder
        }

        return dict
    }

    static func fromFirestore(_ data: [String: Any]) -> Chore? {
        guard let id = data["id"] as? String,
              let houseId = data["houseId"] as? String,
              let title = data["title"] as? String,
              let assignedTo = data["assignedTo"] as? String,
              let assignedToName = data["assignedToName"] as? String,
              let createdBy = data["createdBy"] as? String,
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let dueDateTimestamp = data["dueDate"] as? Timestamp,
              let frequencyString = data["frequency"] as? String,
              let frequency = ChoreFrequency(rawValue: frequencyString),
              let categoryString = data["category"] as? String,
              let category = ChoreCategory(rawValue: categoryString),
              let isCompleted = data["isCompleted"] as? Bool,
              let points = data["points"] as? Int,
              let rotationEnabled = data["rotationEnabled"] as? Bool else {
            return nil
        }

        let description = data["description"] as? String
        let completedAtTimestamp = data["completedAt"] as? Timestamp
        let completedBy = data["completedBy"] as? String
        let completedByName = data["completedByName"] as? String
        let rotationOrder = data["rotationOrder"] as? [String]

        return Chore(
            id: id,
            houseId: houseId,
            title: title,
            description: description,
            assignedTo: assignedTo,
            assignedToName: assignedToName,
            createdBy: createdBy,
            createdAt: createdAtTimestamp.dateValue(),
            dueDate: dueDateTimestamp.dateValue(),
            frequency: frequency,
            category: category,
            isCompleted: isCompleted,
            completedAt: completedAtTimestamp?.dateValue(),
            completedBy: completedBy,
            completedByName: completedByName,
            points: points,
            rotationEnabled: rotationEnabled,
            rotationOrder: rotationOrder
        )
    }

    // Formatted display
    var formattedDueDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: dueDate)
    }

    var shortDueDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: dueDate)
    }

    var dueDateDescription: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(dueDate) {
            return "Today"
        } else if calendar.isDateInTomorrow(dueDate) {
            return "Tomorrow"
        } else if calendar.isDateInYesterday(dueDate) {
            return "Yesterday"
        } else if dueDate < Date() {
            let days = calendar.dateComponents([.day], from: dueDate, to: Date()).day ?? 0
            return "\(days) days overdue"
        } else {
            let days = calendar.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
            return "In \(days) days"
        }
    }

    var isOverdue: Bool {
        return !isCompleted && dueDate < Date()
    }

    var isDueToday: Bool {
        return Calendar.current.isDateInToday(dueDate)
    }

    var isDueTomorrow: Bool {
        return Calendar.current.isDateInTomorrow(dueDate)
    }

    // Calculate next due date based on frequency
    func nextDueDate() -> Date {
        let calendar = Calendar.current
        switch frequency {
        case .once:
            return dueDate
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: dueDate) ?? dueDate
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: dueDate) ?? dueDate
        case .biweekly:
            return calendar.date(byAdding: .weekOfYear, value: 2, to: dueDate) ?? dueDate
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: dueDate) ?? dueDate
        }
    }

    // Get next assignee in rotation
    func nextAssignee() -> String? {
        guard rotationEnabled, let order = rotationOrder, !order.isEmpty else {
            return nil
        }

        if let currentIndex = order.firstIndex(of: assignedTo) {
            let nextIndex = (currentIndex + 1) % order.count
            return order[nextIndex]
        }

        return order.first
    }
}

// MARK: - Chore Frequency

enum ChoreFrequency: String, Codable, CaseIterable {
    case once = "One Time"
    case daily = "Daily"
    case weekly = "Weekly"
    case biweekly = "Every 2 Weeks"
    case monthly = "Monthly"
}

// MARK: - Chore Category

enum ChoreCategory: String, Codable, CaseIterable {
    case cleaning = "Cleaning"
    case kitchen = "Kitchen"
    case bathroom = "Bathroom"
    case trash = "Trash & Recycling"
    case outdoor = "Outdoor"
    case pets = "Pets"
    case laundry = "Laundry"
    case other = "Other"

    var icon: String {
        switch self {
        case .cleaning: return "sparkles"
        case .kitchen: return "fork.knife"
        case .bathroom: return "shower"
        case .trash: return "trash"
        case .outdoor: return "leaf"
        case .pets: return "pawprint"
        case .laundry: return "tshirt"
        case .other: return "square.grid.2x2"
        }
    }

    var color: Color {
        switch self {
        case .cleaning: return .purple
        case .kitchen: return .orange
        case .bathroom: return .blue
        case .trash: return .gray
        case .outdoor: return .green
        case .pets: return .brown
        case .laundry: return .cyan
        case .other: return Color(hex: "8E8E93")
        }
    }
}

// MARK: - Sample Data for Previews

extension Chore {
    static var sampleChores: [Chore] {
        [
            Chore(
                houseId: "sample-house",
                title: "Take out trash",
                description: "Take trash and recycling to the curb",
                assignedTo: "user1",
                assignedToName: "John Doe",
                createdBy: "user1",
                dueDate: Date(),
                frequency: .weekly,
                category: .trash,
                points: 5
            ),
            Chore(
                houseId: "sample-house",
                title: "Clean kitchen",
                description: "Wipe counters, sweep floor, clean sink",
                assignedTo: "user2",
                assignedToName: "Jane Smith",
                createdBy: "user1",
                dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
                frequency: .daily,
                category: .kitchen,
                isCompleted: false,
                points: 10
            ),
            Chore(
                houseId: "sample-house",
                title: "Vacuum living room",
                assignedTo: "user3",
                assignedToName: "Bob Wilson",
                createdBy: "user2",
                dueDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
                frequency: .weekly,
                category: .cleaning,
                isCompleted: false,
                points: 8
            )
        ]
    }
}
