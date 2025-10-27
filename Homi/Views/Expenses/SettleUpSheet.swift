import SwiftUI
import FirebaseAuth

// MARK: - Settle Up Sheet

struct SettleUpSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = AuthService.shared

    let balance: Balance
    let houseId: String
    var onPaymentRecorded: () -> Void

    @State private var showRecordPayment = false
    @State private var paymentAmount: String = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showError = false

    private var maxAmount: Double {
        abs(balance.netBalance)
    }

    private var formattedMaxAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: maxAmount)) ?? "$0.00"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Constants.Spacing.large) {
                if !showRecordPayment {
                    paymentOptionsView
                } else {
                    recordPaymentView
                }
            }
            .padding(Constants.Spacing.large)
            .navigationTitle("Settle Balance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        if showRecordPayment {
                            showRecordPayment = false
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundColor(Constants.Colors.primary)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
    }

    // MARK: - Payment Options View

    private var paymentOptionsView: some View {
        VStack(spacing: Constants.Spacing.medium) {
            // Balance Info
            VStack(spacing: Constants.Spacing.small) {
                Text(balance.userName)
                    .font(Constants.Typography.title2)
                    .foregroundColor(Constants.Colors.textPrimary)

                Text(formattedMaxAmount)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(balance.netBalance > 0 ? Constants.Colors.success : Constants.Colors.danger)

                Text(balance.netBalance > 0 ? "owes you" : "you owe")
                    .font(Constants.Typography.body)
                    .foregroundColor(Constants.Colors.textSecondary)
            }
            .padding(.bottom, Constants.Spacing.large)

            Divider()

            // Payment Options
            VStack(spacing: Constants.Spacing.medium) {
                Text("How would you like to settle?")
                    .font(Constants.Typography.headline)
                    .foregroundColor(Constants.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Venmo (placeholder)
                PaymentOptionButton(
                    icon: "dollarsign.circle.fill",
                    title: "Pay on Venmo",
                    subtitle: "Coming soon",
                    action: {
                        // Placeholder for Venmo integration
                    }
                )
                .disabled(true)
                .opacity(0.5)

                // PayPal (placeholder)
                PaymentOptionButton(
                    icon: "dollarsign.circle.fill",
                    title: "Pay on PayPal",
                    subtitle: "Coming soon",
                    action: {
                        // Placeholder for PayPal integration
                    }
                )
                .disabled(true)
                .opacity(0.5)

                // Record Payment
                PaymentOptionButton(
                    icon: "checkmark.circle.fill",
                    title: "Record Completed Payment",
                    subtitle: "Already paid outside the app",
                    action: {
                        paymentAmount = String(format: "%.2f", maxAmount)
                        showRecordPayment = true
                    }
                )
            }

            Spacer()
        }
    }

    // MARK: - Record Payment View

    private var recordPaymentView: some View {
        VStack(spacing: Constants.Spacing.large) {
            // Balance Info
            VStack(spacing: Constants.Spacing.small) {
                Text("Record Payment")
                    .font(Constants.Typography.title2)
                    .foregroundColor(Constants.Colors.textPrimary)

                Text("Maximum: \(formattedMaxAmount)")
                    .font(Constants.Typography.body)
                    .foregroundColor(Constants.Colors.textSecondary)
            }

            Divider()

            // Amount Input
            VStack(alignment: .leading, spacing: Constants.Spacing.small) {
                Text("Payment Amount")
                    .font(Constants.Typography.headline)
                    .foregroundColor(Constants.Colors.textPrimary)

                HStack {
                    Text("$")
                        .font(Constants.Typography.title2)
                        .foregroundColor(Constants.Colors.textPrimary)

                    TextField("0.00", text: $paymentAmount)
                        .font(Constants.Typography.title2)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            .padding(.vertical, Constants.Spacing.medium)

            // Record Button
            Button(action: {
                Task {
                    await recordPayment()
                }
            }) {
                HStack {
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Record Payment")
                            .font(Constants.Typography.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isValidAmount ? Constants.Colors.primary : Color.gray.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(Constants.CornerRadius.medium)
            }
            .disabled(!isValidAmount || isProcessing)

            Spacer()
        }
    }

    // MARK: - Validation

    private var isValidAmount: Bool {
        guard let amount = Double(paymentAmount) else { return false }
        return amount > 0 && amount <= maxAmount
    }

    // MARK: - Actions

    private func recordPayment() async {
        guard let amount = Double(paymentAmount),
              amount > 0,
              amount <= maxAmount,
              let currentUserId = authService.user?.uid,
              let currentUserName = authService.userProfile?.displayName else {
            errorMessage = "Please enter a valid amount up to \(formattedMaxAmount)"
            showError = true
            return
        }

        isProcessing = true

        do {
            // Determine who is paying whom
            let (fromUserId, fromUserName, toUserId, toUserName): (String, String, String, String)

            if balance.netBalance > 0 {
                // Balance owes you, so they are paying you
                fromUserId = balance.userId
                fromUserName = balance.userName
                toUserId = currentUserId
                toUserName = currentUserName
            } else {
                // You owe balance, so you are paying them
                fromUserId = currentUserId
                fromUserName = currentUserName
                toUserId = balance.userId
                toUserName = balance.userName
            }

            let payment = Payment(
                houseId: houseId,
                fromUserId: fromUserId,
                fromUserName: fromUserName,
                toUserId: toUserId,
                toUserName: toUserName,
                amount: amount,
                expenseIds: [], // Not tracking specific expenses for this flow
                note: nil,
                timestamp: Date()
            )

            try await FirestoreService.shared.recordPayment(payment)

            await MainActor.run {
                HapticManager.success()
                isProcessing = false
                onPaymentRecorded()
                dismiss()
            }
        } catch {
            await MainActor.run {
                HapticManager.error()
                errorMessage = "Failed to record payment: \(error.localizedDescription)"
                showError = true
                isProcessing = false
            }
        }
    }
}

// MARK: - Payment Option Button

struct PaymentOptionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Constants.Spacing.medium) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(Constants.Colors.primary)
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(Constants.Typography.headline)
                        .foregroundColor(Constants.Colors.textPrimary)

                    Text(subtitle)
                        .font(Constants.Typography.caption1)
                        .foregroundColor(Constants.Colors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Constants.Colors.textSecondary)
            }
            .padding(Constants.Spacing.cardPadding)
            .background(Constants.Colors.secondaryBackground)
            .cornerRadius(Constants.CornerRadius.medium)
        }
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
        ),
        houseId: "house123",
        onPaymentRecorded: {}
    )
}
