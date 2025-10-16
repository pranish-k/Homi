import SwiftUI
import Combine
import FirebaseAuth

@MainActor
class MessageViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var messageText = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    private let messagingService = MessagingService.shared
    private var cancellables = Set<AnyCancellable>()
    private var currentHouseId: String?

    var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    init() {
        // Subscribe to messaging service messages
        messagingService.$messages
            .assign(to: &$messages)

        messagingService.$isLoading
            .assign(to: &$isLoading)

        messagingService.$errorMessage
            .sink { [weak self] error in
                if let error = error {
                    self?.errorMessage = error
                    self?.showError = true
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Message Operations

    func startListening(houseId: String) {
        currentHouseId = houseId
        messagingService.startListeningToMessages(houseId: houseId)
    }

    func stopListening() {
        messagingService.stopListening()
    }

    func sendMessage() async {
        guard let houseId = currentHouseId else {
            errorMessage = "No house selected"
            showError = true
            return
        }

        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }

        // Clear input immediately for better UX
        let messageToBeSent = trimmedMessage
        messageText = ""

        do {
            try await messagingService.sendMessage(houseId: houseId, content: messageToBeSent)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            // Restore message if send failed
            messageText = messageToBeSent
        }
    }

    func deleteMessage(_ message: Message) async {
        guard let houseId = currentHouseId else { return }

        do {
            try await messagingService.deleteMessage(houseId: houseId, messageId: message.id)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Helper Methods

    func canDeleteMessage(_ message: Message) -> Bool {
        guard let userId = currentUserId else { return false }
        return message.senderId == userId
    }

    func groupMessagesByDate() -> [(date: Date, messages: [Message])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: messages) { message in
            calendar.startOfDay(for: message.timestamp)
        }

        return grouped.map { (date: $0.key, messages: $0.value) }
            .sorted { $0.date < $1.date }
    }

    func dateHeaderText(for date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d, yyyy"
            return formatter.string(from: date)
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        stopListening()
        messagingService.clearMessages()
        messageText = ""
    }
}
