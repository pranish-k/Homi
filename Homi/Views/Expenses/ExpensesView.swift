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
    @State private var showingBalanceInfo = false

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
            .sheet(isPresented: $showingSettleUp, onDismiss: {
                selectedBalance = nil
            }) {
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
                } else {
                    Text("Loading...")
                        .padding()
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
            .sheet(isPresented: $showingBalanceInfo) {
                BalanceInfoSheet()
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
        VStack(spacing: Constants.Spacing.medium) {
            // Top row: Two cards side by side
            HStack(spacing: Constants.Spacing.medium) {
                // You owe card
                BalanceCardComponent(
                    title: "You owe",
                    amount: viewModel.getTotalYouOwe(),
                    currency: currency,
                    color: Constants.Colors.danger
                )

                // You are owed card
                BalanceCardComponent(
                    title: "You are owed",
                    amount: viewModel.getTotalOwedToYou(),
                    currency: currency,
                    color: Constants.Colors.success
                )
            }

            // Overall balance card
            HStack(spacing: 4) {
                Text("Overall balance")
                    .font(Constants.Typography.subheadline)
                    .foregroundColor(Constants.Colors.textSecondary)

                Button(action: {
                    showingBalanceInfo = true
                    HapticManager.selection()
                }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundColor(Constants.Colors.textSecondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HomiCard(shadowStyle: .subtle) {
                HStack {
                    Text(formattedNetBalance)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(netBalanceColor)

                    Spacer()

                    if netBalance == 0 {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Constants.Colors.success)
                    }
                }
                .padding(Constants.Spacing.medium)
            }
        }
        .padding(.horizontal, Constants.Spacing.screenPadding)
        .padding(.vertical, Constants.Spacing.large)
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

// MARK: - Balance Info Sheet

struct BalanceInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Constants.Spacing.large) {
                    // Header
                    VStack(alignment: .leading, spacing: Constants.Spacing.small) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(Constants.Colors.primary)

                            Spacer()
                        }

                        Text("Understanding Your Bills")
                            .font(Constants.Typography.title2)
                            .foregroundColor(Constants.Colors.textPrimary)

                        Text("Here's how we track what you owe and what others owe you")
                            .font(Constants.Typography.body)
                            .foregroundColor(Constants.Colors.textSecondary)
                    }

                    Divider()

                    // You Owe
                    InfoSection(
                        icon: "arrow.down.circle.fill",
                        iconColor: Constants.Colors.danger,
                        title: "You owe",
                        description: "The total amount you need to pay back to all your housemates. This is calculated from expenses others paid that you participated in but haven't paid back yet."
                    )

                    // You Are Owed
                    InfoSection(
                        icon: "arrow.up.circle.fill",
                        iconColor: Constants.Colors.success,
                        title: "You are owed",
                        description: "The total amount your housemates need to pay you back. This comes from expenses you paid that were split with others who haven't paid their share yet."
                    )

                    Divider()

                    // Overall Balance Section
                    InfoSection(
                        icon: "chart.bar.fill",
                        iconColor: Constants.Colors.primary,
                        title: "Overall balance",
                        description: "Your net financial position with all housemates. This is calculated as (You are owed) minus (You owe)."
                    )

                    // Positive Balance
                    InfoSection(
                        icon: "plus.circle.fill",
                        iconColor: Constants.Colors.success,
                        title: "Positive Overall Balance (Green)",
                        description: "You're owed more than you owe overall. Your housemates owe you money on net."
                    )

                    // Negative Balance
                    InfoSection(
                        icon: "minus.circle.fill",
                        iconColor: Constants.Colors.danger,
                        title: "Negative Overall Balance (Red)",
                        description: "You owe more than you're owed overall. You owe your housemates money on net."
                    )

                    // Settled Up
                    InfoSection(
                        icon: "checkmark.circle.fill",
                        iconColor: Constants.Colors.textSecondary,
                        title: "All Settled Up ($0.00)",
                        description: "Your overall balance is zero! Either everyone has paid you back and you've paid everyone, or the amounts perfectly cancel out."
                    )

                    Divider()

                    // Individual Balances
                    VStack(alignment: .leading, spacing: Constants.Spacing.small) {
                        HStack {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Constants.Colors.primary)

                            Text("Individual Balances")
                                .font(Constants.Typography.headline)
                                .foregroundColor(Constants.Colors.textPrimary)
                        }

                        Text("Below your total balance, you'll see a breakdown with each housemate:")
                            .font(Constants.Typography.body)
                            .foregroundColor(Constants.Colors.textSecondary)

                        VStack(alignment: .leading, spacing: Constants.Spacing.xSmall) {
                            BulletPoint(text: "\"Owes you\" - They need to pay you back")
                            BulletPoint(text: "\"You owe\" - You need to pay them back")
                        }
                        .padding(.leading, Constants.Spacing.small)
                    }

                    Divider()

                    // How It Works
                    VStack(alignment: .leading, spacing: Constants.Spacing.small) {
                        HStack {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Constants.Colors.primary)

                            Text("How It Works")
                                .font(Constants.Typography.headline)
                                .foregroundColor(Constants.Colors.textPrimary)
                        }

                        VStack(alignment: .leading, spacing: Constants.Spacing.small) {
                            NumberedStep(number: 1, text: "Someone pays for an expense (groceries, rent, etc.)")
                            NumberedStep(number: 2, text: "The bill is split among selected housemates")
                            NumberedStep(number: 3, text: "Everyone except the payer owes their share")
                            NumberedStep(number: 4, text: "When you pay back, the balance updates automatically")
                        }
                    }

                    Divider()

                    // Example
                    VStack(alignment: .leading, spacing: Constants.Spacing.small) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.yellow)

                            Text("Example")
                                .font(Constants.Typography.headline)
                                .foregroundColor(Constants.Colors.textPrimary)
                        }

                        ExampleCard(
                            scenario: "You paid $60 for groceries, split 3 ways",
                            result: "Each person owes $20",
                            yourBalance: "+$40",
                            explanation: "Your 2 housemates each owe you $20"
                        )
                    }
                }
                .padding(Constants.Spacing.screenPadding)
            }
            .navigationTitle("Balance Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Constants.Colors.primary)
                }
            }
        }
    }
}

// MARK: - Info Components

struct InfoSection: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: Constants.Spacing.medium) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(iconColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: Constants.Spacing.xxSmall) {
                Text(title)
                    .font(Constants.Typography.bodyMedium)
                    .foregroundColor(Constants.Colors.textPrimary)

                Text(description)
                    .font(Constants.Typography.body)
                    .foregroundColor(Constants.Colors.textSecondary)
            }
        }
    }
}

struct BulletPoint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Constants.Spacing.xSmall) {
            Text("•")
                .font(Constants.Typography.body)
                .foregroundColor(Constants.Colors.textSecondary)

            Text(text)
                .font(Constants.Typography.body)
                .foregroundColor(Constants.Colors.textSecondary)
        }
    }
}

struct NumberedStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Constants.Spacing.small) {
            Text("\(number).")
                .font(Constants.Typography.bodyMedium)
                .foregroundColor(Constants.Colors.primary)
                .frame(width: 24, alignment: .leading)

            Text(text)
                .font(Constants.Typography.body)
                .foregroundColor(Constants.Colors.textSecondary)
        }
    }
}

struct ExampleCard: View {
    let scenario: String
    let result: String
    let yourBalance: String
    let explanation: String

    var body: some View {
        HomiCard(shadowStyle: .subtle) {
            VStack(alignment: .leading, spacing: Constants.Spacing.small) {
                HStack {
                    Image(systemName: "cart.fill")
                        .foregroundColor(Constants.Colors.success)
                    Text(scenario)
                        .font(Constants.Typography.bodyMedium)
                        .foregroundColor(Constants.Colors.textPrimary)
                }

                Text("→ \(result)")
                    .font(Constants.Typography.body)
                    .foregroundColor(Constants.Colors.textSecondary)
                    .padding(.leading, Constants.Spacing.medium)

                HStack {
                    Text("Your Balance:")
                        .font(Constants.Typography.body)
                        .foregroundColor(Constants.Colors.textSecondary)

                    Text(yourBalance)
                        .font(Constants.Typography.bodyMedium)
                        .foregroundColor(Constants.Colors.success)
                }
                .padding(.top, Constants.Spacing.xxSmall)

                Text(explanation)
                    .font(Constants.Typography.caption1)
                    .foregroundColor(Constants.Colors.textSecondary)
                    .italic()
            }
            .padding(Constants.Spacing.cardPadding)
        }
    }
}

// MARK: - Balance Card Component

struct BalanceCardComponent: View {
    let title: String
    let amount: Double
    let currency: String
    let color: Color

    var body: some View {
        HomiCard(shadowStyle: .subtle) {
            VStack(alignment: .leading, spacing: Constants.Spacing.xSmall) {
                Text(title)
                    .font(Constants.Typography.caption1)
                    .foregroundColor(Constants.Colors.textSecondary)

                Text(CurrencyFormatter.format(amount: amount, currencyCode: currency))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(amount > 0 ? color : Constants.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Constants.Spacing.medium)
        }
    }
}

// MARK: - Preview

#Preview {
    ExpensesView()
}
