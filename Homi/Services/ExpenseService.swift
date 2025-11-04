import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class ExpenseService: ObservableObject {
    static let shared = ExpenseService()

    @Published var expenses: [Expense] = []
    @Published var payments: [Payment] = []
    @Published var balances: [Balance] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var expensesListener: ListenerRegistration?
    private var paymentsListener: ListenerRegistration?
    private var currentHouseId: String?
    private var retryCount = 0
    private let maxRetries = 3
    private var retryTask: Task<Void, Never>?

    private init() {}

    // MARK: - Expense Operations

    /// Create a new expense
    func createExpense(expense: Expense) async throws {
        let expenseRef = db.collection(Constants.Collections.houses)
            .document(expense.houseId)
            .collection(Constants.Collections.expenses)
            .document(expense.id)

        try await expenseRef.setData(expense.asDictionary)
    }

    /// Get all expenses for a house
    func getExpenses(houseId: String) async throws -> [Expense] {
        let snapshot = try await db.collection(Constants.Collections.houses)
            .document(houseId)
            .collection(Constants.Collections.expenses)
            .order(by: "date", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            Expense.fromFirestore(doc.data())
        }
    }

    /// Start listening to expenses in real-time
    func startListeningToExpenses(houseId: String) {
        stopListening()
        currentHouseId = houseId
        retryCount = 0

        isLoading = true

        expensesListener = db.collection(Constants.Collections.houses)
            .document(houseId)
            .collection(Constants.Collections.expenses)
            .order(by: "date", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false

                    // Attempt to retry with exponential backoff
                    self.retryListenerWithBackoff(houseId: houseId)
                    return
                }

                guard let documents = snapshot?.documents else {
                    self.isLoading = false
                    return
                }

                self.expenses = documents.compactMap { doc in
                    Expense.fromFirestore(doc.data())
                }
                .filter { $0.deletedAt == nil } // Filter out soft-deleted expenses

                // Reset retry count on successful connection
                self.retryCount = 0
                self.isLoading = false
            }
    }

    /// Retry listener connection with exponential backoff
    private func retryListenerWithBackoff(houseId: String) {
        guard retryCount < maxRetries else {
            errorMessage = "Unable to connect. Please check your internet connection and try again."
            return
        }

        retryCount += 1
        let delay = pow(2.0, Double(retryCount)) // 2, 4, 8 seconds

        retryTask?.cancel()
        retryTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            if !Task.isCancelled {
                startListeningToExpenses(houseId: houseId)
            }
        }
    }

    /// Update an expense
    func updateExpense(houseId: String, expense: Expense) async throws {
        let expenseRef = db.collection(Constants.Collections.houses)
            .document(houseId)
            .collection(Constants.Collections.expenses)
            .document(expense.id)

        try await expenseRef.updateData(expense.asDictionary)
    }

    /// Soft delete an expense (marks as deleted but preserves data)
    /// This maintains financial audit trail and allows recovery if needed
    func deleteExpense(houseId: String, expenseId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ExpenseService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let expenseRef = db.collection(Constants.Collections.houses)
            .document(houseId)
            .collection(Constants.Collections.expenses)
            .document(expenseId)

        // Soft delete: mark as deleted instead of removing from database
        try await expenseRef.updateData([
            "deletedAt": Timestamp(date: Date()),
            "deletedBy": currentUserId
        ])
    }

    /// Hard delete an expense (permanent deletion - use with caution)
    /// Only for admin/cleanup purposes. Regular users should use soft delete.
    func permanentlyDeleteExpense(houseId: String, expenseId: String) async throws {
        try await db.collection(Constants.Collections.houses)
            .document(houseId)
            .collection(Constants.Collections.expenses)
            .document(expenseId)
            .delete()
    }

    /// Mark a split as paid
    func markSplitAsPaid(houseId: String, expenseId: String, userId: String) async throws {
        let expenseRef = db.collection(Constants.Collections.houses)
            .document(houseId)
            .collection(Constants.Collections.expenses)
            .document(expenseId)

        let document = try await expenseRef.getDocument()
        guard let expense = Expense.fromFirestore(document.data() ?? [:]) else {
            throw NSError(domain: "ExpenseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not parse expense"])
        }

        // Update the split
        var updatedSplits = expense.splits
        if let index = updatedSplits.firstIndex(where: { $0.userId == userId }) {
            updatedSplits[index] = ExpenseSplit(
                userId: updatedSplits[index].userId,
                userName: updatedSplits[index].userName,
                amount: updatedSplits[index].amount,
                isPaid: true
            )
        }

        // Check if all splits are paid
        let allPaid = updatedSplits.allSatisfy { $0.isPaid }

        // Update expense
        try await expenseRef.updateData([
            "splits": updatedSplits.map { $0.asDictionary },
            "isSettled": allPaid
        ])
    }

    // MARK: - Payment Operations

    /// Record a payment - simplified to just record the payment without updating expenses
    /// Expenses will be marked as paid separately when needed
    func recordPayment(payment: Payment) async throws {
        // Validate payment before processing
        guard payment.amount > 0 else {
            throw NSError(domain: "ExpenseService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Payment amount must be greater than 0"])
        }

        // Simply add the payment document
        let paymentRef = db.collection(Constants.Collections.houses)
            .document(payment.houseId)
            .collection(Constants.Collections.payments)
            .document(payment.id)

        try await paymentRef.setData(payment.asDictionary)
    }

    /// Get payment history for a house (returns cached data if listener is active)
    func getPaymentHistory(houseId: String) async throws -> [Payment] {
        // If we already have cached payments from the listener, return them
        if !payments.isEmpty && currentHouseId == houseId {
            return payments
        }

        // Otherwise, fetch from Firestore
        let snapshot = try await db.collection(Constants.Collections.houses)
            .document(houseId)
            .collection(Constants.Collections.payments)
            .order(by: "timestamp", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            Payment.fromFirestore(doc.data())
        }
    }

    /// Start listening to payments
    func startListeningToPayments(houseId: String) {
        paymentsListener = db.collection(Constants.Collections.houses)
            .document(houseId)
            .collection(Constants.Collections.payments)
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }

                guard let documents = snapshot?.documents else { return }

                self.payments = documents.compactMap { doc in
                    Payment.fromFirestore(doc.data())
                }
            }
    }

    // MARK: - Balance Calculations

    /// Calculate balances between current user and all other house members
    /// Optimized to filter unsettled expenses first and reduce iterations
    func calculateBalances(currentUserId: String, houseMembers: [HouseMember]) -> [Balance] {
        var balanceDict: [String: Balance] = [:]

        // Initialize balances for all members
        for member in houseMembers where member.userId != currentUserId {
            balanceDict[member.userId] = Balance(
                userId: member.userId,
                userName: member.displayName,
                owedToYou: 0,
                youOwe: 0
            )
        }

        // Filter unsettled expenses once to avoid checking isSettled repeatedly
        let unsettledExpenses = expenses.filter { !$0.isSettled }

        // Calculate from expenses
        for expense in unsettledExpenses {
            // If current user paid
            if expense.paidBy == currentUserId {
                // Use forEach instead of nested for-where for better performance
                expense.splits.forEach { split in
                    guard split.userId != currentUserId && !split.isPaid else { return }
                    balanceDict[split.userId]?.owedToYou += split.amount
                }
            }
            // If current user owes
            else if let currentUserSplit = expense.splits.first(where: { $0.userId == currentUserId && !$0.isPaid }) {
                balanceDict[expense.paidBy]?.youOwe += currentUserSplit.amount
            }
        }

        // Subtract recorded payments from balances
        for payment in payments {
            // If current user received payment
            if payment.toUserId == currentUserId {
                balanceDict[payment.fromUserId]?.owedToYou -= payment.amount
            }
            // If current user made payment
            else if payment.fromUserId == currentUserId {
                balanceDict[payment.toUserId]?.youOwe -= payment.amount
            }
        }

        // Filter out zero balances
        return balanceDict.values.filter { $0.netBalance != 0 }
    }

    /// Get total amount you owe (optimized with reduce)
    func getTotalYouOwe(currentUserId: String) -> Double {
        return expenses
            .filter { !$0.isSettled }
            .compactMap { expense in
                expense.splits.first(where: { $0.userId == currentUserId && !$0.isPaid })?.amount
            }
            .reduce(0, +)
    }

    /// Get total amount owed to you (optimized with reduce)
    func getTotalOwedToYou(currentUserId: String) -> Double {
        return expenses
            .filter { !$0.isSettled && $0.paidBy == currentUserId }
            .flatMap { expense in
                expense.splits.filter { $0.userId != currentUserId && !$0.isPaid }
            }
            .map(\.amount)
            .reduce(0, +)
    }

    // MARK: - Cleanup

    func stopListening() {
        retryTask?.cancel()
        retryTask = nil
        expensesListener?.remove()
        paymentsListener?.remove()
        expensesListener = nil
        paymentsListener = nil
        currentHouseId = nil
        retryCount = 0
    }

    func clearExpenses() {
        expenses = []
        payments = []
        balances = []
    }
}
