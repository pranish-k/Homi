//
//  DirectMessagingService.swift
//  Homi
//
//  Service for managing direct messages between users
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class DirectMessagingService: ObservableObject {
    static let shared = DirectMessagingService()

    private let db = Firestore.firestore()
    @Published var conversations: [Conversation] = []
    @Published var currentMessages: [DirectMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var conversationsListener: ListenerRegistration?
    private var messagesListener: ListenerRegistration?

    private init() {}

    // MARK: - Conversation Management

    /// Get or create a conversation between two users
    func getOrCreateConversation(currentUser: User, otherUser: User) async throws -> Conversation {
        let conversationId = Conversation.generateConversationId(user1: currentUser.id, user2: otherUser.id)
        let conversationRef = db.collection(Constants.Collections.conversations).document(conversationId)

        let document = try await conversationRef.getDocument()

        if document.exists, let conversation = Conversation(document: document) {
            return conversation
        } else {
            // Create new conversation
            let newConversation = Conversation(
                id: conversationId,
                participantIds: [currentUser.id, otherUser.id],
                participantNames: [
                    currentUser.id: currentUser.displayName,
                    otherUser.id: otherUser.displayName
                ],
                participantPhotos: [
                    currentUser.id: currentUser.profilePhotoUrl ?? "",
                    otherUser.id: otherUser.profilePhotoUrl ?? ""
                ],
                unreadCounts: [
                    currentUser.id: 0,
                    otherUser.id: 0
                ]
            )

            try await conversationRef.setData(newConversation.toDictionary())
            return newConversation
        }
    }

    /// Start listening to user's conversations
    func startListeningToConversations(userId: String) {
        stopListeningToConversations()

        conversationsListener = db.collection(Constants.Collections.conversations)
            .whereField("participantIds", arrayContains: userId)
            .order(by: "lastMessageTime", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    self.errorMessage = "Failed to load conversations: \(error.localizedDescription)"
                    return
                }

                guard let documents = snapshot?.documents else { return }

                self.conversations = documents.compactMap { Conversation(document: $0) }
            }
    }

    func stopListeningToConversations() {
        conversationsListener?.remove()
        conversationsListener = nil
    }

    // MARK: - Message Operations

    /// Send a direct message
    func sendDirectMessage(conversationId: String, content: String, sender: User, recipientId: String, type: DirectMessage.MessageType = .text) async throws {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DirectMessagingError.emptyMessage
        }

        let messageRef = db.collection(Constants.Collections.directMessages)
            .document(conversationId)
            .collection("messages")
            .document()

        let message = DirectMessage(
            id: messageRef.documentID,
            conversationId: conversationId,
            content: content,
            senderId: sender.id,
            senderName: sender.displayName,
            senderPhoto: sender.profilePhotoUrl,
            timestamp: Date(),
            type: type,
            readBy: [sender.id]
        )

        // Use batch to update message and conversation
        let batch = db.batch()

        // Add message
        batch.setData(message.toDictionary(), forDocument: messageRef)

        // Update conversation
        let conversationRef = db.collection(Constants.Collections.conversations).document(conversationId)
        let conversationUpdate: [String: Any] = [
            "lastMessage": content,
            "lastMessageTime": Timestamp(date: message.timestamp),
            "lastMessageSenderId": sender.id,
            "unreadCounts.\(recipientId)": FieldValue.increment(Int64(1))
        ]
        batch.updateData(conversationUpdate, forDocument: conversationRef)

        try await batch.commit()
    }

    /// Start listening to messages in a conversation
    func startListeningToMessages(conversationId: String) {
        stopListeningToMessages()

        messagesListener = db.collection(Constants.Collections.directMessages)
            .document(conversationId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .limit(toLast: 100)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    self.errorMessage = "Failed to load messages: \(error.localizedDescription)"
                    return
                }

                guard let documents = snapshot?.documents else { return }

                self.currentMessages = documents.compactMap { DirectMessage(document: $0) }
            }
    }

    func stopListeningToMessages() {
        messagesListener?.remove()
        messagesListener = nil
    }

    /// Mark messages as read
    func markMessagesAsRead(conversationId: String, userId: String) async throws {
        let messagesRef = db.collection(Constants.Collections.directMessages)
            .document(conversationId)
            .collection("messages")

        // Get messages where the user is NOT in the readBy array
        let allMessages = try await messagesRef.getDocuments()
        let unreadMessageDocs = allMessages.documents.filter { doc in
            let readBy = doc.data()["readBy"] as? [String] ?? []
            return !readBy.contains(userId)
        }

        guard !unreadMessageDocs.isEmpty else { return }

        let batch = db.batch()

        for document in unreadMessageDocs {
            batch.updateData([
                "readBy": FieldValue.arrayUnion([userId])
            ], forDocument: document.reference)
        }

        // Reset unread count in conversation
        let conversationRef = db.collection(Constants.Collections.conversations).document(conversationId)
        batch.updateData([
            "unreadCounts.\(userId)": 0
        ], forDocument: conversationRef)

        try await batch.commit()
    }

    /// Delete a message
    func deleteMessage(conversationId: String, messageId: String) async throws {
        let messageRef = db.collection(Constants.Collections.directMessages)
            .document(conversationId)
            .collection("messages")
            .document(messageId)

        try await messageRef.delete()
    }

    /// Load more messages (pagination)
    func loadMoreMessages(conversationId: String, beforeTimestamp: Date) async throws -> [DirectMessage] {
        let snapshot = try await db.collection(Constants.Collections.directMessages)
            .document(conversationId)
            .collection("messages")
            .order(by: "timestamp", descending: true)
            .whereField("timestamp", isLessThan: Timestamp(date: beforeTimestamp))
            .limit(to: 50)
            .getDocuments()

        return snapshot.documents.compactMap { DirectMessage(document: $0) }
    }

    /// Get unread message count for a conversation
    func getUnreadCount(conversationId: String, userId: String) async throws -> Int {
        let document = try await db.collection(Constants.Collections.conversations)
            .document(conversationId)
            .getDocument()

        guard let conversation = Conversation(document: document) else {
            return 0
        }

        return conversation.getUnreadCount(for: userId)
    }

    /// Search conversations by participant name
    func searchConversations(query: String, userId: String) -> [Conversation] {
        guard !query.isEmpty else { return conversations }

        return conversations.filter { conversation in
            guard let otherUserName = conversation.getOtherParticipantName(currentUserId: userId) else {
                return false
            }
            return otherUserName.localizedCaseInsensitiveContains(query)
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        stopListeningToConversations()
        stopListeningToMessages()
        conversations.removeAll()
        currentMessages.removeAll()
    }
}

// MARK: - Error Handling

enum DirectMessagingError: LocalizedError {
    case emptyMessage
    case conversationNotFound
    case userNotFound
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .emptyMessage:
            return "Message cannot be empty"
        case .conversationNotFound:
            return "Conversation not found"
        case .userNotFound:
            return "User not found"
        case .permissionDenied:
            return "You don't have permission to perform this action"
        }
    }
}
