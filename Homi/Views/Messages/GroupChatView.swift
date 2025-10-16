import SwiftUI

struct GroupChatView: View {
    @StateObject private var viewModel = MessageViewModel()
    @EnvironmentObject var firestoreService: FirestoreService
    @Environment(\.dismiss) private var dismiss

    let houseId: String
    let houseName: String

    var body: some View {
        VStack(spacing: 0) {
            // Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: Constants.Spacing.medium) {
                        if viewModel.isLoading && viewModel.messages.isEmpty {
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(.top, 100)
                        } else if viewModel.messages.isEmpty {
                            emptyStateView
                        } else {
                            messagesView
                        }
                    }
                    .padding(.vertical, Constants.Spacing.medium)
                }
                .onChange(of: viewModel.messages.count) { oldCount, newCount in
                    if newCount > oldCount {
                        // Auto-scroll to bottom when new message arrives
                        withAnimation {
                            if let lastMessage = viewModel.messages.last {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            // Message Input
            MessageInputView(messageText: $viewModel.messageText) {
                Task {
                    await viewModel.sendMessage()
                }
            }
        }
        .navigationTitle(houseName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.startListening(houseId: houseId)
        }
        .onDisappear {
            viewModel.stopListening()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: Constants.Spacing.medium) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(Constants.Colors.textSecondary)

            Text("No messages yet")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(Constants.Colors.textPrimary)

            Text("Start the conversation with your housemates!")
                .font(.body)
                .foregroundColor(Constants.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Constants.Spacing.xLarge)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }

    private var messagesView: some View {
        ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
            let isFromCurrentUser = message.isFromCurrentUser(userId: viewModel.currentUserId ?? "")
            let showAvatar = shouldShowAvatar(for: message, at: index)

            MessageBubbleView(
                message: message,
                isFromCurrentUser: isFromCurrentUser,
                showAvatar: showAvatar,
                onDelete: {
                    Task {
                        await viewModel.deleteMessage(message)
                    }
                }
            )
            .padding(.horizontal, Constants.Spacing.medium)
            .id(message.id)
        }
    }

    // MARK: - Helper Methods

    private func shouldShowAvatar(for message: Message, at index: Int) -> Bool {
        // Show avatar if it's the first message or if the previous message is from a different sender
        if index == 0 {
            return true
        }

        let previousMessage = viewModel.messages[index - 1]
        return previousMessage.senderId != message.senderId
    }
}

// MARK: - Preview
struct GroupChatView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            GroupChatView(
                houseId: "preview-house",
                houseName: "The Cozy Cottage"
            )
            .environmentObject(FirestoreService.shared)
        }
    }
}
