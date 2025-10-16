import SwiftUI

struct ExpensesView: View {
    @StateObject private var viewModel = ExpenseViewModel()
    @StateObject private var authService = AuthService.shared
    @StateObject private var firestoreService = FirestoreService.shared

    @State private var showingAddExpense = false
    @State private var selectedTab = 0
    @State private var houseMembers: [HouseMember] = []
    @State private var selectedBalance: Balance?
    @State private var showingSettlePayment = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if authService.userProfile?.currentHouseId != nil {
                    // Tab selector
                    Picker("View", selection: $selectedTab) {
                        Text("Expenses").tag(0)
                        Text("Balances").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, Constants.Spacing.medium)
                    .padding(.vertical, Constants.Spacing.small)

                    // Content based on selected tab
                    if selectedTab == 0 {
                        expensesListView
                    } else {
                        balancesView
                    }
                } else {
                    noHouseView
                }
            }
            .navigationTitle("Bills & Expenses")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if authService.userProfile?.currentHouseId != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingAddExpense = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
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
            .onAppear {
                loadData()
            }
            .onDisappear {
                viewModel.stopListening()
            }
        }
    }

    // MARK: - Expenses List View

    private var expensesListView: some View {
        ScrollView {
            LazyVStack(spacing: Constants.Spacing.medium) {
                if viewModel.isLoading && viewModel.expenses.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 100)
                } else if viewModel.expenses.isEmpty {
                    emptyExpensesView
                } else {
                    ForEach(viewModel.expenses) { expense in
                        ExpenseCardView(
                            expense: expense,
                            currentUserId: viewModel.currentUserId ?? "",
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
            }
            .padding(Constants.Spacing.medium)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Balances View

    private var balancesView: some View {
        ScrollView {
            BalanceSummaryView(
                balances: viewModel.balances,
                totalYouOwe: viewModel.getTotalYouOwe(),
                totalOwedToYou: viewModel.getTotalOwedToYou(),
                onSettle: { balance in
                    selectedBalance = balance
                    showingSettlePayment = true
                }
            )
            .padding(Constants.Spacing.medium)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Empty States

    private var emptyExpensesView: some View {
        VStack(spacing: Constants.Spacing.large) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(Constants.Colors.primary)

            Text("No Expenses Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Constants.Colors.textPrimary)

            Text("Tap the + button to add your first expense")
                .font(.body)
                .foregroundColor(Constants.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Constants.Spacing.xLarge)

            Button {
                showingAddExpense = true
            } label: {
                Label("Add Expense", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, Constants.Spacing.large)
                    .padding(.vertical, Constants.Spacing.medium)
                    .background(Constants.Colors.primary)
                    .cornerRadius(Constants.CornerRadius.medium)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }

    private var noHouseView: some View {
        VStack(spacing: Constants.Spacing.large) {
            Image(systemName: "house.slash")
                .font(.system(size: 60))
                .foregroundColor(Constants.Colors.textSecondary)

            Text("No House Found")
                .font(.title2)
                .fontWeight(.semibold)

            Text("You need to be part of a house to track expenses")
                .font(.body)
                .foregroundColor(Constants.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Constants.Spacing.xLarge)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Data Loading

    private func loadData() {
        guard let houseId = authService.userProfile?.currentHouseId else { return }

        Task {
            do {
                // Load house members
                let members = try await firestoreService.getHouseMembers(houseId: houseId)
                await MainActor.run {
                    houseMembers = members
                }

                // Start listening to expenses
                viewModel.startListening(houseId: houseId, houseMembers: members)
            } catch {
                print("Error loading data: \(error)")
            }
        }
    }
}

// MARK: - Preview

struct ExpensesView_Previews: PreviewProvider {
    static var previews: some View {
        ExpensesView()
    }
}
