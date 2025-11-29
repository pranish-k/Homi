import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

// MARK: - Payment Errors

enum PaymentError: LocalizedError {
    case duplicatePayment
    case overpayment(requested: Double, actuallyOwed: Double)
    case invalidAmount(String)
    case invalidUsers(String)
    case noExpensesSelected
    case expenseNotFound(String)
    case expenseDeleted(String)
    case expenseAlreadySettled(String)
    case noUnpaidSplit(String)
    case networkTimeout
    case batchCommitFailed(Error)
    case optimisticUpdateFailed
    case tooManyOperations
    case noBalanceFound

    var errorDescription: String? {
        switch self {
        case .duplicatePayment:
            return "This payment was already recorded. Please refresh."
        case .overpayment(let requested, let owed):
            return "Payment of $\(String(format: "%.2f", requested)) exceeds balance of $\(String(format: "%.2f", owed))"
        case .invalidAmount(let reason):
            return "Invalid amount: \(reason)"
        case .invalidUsers(let reason):
            return "Invalid users: \(reason)"
        case .noExpensesSelected:
            return "Please select at least one expense to settle"
        case .expenseNotFound(let id):
            return "Expense \(id) not found. It may have been deleted."
        case .expenseDeleted(let id):
            return "Expense \(id) has been deleted and cannot be settled"
        case .expenseAlreadySettled(let id):
            return "Expense \(id) is already settled"
        case .noUnpaidSplit(let id):
            return "You have no unpaid split in expense \(id)"
        case .networkTimeout:
            return "Network timeout. Check your connection and try again."
        case .batchCommitFailed(let error):
            return "Payment recording failed: \(error.localizedDescription)"
        case .optimisticUpdateFailed:
            return "Failed to update local state. Please refresh."
        case .tooManyOperations:
            return "Too many expenses selected. Please split into multiple payments."
        case .noBalanceFound:
            return "No balance found with this user"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .duplicatePayment:
            return "Refresh the page to see the existing payment"
        case .overpayment:
            return "Adjust the amount or select fewer expenses"
        case .networkTimeout:
            return "Check your internet connection and try again"
        case .expenseNotFound, .expenseDeleted:
            return "Refresh the expense list and try again"
        case .tooManyOperations:
            return "Try settling fewer expenses at a time"
        default:
            return "Please try again or contact support if the issue persists"
        }
    }
}

// MARK: - Allocation Strategy

enum AllocationStrategy {
    case chronological  // Pay oldest expenses first (default)
    case largest        // Pay largest expenses first
    case smart          // Smart offset algorithm
}

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

    /// Update an expense with transaction for atomic operation
    func updateExpense(houseId: String, expense: Expense) async throws {
        let expenseRef = db.collection(Constants.Collections.houses)
            .document(houseId)
            .collection(Constants.Collections.expenses)
            .document(expense.id)

        // Use transaction for atomic update
        try await db.runTransaction({ (transaction, errorPointer) -> Any? in
            let document: DocumentSnapshot
            do {
                document = try transaction.getDocument(expenseRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }

            // Verify expense exists and not deleted
            guard let data = document.data(),
                  data["deletedAt"] == nil else {
                let error = NSError(
                    domain: "ExpenseService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Expense not found or already deleted"]
                )
                errorPointer?.pointee = error
                return nil
            }

            // Update with audit trail
            var updateData = expense.asDictionary
            updateData["lastModifiedAt"] = Timestamp()
            updateData["lastModifiedBy"] = Auth.auth().currentUser?.uid ?? "unknown"

            transaction.setData(updateData, forDocument: expenseRef, merge: true)

            return nil
        })

        // Invalidate cache
        ExpenseCacheService.shared.invalidateCache(for: "balances")
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

        // Use transaction for soft delete
        try await db.runTransaction({ (transaction, errorPointer) -> Any? in
            let document: DocumentSnapshot
            do {
                document = try transaction.getDocument(expenseRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }

            // Check if already deleted
            if let deletedAt = document.data()?["deletedAt"] as? Timestamp {
                print("Expense already deleted at: \(deletedAt.dateValue())")
                return nil
            }

            // Soft delete with audit trail
            transaction.updateData([
                "deletedAt": Timestamp(),
                "deletedBy": currentUserId,
                "lastModifiedAt": Timestamp()
            ], forDocument: expenseRef)

            return nil
        })

        // Invalidate cache
        ExpenseCacheService.shared.invalidateCache(for: "balances")
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

    /// Mark a split as paid (with transaction to prevent race conditions)
    func markSplitAsPaid(houseId: String, expenseId: String, userId: String) async throws {
        let expenseRef = db.collection(Constants.Collections.houses)
            .document(houseId)
            .collection(Constants.Collections.expenses)
            .document(expenseId)

        // Use Firestore transaction to prevent race conditions
        _ = try await db.runTransaction({ (transaction, errorPointer) -> Any? in
            // Read the expense document within the transaction
            let document: DocumentSnapshot
            do {
                document = try transaction.getDocument(expenseRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }

            // Parse the expense
            guard let data = document.data(),
                  let expense = Expense.fromFirestore(data) else {
                let error = NSError(
                    domain: "ExpenseService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Could not parse expense"]
                )
                errorPointer?.pointee = error
                return nil
            }

            // Check if already settled
            if expense.isSettled {
                print("Expense already settled, no action needed")
                return nil
            }

            // Update splits atomically
            var updatedSplits = expense.splits
            var splitUpdated = false

            for (index, split) in updatedSplits.enumerated() {
                if split.userId == userId && !split.isPaid {
                    updatedSplits[index] = ExpenseSplit(
                        userId: split.userId,
                        userName: split.userName,
                        amount: split.amount,
                        isPaid: true
                    )
                    splitUpdated = true
                    break
                }
            }

            // Only proceed if we actually updated a split
            guard splitUpdated else {
                print("Split already marked as paid or not found for user: \(userId)")
                return nil
            }

            // Check if all splits are now paid
            let allPaid = updatedSplits.allSatisfy { $0.isPaid }

            // Prepare update data
            var updateData: [String: Any] = [
                "splits": updatedSplits.map { $0.asDictionary },
                "lastModifiedAt": Timestamp(),
                "lastModifiedBy": AuthService.shared.user?.uid ?? "unknown"
            ]

            if allPaid {
                updateData["isSettled"] = true
            }

            // Update the document atomically
            transaction.updateData(updateData, forDocument: expenseRef)

            print("Successfully marked split as paid for user: \(userId)")
            return nil
        })

        // Invalidate balance cache after successful update
        ExpenseCacheService.shared.invalidateCache(for: "balances")
    }

    // MARK: - Payment Operations

    /// Enhanced payment recording with atomic expense settlement
    /// This is the main entry point for recording payments
    func recordPaymentWithSettlement(
        fromUserId: String,
        fromUserName: String,
        toUserId: String,
        toUserName: String,
        amount: Double,
        selectedExpenseIds: [String],
        paymentMethod: PaymentMethod,
        externalTransactionId: String? = nil,
        note: String? = nil,
        houseId: String,
        strategy: AllocationStrategy = .smart
    ) async throws -> Payment {
        // Validation
        try await validatePayment(
            amount: amount,
            fromUserId: fromUserId,
            toUserId: toUserId,
            expenseIds: selectedExpenseIds,
            houseId: houseId
        )

        // Calculate which splits will be settled
        let settledSplits = try await calculateSplitSettlement(
            amount: amount,
            expenseIds: selectedExpenseIds,
            payerId: fromUserId,
            payeeId: toUserId,
            houseId: houseId,
            strategy: strategy
        )

        // Get house settings for payment status
        let house = try await FirestoreService.shared.getHouse(id: houseId)
        let initialStatus: PaymentStatus = house?.settings.requirePaymentConfirmation == true ? .pending : .autoConfirmed

        // Create payment object
        let payment = Payment(
            houseId: houseId,
            fromUserId: fromUserId,
            fromUserName: fromUserName,
            toUserId: toUserId,
            toUserName: toUserName,
            amount: amount,
            expenseIds: selectedExpenseIds,
            settledSplits: settledSplits,
            note: note,
            status: initialStatus,
            confirmedBy: initialStatus == .autoConfirmed ? fromUserId : nil,
            confirmedAt: initialStatus == .autoConfirmed ? Date() : nil,
            paymentMethod: paymentMethod,
            externalTransactionId: externalTransactionId
        )

        // Check for duplicates
        try await checkForDuplicatePayment(payment: payment)

        // Record payment atomically with expense updates
        try await recordPaymentAtomic(payment: payment, settledSplits: settledSplits)

        print("✅ Payment recorded successfully: \(payment.id)")
        return payment
    }

    /// Atomic payment recording with expense split updates
    private func recordPaymentAtomic(
        payment: Payment,
        settledSplits: [SettledSplitInfo]
    ) async throws {
        // Fetch and prepare all expense updates first
        var expenseUpdates: [(ref: DocumentReference, expense: Expense)] = []

        for split in settledSplits {
            let expenseRef = db.collection(Constants.Collections.houses)
                .document(payment.houseId)
                .collection(Constants.Collections.expenses)
                .document(split.expenseId)

            let doc = try await expenseRef.getDocument()
            guard var expense = try? doc.data(as: Expense.self) else {
                throw PaymentError.expenseNotFound(split.expenseId)
            }

            // Update the specific split with append-only approach
            if let splitIndex = expense.splits.firstIndex(where: { $0.userId == split.splitUserId }) {
                // Create partial payment record
                let partialPaymentRecord = PartialPaymentRecord(
                    paymentId: payment.id,
                    amount: split.amountSettled,
                    timestamp: Date(),
                    paymentMethod: payment.paymentMethod
                )

                // Append payment to history
                var updatedSplit = expense.splits[splitIndex]
                updatedSplit.partialPayments.append(partialPaymentRecord)

                // Recalculate if fully paid
                if updatedSplit.isFullyPaid {
                    updatedSplit.isPaid = true
                }

                expense.splits[splitIndex] = updatedSplit
            }

            // Check if all splits are now paid
            expense.isSettled = expense.splits.allSatisfy { $0.isFullyPaid }

            // Update metadata
            expense.lastModifiedAt = Date()
            expense.lastModifiedBy = payment.fromUserId

            expenseUpdates.append((expenseRef, expense))
        }

        // Now perform atomic batch write
        let batch = db.batch()

        // 1. Add payment
        let paymentRef = db.collection(Constants.Collections.houses)
            .document(payment.houseId)
            .collection(Constants.Collections.payments)
            .document(payment.id)

        try batch.setData(from: payment, forDocument: paymentRef)

        // 2. Update all expenses
        for (ref, expense) in expenseUpdates {
            try batch.setData(from: expense, forDocument: ref)
        }

        // 3. Check batch size limit
        guard expenseUpdates.count < 499 else {  // Firestore limit is 500
            throw PaymentError.tooManyOperations
        }

        // 4. Commit atomically
        try await batch.commit()

        // 5. Invalidate cache
        ExpenseCacheService.shared.invalidateCache(for: "balances")
    }

    /// Check for duplicate payment within 10-second window
    private func checkForDuplicatePayment(payment: Payment) async throws {
        let tenSecondsAgo = Timestamp(date: Date().addingTimeInterval(-10))
        let recentPayments = try await db.collection(Constants.Collections.houses)
            .document(payment.houseId)
            .collection(Constants.Collections.payments)
            .whereField("idempotencyKey", isEqualTo: payment.idempotencyKey)
            .whereField("timestamp", isGreaterThan: tenSecondsAgo)
            .getDocuments()

        if !recentPayments.documents.isEmpty {
            print("Duplicate payment detected: \(payment.idempotencyKey)")
            throw PaymentError.duplicatePayment
        }
    }

    /// Legacy method for backward compatibility
    func recordPayment(payment: Payment) async throws {
        guard payment.amount > 0 else {
            throw PaymentError.invalidAmount("Payment amount must be greater than zero")
        }

        try await checkForDuplicatePayment(payment: payment)

        // Use Firestore transaction for atomicity
        _ = try await db.runTransaction { transaction, errorPointer in
            let paymentRef = self.db.collection(Constants.Collections.houses)
                .document(payment.houseId)
                .collection(Constants.Collections.payments)
                .document(payment.id)

            // Check if payment exists
            let doc = try? transaction.getDocument(paymentRef)
            if doc?.exists == true {
                print("Payment already exists: \(payment.id)")
                return nil
            }

            transaction.setData(payment.asDictionary, forDocument: paymentRef)
            return nil
        }

        // Invalidate cache
        ExpenseCacheService.shared.invalidateCache(for: "balances")
    }

    // Helper method for cached house members
    private func getCachedHouseMembers() async -> [HouseMember] {
        // Return cached members or fetch if needed
        guard let houseId = AuthService.shared.userProfile?.currentHouseId else {
            return []
        }

        do {
            return try await FirestoreService.shared.getHouseMembers(houseId: houseId)
        } catch {
            print("Failed to get house members: \(error)")
            return []
        }
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
    func calculateBalances(currentUserId: String, houseMembers: [HouseMember]) async -> [Balance] {
        // Check cache first for performance
        if let cachedBalances = ExpenseCacheService.shared.getCachedBalances(for: currentUserId) {
            print("Returning cached balances for user: \(currentUserId)")
            return cachedBalances
        }

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

        // Convert dictionary to array and filter out zero balances
        let balances = balanceDict.values
            .filter { abs($0.netBalance) > 0.01 } // Filter out near-zero balances
            .sorted { abs($0.netBalance) > abs($1.netBalance) }

        // Cache the calculated balances
        ExpenseCacheService.shared.cacheBalances(balances, for: currentUserId)

        return balances
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

    // MARK: - Payment Helper Methods

    /// Validate payment before recording
    private func validatePayment(
        amount: Double,
        fromUserId: String,
        toUserId: String,
        expenseIds: [String],
        houseId: String
    ) async throws {
        // Amount validation
        guard amount > 0 else {
            throw PaymentError.invalidAmount("Amount must be positive")
        }

        guard amount < 1_000_000 else {
            throw PaymentError.invalidAmount("Amount exceeds maximum ($1M)")
        }

        // User validation
        guard fromUserId != toUserId else {
            throw PaymentError.invalidUsers("Cannot pay yourself")
        }

        guard !fromUserId.isEmpty && !toUserId.isEmpty else {
            throw PaymentError.invalidUsers("User IDs cannot be empty")
        }

        // Expense validation
        guard !expenseIds.isEmpty else {
            throw PaymentError.noExpensesSelected
        }
    }

    /// Calculate which expense splits will be settled by this payment
    private func calculateSplitSettlement(
        amount: Double,
        expenseIds: [String],
        payerId: String,
        payeeId: String,
        houseId: String,
        strategy: AllocationStrategy
    ) async throws -> [SettledSplitInfo] {
        var remaining = amount
        var settled: [SettledSplitInfo] = []

        // Fetch all expenses
        var expenses: [Expense] = []
        for expenseId in expenseIds {
            let expenseRef = db.collection(Constants.Collections.houses)
                .document(houseId)
                .collection(Constants.Collections.expenses)
                .document(expenseId)

            let doc = try await expenseRef.getDocument()
            guard let expense = try? doc.data(as: Expense.self) else {
                throw PaymentError.expenseNotFound(expenseId)
            }

            // Validate expense
            guard expense.deletedAt == nil else {
                throw PaymentError.expenseDeleted(expenseId)
            }

            expenses.append(expense)
        }

        // Sort expenses based on strategy
        let sortedExpenses = sortExpenses(expenses, by: strategy, payerId: payerId, payeeId: payeeId)

        // Allocate payment to splits
        for expense in sortedExpenses {
            guard remaining > 0.01 else { break }  // Account for floating point

            // Find unpaid split for the payer
            guard let split = expense.splits.first(where: {
                $0.userId == payerId && $0.remainingAmount > 0.01
            }) else { continue }

            let amountToSettle = min(split.remainingAmount, remaining)
            let remainingAfter = split.remainingAmount - amountToSettle

            settled.append(SettledSplitInfo(
                expenseId: expense.id,
                expenseDescription: expense.description,
                splitUserId: payerId,
                originalSplitAmount: split.amount,
                amountSettled: amountToSettle,
                remainingAfterPayment: remainingAfter,
                wasPartialPayment: remainingAfter > 0.01
            ))

            remaining -= amountToSettle
        }

        // Warn if not all amount was allocated
        if remaining > 0.01 {
            print("⚠️ Warning: $\(remaining) of payment not allocated to any expense")
        }

        return settled
    }

    /// Sort expenses by allocation strategy
    private func sortExpenses(
        _ expenses: [Expense],
        by strategy: AllocationStrategy,
        payerId: String,
        payeeId: String
    ) -> [Expense] {
        switch strategy {
        case .chronological:
            return expenses.sorted { $0.date < $1.date }

        case .largest:
            return expenses.sorted { expense1, expense2 in
                let amount1 = expense1.splits.first(where: { $0.userId == payerId })?.remainingAmount ?? 0
                let amount2 = expense2.splits.first(where: { $0.userId == payerId })?.remainingAmount ?? 0
                return amount1 > amount2
            }

        case .smart:
            // Smart offset: prioritize expenses where payer owes, then where they're owed
            return expenses.sorted { expense1, expense2 in
                let exp1PayerOwes = (expense1.paidBy == payeeId)
                let exp2PayerOwes = (expense2.paidBy == payeeId)

                if exp1PayerOwes == exp2PayerOwes {
                    // Same category, sort by date
                    return expense1.date < expense2.date
                }
                // Prioritize expenses where payer owes money
                return exp1PayerOwes && !exp2PayerOwes
            }
        }
    }

    /// Get detailed balance information between two users (NET vs GROSS)
    func getBalanceDetail(
        forUser userId: String,
        withUser otherUserId: String,
        inHouse houseId: String
    ) async throws -> BalanceDetail {
        // Fetch all unpaid expenses
        let allExpenses = self.expenses.filter { $0.deletedAt == nil && !$0.isSettled }

        var youOweGross: Double = 0
        var theyOweYouGross: Double = 0
        var unpaidExpensesYouOwe: [Expense] = []
        var unpaidExpensesTheyOweYou: [Expense] = []

        for expense in allExpenses {
            // What you owe them
            if expense.paidBy == otherUserId {
                if let yourSplit = expense.splits.first(where: {
                    $0.userId == userId && $0.remainingAmount > 0.01
                }) {
                    youOweGross += yourSplit.remainingAmount
                    unpaidExpensesYouOwe.append(expense)
                }
            }

            // What they owe you
            if expense.paidBy == userId {
                if let theirSplit = expense.splits.first(where: {
                    $0.userId == otherUserId && $0.remainingAmount > 0.01
                }) {
                    theyOweYouGross += theirSplit.remainingAmount
                    unpaidExpensesTheyOweYou.append(expense)
                }
            }
        }

        // Subtract pending payments
        let pendingPayments = self.payments.filter { $0.status != .disputed }
        for payment in pendingPayments {
            if payment.fromUserId == userId && payment.toUserId == otherUserId {
                youOweGross -= payment.amount
            } else if payment.fromUserId == otherUserId && payment.toUserId == userId {
                theyOweYouGross -= payment.amount
            }
        }

        let netBalance = theyOweYouGross - youOweGross

        return BalanceDetail(
            netBalance: netBalance,
            grossOwed: max(0, youOweGross),
            grossOwedToYou: max(0, theyOweYouGross),
            unpaidExpensesYouOwe: unpaidExpensesYouOwe,
            unpaidExpensesTheyOweYou: unpaidExpensesTheyOweYou
        )
    }

    /// Calculate smart settlement for "Settle Full Balance" button
    func calculateSmartSettlement(
        paymentAmount: Double,
        balanceDetail: BalanceDetail,
        payerId: String,
        payeeId: String
    ) -> [String] {
        var remaining = paymentAmount
        var selectedExpenseIds: [String] = []

        // Step 1: Offset what they owe you first
        for expense in balanceDetail.unpaidExpensesTheyOweYou.sorted(by: { $0.date < $1.date }) {
            guard remaining > 0.01 else { break }

            if let split = expense.splits.first(where: {
                $0.userId == payeeId && $0.remainingAmount > 0.01
            }) {
                let amountToOffset = min(split.remainingAmount, remaining)
                selectedExpenseIds.append(expense.id)
                remaining -= amountToOffset
            }
        }

        // Step 2: Apply to what you owe them
        for expense in balanceDetail.unpaidExpensesYouOwe.sorted(by: { $0.date < $1.date }) {
            guard remaining > 0.01 else { break }

            if let split = expense.splits.first(where: {
                $0.userId == payerId && $0.remainingAmount > 0.01
            }) {
                let amountToSettle = min(split.remainingAmount, remaining)
                selectedExpenseIds.append(expense.id)
                remaining -= amountToSettle
            }
        }

        return selectedExpenseIds
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
