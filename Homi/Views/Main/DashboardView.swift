import SwiftUI
import FirebaseAuth
import OSLog

struct DashboardView: View {
    @Binding var selectedTab: Int
    @StateObject private var viewModel = DashboardViewModel()
    @StateObject private var authService = AuthService.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var nudgeService = NudgeService.shared

    @State private var showSettings = false
    @State private var showNotifications = false

    private let logger = Logger(subsystem: "com.homi.app", category: "DashboardView")

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                if viewModel.isLoading {
                    loadingView
                } else {
                    contentView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Home")
                        .font(Constants.Typography.title2)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: Constants.Spacing.medium) {
                        // Notification Bell
                        Button(action: {
                            showNotifications = true
                        }) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "bell.fill")
                                    .font(.title3)
                                    .foregroundColor(Constants.Colors.primary)

                                // Badge for unread notifications
                                if unreadNudgesCount > 0 {
                                    Circle()
                                        .fill(Constants.Colors.error)
                                        .frame(width: 16, height: 16)
                                        .overlay(
                                            Text("\(min(unreadNudgesCount, 9))")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.white)
                                        )
                                        .offset(x: 8, y: -8)
                                }
                            }
                        }

                        // Menu Button
                        Menu {
                            Button(action: {
                                showSettings = true
                            }) {
                                Label("Settings", systemImage: "gear")
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
                                .foregroundColor(Constants.Colors.primary)
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.loadData()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showNotifications) {
                NotificationView()
            }
        }
        .task {
            await viewModel.loadData()
            if let userId = authService.user?.uid {
                nudgeService.startListening(userId: userId)
            }
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }

    // MARK: - Computed Properties

    private var unreadNudgesCount: Int {
        // Count nudges from the last 24 hours as "unread"
        let oneDayAgo = Date().addingTimeInterval(-24 * 3600)
        return nudgeService.recentNudges.filter { $0.timestamp > oneDayAgo }.count
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: Constants.Spacing.large) {
            SkeletonCard()
            SkeletonCard()
            SkeletonCard()
        }
        .padding(Constants.Spacing.screenPadding)
    }

    // MARK: - Content View

    private var contentView: some View {
        VStack(spacing: Constants.Spacing.sectionSpacing) {
            // House Header Card
            if let house = viewModel.currentHouse {
                HouseHeaderCard(
                    house: house,
                    members: viewModel.houseMembers,
                    onShareInvite: viewModel.shareInvite
                )
                .padding(.horizontal, Constants.Spacing.screenPadding)
            }

            // 2x2 Quick Stats Grid
            QuickStatsGrid(viewModel: viewModel, selectedTab: $selectedTab)
                .padding(.horizontal, Constants.Spacing.screenPadding)

            // What's Next Card
            WhatsNextCard(
                item: viewModel.whatsNextItem,
                onTap: {
                    handleWhatsNextTap(item: viewModel.whatsNextItem)
                }
            )
            .padding(.horizontal, Constants.Spacing.screenPadding)
        }
        .padding(.vertical, Constants.Spacing.medium)
    }

    // MARK: - Actions

    private func handleWhatsNextTap(item: WhatsNextItemType) {
        switch item {
        case .overdueChore, .dueToday:
            selectedTab = 4 // Chores tab
        case .overduePayment:
            selectedTab = 2 // Bills tab
        case .allCaughtUp:
            break // No action
        }
    }
}

// MARK: - House Header Card (Redesigned)

struct HouseHeaderCard: View {
    let house: House
    let members: [HouseMember]
    let onShareInvite: () -> Void

    var body: some View {
        HomiCard(shadowStyle: .subtle) {
            VStack(spacing: Constants.Spacing.medium) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(house.name)
                            .font(Constants.Typography.title2)

                        if let address = house.address {
                            Text(address)
                                .font(Constants.Typography.caption1)
                                .foregroundColor(Constants.Colors.textSecondary)
                        }
                    }

                    Spacer()

                    // Invite Button
                    Button(action: onShareInvite) {
                        HStack(spacing: 6) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 14))

                            Text("Invite")
                                .font(Constants.Typography.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(Constants.Colors.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Constants.Colors.primaryLight)
                        .cornerRadius(Constants.CornerRadius.small)
                    }
                }

                // Members
                if !members.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Constants.Spacing.small) {
                            ForEach(members) { member in
                                MemberAvatarView(member: member)
                            }
                        }
                    }
                }
            }
            .padding(Constants.Spacing.cardPadding)
        }
    }
}

// MARK: - Member Avatar (Redesigned)

struct MemberAvatarView: View {
    let member: HouseMember

    var body: some View {
        VStack(spacing: 6) {
            if let photoURL = member.profilePhotoUrl, let url = URL(string: photoURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    avatarPlaceholder
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                avatarPlaceholder
            }

            Text(member.displayName.components(separatedBy: " ").first ?? member.displayName)
                .font(Constants.Typography.caption2)
                .foregroundColor(Constants.Colors.textSecondary)
                .lineLimit(1)
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Constants.Colors.tertiaryBackground)
            .frame(width: 44, height: 44)
            .overlay(
                Text(member.displayName.prefix(2).uppercased())
                    .font(Constants.Typography.caption1)
                    .fontWeight(.semibold)
                    .foregroundColor(Constants.Colors.primary)
            )
    }
}

// MARK: - Quick Stats Grid (Redesigned)

struct QuickStatsGrid: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Binding var selectedTab: Int

    var body: some View {
        VStack(spacing: Constants.Spacing.small) {
            // Balance card - full width
            QuickStatCard(
                icon: "dollarsign.circle.fill",
                title: "Balance",
                value: viewModel.balanceText,
                color: viewModel.balanceColor,
                onTap: { selectedTab = 2 }
            )

            // Chores and Messages - side by side
            HStack(spacing: Constants.Spacing.small) {
                QuickStatCard(
                    icon: "checklist",
                    title: "Chores",
                    value: "\(viewModel.dueTodayChoresCount)",
                    color: viewModel.dueTodayChoresCount > 0 ? Constants.Colors.warning : Constants.Colors.textSecondary,
                    onTap: { selectedTab = 4 }
                )

                QuickStatCard(
                    icon: "message.fill",
                    title: "Messages",
                    value: "\(viewModel.unreadMessagesCount)",
                    color: viewModel.unreadMessagesCount > 0 ? Constants.Colors.primary : Constants.Colors.textSecondary,
                    onTap: { selectedTab = 1 }
                )
            }
        }
    }
}

// MARK: - Quick Stat Card (Redesigned - Cleaner)

struct QuickStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HomiCard(shadowStyle: .subtle) {
                VStack(alignment: .leading, spacing: Constants.Spacing.xSmall) {
                    // Icon
                    Image(systemName: icon)
                        .font(.system(size: 28))
                        .foregroundColor(color)
                        .frame(height: 32)

                    Spacer(minLength: 8)

                    // Value - with proper scaling
                    Text(value)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(Constants.Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    // Title
                    Text(title)
                        .font(Constants.Typography.subheadline)
                        .foregroundColor(Constants.Colors.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Constants.Spacing.medium)
                .frame(minHeight: 120)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    DashboardView(selectedTab: .constant(0))
}
