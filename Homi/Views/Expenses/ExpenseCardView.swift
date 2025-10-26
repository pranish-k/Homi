import SwiftUI

// MARK: - Minimal Expense Card

struct ExpenseCardView: View {
    let expense: Expense
    let currentUserId: String
    var onTap: (() -> Void)?
    var onDelete: (() -> Void)?
    var onTapSplit: ((ExpenseSplit) -> Void)?

    private var isPaidByCurrentUser: Bool {
        expense.paidBy == currentUserId
    }

    var body: some View {
        Button(action: {
            HapticManager.selection()
            onTap?()
        }) {
            HomiCard(shadowStyle: .subtle) {
                HStack(spacing: Constants.Spacing.medium) {
                    // Amount (Large, left side)
                    Text(expense.formattedAmount)
                        .font(Constants.Typography.title2)
                        .foregroundColor(Constants.Colors.textPrimary)
                        .frame(width: 90, alignment: .leading)

                    // Title & Date
                    VStack(alignment: .leading, spacing: 4) {
                        Text(expense.description)
                            .font(Constants.Typography.headline)
                            .foregroundColor(Constants.Colors.textPrimary)
                            .lineLimit(1)

                        Text(expense.relativeDate)
                            .font(Constants.Typography.caption1)
                            .foregroundColor(Constants.Colors.textSecondary)
                    }

                    Spacer()

                    // Who Paid Badge
                    HomiBadge(
                        isPaidByCurrentUser ? "You" : expense.paidByName.components(separatedBy: " ").first ?? expense.paidByName,
                        style: isPaidByCurrentUser ? .success : .neutral,
                        size: .small
                    )

                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Constants.Colors.textSecondary)
                }
                .padding(Constants.Spacing.cardPadding)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            if let userSplit = expense.splits.first(where: { $0.userId == currentUserId }),
               !userSplit.isPaid, !isPaidByCurrentUser {
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
}

// MARK: - Preview

#Preview {
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
}
