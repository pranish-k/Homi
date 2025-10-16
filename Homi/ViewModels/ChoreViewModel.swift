import SwiftUI
import Combine
import FirebaseAuth

@MainActor
class ChoreViewModel: ObservableObject {
    @Published var chores: [Chore] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    // Add chore form fields
    @Published var title: String = ""
    @Published var description: String = ""
    @Published var selectedAssignee: String = ""
    @Published var selectedDate: Date = Date()
    @Published var selectedFrequency: ChoreFrequency = .once
    @Published var selectedCategory: ChoreCategory = .other
    @Published var points: String = "0"
    @Published var rotationEnabled: Bool = false
    @Published var selectedRotationMembers: [String] = []

    private let choreService = ChoreService.shared
    private let authService = AuthService.shared
    private var cancellables = Set<AnyCancellable>()
    private var currentHouseId: String?

    var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    init() {
        // Subscribe to chore service
        choreService.$chores
            .assign(to: &$chores)

        choreService.$isLoading
            .assign(to: &$isLoading)

        choreService.$errorMessage
            .sink { [weak self] error in
                if let error = error {
                    self?.errorMessage = error
                    self?.showError = true
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Lifecycle

    func startListening(houseId: String) {
        currentHouseId = houseId
        choreService.startListeningToChores(houseId: houseId)
    }

    func stopListening() {
        choreService.stopListening()
    }

    // MARK: - Chore Operations

    func createChore() async {
        guard let houseId = currentHouseId,
              let userId = currentUserId,
              let _ = authService.userProfile?.displayName else {
            errorMessage = "Missing required information"
            showError = true
            return
        }

        // Validate
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter a title"
            showError = true
            return
        }

        guard !selectedAssignee.isEmpty else {
            errorMessage = "Please select an assignee"
            showError = true
            return
        }

        guard let pointsValue = Int(points), pointsValue >= 0 else {
            errorMessage = "Please enter valid points (0 or more)"
            showError = true
            return
        }

        // Validate rotation
        if rotationEnabled && selectedRotationMembers.count < 2 {
            errorMessage = "Please select at least 2 members for rotation"
            showError = true
            return
        }

        // Get house members for names
        let members = try? await FirestoreService.shared.getHouseMembers(houseId: houseId)
        guard let members = members else {
            errorMessage = "Could not load house members"
            showError = true
            return
        }

        let assigneeName = members.first { $0.userId == selectedAssignee }?.displayName ?? "Unknown"

        // Build rotation order if enabled
        var rotationOrder: [String]? = nil
        if rotationEnabled {
            rotationOrder = selectedRotationMembers
        }

        let chore = Chore(
            houseId: houseId,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
            assignedTo: selectedAssignee,
            assignedToName: assigneeName,
            createdBy: userId,
            dueDate: selectedDate,
            frequency: selectedFrequency,
            category: selectedCategory,
            points: pointsValue,
            rotationEnabled: rotationEnabled,
            rotationOrder: rotationOrder
        )

        do {
            try await choreService.createChore(chore: chore)
            resetForm()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func updateChore(_ chore: Chore) async {
        guard let houseId = currentHouseId else { return }

        do {
            try await choreService.updateChore(houseId: houseId, chore: chore)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func deleteChore(_ chore: Chore) async {
        guard let houseId = currentHouseId else { return }

        do {
            try await choreService.deleteChore(houseId: houseId, choreId: chore.id)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func markComplete(_ chore: Chore) async {
        guard let houseId = currentHouseId,
              let userId = currentUserId,
              let userName = authService.userProfile?.displayName else {
            errorMessage = "Missing required information"
            showError = true
            return
        }

        do {
            try await choreService.markChoreComplete(houseId: houseId, choreId: chore.id, userId: userId, userName: userName)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func markIncomplete(_ chore: Chore) async {
        guard let houseId = currentHouseId else { return }

        do {
            try await choreService.markChoreIncomplete(houseId: houseId, choreId: chore.id)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Query Operations

    func getUpcomingChores(days: Int = 7) async -> [Chore] {
        guard let houseId = currentHouseId else { return [] }

        do {
            return try await choreService.getUpcomingChores(houseId: houseId, days: days)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return []
        }
    }

    func getMyChores() async -> [Chore] {
        guard let houseId = currentHouseId,
              let userId = currentUserId else { return [] }

        do {
            return try await choreService.getChoresByAssignee(houseId: houseId, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return []
        }
    }

    func getOverdueChores() async -> [Chore] {
        guard let houseId = currentHouseId else { return [] }

        do {
            return try await choreService.getOverdueChores(houseId: houseId)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return []
        }
    }

    // MARK: - Stats

    func getCompletionRate(userId: String) async -> Double {
        guard let houseId = currentHouseId else { return 0.0 }

        do {
            return try await choreService.getCompletionRate(houseId: houseId, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return 0.0
        }
    }

    func getChoresCompletedCount(userId: String) async -> Int {
        guard let houseId = currentHouseId else { return 0 }

        do {
            return try await choreService.getChoresCompletedCount(houseId: houseId, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return 0
        }
    }

    // MARK: - Filters

    func getActiveChores() -> [Chore] {
        return chores.filter { !$0.isCompleted }
    }

    func getCompletedChores() -> [Chore] {
        return chores.filter { $0.isCompleted }
    }

    func getChoresByAssignee(userId: String) -> [Chore] {
        return chores.filter { $0.assignedTo == userId && !$0.isCompleted }
    }

    func getChoresByCategory(_ category: ChoreCategory) -> [Chore] {
        return chores.filter { $0.category == category && !$0.isCompleted }
    }

    func getOverdueChoresSync() -> [Chore] {
        return chores.filter { $0.isOverdue }
    }

    func getDueTodayChores() -> [Chore] {
        return chores.filter { $0.isDueToday && !$0.isCompleted }
    }

    // MARK: - Permissions

    func canEditChore(_ chore: Chore) -> Bool {
        guard let userId = currentUserId else { return false }
        return chore.createdBy == userId || chore.assignedTo == userId
    }

    func canDeleteChore(_ chore: Chore) -> Bool {
        guard let userId = currentUserId else { return false }
        return chore.createdBy == userId
    }

    func canCompleteChore(_ chore: Chore) -> Bool {
        guard let userId = currentUserId else { return false }
        return chore.assignedTo == userId && !chore.isCompleted
    }

    // MARK: - Helpers

    func resetForm() {
        title = ""
        description = ""
        selectedAssignee = ""
        selectedDate = Date()
        selectedFrequency = .once
        selectedCategory = .other
        points = "0"
        rotationEnabled = false
        selectedRotationMembers = []
    }

    // Get total points for a user
    func getTotalPoints(userId: String) -> Int {
        return chores
            .filter { $0.completedBy == userId }
            .reduce(0) { $0 + $1.points }
    }
}
