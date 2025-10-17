import SwiftUI
import FirebaseAuth
import OSLog

struct DashboardView: View {
    @StateObject private var authService = AuthService.shared
    @StateObject private var firestoreService = FirestoreService.shared
    @State private var currentHouse: House?
    @State private var houseMembers: [HouseMember] = []
    @State private var isLoading = true

    private let logger = Logger(subsystem: "com.homi.app", category: "DashboardView")

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Constants.Spacing.large) {
                    // House Header
                    if let house = currentHouse {
                        VStack(spacing: Constants.Spacing.medium) {
                            HStack {
                                VStack(alignment: .leading, spacing: Constants.Spacing.xSmall) {
                                    Text(house.name)
                                        .font(.largeTitle)
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
                            .padding(.horizontal, Constants.Spacing.large)

                            // Member Avatars
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Constants.Spacing.medium) {
                                    ForEach(houseMembers) { member in
                                        MemberAvatarView(member: member)
                                    }

                                    // Add Member Button
                                    Button(action: shareInvite) {
                                        VStack {
                                            ZStack {
                                                Circle()
                                                    .fill(Color(.secondarySystemBackground))
                                                    .frame(width: 60, height: 60)

                                                Image(systemName: "person.badge.plus")
                                                    .font(.title3)
                                                    .foregroundColor(Constants.Colors.primary)
                                            }

                                            Text("Invite")
                                                .font(.caption)
                                                .foregroundColor(Constants.Colors.textSecondary)
                                        }
                                    }
                                }
                                .padding(.horizontal, Constants.Spacing.large)
                            }
                        }
                        .padding(.vertical, Constants.Spacing.medium)
                    }

                    // Quick Stats
                    VStack(spacing: Constants.Spacing.medium) {
                        Text("Quick Overview")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Constants.Spacing.large)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: Constants.Spacing.medium) {
                            QuickStatCard(
                                icon: "dollarsign.circle.fill",
                                title: "Bills",
                                value: "Coming Soon",
                                color: Constants.Colors.success
                            )

                            QuickStatCard(
                                icon: "checklist",
                                title: "Chores",
                                value: "Coming Soon",
                                color: Constants.Colors.primary
                            )

                            QuickStatCard(
                                icon: "message.fill",
                                title: "Messages",
                                value: "Coming Soon",
                                color: Constants.Colors.warning
                            )

                            QuickStatCard(
                                icon: "location.fill",
                                title: "Location",
                                value: "Coming Soon",
                                color: Constants.Colors.danger
                            )
                        }
                        .padding(.horizontal, Constants.Spacing.large)
                    }

                    // Recent Activity
                    VStack(spacing: Constants.Spacing.medium) {
                        Text("Recent Activity")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Constants.Spacing.large)

                        VStack(spacing: Constants.Spacing.small) {
                            ActivityRow(
                                icon: "person.badge.plus",
                                text: "You created the house",
                                time: "Just now",
                                color: Constants.Colors.success
                            )

                            Text("More features coming in Phase 3!")
                                .font(.caption)
                                .foregroundColor(Constants.Colors.textSecondary)
                                .padding(.vertical, Constants.Spacing.large)
                        }
                        .padding(.horizontal, Constants.Spacing.large)
                    }
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
        }
        .task {
            await loadHouseData()
        }
    }

    private func loadHouseData() async {
        guard let houseId = authService.userProfile?.currentHouseId else { return }

        do {
            currentHouse = try await firestoreService.getHouse(id: houseId)
            houseMembers = try await firestoreService.getHouseMembers(houseId: houseId)
        } catch {
            logger.error("Error loading house data: \(error.localizedDescription)")
        }

        isLoading = false
    }

    private func shareInvite() {
        guard let house = currentHouse else { return }

        let message = """
        Join our house "\(house.name)" on Homi! 🏠

        Use this invite code: \(house.inviteCode)

        Download Homi to stay organized with your housemates!
        """

        let activityVC = UIActivityViewController(
            activityItems: [message],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

struct MemberAvatarView: View {
    let member: HouseMember

    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 60, height: 60)

                Text(member.displayName.prefix(2).uppercased())
                    .font(.headline)
                    .foregroundColor(Constants.Colors.primary)
            }

            Text(member.displayName.components(separatedBy: " ").first ?? member.displayName)
                .font(.caption)
                .foregroundColor(Constants.Colors.textSecondary)
                .lineLimit(1)
        }
    }
}

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
                .font(.headline)
                .foregroundColor(Constants.Colors.textPrimary)
        }
        .padding(Constants.Spacing.medium)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(Constants.CornerRadius.medium)
    }
}

struct ActivityRow: View {
    let icon: String
    let text: String
    let time: String
    let color: Color

    var body: some View {
        HStack(spacing: Constants.Spacing.medium) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(.subheadline)

                Text(time)
                    .font(.caption)
                    .foregroundColor(Constants.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(.vertical, Constants.Spacing.small)
    }
}