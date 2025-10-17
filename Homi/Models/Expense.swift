import Foundation
import FirebaseFirestore

// MARK: - Expense Model

struct Expense: Identifiable, Codable, Equatable {
    static func == (lhs: Expense, rhs: Expense) -> Bool {
        lhs.id == rhs.id && lhs.isSettled == rhs.isSettled
    }
    let id: String
    let houseId: String
    let amount: Double
    let description: String
    let category: ExpenseCategory
    let date: Date
    let paidBy: String
    let paidByName: String
    let splits: [ExpenseSplit]
    let isSettled: Bool
    let createdAt: Date
    let createdBy: String

    init(id: String = UUID().uuidString,
         houseId: String,
         amount: Double,
         description: String,
         category: ExpenseCategory = .other,
         date: Date = Date(),
         paidBy: String,
         paidByName: String,
         splits: [ExpenseSplit],
         isSettled: Bool = false,
         createdAt: Date = Date(),
         createdBy: String) {
        self.id = id
        self.houseId = houseId
        self.amount = amount
        self.description = description
        self.category = category
        self.date = date
        self.paidBy = paidBy
        self.paidByName = paidByName
        self.splits = splits
        self.isSettled = isSettled
        self.createdAt = createdAt
        self.createdBy = createdBy
    }

    // Firestore conversion
    var asDictionary: [String: Any] {
        return [
            "id": id,
            "houseId": houseId,
            "amount": amount,
            "description": description,
            "category": category.rawValue,
            "date": Timestamp(date: date),
            "paidBy": paidBy,
            "paidByName": paidByName,
            "splits": splits.map { $0.asDictionary },
            "isSettled": isSettled,
            "createdAt": Timestamp(date: createdAt),
            "createdBy": createdBy
        ]
    }

    static func fromFirestore(_ data: [String: Any]) -> Expense? {
        guard let id = data["id"] as? String,
              let houseId = data["houseId"] as? String,
              let amount = data["amount"] as? Double,
              let description = data["description"] as? String,
              let categoryString = data["category"] as? String,
              let category = ExpenseCategory(rawValue: categoryString),
              let dateTimestamp = data["date"] as? Timestamp,
              let paidBy = data["paidBy"] as? String,
              let paidByName = data["paidByName"] as? String,
              let splitsData = data["splits"] as? [[String: Any]],
              let isSettled = data["isSettled"] as? Bool,
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let createdBy = data["createdBy"] as? String else {
            return nil
        }

        let splits = splitsData.compactMap { ExpenseSplit.fromFirestore($0) }

        return Expense(
            id: id,
            houseId: houseId,
            amount: amount,
            description: description,
            category: category,
            date: dateTimestamp.dateValue(),
            paidBy: paidBy,
            paidByName: paidByName,
            splits: splits,
            isSettled: isSettled,
            createdAt: createdAtTimestamp.dateValue(),
            createdBy: createdBy
        )
    }

    // Formatted display
    var formattedAmount: String {
        return String(format: "$%.2f", amount)
    }

    func formattedAmount(currency: String) -> String {
        return CurrencyFormatter.format(amount: amount, currencyCode: currency)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Expense Split

struct ExpenseSplit: Codable, Identifiable {
    var id: String { userId }
    let userId: String
    let userName: String
    let amount: Double
    var isPaid: Bool

    var asDictionary: [String: Any] {
        return [
            "userId": userId,
            "userName": userName,
            "amount": amount,
            "isPaid": isPaid
        ]
    }

    static func fromFirestore(_ data: [String: Any]) -> ExpenseSplit? {
        guard let userId = data["userId"] as? String,
              let userName = data["userName"] as? String,
              let amount = data["amount"] as? Double,
              let isPaid = data["isPaid"] as? Bool else {
            return nil
        }

        return ExpenseSplit(userId: userId, userName: userName, amount: amount, isPaid: isPaid)
    }

    var formattedAmount: String {
        return String(format: "$%.2f", amount)
    }

    func formattedAmount(currency: String) -> String {
        return CurrencyFormatter.format(amount: amount, currencyCode: currency)
    }
}

// MARK: - Expense Category

enum ExpenseCategory: String, Codable, CaseIterable {
    case rent = "Rent"
    case utilities = "Utilities"
    case groceries = "Groceries"
    case supplies = "Supplies"
    case internet = "Internet"
    case cleaning = "Cleaning"
    case maintenance = "Maintenance"
    case other = "Other"

    var icon: String {
        switch self {
        case .rent: return "house.fill"
        case .utilities: return "bolt.fill"
        case .groceries: return "cart.fill"
        case .supplies: return "bag.fill"
        case .internet: return "wifi"
        case .cleaning: return "sparkles"
        case .maintenance: return "wrench.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .rent: return "primary"
        case .utilities: return "warning"
        case .groceries: return "success"
        case .supplies: return "primary"
        case .internet: return "primary"
        case .cleaning: return "success"
        case .maintenance: return "warning"
        case .other: return "textSecondary"
        }
    }
}

// MARK: - Payment Model

struct Payment: Identifiable, Codable {
    let id: String
    let houseId: String
    let fromUserId: String
    let fromUserName: String
    let toUserId: String
    let toUserName: String
    let amount: Double
    let expenseIds: [String]
    let note: String?
    let timestamp: Date

    init(id: String = UUID().uuidString,
         houseId: String,
         fromUserId: String,
         fromUserName: String,
         toUserId: String,
         toUserName: String,
         amount: Double,
         expenseIds: [String] = [],
         note: String? = nil,
         timestamp: Date = Date()) {
        self.id = id
        self.houseId = houseId
        self.fromUserId = fromUserId
        self.fromUserName = fromUserName
        self.toUserId = toUserId
        self.toUserName = toUserName
        self.amount = amount
        self.expenseIds = expenseIds
        self.note = note
        self.timestamp = timestamp
    }

    var asDictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "houseId": houseId,
            "fromUserId": fromUserId,
            "fromUserName": fromUserName,
            "toUserId": toUserId,
            "toUserName": toUserName,
            "amount": amount,
            "expenseIds": expenseIds,
            "timestamp": Timestamp(date: timestamp)
        ]

        if let note = note {
            dict["note"] = note
        }

        return dict
    }

    static func fromFirestore(_ data: [String: Any]) -> Payment? {
        guard let id = data["id"] as? String,
              let houseId = data["houseId"] as? String,
              let fromUserId = data["fromUserId"] as? String,
              let fromUserName = data["fromUserName"] as? String,
              let toUserId = data["toUserId"] as? String,
              let toUserName = data["toUserName"] as? String,
              let amount = data["amount"] as? Double,
              let expenseIds = data["expenseIds"] as? [String],
              let timestampValue = data["timestamp"] as? Timestamp else {
            return nil
        }

        let note = data["note"] as? String

        return Payment(
            id: id,
            houseId: houseId,
            fromUserId: fromUserId,
            fromUserName: fromUserName,
            toUserId: toUserId,
            toUserName: toUserName,
            amount: amount,
            expenseIds: expenseIds,
            note: note,
            timestamp: timestampValue.dateValue()
        )
    }

    var formattedAmount: String {
        return String(format: "$%.2f", amount)
    }

    func formattedAmount(currency: String) -> String {
        return CurrencyFormatter.format(amount: amount, currencyCode: currency)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: timestamp)
    }
}

// MARK: - Balance Summary

struct Balance: Identifiable {
    var id: String { userId }
    let userId: String
    let userName: String
    var owedToYou: Double  // Money they owe you
    var youOwe: Double     // Money you owe them

    var netBalance: Double {
        return owedToYou - youOwe
    }

    var formattedBalance: String {
        let amount = abs(netBalance)
        return String(format: "$%.2f", amount)
    }

    func formattedBalance(currency: String) -> String {
        let amount = abs(netBalance)
        return CurrencyFormatter.format(amount: amount, currencyCode: currency)
    }

    var balanceDescription: String {
        if netBalance > 0 {
            return "owes you"
        } else if netBalance < 0 {
            return "you owe"
        } else {
            return "settled up"
        }
    }
}

// MARK: - Sample Data for Previews

extension Expense {
    static var sampleExpenses: [Expense] {
        [
            Expense(
                houseId: "sample-house",
                amount: 150.00,
                description: "Monthly rent",
                category: .rent,
                date: Date(),
                paidBy: "user1",
                paidByName: "John Doe",
                splits: [
                    ExpenseSplit(userId: "user1", userName: "John Doe", amount: 50.00, isPaid: true),
                    ExpenseSplit(userId: "user2", userName: "Jane Smith", amount: 50.00, isPaid: false),
                    ExpenseSplit(userId: "user3", userName: "Bob Wilson", amount: 50.00, isPaid: false)
                ],
                createdBy: "user1"
            ),
            Expense(
                houseId: "sample-house",
                amount: 80.50,
                description: "Grocery shopping",
                category: .groceries,
                date: Date().addingTimeInterval(-86400),
                paidBy: "user2",
                paidByName: "Jane Smith",
                splits: [
                    ExpenseSplit(userId: "user1", userName: "John Doe", amount: 26.83, isPaid: false),
                    ExpenseSplit(userId: "user2", userName: "Jane Smith", amount: 26.83, isPaid: true),
                    ExpenseSplit(userId: "user3", userName: "Bob Wilson", amount: 26.84, isPaid: true)
                ],
                createdBy: "user2"
            )
        ]
    }
}
