import SwiftUI

// MARK: - Redesigned Balance Summary (Individual Balances Only)

struct BalanceSummaryView: View {
    let balances: [Balance]
    let totalYouOwe: Double
    let totalOwedToYou: Double
    var currency: String = "USD"
    var onSettle: ((Balance) -> Void)?
    var onNudge: ((Balance) -> Void)?
    var onClearPayment: ((Balance) -> Void)?
    var onViewHistory: (() -> Void)?
    var onViewPersonHistory: ((Balance) -> Void)?
    var nudgeStates: [String: (canNudge: Bool, lastNudgeTime: Date?)] = [:]

    private var netBalance: Double {
        totalOwedToYou - totalYouOwe
    }

    var body: some View {
        VStack(spacing: Constants.Spacing.large) {
            // Individual Balances (Primary Content)
            if !balances.isEmpty {
                VStack(spacing: Constants.Spacing.small) {
                    ForEach(balances) { balance in
                        let nudgeState = nudgeStates[balance.userId]
                        BalancePersonCard(
                            balance: balance,
                            currency: currency,
                            onSettle: { onSettle?(balance) },
                            onNudge: balance.netBalance > 0 ? { onNudge?(balance) } : nil,
                            onClearPayment: balance.netBalance > 0 ? { onClearPayment?(balance) } : nil,
                            onViewPersonHistory: { onViewPersonHistory?(balance) },
                            lastNudgeTime: nudgeState?.lastNudgeTime,
                            canNudge: nudgeState?.canNudge ?? true
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

                        Text("Complete Payment History")
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
    var onNudge: (() -> Void)?
    var onClearPayment: (() -> Void)?
    var onViewPersonHistory: (() -> Void)?
    var lastNudgeTime: Date?
    var canNudge: Bool = true

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

    private var nudgeTimeText: String? {
        guard let lastNudge = lastNudgeTime else { return nil }
        let timeAgo = Date().timeIntervalSince(lastNudge)
        let hours = Int(timeAgo / 3600)

        if hours < 1 {
            let minutes = Int(timeAgo / 60)
            return "Nudged \(minutes)m ago"
        } else if hours < 24 {
            return "Nudged \(hours)h ago"
        } else {
            let days = hours / 24
            return "Nudged \(days)d ago"
        }
    }

    var body: some View {
        HomiCard(shadowStyle: .subtle) {
            VStack(spacing: Constants.Spacing.small) {
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

                    // Amount
                    Text(formattedAmount(abs(balance.netBalance)))
                        .font(Constants.Typography.title3)
                        .foregroundColor(balanceColor)
                }

                // Action buttons for money owed to you or owed by you
                VStack(spacing: Constants.Spacing.small) {
                    // Action row for when they owe you
                    if balance.netBalance > 0 {
                        HStack(spacing: Constants.Spacing.small) {
                            // Record Payment button (always visible)
                            if let onClearPayment = onClearPayment {
                                Button(action: {
                                    HapticManager.selection()
                                    onClearPayment()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "dollarsign.circle.fill")
                                            .font(.system(size: 12))
                                        Text("Record Payment")
                                            .font(Constants.Typography.caption1)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(Constants.Colors.primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Constants.Colors.primaryLight.opacity(0.3))
                                    .cornerRadius(Constants.CornerRadius.small)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }

                            Spacer()

                            // Nudge status and button
                            if let nudgeTime = nudgeTimeText {
                                Text(nudgeTime)
                                    .font(.system(size: 11))
                                    .foregroundColor(Constants.Colors.textSecondary)
                            }

                            if let onNudge = onNudge {
                                Button(action: {
                                    HapticManager.selection()
                                    onNudge()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: canNudge ? "bell.fill" : "bell.slash.fill")
                                            .font(.system(size: 12))
                                        Text("Nudge")
                                            .font(Constants.Typography.caption1)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(canNudge ? Constants.Colors.primary : Constants.Colors.textSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(canNudge ? Constants.Colors.primaryLight.opacity(0.3) : Constants.Colors.tertiaryBackground)
                                    .cornerRadius(Constants.CornerRadius.small)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(!canNudge)
                            }
                        }
                    }

                    // Settle Up button (only if user owes money)
                    if balance.netBalance < 0, let onSettle = onSettle {
                        Button(action: {
                            HapticManager.selection()
                            onSettle()
                        }) {
                            Text("Clear Balance")
                                .font(Constants.Typography.bodyMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Constants.Colors.primary)
                                .cornerRadius(Constants.CornerRadius.medium)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    // View payment history button (for this person)
                    if let onViewPersonHistory = onViewPersonHistory {
                        Button(action: {
                            HapticManager.selection()
                            onViewPersonHistory()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 12))
                                Text("Payment History")
                                    .font(Constants.Typography.caption1)
                            }
                            .foregroundColor(Constants.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
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
