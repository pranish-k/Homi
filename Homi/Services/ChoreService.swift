import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine
import OSLog

@MainActor
class ChoreService: ObservableObject {
    static let shared = ChoreService()

    @Published var chores: [Chore] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var choresListener: ListenerRegistration?
    private let logger = Logger(subsystem: "com.homi.app", category: "ChoreService")

    private init() {}

    // MARK: - Chore Operations

    /// Create a new chore
    func createChore(chore: Chore) async throws {
        let choreRef = db.collection(Constants.Collections.houses)
            .document(chore.houseId)
            .collection(Constants.Collections.chores)
            .document(chore.id)

        try await choreRef.setData(chore.asDictionary)
    }

    /// Get all chores for a house
    func getChores(houseId: String) async throws -> [Chore] {
        let snapshot = try await db.collection(Constants.Collections.houses)
            .document(houseId)
            .collection(Constants.Collections.chores)
            .order(by: "dueDate", descending: false)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            Chore.fromFirestore(doc.data())
        }
    }

    /// Start listening to chores in real-time
    func startListeningToChores(houseId: String) {
        stopListening()

        isLoading = true

        choresListener = db.collection(Constants.Collections.houses)
            .document(houseId)
            .collection(Constants.Collections.chores)
            .order(by: "dueDate", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    return
                }

                guard let documents = snapshot?.documents else {
                    self.isLoading = false
                    return
                }

                self.chores = documents.compactMap { doc in
                    Chore.fromFirestore(doc.data())
                }

                self.isLoading = false
            }
    }

    /// Update a chore
    func updateChore(houseId: String, chore: Chore) async throws {
        let choreRef = db.collection(Constants.Collections.houses)
            .document(houseId)
            .collection(Constants.Collections.chores)
            .document(chore.id)

        try await choreRef.updateData(chore.asDictionary)
    }

    /// Delete a chore
    func deleteChore(houseId: String, choreId: String) async throws {
        try await db.collection(Constants.Collections.houses)
            .document(houseId)
            .collection(Constants.Collections.chores)
            .document(choreId)
            .delete()
    }

    /// Mark chore as complete
    func markChoreComplete(houseId: String, choreId: String, userId: String, userName: String) async throws {
        let choreRef = db.collection(Constants.Collections.houses)
            .document(houseId)
            .collection(Constants.Collections.chores)
            .document(choreId)

        let document = try await choreRef.getDocument()
        guard let chore = Chore.fromFirestore(document.data() ?? [:]) else {
            throw NSError(domain: "ChoreService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not parse chore"])
        }

        // Mark as complete
        try await choreRef.updateData([
            "isCompleted": true,
            "completedAt": Timestamp(date: Date()),
            "completedBy": userId,
            "completedByName": userName
        ])

        // If recurring, create next occurrence
        if chore.frequency != .once {
            try await createNextOccurrence(chore: chore, houseId: houseId)
        }
    }

    /// Mark chore as incomplete
    func markChoreIncomplete(houseId: String, choreId: String) async throws {
        let choreRef = db.collection(Constants.Collections.houses)
            .document(houseId)
            .collection(Constants.Collections.chores)
            .document(choreId)

        try await choreRef.updateData([
            "isCompleted": false,
            "completedAt": FieldValue.delete(),
            "completedBy": FieldValue.delete(),
            "completedByName": FieldValue.delete()
        ])
    }

    /// Create next occurrence for recurring chore
    private func createNextOccurrence(chore: Chore, houseId: String) async throws {
        let nextDueDate = chore.nextDueDate()

        // Determine next assignee if rotation is enabled
        var nextAssignee = chore.assignedTo
        var nextAssigneeName = chore.assignedToName

        if chore.rotationEnabled, let nextUserId = chore.nextAssignee() {
            nextAssignee = nextUserId

            // Fetch the actual assignee name from Firestore
            do {
                let userDoc = try await db.collection(Constants.Collections.users)
                    .document(nextUserId)
                    .getDocument()

                if let user = User(document: userDoc) {
                    nextAssigneeName = user.displayName
                } else {
                    nextAssigneeName = "Unknown User"
                }
            } catch {
                logger.error("Error fetching next assignee name: \(error.localizedDescription)")
                nextAssigneeName = "Unknown User"
            }
        }

        let nextChore = Chore(
            houseId: houseId,
            title: chore.title,
            description: chore.description,
            assignedTo: nextAssignee,
            assignedToName: nextAssigneeName,
            createdBy: chore.createdBy,
            dueDate: nextDueDate,
            frequency: chore.frequency,
            category: chore.category,
            points: chore.points,
            rotationEnabled: chore.rotationEnabled,
            rotationOrder: chore.rotationOrder
        )

        try await createChore(chore: nextChore)
    }

    // MARK: - Query Operations

    /// Get upcoming chores (not completed, due within X days)
    func getUpcomingChores(houseId: String, days: Int = 7) async throws -> [Chore] {
        let endDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()

        let snapshot = try await db.collection(Constants.Collections.houses)
            .document(houseId)
            .collection(Constants.Collections.chores)
            .whereField("isCompleted", isEqualTo: false)
            .whereField("dueDate", isLessThanOrEqualTo: Timestamp(date: endDate))
            .order(by: "dueDate", descending: false)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            Chore.fromFirestore(doc.data())
        }
    }

    /// Get chores assigned to a specific user
    func getChoresByAssignee(houseId: String, userId: String) async throws -> [Chore] {
        let snapshot = try await db.collection(Constants.Collections.houses)
            .document(houseId)
            .collection(Constants.Collections.chores)
            .whereField("assignedTo", isEqualTo: userId)
            .whereField("isCompleted", isEqualTo: false)
            .order(by: "dueDate", descending: false)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            Chore.fromFirestore(doc.data())
        }
    }

    /// Get overdue chores
    func getOverdueChores(houseId: String) async throws -> [Chore] {
        let now = Date()

        let snapshot = try await db.collection(Constants.Collections.houses)
            .document(houseId)
            .collection(Constants.Collections.chores)
            .whereField("isCompleted", isEqualTo: false)
            .whereField("dueDate", isLessThan: Timestamp(date: now))
            .order(by: "dueDate", descending: false)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            Chore.fromFirestore(doc.data())
        }
    }

    // MARK: - Stats

    /// Get completion rate for a user
    func getCompletionRate(houseId: String, userId: String) async throws -> Double {
        // Get all chores assigned to user (completed and incomplete)
        let allSnapshot = try await db.collection(Constants.Collections.houses)
            .document(houseId)
            .collection(Constants.Collections.chores)
            .whereField("assignedTo", isEqualTo: userId)
            .getDocuments()

        let total = allSnapshot.documents.count
        guard total > 0 else { return 0.0 }

        let completed = allSnapshot.documents.filter { doc in
            let data = doc.data()
            return data["isCompleted"] as? Bool ?? false
        }.count

        return Double(completed) / Double(total)
    }

    /// Get count of completed chores for a user
    func getChoresCompletedCount(houseId: String, userId: String) async throws -> Int {
        let snapshot = try await db.collection(Constants.Collections.houses)
            .document(houseId)
            .collection(Constants.Collections.chores)
            .whereField("completedBy", isEqualTo: userId)
            .getDocuments()

        return snapshot.documents.count
    }

    // MARK: - Cleanup

    func stopListening() {
        choresListener?.remove()
        choresListener = nil
    }

    func clearChores() {
        chores = []
    }
}
