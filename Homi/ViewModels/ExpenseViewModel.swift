import SwiftUI
import Combine
import FirebaseAuth

@MainActor
class ExpenseViewModel: ObservableObject {
    @Published var expenses: [Expense] = []
    @Published var balances: [Balance] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    // Add expense form fields
    @Published var amount: String = ""
    @Published var description: String = ""
    @Published var selectedCategory: ExpenseCategory = .other
    @Published var selectedDate: Date = Date()
    @Published var selectedPayer: String = ""
    @Published var splitType: SplitType = .equal
    @Published var selectedParticipants: Set<String> = []
    @Published var customSplits: [String: String] = [:] // userId: amount

    private let expenseService = ExpenseService.shared
    private let authService = AuthService.shared
    private var cancellables = Set<AnyCancellable>()
    private var currentHouseId: String?

    var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    init() {
        // Subscribe to expense service
        expenseService.$expenses
            .assign(to: &$expenses)

        expenseService.$isLoading
            .assign(to: &$isLoading)

        expenseService.$errorMessage
            .sink { [weak self] error in
                if let error = error {
                    self?.errorMessage = error
                    self?.showError = true
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Lifecycle

    func startListening(houseId: String, houseMembers: [HouseMember]) {
        currentHouseId = houseId
        expenseService.startListeningToExpenses(houseId: houseId)
        expenseService.startListeningToPayments(houseId: houseId)

        // Calculate balances whenever expenses change
        expenseService.$expenses
            .sink { [weak self] _ in
                guard let self = self, let userId = self.currentUserId else { return }
                self.balances = self.expenseService.calculateBalances(currentUserId: userId, houseMembers: houseMembers)
            }
            .store(in: &cancellables)
    }

    func stopListening() {
        expenseService.stopListening()
    }

    // MARK: - Expense Operations

    func createExpense() async {
        guard let houseId = currentHouseId,
              let userId = currentUserId,
              let _ = authService.userProfile?.displayName else {
            errorMessage = "Missing required information"
            showError = true
            return
        }

        // Validate
        guard let amountValue = Double(amount), amountValue > 0 else {
            errorMessage = "Please enter a valid amount"
            showError = true
            return
        }

        guard !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter a description"
            showError = true
            return
        }

        guard !selectedPayer.isEmpty else {
            errorMessage = "Please select who paid"
            showError = true
            return
        }

        guard !selectedParticipants.isEmpty else {
            errorMessage = "Please select participants"
            showError = true
            return
        }

        // Get house members for names
        let members = try? await FirestoreService.shared.getHouseMembers(houseId: houseId)
        guard let members = members else {
            errorMessage = "Could not load house members"
            showError = true
            return
        }

        // Create splits
        let splits: [ExpenseSplit]

        if splitType == .equal {
            let splitAmount = amountValue / Double(selectedParticipants.count)
            splits = selectedParticipants.map { participantId in
                let member = members.first { $0.id == participantId }
                return ExpenseSplit(
                    userId: participantId,
                    userName: member?.displayName ?? "Unknown",
                    amount: splitAmount,
                    isPaid: participantId == selectedPayer
                )
            }
        } else {
            // Custom splits
            splits = selectedParticipants.compactMap { participantId in
                guard let amountStr = customSplits[participantId],
                      let splitAmount = Double(amountStr),
                      splitAmount > 0 else {
                    return nil
                }

                let member = members.first { $0.id == participantId }
                return ExpenseSplit(
                    userId: participantId,
                    userName: member?.displayName ?? "Unknown",
                    amount: splitAmount,
                    isPaid: participantId == selectedPayer
                )
            }

            // Validate custom splits sum to total
            let totalSplit = splits.reduce(0.0) { $0 + $1.amount }
            if abs(totalSplit - amountValue) > 0.01 {
                errorMessage = "Split amounts must add up to total amount"
                showError = true
                return
            }
        }

        let payerName = members.first { $0.id == selectedPayer }?.displayName ?? "Unknown"

        let expense = Expense(
            houseId: houseId,
            amount: amountValue,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            category: selectedCategory,
            date: selectedDate,
            paidBy: selectedPayer,
            paidByName: payerName,
            splits: splits,
            createdBy: userId
        )

        do {
            try await expenseService.createExpense(expense: expense)
            resetForm()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func deleteExpense(_ expense: Expense) async {
        guard let houseId = currentHouseId else { return }

        do {
            try await expenseService.deleteExpense(houseId: houseId, expenseId: expense.id)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func markAsPaid(expense: Expense, userId: String) async {
        guard let houseId = currentHouseId else { return }

        do {
            try await expenseService.markSplitAsPaid(houseId: houseId, expenseId: expense.id, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Payment Operations

    func recordPayment(to toUserId: String, toUserName: String, amount: Double, expenseIds: [String], note: String?) async {
        guard let houseId = currentHouseId,
              let fromUserId = currentUserId,
              let fromUserName = authService.userProfile?.displayName else {
            errorMessage = "Missing required information"
            showError = true
            return
        }

        let payment = Payment(
            houseId: houseId,
            fromUserId: fromUserId,
            fromUserName: fromUserName,
            toUserId: toUserId,
            toUserName: toUserName,
            amount: amount,
            expenseIds: expenseIds,
            note: note
        )

        do {
            try await expenseService.recordPayment(payment: payment)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Balance Calculations

    func getTotalYouOwe() -> Double {
        guard let userId = currentUserId else { return 0 }
        return expenseService.getTotalYouOwe(currentUserId: userId)
    }

    func getTotalOwedToYou() -> Double {
        guard let userId = currentUserId else { return 0 }
        return expenseService.getTotalOwedToYou(currentUserId: userId)
    }

    func getNetBalance() -> Double {
        return getTotalOwedToYou() - getTotalYouOwe()
    }

    // MARK: - Helpers

    func resetForm() {
        amount = ""
        description = ""
        selectedCategory = .other
        selectedDate = Date()
        selectedPayer = ""
        splitType = .equal
        selectedParticipants = []
        customSplits = [:]
    }

    func canDeleteExpense(_ expense: Expense) -> Bool {
        guard let userId = currentUserId else { return false }
        return expense.createdBy == userId
    }

    // Filter expenses
    func getRecentExpenses(limit: Int = 10) -> [Expense] {
        return Array(expenses.prefix(limit))
    }

    func getUnsettledExpenses() -> [Expense] {
        return expenses.filter { !$0.isSettled }
    }

    func getExpensesByCategory(_ category: ExpenseCategory) -> [Expense] {
        return expenses.filter { $0.category == category }
    }
}

// MARK: - Split Type

enum SplitType: String, CaseIterable {
    case equal = "Equal Split"
    case custom = "Custom Amounts"
}
