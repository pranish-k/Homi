import Foundation
import SwiftUI
import Combine
import OSLog
import FirebaseAuth

// MARK: - Dashboard ViewModel

@MainActor
class DashboardViewModel: ObservableObject {
    // Published properties
    @Published var currentHouse: House?
    @Published var houseMembers: [HouseMember] = []

    // Stats
    @Published var upcomingChores: [Chore] = []
    @Published var myBalance: Double = 0.0
    @Published var recentMessages: [Message] = []
    @Published var activeSharingMembers: Int = 0

    // Loading states
    @Published var isLoading = true
    @Published var errorMessage: String?

    // Services
    private let authService = AuthService.shared
    private let firestoreService = FirestoreService.shared
    private let choreService = ChoreService.shared
    private let expenseService = ExpenseService.shared
    private let messagingService = MessagingService.shared
    private let locationService = LocationService.shared

    private let logger = Logger(subsystem: "com.homi.app", category: "DashboardViewModel")
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Subscribe to chores updates
        choreService.$chores
            .receive(on: DispatchQueue.main)
            .sink { [weak self] chores in
                self?.updateUpcomingChores(chores)
            }
            .store(in: &cancellables)

        // Subscribe to expenses updates
        expenseService.$expenses
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateBalance()
            }
            .store(in: &cancellables)

        // Subscribe to messages updates
        messagingService.$messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] messages in
                self?.updateRecentMessages(messages)
            }
            .store(in: &cancellables)

        // Subscribe to location updates
        locationService.$userLocations
            .receive(on: DispatchQueue.main)
            .sink { [weak self] locations in
                self?.activeSharingMembers = locations.filter { $0.isSharingEnabled && $0.isRecent }.count
            }
            .store(in: &cancellables)
    }

    // MARK: - Load Data

    func loadData() async {
        guard let houseId = authService.userProfile?.currentHouseId else {
            logger.warning("No house ID found")
            isLoading = false
            return
        }

        isLoading = true

        do {
            // Load house info
            currentHouse = try await firestoreService.getHouse(id: houseId)
            houseMembers = try await firestoreService.getHouseMembers(houseId: houseId)

            // Start listening to real-time updates
            choreService.startListeningToChores(houseId: houseId)
            expenseService.startListeningToExpenses(houseId: houseId)
            messagingService.startListeningToMessages(houseId: houseId)
            locationService.startListening(houseId: houseId)

            logger.info("Dashboard data loaded successfully")
        } catch {
            logger.error("Error loading dashboard data: \(error.localizedDescription)")
            errorMessage = "Failed to load dashboard data"
        }

        isLoading = false
    }

    // MARK: - Update Stats

    private func updateUpcomingChores(_ allChores: [Chore]) {
        // Get next 3 upcoming chores (not completed, sorted by due date)
        upcomingChores = allChores
            .filter { !$0.isCompleted }
            .sorted { $0.dueDate < $1.dueDate }
            .prefix(3)
            .map { $0 }
    }

    private func updateBalance() {
        guard let userId = authService.user?.uid else { return }

        // Calculate net balance (what you're owed - what you owe)
        let balances = expenseService.calculateBalances(currentUserId: userId, houseMembers: houseMembers)

        // Sum up all balances - positive means they owe you, negative means you owe them
        myBalance = balances.reduce(into: 0.0) { result, balance in
            result += balance.netBalance
        }
    }

    private func updateRecentMessages(_ allMessages: [Message]) {
        // Get last 3 messages
        recentMessages = allMessages
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(3)
            .map { $0 }
    }

    // MARK: - Computed Properties

    var overdueChoresCount: Int {
        choreService.chores.filter { !$0.isCompleted && $0.dueDate < Date() }.count
    }

    var dueTodayChoresCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        return choreService.chores.filter { chore in
            !chore.isCompleted &&
            chore.dueDate >= today &&
            chore.dueDate < tomorrow
        }.count
    }

    var unreadMessagesCount: Int {
        guard let userId = authService.user?.uid else { return 0 }
        return messagingService.messages.filter { !$0.readBy.contains(userId) }.count
    }

    var balanceText: String {
        let absBalance = abs(myBalance)
        if myBalance > 0 {
            return "+\(CurrencyFormatter.format(amount: absBalance))"
        } else if myBalance < 0 {
            return "-\(CurrencyFormatter.format(amount: absBalance))"
        } else {
            return CurrencyFormatter.format(amount: 0)
        }
    }

    var balanceColor: Color {
        if myBalance > 0 {
            return Constants.Colors.success
        } else if myBalance < 0 {
            return Constants.Colors.danger
        } else {
            return Constants.Colors.textSecondary
        }
    }

    // What's Next - Most urgent item to show user
    var whatsNextItem: WhatsNextItemType {
        // Priority 1: Overdue chore
        if let overdueChore = choreService.chores
            .filter({ !$0.isCompleted && $0.dueDate < Date() })
            .sorted(by: { $0.dueDate < $1.dueDate })
            .first {
            return .overdueChore(overdueChore)
        }

        // Priority 2: Payment owed by user
        guard let userId = authService.user?.uid else {
            return .allCaughtUp
        }

        if myBalance < 0 {
            // Find who user owes the most
            let balances = expenseService.calculateBalances(currentUserId: userId, houseMembers: houseMembers)
            if let maxDebt = balances.filter({ $0.netBalance < 0 }).max(by: { abs($0.netBalance) < abs($1.netBalance) }) {
                return .overduePayment(amount: abs(maxDebt.netBalance), person: maxDebt.userName)
            }
        }

        // Priority 3: Chore due today
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        if let dueTodayChore = choreService.chores
            .filter({ !$0.isCompleted && $0.dueDate >= today && $0.dueDate < tomorrow })
            .sorted(by: { $0.dueDate < $1.dueDate })
            .first {
            return .dueToday(dueTodayChore)
        }

        // No urgent items
        return .allCaughtUp
    }

    // MARK: - Actions

    func shareInvite() {
        guard let house = currentHouse else { return }

        let message = """
        Join our house "\(house.name)" on Homi! 🏠

        Use this invite code: \(house.inviteCode)

        Download Homi to stay organized with your housemates!
        """

        let activityVC = UIActivityViewController(
            activityItems: [message],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        choreService.stopListening()
        expenseService.stopListening()
        messagingService.stopListening()
        locationService.stopListening()
        cancellables.removeAll()
    }
}
