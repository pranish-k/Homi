import SwiftUI

struct ExpenseCardView: View {
    let expense: Expense
    let currentUserId: String
    var onDelete: (() -> Void)?
    var onTapSplit: ((ExpenseSplit) -> Void)?

    private var userSplit: ExpenseSplit? {
        expense.splits.first { $0.userId == currentUserId }
    }

    private var isPaidByCurrentUser: Bool {
        expense.paidBy == currentUserId
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.small) {
            // Header
            HStack(alignment: .top) {
                // Category icon
                Image(systemName: expense.category.icon)
                    .font(.title3)
                    .foregroundColor(categoryColor)
                    .frame(width: 36, height: 36)
                    .background(categoryColor.opacity(0.1))
                    .cornerRadius(Constants.CornerRadius.small)

                VStack(alignment: .leading, spacing: 4) {
                    Text(expense.description)
                        .font(.headline)
                        .foregroundColor(Constants.Colors.textPrimary)

                    Text(expense.category.rawValue)
                        .font(.caption)
                        .foregroundColor(Constants.Colors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(expense.formattedAmount)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(Constants.Colors.textPrimary)

                    Text(expense.shortDate)
                        .font(.caption)
                        .foregroundColor(Constants.Colors.textSecondary)
                }
            }

            Divider()
                .padding(.vertical, Constants.Spacing.xxSmall)

            // Split info
            HStack {
                // Who paid
                HStack(spacing: 4) {
                    Image(systemName: "creditcard.fill")
                        .font(.caption)
                        .foregroundColor(Constants.Colors.textSecondary)

                    if isPaidByCurrentUser {
                        Text("You paid")
                            .font(.subheadline)
                            .foregroundColor(Constants.Colors.success)
                    } else {
                        Text("Paid by \(expense.paidByName)")
                            .font(.subheadline)
                            .foregroundColor(Constants.Colors.textSecondary)
                    }
                }

                Spacer()

                // Current user's share
                if let userSplit = userSplit {
                    if !userSplit.isPaid {
                        HStack(spacing: 4) {
                            Text("You owe")
                                .font(.caption)
                                .foregroundColor(Constants.Colors.textSecondary)

                            Text(userSplit.formattedAmount)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(Constants.Colors.danger)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Constants.Colors.success)
                                .font(.caption)

                            Text("Paid")
                                .font(.subheadline)
                                .foregroundColor(Constants.Colors.success)
                        }
                    }
                }
            }

            // Show status for expenses current user paid
            if isPaidByCurrentUser && !expense.isSettled {
                let unpaidCount = expense.splits.filter { !$0.isPaid && $0.userId != currentUserId }.count
                if unpaidCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                            .foregroundColor(Constants.Colors.warning)

                        Text("\(unpaidCount) \(unpaidCount == 1 ? "person" : "people") haven't paid yet")
                            .font(.caption)
                            .foregroundColor(Constants.Colors.warning)
                    }
                    .padding(.top, Constants.Spacing.xxSmall)
                }
            }

            // Settled badge
            if expense.isSettled {
                HStack {
                    Spacer()
                    Label("Settled", systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundColor(Constants.Colors.success)
                        .padding(.horizontal, Constants.Spacing.small)
                        .padding(.vertical, Constants.Spacing.xxSmall)
                        .background(Constants.Colors.success.opacity(0.1))
                        .cornerRadius(Constants.CornerRadius.small)
                }
            }
        }
        .padding(Constants.Spacing.medium)
        .background(Color(.systemBackground))
        .cornerRadius(Constants.CornerRadius.medium)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .contextMenu {
            if let userSplit = userSplit, !userSplit.isPaid, !isPaidByCurrentUser {
                Button {
                    onTapSplit?(userSplit)
                } label: {
                    Label("Mark as Paid", systemImage: "checkmark.circle")
                }
            }

            if expense.createdBy == currentUserId {
                Button(role: .destructive) {
                    onDelete?()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private var categoryColor: Color {
        switch expense.category.color {
        case "primary": return Constants.Colors.primary
        case "success": return Constants.Colors.success
        case "warning": return Constants.Colors.warning
        case "danger": return Constants.Colors.danger
        default: return Constants.Colors.textSecondary
        }
    }
}

// MARK: - Preview

struct ExpenseCardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: Constants.Spacing.medium) {
            ExpenseCardView(
                expense: Expense.sampleExpenses[0],
                currentUserId: "user2"
            )

            ExpenseCardView(
                expense: Expense.sampleExpenses[1],
                currentUserId: "user2"
            )
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}
