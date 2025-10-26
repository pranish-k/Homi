import SwiftUI
import OSLog

// MARK: - Redesigned Expenses View (Clean & Minimal)

struct ExpensesView: View {
    @StateObject private var viewModel = ExpenseViewModel()
    @StateObject private var authService = AuthService.shared
    @StateObject private var firestoreService = FirestoreService.shared

    @State private var showingAddExpense = false
    @State private var houseMembers: [HouseMember] = []
    @State private var selectedBalance: Balance?
    @State private var selectedExpense: Expense?
    @State private var showingSettlePayment = false
    @State private var showingPaymentHistory = false
    @State private var currentHouse: House?

    private let logger = Logger(subsystem: "com.homi.app", category: "ExpensesView")

    private var currency: String {
        currentHouse?.settings.currency ?? "USD"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Constants.Spacing.sectionSpacing) {
                    if authService.userProfile?.currentHouseId != nil {
                        // Total Balance Summary (Top)
                        totalBalanceHeader

                        // Individual Balances Section
                        balancesSection

                        // Recent Expenses Section
                        recentExpensesSection
                    } else {
                        noHouseView
                    }
                }
                .padding(.vertical, Constants.Spacing.medium)
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
            .sheet(item: $selectedBalance) { balance in
                SettlePaymentView(viewModel: viewModel, balance: balance)
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
                        showingSettlePayment = true
                    },
                    onViewHistory: {
                        showingPaymentHistory = true
                    }
                )
                .padding(.horizontal, Constants.Spacing.screenPadding)
            }
        }
    }

    // MARK: - Recent Expenses Section

    private var recentExpensesSection: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.medium) {
            Text("Recent Expenses")
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
            } catch {
                logger.error("Error loading data: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ExpensesView()
}
