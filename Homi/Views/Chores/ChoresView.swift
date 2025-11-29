import SwiftUI
import OSLog

struct ChoresView: View {
    @StateObject private var viewModel = ChoreViewModel()
    @ObservedObject var authService = AuthService.shared

    @State private var showingAddChore = false
    @State private var selectedFilter: ChoreFilter = .all
    @State private var houseMembers: [HouseMember] = []
    @State private var selectedCompletedByUserId: String? = nil // nil = all
    @State private var showingCompletedFilter = false

    private let logger = Logger(subsystem: "com.homi.app", category: "ChoresView")

    var currentUserId: String? {
        authService.userProfile?.id
    }

    var filteredChores: [Chore] {
        switch selectedFilter {
        case .all:
            return viewModel.getActiveChores()
        case .mine:
            guard let userId = currentUserId else { return [] }
            return viewModel.getChoresByAssignee(userId: userId)
        case .overdue:
            return viewModel.getOverdueChoresSync()
        case .completed:
            let completedChores = viewModel.getCompletedChores()
            // Apply completed by filter if set
            if let filterId = selectedCompletedByUserId {
                return completedChores.filter { $0.completedBy == filterId }
            }
            return completedChores
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if authService.userProfile?.currentHouseId != nil {
                    // Filter picker
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(ChoreFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, Constants.Spacing.medium)
                    .padding(.vertical, Constants.Spacing.small)

                    if viewModel.isLoading && viewModel.chores.isEmpty {
                        loadingView
                    } else if filteredChores.isEmpty {
                        emptyStateView
                    } else {
                        choresListView
                    }
                } else {
                    noHouseView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Chores")
                        .font(Constants.Typography.title2)
                }

                if authService.userProfile?.currentHouseId != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingAddChore = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.title3)
                                .foregroundColor(Constants.Colors.primary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddChore) {
                AddChoreView(viewModel: viewModel, houseMembers: houseMembers)
            }
            .task {
                await loadData()
            }
            .onDisappear {
                viewModel.stopListening()
            }
        }
    }

    // MARK: - Views

    private var choresListView: some View {
        VStack(spacing: 0) {
            // Show filter button only on Completed tab
            if selectedFilter == .completed {
                HStack {
                    Menu {
                        Button(action: {
                            selectedCompletedByUserId = nil
                        }) {
                            HStack {
                                Text("All Members")
                                Spacer()
                                if selectedCompletedByUserId == nil {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }

                        Divider()

                        ForEach(houseMembers) { member in
                            Button(action: {
                                selectedCompletedByUserId = member.userId
                            }) {
                                HStack {
                                    Text(member.displayName)
                                    Spacer()
                                    if selectedCompletedByUserId == member.userId {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: Constants.Spacing.xSmall) {
                            Text("Filter")
                                .font(Constants.Typography.bodyMedium)
                                .foregroundColor(Constants.Colors.primary)

                            if let selectedUserId = selectedCompletedByUserId,
                               let member = houseMembers.first(where: { $0.userId == selectedUserId }) {
                                Text("• \(member.displayName)")
                                    .font(Constants.Typography.body)
                                    .foregroundColor(Constants.Colors.textSecondary)
                            }

                            Image(systemName: "chevron.down")
                                .font(.system(size: 12))
                                .foregroundColor(Constants.Colors.primary)
                        }
                        .padding(.horizontal, Constants.Spacing.medium)
                        .padding(.vertical, Constants.Spacing.small)
                    }

                    Spacer()
                }
                .padding(.horizontal, Constants.Spacing.medium)
                .padding(.top, Constants.Spacing.small)
                .background(Color(.systemGroupedBackground))
            }

            ScrollView {
                LazyVStack(spacing: selectedFilter == .completed ? Constants.Spacing.small : Constants.Spacing.medium) {
                    ForEach(filteredChores) { chore in
                        if selectedFilter == .completed {
                            // Use compact card for completed chores
                            CompactChoreCardView(
                                chore: chore,
                                currentUserId: currentUserId ?? "",
                                onUncomplete: {
                                    Task {
                                        await viewModel.markIncomplete(chore)
                                    }
                                },
                                onDelete: {
                                    Task {
                                        await viewModel.deleteChore(chore)
                                    }
                                }
                            )
                        } else {
                            // Use regular card for active chores
                            ChoreCardView(
                                chore: chore,
                                currentUserId: currentUserId ?? "",
                                onComplete: {
                                    Task {
                                        await viewModel.markComplete(chore)
                                    }
                                },
                                onUncomplete: {
                                    Task {
                                        await viewModel.markIncomplete(chore)
                                    }
                                },
                                onDelete: {
                                    Task {
                                        await viewModel.deleteChore(chore)
                                    }
                                }
                            )
                        }
                    }
                }
                .padding(Constants.Spacing.medium)
            }
            .background(Color(.systemGroupedBackground))
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: Constants.Spacing.medium) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 60))
                .foregroundColor(Constants.Colors.textSecondary.opacity(0.5))

            Text(emptyStateTitle)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(Constants.Colors.textPrimary)

            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundColor(Constants.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Constants.Spacing.large)

            if selectedFilter == .all {
                Button {
                    showingAddChore = true
                } label: {
                    Text("Add Chore")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, Constants.Spacing.large)
                        .padding(.vertical, Constants.Spacing.small)
                        .background(Constants.Colors.primary)
                        .cornerRadius(Constants.CornerRadius.medium)
                }
                .padding(.top, Constants.Spacing.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var loadingView: some View {
        VStack(spacing: Constants.Spacing.medium) {
            ProgressView()
            Text("Loading chores...")
                .font(.subheadline)
                .foregroundColor(Constants.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var noHouseView: some View {
        VStack(spacing: Constants.Spacing.medium) {
            Image(systemName: "house.fill")
                .font(.system(size: 60))
                .foregroundColor(Constants.Colors.textSecondary.opacity(0.5))

            Text("No House")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(Constants.Colors.textPrimary)

            Text("Join or create a house to start managing chores")
                .font(.subheadline)
                .foregroundColor(Constants.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Constants.Spacing.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Helpers

    private var emptyStateIcon: String {
        switch selectedFilter {
        case .all: return "checkmark.circle"
        case .mine: return "person.circle"
        case .overdue: return "exclamationmark.triangle"
        case .completed: return "checkmark.seal"
        }
    }

    private var emptyStateTitle: String {
        switch selectedFilter {
        case .all: return "No Active Chores"
        case .mine: return "No Chores Assigned to You"
        case .overdue: return "No Overdue Chores"
        case .completed: return "No Completed Chores"
        }
    }

    private var emptyStateMessage: String {
        switch selectedFilter {
        case .all: return "Create a chore to get started with household task management"
        case .mine: return "You don't have any chores assigned to you right now"
        case .overdue: return "Awesome! All chores are up to date"
        case .completed: return "Complete some chores to see them here"
        }
    }

    private func loadData() async {
        guard let houseId = authService.userProfile?.currentHouseId else { return }

        // Load house members
        do {
            houseMembers = try await FirestoreService.shared.getHouseMembers(houseId: houseId)
        } catch {
            logger.error("Error loading house members: \(error.localizedDescription)")
        }

        // Start listening to chores
        viewModel.startListening(houseId: houseId)
    }
}

// MARK: - Chore Filter

enum ChoreFilter: String, CaseIterable {
    case all = "All"
    case mine = "Mine"
    case overdue = "Overdue"
    case completed = "Completed"
}

// MARK: - Preview

struct ChoresView_Previews: PreviewProvider {
    static var previews: some View {
        ChoresView()
    }
}
