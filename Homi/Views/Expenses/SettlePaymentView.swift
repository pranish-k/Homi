import SwiftUI

struct SettlePaymentView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ExpenseViewModel
    let balance: Balance

    @State private var note: String = ""

    private var formattedAmount: String {
        String(format: "$%.2f", abs(balance.netBalance))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: Constants.Spacing.medium) {
                        // Icon
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(Constants.Colors.primary)

                        // Amount
                        VStack(spacing: 4) {
                            Text("Settle Payment")
                                .font(.headline)
                                .foregroundColor(Constants.Colors.textSecondary)

                            Text(formattedAmount)
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(Constants.Colors.textPrimary)
                        }

                        // Payment direction
                        HStack(spacing: Constants.Spacing.small) {
                            Text("You")
                                .fontWeight(.semibold)

                            Image(systemName: "arrow.right")
                                .foregroundColor(Constants.Colors.textSecondary)

                            Text(balance.userName)
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                        .foregroundColor(Constants.Colors.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Constants.Spacing.medium)
                }

                Section("Payment Details") {
                    VStack(alignment: .leading, spacing: Constants.Spacing.small) {
                        Text("Settling up with \(balance.userName)")
                            .font(.headline)

                        Text("This will mark your portion as paid for all outstanding expenses with this person.")
                            .font(.caption)
                            .foregroundColor(Constants.Colors.textSecondary)
                    }
                }

                Section("Note (Optional)") {
                    TextField("Add a note...", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button {
                        Task {
                            await settleBalance()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Label("Confirm Payment", systemImage: "checkmark.circle.fill")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settle Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
        }
    }

    private func settleBalance() async {
        // Get all unsettled expenses where current user owes this person
        let relevantExpenses = viewModel.expenses.filter { expense in
            !expense.isSettled &&
            expense.paidBy == balance.userId &&
            expense.splits.contains { $0.userId == viewModel.currentUserId && !$0.isPaid }
        }

        let expenseIds = relevantExpenses.map { $0.id }

        await viewModel.recordPayment(
            to: balance.userId,
            toUserName: balance.userName,
            amount: abs(balance.netBalance),
            expenseIds: expenseIds,
            note: note.isEmpty ? nil : note
        )

        if viewModel.errorMessage == nil {
            dismiss()
        }
    }
}

// MARK: - Preview

struct SettlePaymentView_Previews: PreviewProvider {
    static var previews: some View {
        SettlePaymentView(
            viewModel: ExpenseViewModel(),
            balance: Balance(userId: "1", userName: "John Doe", owedToYou: 0, youOwe: 50.00)
        )
    }
}
