import SwiftUI
import Combine
import FirebaseAuth

// MARK: - Settle Up Sheet

struct SettleUpSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: SettleUpViewModel

    let balance: Balance

    init(balance: Balance) {
        self.balance = balance
        _viewModel = StateObject(wrappedValue: SettleUpViewModel(balance: balance))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Constants.Spacing.large) {
                    // Amount to settle
                    amountSection

                    // Expenses being settled
                    if !viewModel.unsettledExpenses.isEmpty {
                        expensesSection
                    }

                    // Note field
                    noteSection

                    Spacer(minLength: Constants.Spacing.xxLarge)
                }
                .padding(Constants.Spacing.screenPadding)
            }
            .navigationTitle("Settle Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Constants.Colors.primary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Confirm") {
                        Task {
                            await settleUp()
                        }
                    }
                    .foregroundColor(Constants.Colors.primary)
                    .fontWeight(.semibold)
                    .disabled(viewModel.isSending)
                }
            }
            .alert("Payment Recorded", isPresented: $viewModel.showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your payment has been recorded successfully.")
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }

    // MARK: - Amount Section

    private var amountSection: some View {
        VStack(spacing: Constants.Spacing.medium) {
            // Large amount display
            VStack(spacing: Constants.Spacing.small) {
                Text("You're settling")
                    .font(Constants.Typography.subheadline)
                    .foregroundColor(Constants.Colors.textSecondary)

                Text(balance.formattedBalance)
                    .font(Constants.Typography.displayLarge)
                    .foregroundColor(Constants.Colors.danger)

                HStack(spacing: 4) {
                    Text("to")
                        .font(Constants.Typography.body)
                        .foregroundColor(Constants.Colors.textSecondary)

                    Text(balance.userName)
                        .font(Constants.Typography.bodyMedium)
                        .foregroundColor(Constants.Colors.textPrimary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Constants.Spacing.large)
        }
    }

    // MARK: - Expenses Section

    private var expensesSection: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.medium) {
            Text("Expenses Being Settled")
                .font(Constants.Typography.headline)
                .foregroundColor(Constants.Colors.textPrimary)
                .padding(.horizontal, 4)

            VStack(spacing: Constants.Spacing.small) {
                ForEach(viewModel.unsettledExpenses) { expense in
                    SettleUpExpenseRow(
                        expense: expense,
                        isSelected: viewModel.selectedExpenseIds.contains(expense.id),
                        onToggle: {
                            viewModel.toggleExpense(expense.id)
                        }
                    )
                }
            }

            // Summary
            HomiCard(shadowStyle: .subtle) {
                VStack(spacing: Constants.Spacing.small) {
                    HStack {
                        Text("Total Amount")
                            .font(Constants.Typography.bodyMedium)
                            .foregroundColor(Constants.Colors.textPrimary)

                        Spacer()

                        Text(CurrencyFormatter.format(amount: viewModel.totalSelectedAmount))
                            .font(Constants.Typography.title3)
                            .foregroundColor(Constants.Colors.textPrimary)
                    }

                    HStack {
                        Text("\(viewModel.selectedExpenseIds.count) expense\(viewModel.selectedExpenseIds.count == 1 ? "" : "s") selected")
                            .font(Constants.Typography.caption1)
                            .foregroundColor(Constants.Colors.textSecondary)

                        Spacer()
                    }
                }
                .padding(Constants.Spacing.cardPadding)
            }
        }
    }

    // MARK: - Note Section

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.small) {
            Text("Note (Optional)")
                .font(Constants.Typography.subheadline)
                .foregroundColor(Constants.Colors.textSecondary)
                .padding(.horizontal, 4)

            HomiCard(shadowStyle: .subtle) {
                TextField("Add a note", text: $viewModel.note, axis: .vertical)
                    .font(Constants.Typography.body)
                    .lineLimit(3...6)
                    .padding(Constants.Spacing.cardPadding)
            }
        }
    }

    // MARK: - Settle Up

    private func settleUp() async {
        await viewModel.settleUp()
    }
}

// MARK: - Settle Up Expense Row

struct SettleUpExpenseRow: View {
    let expense: Expense
    let isSelected: Bool
    let onToggle: () -> Void

    @StateObject private var authService = AuthService.shared

    var amountOwed: Double {
        guard let currentUserId = authService.user?.uid,
              let split = expense.splits.first(where: { $0.userId == currentUserId }) else {
            return 0
        }
        return split.amount
    }

    var body: some View {
        Button(action: {
            HapticManager.selection()
            onToggle()
        }) {
            HomiCard(shadowStyle: isSelected ? .medium : .subtle) {
                HStack(spacing: Constants.Spacing.medium) {
                    // Checkbox
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundColor(isSelected ? Constants.Colors.primary : Constants.Colors.textSecondary)

                    // Expense details
                    VStack(alignment: .leading, spacing: 4) {
                        Text(expense.description)
                            .font(Constants.Typography.body)
                            .foregroundColor(Constants.Colors.textPrimary)
                            .lineLimit(1)

                        HStack(spacing: 4) {
                            HomiBadge(
                                expense.category.rawValue,
                                style: .neutral,
                                size: .small
                            )

                            Text("•")
                                .font(Constants.Typography.caption2)
                                .foregroundColor(Constants.Colors.textSecondary)

                            Text(expense.shortDate)
                                .font(Constants.Typography.caption1)
                                .foregroundColor(Constants.Colors.textSecondary)
                        }
                    }

                    Spacer()

                    // Amount owed
                    Text(CurrencyFormatter.format(amount: amountOwed))
                        .font(Constants.Typography.bodyMedium)
                        .foregroundColor(Constants.Colors.textPrimary)
                }
                .padding(Constants.Spacing.cardPadding)
                .overlay(
                    RoundedRectangle(cornerRadius: Constants.CornerRadius.card)
                        .stroke(
                            isSelected ? Constants.Colors.primary.opacity(0.5) : Color.clear,
                            lineWidth: 2
                        )
                )
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Settle Up ViewModel

@MainActor
class SettleUpViewModel: ObservableObject {
    @Published var unsettledExpenses: [Expense] = []
    @Published var selectedExpenseIds: Set<String> = []
    @Published var note: String = ""
    @Published var isSending = false
    @Published var showSuccess = false
    @Published var errorMessage: String?

    private let balance: Balance
    private let expenseService = ExpenseService.shared
    private let authService = AuthService.shared

    var totalSelectedAmount: Double {
        unsettledExpenses
            .filter { selectedExpenseIds.contains($0.id) }
            .compactMap { expense in
                expense.splits.first(where: { $0.userId == authService.user?.uid })?.amount
            }
            .reduce(0, +)
    }

    init(balance: Balance) {
        self.balance = balance
        loadUnsettledExpenses()
    }

    private func loadUnsettledExpenses() {
        guard let currentUserId = authService.user?.uid else { return }

        // Filter unsettled expenses where current user owes the other person
        unsettledExpenses = expenseService.expenses.filter { expense in
            !expense.isSettled &&
            expense.paidBy == balance.userId &&
            expense.splits.contains(where: { $0.userId == currentUserId && !$0.isPaid })
        }

        // Auto-select all expenses by default
        selectedExpenseIds = Set(unsettledExpenses.map { $0.id })
    }

    func toggleExpense(_ expenseId: String) {
        if selectedExpenseIds.contains(expenseId) {
            selectedExpenseIds.remove(expenseId)
        } else {
            selectedExpenseIds.insert(expenseId)
        }
    }

    func settleUp() async {
        guard let currentUserId = authService.user?.uid,
              let currentUserName = authService.userProfile?.displayName,
              let houseId = authService.userProfile?.currentHouseId,
              !selectedExpenseIds.isEmpty else {
            return
        }

        isSending = true

        do {
            let payment = Payment(
                houseId: houseId,
                fromUserId: currentUserId,
                fromUserName: currentUserName,
                toUserId: balance.userId,
                toUserName: balance.userName,
                amount: totalSelectedAmount,
                expenseIds: Array(selectedExpenseIds),
                note: note.isEmpty ? nil : note
            )

            try await expenseService.recordPayment(payment: payment)

            HapticManager.success()
            showSuccess = true
        } catch {
            HapticManager.error()
            errorMessage = error.localizedDescription
        }

        isSending = false
    }
}

// MARK: - Preview

#Preview {
    SettleUpSheet(
        balance: Balance(
            userId: "user1",
            userName: "John Doe",
            owedToYou: 0,
            youOwe: 45.50
        )
    )
}
