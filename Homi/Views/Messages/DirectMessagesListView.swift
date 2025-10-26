//
//  DirectMessagesListView.swift
//  Homi
//
//  List of all direct message conversations
//

import SwiftUI

struct DirectMessagesListView: View {
    @StateObject private var viewModel = DirectMessageViewModel()
    @State private var showingNewMessage = false
    @State private var selectedConversation: Conversation?

    var body: some View {
        ZStack {
            if viewModel.isLoading && viewModel.conversations.isEmpty {
                ProgressView("Loading conversations...")
            } else if viewModel.filteredConversations.isEmpty {
                emptyStateView
            } else {
                conversationsList
            }
        }
        .searchable(text: $viewModel.searchQuery, prompt: "Search conversations")
        .navigationDestination(item: $selectedConversation) { conversation in
            DirectChatView(conversation: conversation, viewModel: viewModel)
        }
        .sheet(isPresented: $showingNewMessage) {
            NewDirectMessageView { otherUser in
                Task {
                    do {
                        let conversation = try await viewModel.getOrCreateConversation(with: otherUser)
                        showingNewMessage = false
                        selectedConversation = conversation
                    } catch {
                        viewModel.errorMessage = "Failed to create conversation: \(error.localizedDescription)"
                        viewModel.showError = true
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingNewMessage = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .onAppear {
            viewModel.startListeningToConversations()
        }
        .onDisappear {
            viewModel.stopListeningToConversations()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }

    private var conversationsList: some View {
        List {
            ForEach(viewModel.filteredConversations) { conversation in
                ConversationRow(conversation: conversation, viewModel: viewModel)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedConversation = conversation
                    }
            }
        }
        .listStyle(.plain)
    }

    private var emptyStateView: some View {
        VStack(spacing: Constants.Spacing.medium) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(Constants.Colors.textSecondary)

            Text("No Messages Yet")
                .font(Constants.Typography.title2)
                .foregroundColor(Constants.Colors.textPrimary)

            Text("Start a conversation with your housemates")
                .font(Constants.Typography.body)
                .foregroundColor(Constants.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                showingNewMessage = true
            } label: {
                Label("New Message", systemImage: "square.and.pencil")
                    .font(Constants.Typography.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, Constants.Spacing.large)
                    .padding(.vertical, Constants.Spacing.small)
                    .background(Constants.Colors.primary)
                    .cornerRadius(Constants.CornerRadius.medium)
            }
            .padding(.top, Constants.Spacing.small)
        }
        .padding()
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: Conversation
    @ObservedObject var viewModel: DirectMessageViewModel

    var otherUserName: String {
        conversation.getOtherParticipantName(currentUserId: viewModel.currentUserId ?? "") ?? "Unknown"
    }

    var otherUserPhoto: String? {
        conversation.getOtherParticipantPhoto(currentUserId: viewModel.currentUserId ?? "")
    }

    var unreadCount: Int {
        viewModel.getUnreadCount(for: conversation)
    }

    var hasUnread: Bool {
        unreadCount > 0
    }

    var body: some View {
        HStack(spacing: Constants.Spacing.small) {
            // Avatar
            ZStack(alignment: .bottomTrailing) {
                if let photoUrl = otherUserPhoto, !photoUrl.isEmpty, let url = URL(string: photoUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        initialsBubble
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                } else {
                    initialsBubble
                }

                // Unread indicator
                if hasUnread {
                    Circle()
                        .fill(Constants.Colors.primary)
                        .frame(width: 18, height: 18)
                        .overlay {
                            Text("\(min(unreadCount, 9))")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(otherUserName)
                        .font(hasUnread ? Constants.Typography.headline : Constants.Typography.body)
                        .foregroundColor(Constants.Colors.textPrimary)

                    Spacer()

                    Text(conversation.formattedLastMessageTime)
                        .font(Constants.Typography.caption1)
                        .foregroundColor(hasUnread ? Constants.Colors.primary : Constants.Colors.textSecondary)
                }

                if let lastMessage = conversation.lastMessage {
                    Text(lastMessage)
                        .font(Constants.Typography.subheadline)
                        .foregroundColor(Constants.Colors.textSecondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, Constants.Spacing.xxSmall)
    }

    private var initialsBubble: some View {
        Circle()
            .fill(Constants.Colors.primary.opacity(0.2))
            .frame(width: 50, height: 50)
            .overlay {
                Text(String(otherUserName.prefix(1)).uppercased())
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Constants.Colors.primary)
            }
    }
}

// MARK: - New Direct Message View

struct NewDirectMessageView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var houseMembers: [HouseMember] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    let onSelectUser: (User) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading members...")
                } else if houseMembers.isEmpty {
                    emptyView
                } else {
                    membersList
                }
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadHouseMembers()
            }
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
    }

    private var membersList: some View {
        List {
            ForEach(houseMembers.filter { $0.userId != AuthService.shared.userProfile?.id }) { member in
                Button {
                    // Convert HouseMember to User for conversation creation
                    let user = User(
                        id: member.userId,
                        email: nil,
                        phoneNumber: nil,
                        displayName: member.displayName,
                        profilePhotoUrl: member.profilePhotoUrl,
                        authProviders: [],
                        currentHouseId: nil,
                        fcmToken: nil,
                        createdAt: member.joinedAt,
                        lastSeen: Date(),
                        settings: UserSettings()
                    )
                    onSelectUser(user)
                } label: {
                    HStack(spacing: Constants.Spacing.small) {
                        // Avatar
                        if let photoUrl = member.profilePhotoUrl,
                           !photoUrl.isEmpty,
                           let url = URL(string: photoUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                memberInitialsBubble(for: member)
                            }
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                        } else {
                            memberInitialsBubble(for: member)
                        }

                        Text(member.displayName)
                            .font(Constants.Typography.body)
                            .foregroundColor(Constants.Colors.textPrimary)

                        Spacer()
                    }
                    .padding(.vertical, Constants.Spacing.xxSmall)
                }
            }
        }
        .listStyle(.plain)
    }

    private var emptyView: some View {
        VStack(spacing: Constants.Spacing.medium) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 50))
                .foregroundColor(Constants.Colors.textSecondary)

            Text("No Housemates")
                .font(Constants.Typography.title3)
                .foregroundColor(Constants.Colors.textPrimary)

            Text("Invite people to your house to start messaging")
                .font(Constants.Typography.body)
                .foregroundColor(Constants.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func memberInitialsBubble(for member: HouseMember) -> some View {
        Circle()
            .fill(Constants.Colors.primary.opacity(0.2))
            .frame(width: 44, height: 44)
            .overlay {
                Text(String(member.displayName.prefix(1)).uppercased())
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Constants.Colors.primary)
            }
    }

    private func loadHouseMembers() async {
        guard let currentUser = AuthService.shared.userProfile,
              let houseId = currentUser.currentHouseId else {
            errorMessage = "No house found"
            return
        }

        isLoading = true

        do {
            houseMembers = try await FirestoreService.shared.getHouseMembers(houseId: houseId)
        } catch {
            errorMessage = "Failed to load members: \(error.localizedDescription)"
        }

        isLoading = false
    }
}
