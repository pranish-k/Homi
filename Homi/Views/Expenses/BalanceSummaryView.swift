import SwiftUI

struct BalanceSummaryView: View {
    let balances: [Balance]
    let totalYouOwe: Double
    let totalOwedToYou: Double
    var onSettle: ((Balance) -> Void)?

    private var netBalance: Double {
        totalOwedToYou - totalYouOwe
    }

    var body: some View {
        VStack(spacing: Constants.Spacing.medium) {
            // Overall balance card
            overallBalanceCard

            // Individual balances
            if !balances.isEmpty {
                VStack(spacing: Constants.Spacing.small) {
                    ForEach(balances) { balance in
                        balanceRow(balance: balance)
                    }
                }
            } else if totalYouOwe == 0 && totalOwedToYou == 0 {
                // Only show empty state when truly no balances at all
                emptyStateView
            } else {
                // If we have totals but no individual balances, something's wrong
                // Show a message for debugging
                Text("Balances are being calculated...")
                    .font(.caption)
                    .foregroundColor(Constants.Colors.textSecondary)
                    .padding()
            }
        }
    }

    private var overallBalanceCard: some View {
        VStack(spacing: Constants.Spacing.small) {
            Text("Your Balance")
                .font(.headline)
                .foregroundColor(Constants.Colors.textSecondary)

            Text(formattedAmount(netBalance))
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(balanceColor)

            if netBalance > 0 {
                Text("You are owed")
                    .font(.subheadline)
                    .foregroundColor(Constants.Colors.textSecondary)
            } else if netBalance < 0 {
                Text("You owe")
                    .font(.subheadline)
                    .foregroundColor(Constants.Colors.textSecondary)
            } else {
                Text("All settled up! 🎉")
                    .font(.subheadline)
                    .foregroundColor(Constants.Colors.success)
            }

            Divider()
                .padding(.vertical, Constants.Spacing.xxSmall)

            // Breakdown
            HStack(spacing: Constants.Spacing.large) {
                VStack(spacing: 4) {
                    Text(formattedAmount(totalOwedToYou))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(Constants.Colors.success)

                    Text("Owed to you")
                        .font(.caption)
                        .foregroundColor(Constants.Colors.textSecondary)
                }

                Divider()
                    .frame(height: 40)

                VStack(spacing: 4) {
                    Text(formattedAmount(totalYouOwe))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(Constants.Colors.danger)

                    Text("You owe")
                        .font(.caption)
                        .foregroundColor(Constants.Colors.textSecondary)
                }
            }
        }
        .padding(Constants.Spacing.medium)
        .background(
            LinearGradient(
                colors: [Constants.Colors.primary.opacity(0.05), Constants.Colors.primary.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(Constants.CornerRadius.medium)
    }

    private func balanceRow(balance: Balance) -> some View {
        HStack(spacing: Constants.Spacing.medium) {
            // Avatar placeholder
            Circle()
                .fill(Constants.Colors.primary.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay {
                    Text(balance.userName.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundColor(Constants.Colors.primary)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(balance.userName)
                    .font(.headline)
                    .foregroundColor(Constants.Colors.textPrimary)

                if balance.netBalance > 0 {
                    Text("owes you")
                        .font(.caption)
                        .foregroundColor(Constants.Colors.textSecondary)
                } else {
                    Text("you owe")
                        .font(.caption)
                        .foregroundColor(Constants.Colors.textSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(balance.formattedBalance)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(balance.netBalance > 0 ? Constants.Colors.success : Constants.Colors.danger)

                if balance.netBalance < 0 {
                    Button {
                        onSettle?(balance)
                    } label: {
                        Text("Settle Up")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, Constants.Spacing.small)
                            .padding(.vertical, Constants.Spacing.xxSmall)
                            .background(Constants.Colors.primary)
                            .cornerRadius(Constants.CornerRadius.small)
                    }
                }
            }
        }
        .padding(Constants.Spacing.medium)
        .background(Color(.systemBackground))
        .cornerRadius(Constants.CornerRadius.medium)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var emptyStateView: some View {
        VStack(spacing: Constants.Spacing.medium) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(Constants.Colors.success)

            Text("All Settled Up!")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(Constants.Colors.textPrimary)

            Text("No outstanding balances with your housemates")
                .font(.body)
                .foregroundColor(Constants.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Constants.Spacing.xLarge)
    }

    private var balanceColor: Color {
        if netBalance > 0 {
            return Constants.Colors.success
        } else if netBalance < 0 {
            return Constants.Colors.danger
        } else {
            return Constants.Colors.textPrimary
        }
    }

    private func formattedAmount(_ amount: Double) -> String {
        return String(format: "$%.2f", abs(amount))
    }
}

// MARK: - Preview

struct BalanceSummaryView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            BalanceSummaryView(
                balances: [
                    Balance(userId: "1", userName: "John Doe", owedToYou: 50.00, youOwe: 0),
                    Balance(userId: "2", userName: "Jane Smith", owedToYou: 0, youOwe: 30.50)
                ],
                totalYouOwe: 30.50,
                totalOwedToYou: 50.00
            )
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}
