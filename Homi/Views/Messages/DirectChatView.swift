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
                            .font(Constants.Typography.caption)
                            .foregroundColor(Constants.Colors.textSecondary)
                            .padding(.vertical, Constants.Spacing.xSmall)

                        // Messages for this date
                        ForEach(messages) { message in
                            DirectMessageBubble(
                                message: message,
                                currentUserId: viewModel.currentUserId ?? "",
                                onDelete: {
                                    Task {
                                        await viewModel.deleteMessage(message)
                                    }
                                },
                                canDelete: viewModel.canDeleteMessage(message)
                            )
                            .id(message.id)
                        }
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.messages.count) { oldCount, newCount in
                if newCount > oldCount, let lastMessage = viewModel.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                if let lastMessage = viewModel.messages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
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

    private var isFromCurrentUser: Bool {
        message.isFromCurrentUser(currentUserId: currentUserId)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: Constants.Spacing.xSmall) {
            if !isFromCurrentUser {
                // Other user's avatar
                if let photoUrl = message.senderPhoto, !photoUrl.isEmpty, let url = URL(string: photoUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        initialsBubble
                    }
                    .frame(width: 30, height: 30)
                    .clipShape(Circle())
                } else {
                    initialsBubble
                }
            } else {
                Spacer()
            }

            // Message bubble
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(Constants.Typography.body)
                    .foregroundColor(isFromCurrentUser ? .white : Constants.Colors.textPrimary)
                    .padding(.horizontal, Constants.Spacing.small)
                    .padding(.vertical, Constants.Spacing.xSmall)
                    .background(isFromCurrentUser ? Constants.Colors.primary : Color(.systemGray5))
                    .cornerRadius(Constants.CornerRadius.medium)

                Text(message.formattedTime)
                    .font(Constants.Typography.caption)
                    .foregroundColor(Constants.Colors.textSecondary)
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

            if isFromCurrentUser {
                Spacer()
            }
        }
    }

    private var initialsBubble: some View {
        Circle()
            .fill(Constants.Colors.primary.opacity(0.2))
            .frame(width: 30, height: 30)
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
