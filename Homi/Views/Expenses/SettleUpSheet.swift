import SwiftUI
import FirebaseAuth

// MARK: - Settle Up Sheet

struct SettleUpSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = AuthService.shared
    @StateObject private var expenseService = ExpenseService.shared

    let balance: Balance
    let houseId: String
    var onPaymentRecorded: () -> Void

    // State
    @State private var balanceDetail: BalanceDetail?
    @State private var isLoadingDetail = true
    @State private var showExpenseSelection = false
    @State private var selectedExpenses: Set<String> = []
    @State private var paymentAmount: String = ""
    @State private var selectedPaymentMethod: PaymentMethod = .cash
    @State private var externalTransactionId: String = ""
    @State private var note: String = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showBreakdown = false

    private var currentUserId: String {
        authService.user?.uid ?? ""
    }

    private var currentUserName: String {
        authService.userProfile?.displayName ?? ""
    }

    // Calculate NET balance amount
    private var netBalanceAmount: Double {
        abs(balanceDetail?.netBalance ?? balance.netBalance)
    }

    // Determine if user owes or is owed
    private var userOwes: Bool {
        (balanceDetail?.netBalance ?? balance.netBalance) < 0
    }

    // Calculate selected expenses total
    private var selectedExpensesTotal: Double {
        guard let detail = balanceDetail else { return 0 }
        var total: Double = 0

        for expenseId in selectedExpenses {
            if let expense = (detail.unpaidExpensesYouOwe + detail.unpaidExpensesTheyOweYou)
                .first(where: { $0.id == expenseId }) {
                // Find the split amount for current user or other user
                if let split = expense.splits.first(where: { $0.userId == currentUserId }) {
                    total += split.remainingAmount
                } else if let split = expense.splits.first(where: { $0.userId == balance.userId }) {
                    total += split.remainingAmount
                }
            }
        }
        return total
    }

    private var paymentAmountValue: Double {
        Double(paymentAmount) ?? 0
    }

    private var isValidAmount: Bool {
        guard let amount = Double(paymentAmount) else { return false }
        return amount > 0 && amount <= netBalanceAmount + 0.01  // Small tolerance
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Constants.Spacing.large) {
                    if isLoadingDetail {
                        ProgressView("Loading balance details...")
                            .padding()
                    } else if let detail = balanceDetail {
                        netBalanceSection(detail: detail)

                        Divider()

                        if !showExpenseSelection {
                            quickActionsSection
                        } else {
                            expenseSelectionSection(detail: detail)

                            Divider()

                            paymentMethodSection

                            Divider()

                            amountInputSection

                            recordPaymentButton
                        }
                    }
                }
                .padding(Constants.Spacing.large)
            }
            .navigationTitle("Settle Balance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        if showExpenseSelection {
                            showExpenseSelection = false
                            selectedExpenses.removeAll()
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundColor(Constants.Colors.primary)
                }
            }
            .task {
                await loadBalanceDetail()
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

    // MARK: - NET Balance Section

    private func netBalanceSection(detail: BalanceDetail) -> some View {
        VStack(spacing: Constants.Spacing.medium) {
            // User name
            Text(balance.userName)
                .font(Constants.Typography.title2)
                .foregroundColor(Constants.Colors.textPrimary)

            // NET Balance label
            Text("NET Balance")
                .font(Constants.Typography.caption1)
                .foregroundColor(Constants.Colors.textSecondary)

            // Amount
            Text("$\(netBalanceAmount, specifier: "%.2f")")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(userOwes ? Constants.Colors.danger : Constants.Colors.success)

            // Description
            Text(userOwes ? "You Owe" : "Owes You")
                .font(Constants.Typography.headline)
                .foregroundColor(Constants.Colors.textSecondary)

            // Breakdown toggle
            Button(action: { showBreakdown.toggle() }) {
                HStack {
                    Text(showBreakdown ? "Hide Breakdown" : "View Breakdown")
                        .font(Constants.Typography.caption1)
                    Image(systemName: showBreakdown ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .foregroundColor(Constants.Colors.primary)
            }
            .padding(.top, Constants.Spacing.small)

            // Breakdown detail
            if showBreakdown {
                VStack(spacing: Constants.Spacing.small) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("They owe you:")
                                .font(Constants.Typography.caption1)
                                .foregroundColor(Constants.Colors.textSecondary)
                            Text("$\(detail.grossOwedToYou, specifier: "%.2f")")
                                .font(Constants.Typography.headline)
                                .foregroundColor(Constants.Colors.success)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("You owe them:")
                                .font(Constants.Typography.caption1)
                                .foregroundColor(Constants.Colors.textSecondary)
                            Text("$\(detail.grossOwed, specifier: "%.2f")")
                                .font(Constants.Typography.headline)
                                .foregroundColor(Constants.Colors.danger)
                        }
                    }
                    .padding()
                    .background(Constants.Colors.secondaryBackground)
                    .cornerRadius(Constants.CornerRadius.medium)
                }
            }
        }
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        VStack(spacing: Constants.Spacing.medium) {
            Text("How would you like to settle?")
                .font(Constants.Typography.headline)
                .foregroundColor(Constants.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Settle Full Balance
            Button(action: {
                settleFullBalance()
            }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Constants.Colors.success)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Settle Full Balance")
                            .font(Constants.Typography.headline)
                            .foregroundColor(Constants.Colors.textPrimary)

                        Text("Pay $\(netBalanceAmount, specifier: "%.2f") using smart offset")
                            .font(Constants.Typography.caption1)
                            .foregroundColor(Constants.Colors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(Constants.Colors.textSecondary)
                }
                .padding(Constants.Spacing.cardPadding)
                .background(Constants.Colors.secondaryBackground)
                .cornerRadius(Constants.CornerRadius.medium)
            }

            // Select Specific Expenses
            Button(action: {
                showExpenseSelection = true
            }) {
                HStack {
                    Image(systemName: "list.bullet.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Constants.Colors.primary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Select Specific Expenses")
                            .font(Constants.Typography.headline)
                            .foregroundColor(Constants.Colors.textPrimary)

                        Text("Choose which expenses to settle")
                            .font(Constants.Typography.caption1)
                            .foregroundColor(Constants.Colors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(Constants.Colors.textSecondary)
                }
                .padding(Constants.Spacing.cardPadding)
                .background(Constants.Colors.secondaryBackground)
                .cornerRadius(Constants.CornerRadius.medium)
            }
        }
    }

    // MARK: - Expense Selection Section

    private func expenseSelectionSection(detail: BalanceDetail) -> some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.medium) {
            Text("Select Expenses")
                .font(Constants.Typography.headline)
                .foregroundColor(Constants.Colors.textPrimary)

            // Your unpaid expenses (you owe them)
            if !detail.unpaidExpensesYouOwe.isEmpty {
                Text("Your Unpaid Expenses to \(balance.userName)")
                    .font(Constants.Typography.subheadline)
                    .foregroundColor(Constants.Colors.textSecondary)

                ForEach(detail.unpaidExpensesYouOwe) { expense in
                    ExpenseCheckboxRow(
                        expense: expense,
                        userId: currentUserId,
                        isSelected: selectedExpenses.contains(expense.id),
                        onToggle: { toggleExpense(expense.id) }
                    )
                }
            }

            // Their unpaid expenses (they owe you) - can offset
            if !detail.unpaidExpensesTheyOweYou.isEmpty {
                Text("\(balance.userName)'s Unpaid Expenses to You (Can Offset)")
                    .font(Constants.Typography.subheadline)
                    .foregroundColor(Constants.Colors.textSecondary)
                    .padding(.top, Constants.Spacing.small)

                ForEach(detail.unpaidExpensesTheyOweYou) { expense in
                    ExpenseCheckboxRow(
                        expense: expense,
                        userId: balance.userId,
                        isSelected: selectedExpenses.contains(expense.id),
                        onToggle: { toggleExpense(expense.id) }
                    )
                }
            }

            // Selected total
            if !selectedExpenses.isEmpty {
                HStack {
                    Text("Total Selected:")
                        .font(Constants.Typography.headline)
                    Spacer()
                    Text("$\(selectedExpensesTotal, specifier: "%.2f")")
                        .font(Constants.Typography.headline)
                        .foregroundColor(Constants.Colors.primary)
                }
                .padding()
                .background(Constants.Colors.secondaryBackground)
                .cornerRadius(Constants.CornerRadius.medium)
            }
        }
    }

    // MARK: - Payment Method Section

    private var paymentMethodSection: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.medium) {
            Text("Payment Method")
                .font(Constants.Typography.headline)
                .foregroundColor(Constants.Colors.textPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: Constants.Spacing.small) {
                ForEach(PaymentMethod.allCases, id: \.self) { method in
                    PaymentMethodButton(
                        method: method,
                        isSelected: selectedPaymentMethod == method,
                        action: { selectedPaymentMethod = method }
                    )
                }
            }

            // External transaction ID (if applicable)
            if selectedPaymentMethod.supportsExternalId {
                VStack(alignment: .leading, spacing: Constants.Spacing.small) {
                    Text("Transaction ID (Optional)")
                        .font(Constants.Typography.caption1)
                        .foregroundColor(Constants.Colors.textSecondary)

                    TextField("Enter transaction ID", text: $externalTransactionId)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
        }
    }

    // MARK: - Amount Input Section

    private var amountInputSection: some View {
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

            Text("Maximum: $\(netBalanceAmount, specifier: "%.2f")")
                .font(Constants.Typography.caption1)
                .foregroundColor(Constants.Colors.textSecondary)

            // Validation warning
            if let warning = paymentWarning {
                Text(warning)
                    .font(Constants.Typography.caption1)
                    .foregroundColor(Constants.Colors.warning)
            }
        }
    }

    private var paymentWarning: String? {
        if paymentAmountValue > netBalanceAmount + 0.01 {
            return "⚠️ Amount exceeds NET balance"
        }
        if !selectedExpenses.isEmpty && paymentAmountValue > selectedExpensesTotal + 0.01 {
            return "⚠️ Amount exceeds selected expenses total"
        }
        return nil
    }

    // MARK: - Record Payment Button

    private var recordPaymentButton: some View {
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
            .background(isValidAmount && !selectedExpenses.isEmpty ? Constants.Colors.primary : Color.gray.opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(Constants.CornerRadius.medium)
        }
        .disabled(!isValidAmount || selectedExpenses.isEmpty || isProcessing)
    }

    // MARK: - Actions

    private func loadBalanceDetail() async {
        isLoadingDetail = true
        do {
            let detail = try await expenseService.getBalanceDetail(
                forUser: currentUserId,
                withUser: balance.userId,
                inHouse: houseId
            )
            await MainActor.run {
                self.balanceDetail = detail
                self.isLoadingDetail = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load balance details: \(error.localizedDescription)"
                showError = true
                isLoadingDetail = false
            }
        }
    }

    private func toggleExpense(_ expenseId: String) {
        if selectedExpenses.contains(expenseId) {
            selectedExpenses.remove(expenseId)
        } else {
            selectedExpenses.insert(expenseId)
        }

        // Auto-calculate total
        paymentAmount = String(format: "%.2f", selectedExpensesTotal)
    }

    private func settleFullBalance() {
        guard let detail = balanceDetail else { return }

        // Use smart settlement to select expenses
        let selectedIds = expenseService.calculateSmartSettlement(
            paymentAmount: netBalanceAmount,
            balanceDetail: detail,
            payerId: currentUserId,
            payeeId: balance.userId
        )

        selectedExpenses = Set(selectedIds)
        paymentAmount = String(format: "%.2f", netBalanceAmount)
        showExpenseSelection = true
    }

    private func recordPayment() async {
        guard let amount = Double(paymentAmount),
              amount > 0,
              !selectedExpenses.isEmpty,
              let detail = balanceDetail else {
            await MainActor.run {
                errorMessage = "Invalid payment details"
                showError = true
            }
            return
        }

        await MainActor.run {
            isProcessing = true
        }

        // Determine payer and payee based on who owes
        let (fromUserId, fromUserName, toUserId, toUserName): (String, String, String, String)

        if userOwes {
            // User owes balance
            fromUserId = currentUserId
            fromUserName = currentUserName
            toUserId = balance.userId
            toUserName = balance.userName
        } else {
            // Balance owes user
            fromUserId = balance.userId
            fromUserName = balance.userName
            toUserId = currentUserId
            toUserName = currentUserName
        }

        do {
            _ = try await expenseService.recordPaymentWithSettlement(
                fromUserId: fromUserId,
                fromUserName: fromUserName,
                toUserId: toUserId,
                toUserName: toUserName,
                amount: amount,
                selectedExpenseIds: Array(selectedExpenses),
                paymentMethod: selectedPaymentMethod,
                externalTransactionId: externalTransactionId.isEmpty ? nil : externalTransactionId,
                note: note.isEmpty ? nil : note,
                houseId: houseId,
                strategy: .smart
            )

            await MainActor.run {
                HapticManager.success()
                isProcessing = false
                onPaymentRecorded()
                dismiss()
            }

            print("✅ Payment recorded successfully")

        } catch {
            await MainActor.run {
                HapticManager.error()
                errorMessage = error.localizedDescription
                showError = true
                isProcessing = false
            }
        }
    }
}

// MARK: - Expense Checkbox Row

struct ExpenseCheckboxRow: View {
    let expense: Expense
    let userId: String
    let isSelected: Bool
    let onToggle: () -> Void

    private var splitAmount: Double {
        expense.splits.first(where: { $0.userId == userId })?.remainingAmount ?? 0
    }

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? Constants.Colors.success : Constants.Colors.textSecondary)
                    .font(.system(size: 20))

                VStack(alignment: .leading, spacing: 4) {
                    Text(expense.description)
                        .font(Constants.Typography.subheadline)
                        .foregroundColor(Constants.Colors.textPrimary)

                    Text(expense.shortDate)
                        .font(Constants.Typography.caption1)
                        .foregroundColor(Constants.Colors.textSecondary)
                }

                Spacer()

                Text("$\(splitAmount, specifier: "%.2f")")
                    .font(Constants.Typography.headline)
                    .foregroundColor(Constants.Colors.textPrimary)
            }
            .padding(Constants.Spacing.small)
            .background(isSelected ? Constants.Colors.success.opacity(0.1) : Constants.Colors.secondaryBackground)
            .cornerRadius(Constants.CornerRadius.small)
        }
    }
}

// MARK: - Payment Method Button

struct PaymentMethodButton: View {
    let method: PaymentMethod
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: method.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : Constants.Colors.primary)

                Text(method.displayName)
                    .font(Constants.Typography.caption1)
                    .foregroundColor(isSelected ? .white : Constants.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Constants.Colors.primary : Constants.Colors.secondaryBackground)
            .cornerRadius(Constants.CornerRadius.small)
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
