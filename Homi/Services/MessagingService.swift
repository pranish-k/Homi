import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth
import OSLog

@MainActor
class MessagingService: ObservableObject {
    static let shared = MessagingService()

    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private let logger = Logger(subsystem: "com.homi.app", category: "MessagingService")

    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var messagesListener: ListenerRegistration?

    // MARK: - Message Operations

    func sendMessage(houseId: String, content: String, type: Message.MessageType = .text) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw MessagingError.noUser
        }

        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MessagingError.emptyMessage
        }

        // Get user profile for sender info
        let userProfile = AuthService.shared.userProfile

        let message = Message(
            content: content,
            senderId: userId,
            senderName: userProfile?.displayName ?? "Unknown",
            senderPhoto: userProfile?.profilePhotoUrl,
            type: type,
            readBy: [userId] // Mark as read by sender
        )

        do {
            try await db.collection(Constants.Collections.houses)
                .document(houseId)
                .collection(Constants.Collections.messages)
                .document(message.id)
                .setData(message.toFirestore)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func sendSystemMessage(houseId: String, content: String) async throws {
        let message = Message(
            content: content,
            senderId: "system",
            senderName: "System",
            type: .system
        )

        do {
            try await db.collection(Constants.Collections.houses)
                .document(houseId)
                .collection(Constants.Collections.messages)
                .document(message.id)
                .setData(message.toFirestore)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - Real-time Listeners

    func startListeningToMessages(houseId: String) {
        // Remove any existing listener
        stopListening()

        isLoading = true

        messagesListener = db.collection(Constants.Collections.houses)
            .document(houseId)
            .collection(Constants.Collections.messages)
            .order(by: "timestamp", descending: false)
            .limit(toLast: 100) // Load last 100 messages
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

                self.messages = documents.compactMap { Message(document: $0) }
                self.isLoading = false

                // Mark messages as read
                Task {
                    await self.markMessagesAsRead(houseId: houseId)
                }
            }
    }

    func stopListening() {
        messagesListener?.remove()
        messagesListener = nil
    }

    // MARK: - Read Receipts

    func markMessagesAsRead(houseId: String) async {
        guard let userId = auth.currentUser?.uid else { return }

        let batch = db.batch()
        var updateCount = 0

        // Find messages not read by current user
        let unreadMessages = messages.filter { !$0.isReadBy(userId: userId) && $0.senderId != userId }

        for message in unreadMessages {
            var updatedReadBy = message.readBy
            updatedReadBy.append(userId)

            let messageRef = db.collection(Constants.Collections.houses)
                .document(houseId)
                .collection(Constants.Collections.messages)
                .document(message.id)

            batch.updateData(["readBy": updatedReadBy], forDocument: messageRef)
            updateCount += 1

            // Firestore batch limit is 500 operations
            if updateCount >= 500 {
                break
            }
        }

        if updateCount > 0 {
            do {
                try await batch.commit()
            } catch {
                logger.error("Error marking messages as read: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Load More Messages

    func loadMoreMessages(houseId: String, before timestamp: Date) async throws -> [Message] {
        do {
            let snapshot = try await db.collection(Constants.Collections.houses)
                .document(houseId)
                .collection(Constants.Collections.messages)
                .order(by: "timestamp", descending: true)
                .start(after: [Timestamp(date: timestamp)])
                .limit(to: 50)
                .getDocuments()

            let olderMessages = snapshot.documents.compactMap { Message(document: $0) }
            return olderMessages.reversed()
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - Delete Message

    func deleteMessage(houseId: String, messageId: String) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw MessagingError.noUser
        }

        // Get the message to check if user is the sender
        let messageRef = db.collection(Constants.Collections.houses)
            .document(houseId)
            .collection(Constants.Collections.messages)
            .document(messageId)

        let document = try await messageRef.getDocument()
        guard let message = Message(document: document) else {
            throw MessagingError.messageNotFound
        }

        // Only allow deleting own messages
        guard message.senderId == userId else {
            throw MessagingError.unauthorized
        }

        try await messageRef.delete()
    }

    // MARK: - Unread Count

    func getUnreadCount(houseId: String) async throws -> Int {
        guard let userId = auth.currentUser?.uid else {
            return 0
        }

        let snapshot = try await db.collection(Constants.Collections.houses)
            .document(houseId)
            .collection(Constants.Collections.messages)
            .order(by: "timestamp", descending: true)
            .limit(to: 100)
            .getDocuments()

        let messages = snapshot.documents.compactMap { Message(document: $0) }
        return messages.filter { !$0.isReadBy(userId: userId) && $0.senderId != userId }.count
    }

    // MARK: - Helper Methods

    func clearMessages() {
        messages = []
        stopListening()
    }
}

// MARK: - Messaging Errors

enum MessagingError: LocalizedError {
    case noUser
    case emptyMessage
    case messageNotFound
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .noUser:
            return "No user logged in"
        case .emptyMessage:
            return "Message cannot be empty"
        case .messageNotFound:
            return "Message not found"
        case .unauthorized:
            return "You can only delete your own messages"
        }
    }
}
