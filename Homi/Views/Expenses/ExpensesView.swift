import SwiftUI
import OSLog
import FirebaseFirestore

// MARK: - Redesigned Expenses View (Clean & Minimal)

struct ExpensesView: View {
    @StateObject private var viewModel = ExpenseViewModel()
    @StateObject private var authService = AuthService.shared
    @StateObject private var firestoreService = FirestoreService.shared
    @StateObject private var nudgeService = NudgeService.shared

    @State private var showingAddExpense = false
    @State private var houseMembers: [HouseMember] = []
    @State private var selectedBalance: Balance?
    @State private var selectedExpense: Expense?
    @State private var showingSettleUp = false
    @State private var showingPaymentHistory = false
    @State private var showingPersonPaymentHistory = false
    @State private var selectedBalanceForHistory: Balance?
    @State private var currentHouse: House?
    @State private var nudgeStates: [String: (canNudge: Bool, lastNudgeTime: Date?)] = [:]
    @State private var selectedTab = 0 // 0 = Balances, 1 = Transactions

    private let logger = Logger(subsystem: "com.homi.app", category: "ExpensesView")

    private var currency: String {
        currentHouse?.settings.currency ?? "USD"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if authService.userProfile?.currentHouseId != nil {
                    // Segmented Control
                    Picker("View", selection: $selectedTab) {
                        Text("Balances").tag(0)
                        Text("Transactions").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, Constants.Spacing.medium)
                    .padding(.vertical, Constants.Spacing.small)

                    // Content based on selected tab
                    ScrollView {
                        VStack(spacing: Constants.Spacing.sectionSpacing) {
                            if selectedTab == 0 {
                                // Balances Tab
                                totalBalanceHeader
                                balancesSection
                            } else {
                                // Transactions Tab
                                transactionsSection
                            }
                        }
                        .padding(.vertical, Constants.Spacing.medium)
                    }
                } else {
                    noHouseView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Bills")
                        .font(Constants.Typography.title2)
                }

                if authService.userProfile?.currentHouseId != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingAddExpense = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.title3)
                                .foregroundColor(Constants.Colors.primary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddExpense) {
                AddExpenseView(viewModel: viewModel, houseMembers: houseMembers)
            }
            .sheet(isPresented: $showingSettleUp) {
                if let balance = selectedBalance,
                   let houseId = authService.userProfile?.currentHouseId {
                    SettleUpSheet(
                        balance: balance,
                        houseId: houseId,
                        onPaymentRecorded: {
                            Task {
                                await loadNudgeStates()
                            }
                        }
                    )
                }
            }
            .sheet(isPresented: $showingPaymentHistory) {
                PaymentHistoryView()
            }
            .sheet(isPresented: $showingPersonPaymentHistory) {
                if let balance = selectedBalanceForHistory {
                    PaymentHistoryView(
                        filterUserId: balance.userId,
                        filterUserName: balance.userName
                    )
                }
            }
            .sheet(item: $selectedExpense) { expense in
                ExpenseDetailSheet(
                    expense: expense,
                    currentUserId: viewModel.currentUserId ?? "",
                    onDelete: {
                        Task {
                            await viewModel.deleteExpense(expense)
                        }
                    },
                    onMarkPaid: { split in
                        Task {
                            await viewModel.markAsPaid(expense: expense, userId: split.userId)
                        }
                    }
                )
            }
            .onAppear {
                loadData()
            }
            .onDisappear {
                viewModel.stopListening()
            }
        }
    }

    // MARK: - Total Balance Header

    private var totalBalanceHeader: some View {
        VStack(spacing: Constants.Spacing.small) {
            Text("Your Balance")
                .font(Constants.Typography.subheadline)
                .foregroundColor(Constants.Colors.textSecondary)

            Text(formattedNetBalance)
                .font(Constants.Typography.display)
                .foregroundColor(netBalanceColor)

            Text(netBalanceSubtitle)
                .font(Constants.Typography.subheadline)
                .foregroundColor(Constants.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Constants.Spacing.large)
        .padding(.horizontal, Constants.Spacing.screenPadding)
    }

    // MARK: - Balances Section

    private var balancesSection: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.medium) {
            if !viewModel.balances.isEmpty {
                Text("Individual Balances")
                    .font(Constants.Typography.headline)
                    .padding(.horizontal, Constants.Spacing.screenPadding)

                BalanceSummaryView(
                    balances: viewModel.balances,
                    totalYouOwe: viewModel.getTotalYouOwe(),
                    totalOwedToYou: viewModel.getTotalOwedToYou(),
                    currency: currency,
                    onSettle: { balance in
                        selectedBalance = balance
                        showingSettleUp = true
                    },
                    onNudge: { balance in
                        sendNudge(for: balance)
                    },
                    onClearPayment: { balance in
                        selectedBalance = balance
                        showingSettleUp = true
                    },
                    onViewHistory: {
                        showingPaymentHistory = true
                    },
                    onViewPersonHistory: { balance in
                        selectedBalanceForHistory = balance
                        showingPersonPaymentHistory = true
                    },
                    nudgeStates: nudgeStates
                )
                .padding(.horizontal, Constants.Spacing.screenPadding)
            }
        }
    }

    // MARK: - Transactions Section

    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.medium) {
            Text("All Transactions")
                .font(Constants.Typography.headline)
                .padding(.horizontal, Constants.Spacing.screenPadding)

            if viewModel.isLoading && viewModel.expenses.isEmpty {
                VStack(spacing: Constants.Spacing.medium) {
                    SkeletonCard()
                    SkeletonCard()
                    SkeletonCard()
                }
                .padding(.horizontal, Constants.Spacing.screenPadding)
            } else if viewModel.expenses.isEmpty {
                HomiEmptyState(
                    icon: "dollarsign.circle",
                    title: "No Expenses Yet",
                    message: "Tap the + button to add your first expense",
                    actionTitle: "Add Expense",
                    action: {
                        showingAddExpense = true
                    }
                )
                .padding(.horizontal, Constants.Spacing.screenPadding)
            } else {
                LazyVStack(spacing: Constants.Spacing.small) {
                    ForEach(viewModel.expenses) { expense in
                        ExpenseCardView(
                            expense: expense,
                            currentUserId: viewModel.currentUserId ?? "",
                            onTap: {
                                selectedExpense = expense
                            },
                            onDelete: {
                                Task {
                                    await viewModel.deleteExpense(expense)
                                }
                            },
                            onTapSplit: { split in
                                Task {
                                    await viewModel.markAsPaid(expense: expense, userId: split.userId)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, Constants.Spacing.screenPadding)
            }
        }
    }

    // MARK: - Empty States

    private var noHouseView: some View {
        HomiEmptyState(
            icon: "house.slash",
            title: "No House Found",
            message: "You need to be part of a house to track expenses"
        )
        .padding(.top, 100)
    }

    // MARK: - Computed Properties

    private var netBalance: Double {
        viewModel.getTotalOwedToYou() - viewModel.getTotalYouOwe()
    }

    private var formattedNetBalance: String {
        let amount = abs(netBalance)
        if netBalance > 0 {
            return "+\(CurrencyFormatter.format(amount: amount, currencyCode: currency))"
        } else if netBalance < 0 {
            return "-\(CurrencyFormatter.format(amount: amount, currencyCode: currency))"
        } else {
            return CurrencyFormatter.format(amount: 0, currencyCode: currency)
        }
    }

    private var netBalanceColor: Color {
        if netBalance > 0 {
            return Constants.Colors.success
        } else if netBalance < 0 {
            return Constants.Colors.danger
        } else {
            return Constants.Colors.textPrimary
        }
    }

    private var netBalanceSubtitle: String {
        if netBalance > 0 {
            return "You're owed"
        } else if netBalance < 0 {
            return "You owe"
        } else {
            return "All settled up"
        }
    }

    // MARK: - Data Loading

    private func loadData() {
        guard let houseId = authService.userProfile?.currentHouseId else { return }

        Task {
            do {
                // Load house
                if let house = try await firestoreService.getHouse(id: houseId) {
                    await MainActor.run {
                        currentHouse = house
                    }
                }

                // Load house members
                let members = try await firestoreService.getHouseMembers(houseId: houseId)
                await MainActor.run {
                    houseMembers = members
                }

                // Start listening to expenses
                viewModel.startListening(houseId: houseId, houseMembers: members)

                // Load nudge states for each balance
                await loadNudgeStates()
            } catch {
                logger.error("Error loading data: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Nudge Functions

    private func loadNudgeStates() async {
        guard let currentUserId = authService.userProfile?.id else { return }

        var states: [String: (canNudge: Bool, lastNudgeTime: Date?)] = [:]

        for balance in viewModel.balances where balance.netBalance > 0 {
            // Only check for balances where money is owed to you
            let itemId = "balance_\(balance.userId)"
            let canSend = await nudgeService.canSendNudge(
                fromUserId: currentUserId,
                toUserId: balance.userId,
                itemId: itemId
            )

            // Get last nudge time
            let lastNudgeTime = await getLastNudgeTime(
                fromUserId: currentUserId,
                toUserId: balance.userId,
                itemId: itemId
            )

            states[balance.userId] = (canNudge: canSend, lastNudgeTime: lastNudgeTime)
        }

        await MainActor.run {
            nudgeStates = states
        }
    }

    private func getLastNudgeTime(fromUserId: String, toUserId: String, itemId: String) async -> Date? {
        // Get the most recent nudge
        do {
            let cutoffDate = Date().addingTimeInterval(-Nudge.cooldownHours * 3600)
            let db = Firestore.firestore()
            let snapshot = try await db.collection(Constants.Collections.nudges)
                .whereField("fromUserId", isEqualTo: fromUserId)
                .whereField("toUserId", isEqualTo: toUserId)
                .whereField("itemId", isEqualTo: itemId)
                .whereField("timestamp", isGreaterThan: Timestamp(date: cutoffDate))
                .order(by: "timestamp", descending: true)
                .limit(to: 1)
                .getDocuments()

            guard let doc = snapshot.documents.first,
                  let nudge = Nudge.fromFirestore(doc.data()) else {
                return nil
            }

            return nudge.timestamp
        } catch {
            return nil
        }
    }

    private func sendNudge(for balance: Balance) {
        guard let currentUserId = authService.userProfile?.id,
              let currentUserName = authService.userProfile?.displayName,
              let houseId = authService.userProfile?.currentHouseId else {
            return
        }

        let itemId = "balance_\(balance.userId)"
        let amountFormatted = CurrencyFormatter.format(amount: abs(balance.netBalance), currencyCode: currency)

        Task {
            do {
                try await nudgeService.sendNudge(
                    houseId: houseId,
                    fromUserId: currentUserId,
                    fromUserName: currentUserName,
                    toUserId: balance.userId,
                    toUserName: balance.userName,
                    type: .paymentOverdue,
                    itemId: itemId,
                    itemTitle: amountFormatted
                )

                // Show success feedback
                await MainActor.run {
                    HapticManager.success()
                }

                // Reload nudge states
                await loadNudgeStates()

                logger.info("Nudge sent successfully to \(balance.userName)")
            } catch {
                await MainActor.run {
                    HapticManager.error()
                }
                logger.error("Failed to send nudge: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ExpensesView()
}
