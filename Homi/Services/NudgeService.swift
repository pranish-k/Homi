import Foundation
import FirebaseFirestore
import Combine
import OSLog

// MARK: - Nudge Service

@MainActor
class NudgeService: ObservableObject {
    static let shared = NudgeService()

    @Published var recentNudges: [Nudge] = []

    private let db = Firestore.firestore()
    private let logger = Logger(subsystem: "com.homi.app", category: "NudgeService")
    private var listener: ListenerRegistration?

    private init() {}

    // MARK: - Send Nudge

    func sendNudge(
        houseId: String,
        fromUserId: String,
        fromUserName: String,
        toUserId: String,
        toUserName: String,
        type: NudgeType,
        itemId: String,
        itemTitle: String
    ) async throws {
        // Check if there's a recent nudge for this item
        if let recentNudge = try await getRecentNudge(
            fromUserId: fromUserId,
            toUserId: toUserId,
            itemId: itemId
        ) {
            if recentNudge.isWithinCooldown {
                throw NudgeError.cooldownActive(
                    remainingHours: Int(Nudge.cooldownHours - (Date().timeIntervalSince(recentNudge.timestamp) / 3600))
                )
            }
        }

        // Create new nudge
        let nudge = Nudge(
            houseId: houseId,
            fromUserId: fromUserId,
            fromUserName: fromUserName,
            toUserId: toUserId,
            toUserName: toUserName,
            type: type,
            itemId: itemId,
            itemTitle: itemTitle
        )

        // Save to Firestore
        try await db.collection(Constants.Collections.nudges)
            .document(nudge.id)
            .setData(nudge.asDictionary)

        logger.info("Nudge sent: \(nudge.id)")

        // TODO: Send push notification via Cloud Function
        // This would trigger a Cloud Function to send FCM notification to toUserId
    }

    // MARK: - Get Recent Nudge

    private func getRecentNudge(
        fromUserId: String,
        toUserId: String,
        itemId: String
    ) async throws -> Nudge? {
        let cutoffDate = Date().addingTimeInterval(-Nudge.cooldownHours * 3600)

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

        return nudge
    }

    // MARK: - Get Nudge History

    func getNudgeHistory(userId: String, limit: Int = 20) async throws -> [Nudge] {
        let snapshot = try await db.collection(Constants.Collections.nudges)
            .whereField("toUserId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { Nudge.fromFirestore($0.data()) }
    }

    // MARK: - Listen to Nudges

    func startListening(userId: String) {
        stopListening()

        listener = db.collection(Constants.Collections.nudges)
            .whereField("toUserId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    self.logger.error("Error listening to nudges: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else { return }

                Task { @MainActor in
                    self.recentNudges = documents.compactMap { Nudge.fromFirestore($0.data()) }
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Can Send Nudge

    func canSendNudge(
        fromUserId: String,
        toUserId: String,
        itemId: String
    ) async -> Bool {
        do {
            if let recentNudge = try await getRecentNudge(
                fromUserId: fromUserId,
                toUserId: toUserId,
                itemId: itemId
            ) {
                return !recentNudge.isWithinCooldown
            }
            return true
        } catch {
            logger.error("Error checking nudge eligibility: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Get Last Nudge Time

    func getLastNudgeTime(
        fromUserId: String,
        toUserId: String,
        itemId: String
    ) async -> Date? {
        do {
            if let recentNudge = try await getRecentNudge(
                fromUserId: fromUserId,
                toUserId: toUserId,
                itemId: itemId
            ) {
                return recentNudge.timestamp
            }
            return nil
        } catch {
            logger.error("Error getting last nudge time: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Get Time Until Next Nudge

    func timeUntilNextNudge(
        fromUserId: String,
        toUserId: String,
        itemId: String
    ) async -> String? {
        do {
            if let recentNudge = try await getRecentNudge(
                fromUserId: fromUserId,
                toUserId: toUserId,
                itemId: itemId
            ) {
                if recentNudge.isWithinCooldown {
                    let remainingSeconds = (Nudge.cooldownHours * 3600) - Date().timeIntervalSince(recentNudge.timestamp)
                    let hours = Int(remainingSeconds / 3600)
                    let minutes = Int((remainingSeconds.truncatingRemainder(dividingBy: 3600)) / 60)

                    if hours > 0 {
                        return "\(hours)h \(minutes)m"
                    } else {
                        return "\(minutes)m"
                    }
                }
            }
            return nil
        } catch {
            return nil
        }
    }
}

// MARK: - Nudge Error

enum NudgeError: LocalizedError {
    case cooldownActive(remainingHours: Int)

    var errorDescription: String? {
        switch self {
        case .cooldownActive(let hours):
            return "You can nudge again in \(hours) hour\(hours == 1 ? "" : "s")"
        }
    }
}
