//
//  DirectChatView.swift
//  Homi
//
//  1-on-1 direct messaging view
//

import SwiftUI

struct DirectChatView: View {
    let conversation: Conversation
    @ObservedObject var viewModel: DirectMessageViewModel
    @FocusState private var isInputFocused: Bool

    var otherUserName: String {
        conversation.getOtherParticipantName(currentUserId: viewModel.currentUserId ?? "") ?? "Unknown"
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading && viewModel.messages.isEmpty {
                Spacer()
                ProgressView("Loading messages...")
                Spacer()
            } else if viewModel.messages.isEmpty {
                emptyStateView
            } else {
                messagesList
            }

            Divider()

            DirectMessageInputView(
                messageText: $viewModel.messageText,
                isInputFocused: _isInputFocused,
                onSend: {
                    Task {
                        await viewModel.sendMessage(to: conversation)
                    }
                }
            )
            .padding(.horizontal)
            .padding(.vertical, Constants.Spacing.xSmall)
        }
        .navigationTitle(otherUserName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.startListeningToMessages(conversationId: conversation.id)
        }
        .onDisappear {
            viewModel.stopListeningToMessages()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Constants.Spacing.small) {
                    ForEach(viewModel.groupMessagesByDate(), id: \.0) { date, messages in
                        // Date header
                        Text(date)
                            .font(Constants.Typography.caption1)
                            .foregroundColor(Constants.Colors.textSecondary)
                            .padding(.vertical, Constants.Spacing.xSmall)

                        // Messages for this date
                        ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                            let showAvatar = shouldShowAvatar(for: message, at: index, in: messages)
                            let isLastMessage = (index == messages.count - 1)

                            DirectMessageBubble(
                                message: message,
                                currentUserId: viewModel.currentUserId ?? "",
                                onDelete: {
                                    Task {
                                        await viewModel.deleteMessage(message)
                                    }
                                },
                                canDelete: viewModel.canDeleteMessage(message),
                                showAvatar: showAvatar
                            )
                            .id(message.id)

                            // Show timestamp for last message in the conversation
                            if isLastMessage && messages.count > 0 {
                                Text(message.formattedTime)
                                    .font(.caption2)
                                    .foregroundColor(Constants.Colors.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.top, 2)
                            }
                        }
                    }
                }
                .padding()
            }
            .onAppear {
                // Scroll to bottom when view first loads
                if let lastMessage = viewModel.messages.last {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.messages.count) { oldCount, newCount in
                if newCount > oldCount, let lastMessage = viewModel.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // Helper to determine if avatar should be shown
    private func shouldShowAvatar(for message: DirectMessage, at index: Int, in messages: [DirectMessage]) -> Bool {
        // Show avatar if it's the first message or if the previous message is from a different sender
        if index == 0 {
            return true
        }

        let previousMessage = messages[index - 1]
        return previousMessage.senderId != message.senderId
    }

    private var emptyStateView: some View {
        VStack(spacing: Constants.Spacing.medium) {
            Spacer()

            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 50))
                .foregroundColor(Constants.Colors.textSecondary)

            Text("No messages yet")
                .font(Constants.Typography.title3)
                .foregroundColor(Constants.Colors.textPrimary)

            Text("Send a message to start the conversation")
                .font(Constants.Typography.body)
                .foregroundColor(Constants.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Direct Message Bubble

struct DirectMessageBubble: View {
    let message: DirectMessage
    let currentUserId: String
    let onDelete: () -> Void
    let canDelete: Bool
    let showAvatar: Bool

    @State private var showTimestamp = false

    private var isFromCurrentUser: Bool {
        message.isFromCurrentUser(currentUserId: currentUserId)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: Constants.Spacing.small) {
            // Left avatar for other user
            if !isFromCurrentUser && showAvatar {
                if let photoUrl = message.senderPhoto, !photoUrl.isEmpty, let url = URL(string: photoUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        initialsBubble
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                } else {
                    initialsBubble
                }
            } else if !isFromCurrentUser {
                // Spacer to align non-avatar messages
                Color.clear.frame(width: 32, height: 32)
            }

            // Spacer for current user messages to push right
            if isFromCurrentUser {
                Spacer(minLength: 60)
            }

            // Message bubble with tap-to-reveal timestamp
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: Constants.Spacing.xxSmall) {
                Text(message.content)
                    .font(Constants.Typography.body)
                    .foregroundColor(isFromCurrentUser ? .white : Constants.Colors.textPrimary)
                    .padding(.horizontal, Constants.Spacing.medium)
                    .padding(.vertical, Constants.Spacing.small)
                    .background(isFromCurrentUser ? Constants.Colors.primary : Color(.systemGray5))
                    .cornerRadius(Constants.CornerRadius.medium, corners: isFromCurrentUser ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight])
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showTimestamp.toggle()
                        }
                    }

                // Timestamp (only shown when tapped)
                if showTimestamp {
                    Text(message.formattedTime)
                        .font(.caption2)
                        .foregroundColor(Constants.Colors.textSecondary)
                        .padding(isFromCurrentUser ? .trailing : .leading, Constants.Spacing.small)
                        .transition(.opacity)
                }
            }
            .contextMenu {
                if canDelete {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            // Spacer for other user messages to push left
            if !isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }

    private var initialsBubble: some View {
        Circle()
            .fill(Constants.Colors.primary.opacity(0.2))
            .frame(width: 32, height: 32)
            .overlay {
                Text(String(message.senderName.prefix(1)).uppercased())
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Constants.Colors.primary)
            }
    }
}

// MARK: - Direct Message Input View

struct DirectMessageInputView: View {
    @Binding var messageText: String
    @FocusState var isInputFocused: Bool
    let onSend: () -> Void

    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: Constants.Spacing.xSmall) {
            // Text input
            TextField("Message", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(Constants.Spacing.xSmall)
                .background(Color(.systemGray6))
                .cornerRadius(Constants.CornerRadius.medium)
                .lineLimit(1...5)
                .focused($isInputFocused)
                .onSubmit {
                    if canSend {
                        onSend()
                    }
                }

            // Send button
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(canSend ? Constants.Colors.primary : Constants.Colors.textSecondary)
            }
            .disabled(!canSend)
        }
    }
}
