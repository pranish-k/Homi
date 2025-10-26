import SwiftUI

// MARK: - Expense Detail Sheet

struct ExpenseDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let expense: Expense
    let currentUserId: String
    var onDelete: (() -> Void)?
    var onMarkPaid: ((ExpenseSplit) -> Void)?

    private var isPaidByCurrentUser: Bool {
        expense.paidBy == currentUserId
    }

    private var userSplit: ExpenseSplit? {
        expense.splits.first { $0.userId == currentUserId }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Constants.Spacing.large) {
                    // Amount Header
                    VStack(spacing: Constants.Spacing.small) {
                        Text(expense.formattedAmount)
                            .font(Constants.Typography.displayLarge)
                            .foregroundColor(Constants.Colors.textPrimary)

                        Text(expense.description)
                            .font(Constants.Typography.title3)
                            .foregroundColor(Constants.Colors.textSecondary)

                        Text(expense.formattedDate)
                            .font(Constants.Typography.subheadline)
                            .foregroundColor(Constants.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Constants.Spacing.large)

                    // Details Section
                    VStack(spacing: Constants.Spacing.medium) {
                        DetailRow(
                            icon: "tag.fill",
                            label: "Category",
                            value: expense.category.rawValue
                        )

                        DetailRow(
                            icon: "creditcard.fill",
                            label: "Paid by",
                            value: isPaidByCurrentUser ? "You" : expense.paidByName
                        )

                        DetailRow(
                            icon: "calendar",
                            label: "Date",
                            value: expense.formattedDate
                        )
                    }
                    .padding(.horizontal, Constants.Spacing.screenPadding)

                    Divider()
                        .padding(.horizontal, Constants.Spacing.screenPadding)

                    // Split Breakdown Section
                    VStack(alignment: .leading, spacing: Constants.Spacing.medium) {
                        Text("Split Between")
                            .font(Constants.Typography.headline)
                            .padding(.horizontal, Constants.Spacing.screenPadding)

                        ForEach(expense.splits) { split in
                            SplitRow(
                                split: split,
                                isCurrentUser: split.userId == currentUserId,
                                onMarkPaid: split.userId == currentUserId && !split.isPaid && !isPaidByCurrentUser ? {
                                    onMarkPaid?(split)
                                } : nil
                            )
                            .padding(.horizontal, Constants.Spacing.screenPadding)
                        }
                    }

                    Spacer()
                }
            }
            .navigationTitle("Expense Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Constants.Colors.primary)
                }

                if expense.createdBy == currentUserId {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(role: .destructive) {
                            onDelete?()
                            dismiss()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(Constants.Colors.danger)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: Constants.Spacing.medium) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Constants.Colors.primary)
                .frame(width: 28)

            Text(label)
                .font(Constants.Typography.body)
                .foregroundColor(Constants.Colors.textSecondary)

            Spacer()

            Text(value)
                .font(Constants.Typography.bodyMedium)
                .foregroundColor(Constants.Colors.textPrimary)
        }
    }
}

// MARK: - Split Row

struct SplitRow: View {
    let split: ExpenseSplit
    let isCurrentUser: Bool
    var onMarkPaid: (() -> Void)?

    var body: some View {
        HStack(spacing: Constants.Spacing.medium) {
            // Avatar
            Circle()
                .fill(Constants.Colors.tertiaryBackground)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(split.userName.prefix(1).uppercased())
                        .font(Constants.Typography.caption1)
                        .fontWeight(.semibold)
                        .foregroundColor(Constants.Colors.primary)
                )

            // Name
            Text(isCurrentUser ? "You" : split.userName)
                .font(Constants.Typography.body)

            Spacer()

            // Amount
            Text(split.formattedAmount)
                .font(Constants.Typography.bodyMedium)
                .foregroundColor(Constants.Colors.textPrimary)

            // Status
            if split.isPaid {
                HomiBadge("Paid", icon: "checkmark", style: .success, size: .small)
            } else if let onMarkPaid = onMarkPaid {
                Button(action: {
                    HapticManager.success()
                    onMarkPaid()
                }) {
                    HomiBadge("Mark Paid", style: .primary, size: .small)
                }
            } else {
                HomiBadge("Unpaid", style: .warning, size: .small)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ExpenseDetailSheet(
        expense: Expense.sampleExpenses[0],
        currentUserId: "user2"
    )
}
