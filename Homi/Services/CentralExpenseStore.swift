import Foundation
import FirebaseFirestore
import Combine

/// Central store for all expense-related data (single source of truth)
@MainActor
final class CentralExpenseStore: ObservableObject {
    static let shared = CentralExpenseStore()

    // MARK: - Published Properties

    @Published private(set) var expenses: [Expense] = []
    @Published private(set) var payments: [Payment] = []
    @Published private(set) var balances: [Balance] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?

    // MARK: - Private Properties

    private var expenseListener: ListenerRegistration?
    private var paymentListener: ListenerRegistration?
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    private var houseId: String?
    private var currentUserId: String?
    private var houseMembers: [HouseMember] = []

    // MARK: - Initialization

    private init() {
        setupSubscriptions()
    }

    private func setupSubscriptions() {
        // Auto-recalculate balances when expenses or payments change
        Publishers.CombineLatest($expenses, $payments)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _, _ in
                guard let self = self,
                      self.currentUserId != nil else { return }

                Task {
                    await self.recalculateBalances()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    func initialize(houseId: String, currentUserId: String, houseMembers: [HouseMember]) {
        // Prevent duplicate initialization
        guard self.houseId != houseId || self.currentUserId != currentUserId else {
            print("CentralExpenseStore already initialized for house: \(houseId)")
            return
        }

        self.houseId = houseId
        self.currentUserId = currentUserId
        self.houseMembers = houseMembers

        startListening()
    }

    // MARK: - Listening Management

    private func startListening() {
        guard let houseId = houseId else { return }

        isLoading = true
        error = nil

        // Clean up existing listeners
        stopListening()

        // Start expense listener
        expenseListener = db.collection(Constants.Collections.houses)
            .document(houseId)
            .collection(Constants.Collections.expenses)
            .order(by: "date", descending: true)
            .limit(to: 100) // Pagination: load only recent 100
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    self.error = error
                    self.isLoading = false
                    print("Error listening to expenses: \(error)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    self.expenses = []
                    self.isLoading = false
                    return
                }

                self.expenses = documents.compactMap { doc in
                    try? doc.data(as: Expense.self)
                }.filter { $0.deletedAt == nil }

                print("Loaded \(self.expenses.count) expenses")
            }

        // Start payment listener
        paymentListener = db.collection(Constants.Collections.houses)
            .document(houseId)
            .collection(Constants.Collections.payments)
            .order(by: "timestamp", descending: true)
            .limit(to: 50) // Pagination: load only recent 50
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    self.error = error
                    self.isLoading = false
                    print("Error listening to payments: \(error)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    self.payments = []
                    self.isLoading = false
                    return
                }

                self.payments = documents.compactMap { doc in
                    try? doc.data(as: Payment.self)
                }

                self.isLoading = false
                print("Loaded \(self.payments.count) payments")
            }
    }

    func stopListening() {
        expenseListener?.remove()
        paymentListener?.remove()
        expenseListener = nil
        paymentListener = nil
    }

    // MARK: - Balance Calculation

    private func recalculateBalances() async {
        guard let currentUserId = currentUserId else { return }

        // Use cached balances if available
        if let cached = ExpenseCacheService.shared.getCachedBalances(for: currentUserId) {
            self.balances = cached
            return
        }

        // Calculate new balances
        let balances = await ExpenseService.shared.calculateBalances(
            currentUserId: currentUserId,
            houseMembers: houseMembers
        )

        self.balances = balances
    }

    // MARK: - Optimistic Updates

    func recordPaymentOptimistic(_ payment: Payment) async throws {
        // Add payment optimistically for immediate UI feedback
        payments.insert(payment, at: 0)

        // Recalculate balances immediately
        await recalculateBalances()

        do {
            // Record payment to Firebase
            try await ExpenseService.shared.recordPayment(payment: payment)

            // Invalidate cache after successful write
            ExpenseCacheService.shared.invalidateCache(for: "balances")

            print("Payment recorded successfully: \(payment.id)")
        } catch {
            // Rollback on failure
            payments.removeAll { $0.id == payment.id }
            await recalculateBalances()

            print("Failed to record payment, rolling back: \(error)")
            throw error
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        stopListening()
        expenses = []
        payments = []
        balances = []
        houseId = nil
        currentUserId = nil
        houseMembers = []
        ExpenseCacheService.shared.invalidateCache()
    }

    nonisolated deinit {
        // Note: Cannot call @MainActor methods from deinit
        // Cleanup will be handled when the instance is deallocated
        // or manually by calling cleanup() before deallocation
    }
}
