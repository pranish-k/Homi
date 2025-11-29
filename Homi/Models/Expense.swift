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
    var splits: [ExpenseSplit]  // Changed to var to allow updates
    var isSettled: Bool  // Changed to var to allow updates
    let createdAt: Date
    let createdBy: String
    var lastModifiedAt: Date?  // Changed to var - Audit trail: when was this expense last modified
    var lastModifiedBy: String? // Changed to var - Audit trail: who last modified this expense
    let deletedAt: Date?       // Soft delete: when was this expense deleted
    let deletedBy: String?     // Soft delete: who deleted this expense

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
         createdBy: String,
         lastModifiedAt: Date? = nil,
         lastModifiedBy: String? = nil,
         deletedAt: Date? = nil,
         deletedBy: String? = nil) {
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
        self.lastModifiedAt = lastModifiedAt
        self.lastModifiedBy = lastModifiedBy
        self.deletedAt = deletedAt
        self.deletedBy = deletedBy
    }

    // Firestore conversion
    var asDictionary: [String: Any] {
        var dict: [String: Any] = [
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

        // Add optional audit fields if present
        if let lastModifiedAt = lastModifiedAt {
            dict["lastModifiedAt"] = Timestamp(date: lastModifiedAt)
        }
        if let lastModifiedBy = lastModifiedBy {
            dict["lastModifiedBy"] = lastModifiedBy
        }
        if let deletedAt = deletedAt {
            dict["deletedAt"] = Timestamp(date: deletedAt)
        }
        if let deletedBy = deletedBy {
            dict["deletedBy"] = deletedBy
        }

        return dict
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

        // Parse optional audit fields
        let lastModifiedAt = (data["lastModifiedAt"] as? Timestamp)?.dateValue()
        let lastModifiedBy = data["lastModifiedBy"] as? String
        let deletedAt = (data["deletedAt"] as? Timestamp)?.dateValue()
        let deletedBy = data["deletedBy"] as? String

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
            createdBy: createdBy,
            lastModifiedAt: lastModifiedAt,
            lastModifiedBy: lastModifiedBy,
            deletedAt: deletedAt,
            deletedBy: deletedBy
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

    var relativeDate: String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if let daysAgo = calendar.dateComponents([.day], from: date, to: now).day {
            if daysAgo < 7 {
                return "\(daysAgo) days ago"
            } else if daysAgo < 30 {
                let weeksAgo = daysAgo / 7
                return "\(weeksAgo) \(weeksAgo == 1 ? "week" : "weeks") ago"
            }
        }

        // Fall back to short date for older expenses
        return shortDate
    }
}

// MARK: - Expense Split

struct ExpenseSplit: Codable, Identifiable, Equatable {
    var id: String { userId }
    let userId: String
    let userName: String
    let amount: Double  // ORIGINAL amount (never changes)
    var isPaid: Bool
    var partialPayments: [PartialPaymentRecord]  // Payment history

    init(userId: String, userName: String, amount: Double, isPaid: Bool, partialPayments: [PartialPaymentRecord] = []) {
        self.userId = userId
        self.userName = userName
        self.amount = amount
        self.isPaid = isPaid
        self.partialPayments = partialPayments
    }

    // Computed property for remaining amount
    var remainingAmount: Double {
        let totalPaid = partialPayments.reduce(0) { $0 + $1.amount }
        return max(0, amount - totalPaid)
    }

    // Check if fully paid
    var isFullyPaid: Bool {
        return remainingAmount <= 0.01  // Account for floating point
    }

    var asDictionary: [String: Any] {
        return [
            "userId": userId,
            "userName": userName,
            "amount": amount,
            "isPaid": isPaid,
            "partialPayments": partialPayments.map { $0.asDictionary }
        ]
    }

    static func fromFirestore(_ data: [String: Any]) -> ExpenseSplit? {
        guard let userId = data["userId"] as? String,
              let userName = data["userName"] as? String,
              let amount = data["amount"] as? Double,
              let isPaid = data["isPaid"] as? Bool else {
            return nil
        }

        let partialPaymentsData = data["partialPayments"] as? [[String: Any]] ?? []
        let partialPayments = partialPaymentsData.compactMap { PartialPaymentRecord.fromFirestore($0) }

        return ExpenseSplit(userId: userId, userName: userName, amount: amount, isPaid: isPaid, partialPayments: partialPayments)
    }

    var formattedAmount: String {
        return String(format: "$%.2f", amount)
    }

    func formattedAmount(currency: String) -> String {
        return CurrencyFormatter.format(amount: amount, currencyCode: currency)
    }

    var formattedRemainingAmount: String {
        return String(format: "$%.2f", remainingAmount)
    }
}

// MARK: - Partial Payment Record

struct PartialPaymentRecord: Codable, Equatable, Identifiable {
    var id: String { paymentId }
    let paymentId: String
    let amount: Double
    let timestamp: Date
    let paymentMethod: PaymentMethod?

    var asDictionary: [String: Any] {
        var dict: [String: Any] = [
            "paymentId": paymentId,
            "amount": amount,
            "timestamp": Timestamp(date: timestamp)
        ]
        if let method = paymentMethod {
            dict["paymentMethod"] = method.rawValue
        }
        return dict
    }

    static func fromFirestore(_ data: [String: Any]) -> PartialPaymentRecord? {
        guard let paymentId = data["paymentId"] as? String,
              let amount = data["amount"] as? Double,
              let timestampValue = data["timestamp"] as? Timestamp else {
            return nil
        }

        let paymentMethodStr = data["paymentMethod"] as? String
        let paymentMethod = paymentMethodStr != nil ? PaymentMethod(rawValue: paymentMethodStr!) : nil

        return PartialPaymentRecord(
            paymentId: paymentId,
            amount: amount,
            timestamp: timestampValue.dateValue(),
            paymentMethod: paymentMethod
        )
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

struct Payment: Identifiable, Codable, Equatable {
    let id: String
    let transactionId: String // Unique transaction identifier
    let idempotencyKey: String // For deduplication
    let houseId: String
    let fromUserId: String
    let fromUserName: String
    let toUserId: String
    let toUserName: String
    let amount: Double
    let expenseIds: [String]
    let settledSplits: [SettledSplitInfo]  // Detailed split settlement info
    let note: String?
    let timestamp: Date
    let status: PaymentStatus  // Payment status
    let confirmedBy: String?  // Payee confirmation
    let confirmedAt: Date?  // Confirmation timestamp
    let paymentMethod: PaymentMethod  // How the payment was made
    let externalTransactionId: String?  // Venmo/Zelle transaction ID

    init(id: String? = nil,
         houseId: String,
         fromUserId: String,
         fromUserName: String,
         toUserId: String,
         toUserName: String,
         amount: Double,
         expenseIds: [String] = [],
         settledSplits: [SettledSplitInfo] = [],
         note: String? = nil,
         timestamp: Date = Date(),
         status: PaymentStatus = .autoConfirmed,
         confirmedBy: String? = nil,
         confirmedAt: Date? = nil,
         paymentMethod: PaymentMethod = .other,
         externalTransactionId: String? = nil) {
        // Generate deterministic ID to prevent duplicates using SORTED user IDs
        let sortedUsers = [fromUserId, toUserId].sorted()
        let timestampInt = Int(timestamp.timeIntervalSince1970 * 1000)  // milliseconds for uniqueness
        let amountCents = Int(amount * 100)
        self.id = id ?? "\(sortedUsers[0])_\(sortedUsers[1])_\(timestampInt)_\(amountCents)"

        // Unique transaction ID for this specific payment attempt
        self.transactionId = UUID().uuidString

        // Idempotency key with 10-second window for duplicate detection (SORTED user IDs)
        self.idempotencyKey = "\(sortedUsers[0])_\(sortedUsers[1])_\(amountCents)_\(timestampInt / 10000)"

        self.houseId = houseId
        self.fromUserId = fromUserId
        self.fromUserName = fromUserName
        self.toUserId = toUserId
        self.toUserName = toUserName
        self.amount = amount
        self.expenseIds = expenseIds
        self.settledSplits = settledSplits
        self.note = note
        self.timestamp = timestamp
        self.status = status
        self.confirmedBy = confirmedBy
        self.confirmedAt = confirmedAt
        self.paymentMethod = paymentMethod
        self.externalTransactionId = externalTransactionId
    }

    var asDictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "transactionId": transactionId,
            "idempotencyKey": idempotencyKey,
            "houseId": houseId,
            "fromUserId": fromUserId,
            "fromUserName": fromUserName,
            "toUserId": toUserId,
            "toUserName": toUserName,
            "amount": amount,
            "expenseIds": expenseIds,
            "settledSplits": settledSplits.map { $0.asDictionary },
            "timestamp": Timestamp(date: timestamp),
            "status": status.rawValue,
            "paymentMethod": paymentMethod.rawValue
        ]

        if let note = note {
            dict["note"] = note
        }
        if let confirmedBy = confirmedBy {
            dict["confirmedBy"] = confirmedBy
        }
        if let confirmedAt = confirmedAt {
            dict["confirmedAt"] = Timestamp(date: confirmedAt)
        }
        if let externalTransactionId = externalTransactionId {
            dict["externalTransactionId"] = externalTransactionId
        }

        return dict
    }

    static func fromFirestore(_ data: [String: Any]) -> Payment? {
        guard let houseId = data["houseId"] as? String,
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
        let id = data["id"] as? String

        // Parse new fields with defaults for backward compatibility
        let statusStr = data["status"] as? String ?? "auto_confirmed"
        let status = PaymentStatus(rawValue: statusStr) ?? .autoConfirmed

        let methodStr = data["paymentMethod"] as? String ?? "other"
        let paymentMethod = PaymentMethod(rawValue: methodStr) ?? .other

        let confirmedBy = data["confirmedBy"] as? String
        let confirmedAt = (data["confirmedAt"] as? Timestamp)?.dateValue()
        let externalTransactionId = data["externalTransactionId"] as? String

        let settledSplitsData = data["settledSplits"] as? [[String: Any]] ?? []
        let settledSplits = settledSplitsData.compactMap { SettledSplitInfo.fromFirestore($0) }

        return Payment(
            id: id,
            houseId: houseId,
            fromUserId: fromUserId,
            fromUserName: fromUserName,
            toUserId: toUserId,
            toUserName: toUserName,
            amount: amount,
            expenseIds: expenseIds,
            settledSplits: settledSplits,
            note: note,
            timestamp: timestampValue.dateValue(),
            status: status,
            confirmedBy: confirmedBy,
            confirmedAt: confirmedAt,
            paymentMethod: paymentMethod,
            externalTransactionId: externalTransactionId
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

// MARK: - Payment Status

enum PaymentStatus: String, Codable {
    case pending = "pending"           // Just recorded, awaiting confirmation
    case confirmed = "confirmed"       // Payee confirmed receipt
    case disputed = "disputed"         // Issue reported
    case autoConfirmed = "auto_confirmed"  // Auto-confirmed or no confirmation required
}

// MARK: - Payment Method

enum PaymentMethod: String, Codable, CaseIterable {
    case cash = "cash"
    case venmo = "venmo"
    case zelle = "zelle"
    case cashApp = "cash_app"
    case bankTransfer = "bank_transfer"
    case check = "check"
    case other = "other"

    var displayName: String {
        switch self {
        case .cash: return "Cash"
        case .venmo: return "Venmo"
        case .zelle: return "Zelle"
        case .cashApp: return "Cash App"
        case .bankTransfer: return "Bank Transfer"
        case .check: return "Check"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .cash: return "dollarsign.circle.fill"
        case .venmo: return "v.circle.fill"
        case .zelle: return "z.circle.fill"
        case .cashApp: return "dollarsign.square.fill"
        case .bankTransfer: return "building.columns.fill"
        case .check: return "doc.text.fill"
        case .other: return "creditcard.fill"
        }
    }

    var supportsExternalId: Bool {
        return [.venmo, .zelle, .cashApp, .bankTransfer].contains(self)
    }
}

// MARK: - Settled Split Info

struct SettledSplitInfo: Codable, Equatable, Identifiable {
    var id: String { expenseId + splitUserId }
    let expenseId: String
    let expenseDescription: String
    let splitUserId: String  // Which user's split was settled
    let originalSplitAmount: Double  // Track original amount
    let amountSettled: Double
    let remainingAfterPayment: Double  // What's left after this payment
    let wasPartialPayment: Bool

    var asDictionary: [String: Any] {
        return [
            "expenseId": expenseId,
            "expenseDescription": expenseDescription,
            "splitUserId": splitUserId,
            "originalSplitAmount": originalSplitAmount,
            "amountSettled": amountSettled,
            "remainingAfterPayment": remainingAfterPayment,
            "wasPartialPayment": wasPartialPayment
        ]
    }

    static func fromFirestore(_ data: [String: Any]) -> SettledSplitInfo? {
        guard let expenseId = data["expenseId"] as? String,
              let expenseDescription = data["expenseDescription"] as? String,
              let splitUserId = data["splitUserId"] as? String,
              let originalSplitAmount = data["originalSplitAmount"] as? Double,
              let amountSettled = data["amountSettled"] as? Double,
              let remainingAfterPayment = data["remainingAfterPayment"] as? Double,
              let wasPartialPayment = data["wasPartialPayment"] as? Bool else {
            return nil
        }

        return SettledSplitInfo(
            expenseId: expenseId,
            expenseDescription: expenseDescription,
            splitUserId: splitUserId,
            originalSplitAmount: originalSplitAmount,
            amountSettled: amountSettled,
            remainingAfterPayment: remainingAfterPayment,
            wasPartialPayment: wasPartialPayment
        )
    }
}

// MARK: - Balance Summary

struct Balance: Identifiable {
    var id: String { userId }
    let userId: String
    let userName: String
    var owedToYou: Double  // Money they owe you (GROSS)
    var youOwe: Double     // Money you owe them (GROSS)

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

// MARK: - Balance Detail (NET vs GROSS)

struct BalanceDetail {
    let netBalance: Double          // +$10 (you're owed) or -$10 (you owe)
    let grossOwed: Double           // $50 - what you owe them
    let grossOwedToYou: Double      // $40 - what they owe you
    let unpaidExpensesYouOwe: [Expense]        // Expenses where you owe them
    let unpaidExpensesTheyOweYou: [Expense]    // Expenses where they owe you

    var formattedNetBalance: String {
        return String(format: "$%.2f", abs(netBalance))
    }

    var formattedGrossOwed: String {
        return String(format: "$%.2f", grossOwed)
    }

    var formattedGrossOwedToYou: String {
        return String(format: "$%.2f", grossOwedToYou)
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
