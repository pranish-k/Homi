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
                    return
                }

                guard let documents = snapshot?.documents else {
                    self.isLoading = false
                    return
                }

                self.expenses = documents.compactMap { doc in
                    Expense.fromFirestore(doc.data())
                }

                self.isLoading = false
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

    /// Delete an expense
    func deleteExpense(houseId: String, expenseId: String) async throws {
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
        guard var expense = Expense.fromFirestore(document.data() ?? [:]) else {
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

    /// Record a payment
    func recordPayment(payment: Payment) async throws {
        let batch = db.batch()

        // Add payment document
        let paymentRef = db.collection(Constants.Collections.houses)
            .document(payment.houseId)
            .collection(Constants.Collections.payments)
            .document(payment.id)

        batch.setData(payment.asDictionary, forDocument: paymentRef)

        // Mark related expense splits as paid
        for expenseId in payment.expenseIds {
            let expenseRef = db.collection(Constants.Collections.houses)
                .document(payment.houseId)
                .collection(Constants.Collections.expenses)
                .document(expenseId)

            // Get expense and update split
            let expenseDoc = try await expenseRef.getDocument()
            if var expense = Expense.fromFirestore(expenseDoc.data() ?? [:]) {
                var updatedSplits = expense.splits
                if let index = updatedSplits.firstIndex(where: { $0.userId == payment.fromUserId }) {
                    updatedSplits[index] = ExpenseSplit(
                        userId: updatedSplits[index].userId,
                        userName: updatedSplits[index].userName,
                        amount: updatedSplits[index].amount,
                        isPaid: true
                    )
                }

                let allPaid = updatedSplits.allSatisfy { $0.isPaid }

                batch.updateData([
                    "splits": updatedSplits.map { $0.asDictionary },
                    "isSettled": allPaid
                ], forDocument: expenseRef)
            }
        }

        try await batch.commit()
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

        // Calculate from expenses
        for expense in expenses where !expense.isSettled {
            // If current user paid
            if expense.paidBy == currentUserId {
                for split in expense.splits where split.userId != currentUserId && !split.isPaid {
                    if var balance = balanceDict[split.userId] {
                        balance.owedToYou += split.amount
                        balanceDict[split.userId] = balance
                    }
                }
            }
            // If current user owes
            else if let currentUserSplit = expense.splits.first(where: { $0.userId == currentUserId && !$0.isPaid }) {
                if var balance = balanceDict[expense.paidBy] {
                    balance.youOwe += currentUserSplit.amount
                    balanceDict[expense.paidBy] = balance
                }
            }
        }

        return Array(balanceDict.values).filter { $0.netBalance != 0 }
    }

    /// Get total amount you owe
    func getTotalYouOwe(currentUserId: String) -> Double {
        var total = 0.0

        for expense in expenses where !expense.isSettled {
            if let currentUserSplit = expense.splits.first(where: { $0.userId == currentUserId && !$0.isPaid }) {
                total += currentUserSplit.amount
            }
        }

        return total
    }

    /// Get total amount owed to you
    func getTotalOwedToYou(currentUserId: String) -> Double {
        var total = 0.0

        for expense in expenses where !expense.isSettled && expense.paidBy == currentUserId {
            for split in expense.splits where split.userId != currentUserId && !split.isPaid {
                total += split.amount
            }
        }

        return total
    }

    // MARK: - Cleanup

    func stopListening() {
        expensesListener?.remove()
        paymentsListener?.remove()
        expensesListener = nil
        paymentsListener = nil
    }

    func clearExpenses() {
        expenses = []
        payments = []
        balances = []
    }
}
