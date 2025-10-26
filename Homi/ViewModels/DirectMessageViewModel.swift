//
//  DirectMessageViewModel.swift
//  Homi
//
//  ViewModel for managing direct messaging UI state
//

import Foundation
import Combine

@MainActor
class DirectMessageViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var messages: [DirectMessage] = []
    @Published var messageText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var searchQuery: String = ""

    private let messagingService = DirectMessagingService.shared
    private var cancellables = Set<AnyCancellable>()

    var currentUserId: String? {
        AuthService.shared.userProfile?.id
    }

    var currentUser: User? {
        AuthService.shared.userProfile
    }

    init() {
        setupBindings()
    }

    private func setupBindings() {
        // Subscribe to messaging service updates
        messagingService.$conversations
            .receive(on: DispatchQueue.main)
            .assign(to: &$conversations)

        messagingService.$currentMessages
            .receive(on: DispatchQueue.main)
            .assign(to: &$messages)

        messagingService.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)

        messagingService.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.errorMessage = error
                self?.showError = error != nil
            }
            .store(in: &cancellables)
    }

    // MARK: - Conversation Management

    func startListeningToConversations() {
        guard let userId = currentUserId else { return }
        messagingService.startListeningToConversations(userId: userId)
    }

    func stopListeningToConversations() {
        messagingService.stopListeningToConversations()
    }

    func getOrCreateConversation(with otherUser: User) async throws -> Conversation {
        guard let currentUser = currentUser else {
            throw DirectMessagingError.userNotFound
        }

        return try await messagingService.getOrCreateConversation(currentUser: currentUser, otherUser: otherUser)
    }

    // MARK: - Message Operations

    func startListeningToMessages(conversationId: String) {
        messagingService.startListeningToMessages(conversationId: conversationId)

        // Mark messages as read when opening conversation
        Task {
            guard let userId = currentUserId else { return }
            try? await messagingService.markMessagesAsRead(conversationId: conversationId, userId: userId)
        }
    }

    func stopListeningToMessages() {
        messagingService.stopListeningToMessages()
    }

    func sendMessage(to conversation: Conversation) async {
        guard let currentUser = currentUser,
              let recipientId = conversation.getOtherParticipantId(currentUserId: currentUser.id),
              !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let content = messageText
        messageText = ""

        do {
            try await messagingService.sendDirectMessage(
                conversationId: conversation.id,
                content: content,
                sender: currentUser,
                recipientId: recipientId
            )
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            // Restore message text on error
            messageText = content
        }
    }

    func deleteMessage(_ message: DirectMessage) async {
        guard canDeleteMessage(message) else { return }

        do {
            try await messagingService.deleteMessage(
                conversationId: message.conversationId,
                messageId: message.id
            )
        } catch {
            errorMessage = "Failed to delete message: \(error.localizedDescription)"
            showError = true
        }
    }

    func canDeleteMessage(_ message: DirectMessage) -> Bool {
        guard let userId = currentUserId else { return false }
        return message.senderId == userId
    }

    // MARK: - UI Helpers

    func groupMessagesByDate() -> [(String, [DirectMessage])] {
        let grouped = Dictionary(grouping: messages) { message -> String in
            dateHeaderText(for: message.timestamp)
        }

        return grouped.sorted { first, second in
            // Sort by the first message timestamp in each group
            guard let firstMessage = first.value.first,
                  let secondMessage = second.value.first else {
                return false
            }
            return firstMessage.timestamp < secondMessage.timestamp
        }
    }

    func dateHeaderText(for date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }

    var filteredConversations: [Conversation] {
        guard !searchQuery.isEmpty, let userId = currentUserId else {
            return conversations
        }
        return messagingService.searchConversations(query: searchQuery, userId: userId)
    }

    func getUnreadCount(for conversation: Conversation) -> Int {
        guard let userId = currentUserId else { return 0 }
        return conversation.getUnreadCount(for: userId)
    }

    func hasUnreadMessages(for conversation: Conversation) -> Bool {
        return getUnreadCount(for: conversation) > 0
    }

    // MARK: - Cleanup

    func cleanup() {
        stopListeningToConversations()
        stopListeningToMessages()
        messagingService.cleanup()
        cancellables.removeAll()
    }
}
