import SwiftUI
import FirebaseAuth
import OSLog

struct DashboardView: View {
    @Binding var selectedTab: Int
    @StateObject private var viewModel = DashboardViewModel()
    @StateObject private var authService = AuthService.shared

    private let logger = Logger(subsystem: "com.homi.app", category: "DashboardView")

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: Constants.Spacing.large) {
                    // House Header
                    if let house = viewModel.currentHouse {
                        HouseHeaderCard(
                            house: house,
                            members: viewModel.houseMembers,
                            onShareInvite: viewModel.shareInvite
                        )
                    }

                    // Quick Stats Grid
                    QuickStatsGrid(viewModel: viewModel)

                    // Quick Actions
                    QuickActionsCard(
                        onAddExpense: { selectedTab = 2 },
                        onAddChore: { selectedTab = 4 },
                        onSendMessage: { selectedTab = 1 }
                    )
                    .padding(.horizontal, Constants.Spacing.medium)

                    // Upcoming Chores Widget
                    if !viewModel.upcomingChores.isEmpty {
                        UpcomingChoresWidget(
                            chores: viewModel.upcomingChores,
                            overdueCount: viewModel.overdueChoresCount,
                            dueTodayCount: viewModel.dueTodayChoresCount,
                            onTap: { selectedTab = 4 }
                        )
                        .padding(.horizontal, Constants.Spacing.medium)
                    }

                    // Balance Summary Widget
                    BalanceSummaryWidget(
                        balance: viewModel.myBalance,
                        balanceText: viewModel.balanceText,
                        balanceColor: viewModel.balanceColor,
                        onTap: { selectedTab = 2 }
                    )
                    .padding(.horizontal, Constants.Spacing.medium)

                    // Recent Messages Widget
                    if !viewModel.recentMessages.isEmpty {
                        RecentMessagesWidget(
                            messages: viewModel.recentMessages,
                            unreadCount: viewModel.unreadMessagesCount,
                            onTap: { selectedTab = 1 }
                        )
                        .padding(.horizontal, Constants.Spacing.medium)
                    }

                    // Location Status
                    LocationStatusCard(
                        activeMembersCount: viewModel.activeSharingMembers,
                        isSharing: LocationService.shared.isLocationSharingEnabled,
                        onTap: { selectedTab = 3 }
                    )
                    .padding(.horizontal, Constants.Spacing.medium)
                }
                .padding(.vertical, Constants.Spacing.medium)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Home")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {}) {
                            Label("House Settings", systemImage: "gear")
                        }

                        Button(action: {
                            do {
                                try authService.signOut()
                            } catch {
                                logger.error("Error signing out: \(error.localizedDescription)")
                            }
                        }) {
                            Label("Sign Out", systemImage: "arrow.right.square")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                    }
                }
            }
            .refreshable {
                await viewModel.loadData()
            }
        }
        .task {
            await viewModel.loadData()
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .onChange(of: selectedTab) { _, newValue in
            // This binding allows widgets to change tabs
        }
    }
}

// MARK: - House Header Card

struct HouseHeaderCard: View {
    let house: House
    let members: [HouseMember]
    let onShareInvite: () -> Void

    var body: some View {
        VStack(spacing: Constants.Spacing.medium) {
            HStack {
                VStack(alignment: .leading, spacing: Constants.Spacing.xSmall) {
                    Text(house.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    if let address = house.address {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(Constants.Colors.textSecondary)
                    }
                }

                Spacer()

                // Invite Code Button
                Button(action: {
                    UIPasteboard.general.string = house.inviteCode
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                        Text(house.inviteCode)
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(Constants.Colors.primary)
                }
            }

            // Member Avatars
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Constants.Spacing.medium) {
                    ForEach(members) { member in
                        MemberAvatarView(member: member)
                    }

                    // Add Member Button
                    Button(action: onShareInvite) {
                        VStack {
                            ZStack {
                                Circle()
                                    .fill(Color(UIColor.tertiarySystemBackground))
                                    .frame(width: 50, height: 50)

                                Image(systemName: "person.badge.plus")
                                    .font(.body)
                                    .foregroundColor(Constants.Colors.primary)
                            }

                            Text("Invite")
                                .font(.caption)
                                .foregroundColor(Constants.Colors.textSecondary)
                        }
                    }
                }
            }
        }
        .padding(Constants.Spacing.medium)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(Constants.CornerRadius.medium)
        .padding(.horizontal, Constants.Spacing.medium)
    }
}

// MARK: - Quick Stats Grid

struct QuickStatsGrid: View {
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: Constants.Spacing.medium) {
            QuickStatCard(
                icon: "dollarsign.circle.fill",
                title: "Balance",
                value: viewModel.balanceText,
                color: viewModel.balanceColor
            )

            QuickStatCard(
                icon: "checklist",
                title: "Due Today",
                value: "\(viewModel.dueTodayChoresCount)",
                color: Constants.Colors.primary
            )

            QuickStatCard(
                icon: "message.fill",
                title: "Unread",
                value: "\(viewModel.unreadMessagesCount)",
                color: Constants.Colors.warning
            )

            QuickStatCard(
                icon: "location.fill",
                title: "Sharing",
                value: "\(viewModel.activeSharingMembers)",
                color: Constants.Colors.success
            )
        }
        .padding(.horizontal, Constants.Spacing.medium)
    }
}

// MARK: - Member Avatar View

struct MemberAvatarView: View {
    let member: HouseMember

    var body: some View {
        VStack(spacing: Constants.Spacing.xSmall) {
            if let photoURL = member.profilePhotoUrl, let url = URL(string: photoURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(Color(UIColor.tertiarySystemBackground))
                        .overlay(
                            Text(member.displayName.prefix(2).uppercased())
                                .font(.caption)
                                .foregroundColor(Constants.Colors.primary)
                        )
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color(UIColor.tertiarySystemBackground))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(member.displayName.prefix(2).uppercased())
                            .font(.caption)
                            .foregroundColor(Constants.Colors.primary)
                    )
            }

            Text(member.displayName.components(separatedBy: " ").first ?? member.displayName)
                .font(.caption)
                .foregroundColor(Constants.Colors.textSecondary)
                .lineLimit(1)
        }
    }
}

// MARK: - Quick Stat Card

struct QuickStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.small) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Spacer()
            }

            Text(title)
                .font(.caption)
                .foregroundColor(Constants.Colors.textSecondary)

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(Constants.Colors.textPrimary)
        }
        .padding(Constants.Spacing.medium)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(Constants.CornerRadius.medium)
    }
}

// MARK: - Preview

#Preview {
    DashboardView(selectedTab: .constant(0))
}
