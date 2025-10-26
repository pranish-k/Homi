import SwiftUI

// MARK: - Redesigned Balance Summary (Individual Balances Only)

struct BalanceSummaryView: View {
    let balances: [Balance]
    let totalYouOwe: Double
    let totalOwedToYou: Double
    var currency: String = "USD"
    var onSettle: ((Balance) -> Void)?
    var onViewHistory: (() -> Void)?

    private var netBalance: Double {
        totalOwedToYou - totalYouOwe
    }

    var body: some View {
        VStack(spacing: Constants.Spacing.large) {
            // Individual Balances (Primary Content)
            if !balances.isEmpty {
                VStack(spacing: Constants.Spacing.small) {
                    ForEach(balances) { balance in
                        BalancePersonCard(
                            balance: balance,
                            currency: currency,
                            onSettle: { onSettle?(balance) }
                        )
                    }
                }
            } else {
                // All settled up state
                HomiEmptyState(
                    icon: "checkmark.circle.fill",
                    title: "All Settled Up!",
                    message: "No outstanding balances with your housemates"
                )
                .padding(.vertical, Constants.Spacing.xxLarge)
            }

            // Payment History Button
            if let onViewHistory = onViewHistory {
                Button(action: onViewHistory) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 16))

                        Text("View Payment History")
                            .font(Constants.Typography.bodyMedium)
                    }
                    .foregroundColor(Constants.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Constants.Spacing.medium)
                }
            }
        }
    }
}

// MARK: - Balance Person Card (Clean, Minimal)

struct BalancePersonCard: View {
    let balance: Balance
    var currency: String = "USD"
    var onSettle: (() -> Void)?

    private var balanceText: String {
        if balance.netBalance > 0 {
            return "\(balance.userName) owes you \(formattedAmount(balance.netBalance))"
        } else {
            return "You owe \(balance.userName) \(formattedAmount(abs(balance.netBalance)))"
        }
    }

    private var balanceColor: Color {
        balance.netBalance > 0 ? Constants.Colors.success : Constants.Colors.danger
    }

    var body: some View {
        HomiCard(shadowStyle: .subtle) {
            HStack(spacing: Constants.Spacing.medium) {
                // Avatar
                Circle()
                    .fill(Constants.Colors.tertiaryBackground)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(balance.userName.prefix(1).uppercased())
                            .font(Constants.Typography.headline)
                            .foregroundColor(Constants.Colors.primary)
                    )

                // Name & Description
                VStack(alignment: .leading, spacing: 4) {
                    Text(balance.userName)
                        .font(Constants.Typography.headline)
                        .foregroundColor(Constants.Colors.textPrimary)

                    Text(balance.netBalance > 0 ? "Owes you" : "You owe")
                        .font(Constants.Typography.caption1)
                        .foregroundColor(Constants.Colors.textSecondary)
                }

                Spacer()

                // Amount & Action
                VStack(alignment: .trailing, spacing: 8) {
                    Text(formattedAmount(abs(balance.netBalance)))
                        .font(Constants.Typography.title3)
                        .foregroundColor(balanceColor)

                    // Settle Up button (only if user owes money)
                    if balance.netBalance < 0, let onSettle = onSettle {
                        Button(action: {
                            HapticManager.selection()
                            onSettle()
                        }) {
                            Text("Settle Up")
                                .font(Constants.Typography.caption1)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Constants.Colors.primary)
                                .cornerRadius(Constants.CornerRadius.small)
                        }
                    }
                }
            }
            .padding(Constants.Spacing.cardPadding)
        }
    }

    private func formattedAmount(_ amount: Double) -> String {
        return CurrencyFormatter.format(amount: amount, currencyCode: currency)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        BalanceSummaryView(
            balances: [
                Balance(userId: "1", userName: "John Doe", owedToYou: 50.00, youOwe: 0),
                Balance(userId: "2", userName: "Jane Smith", owedToYou: 0, youOwe: 30.50),
                Balance(userId: "3", userName: "Mike Johnson", owedToYou: 25.00, youOwe: 0)
            ],
            totalYouOwe: 30.50,
            totalOwedToYou: 75.00,
            onViewHistory: {}
        )
        .padding()
    }
}
