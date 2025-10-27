import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = AuthService.shared

    @State private var showChangePassword = false
    @State private var showThemeSelection = false
    @State private var showNotificationSettings = false
    @State private var showMyHouse = false
    @State private var showAdminPanel = false
    @State private var currentHouse: House?

    private var isHouseCreator: Bool {
        guard let userId = authService.userProfile?.id,
              let house = currentHouse else {
            return false
        }
        return house.createdBy == userId
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Constants.Spacing.large) {
                    // Account Section
                    SettingsSection(title: "Account") {
                        if let user = authService.userProfile {
                            SettingsRow(
                                icon: "person.circle.fill",
                                title: "Profile",
                                value: user.displayName
                            )

                            SettingsRow(
                                icon: "envelope.fill",
                                title: "Email",
                                value: user.email ?? "Not set"
                            )
                        }

                        SettingsButton(
                            icon: "key.fill",
                            title: "Change Password",
                            action: { showChangePassword = true }
                        )
                    }

                    // Appearance Section
                    SettingsSection(title: "Appearance") {
                        SettingsButton(
                            icon: "paintpalette.fill",
                            title: "Theme",
                            value: ThemeManager.shared.currentTheme.name,
                            action: { showThemeSelection = true }
                        )
                    }

                    // Notifications Section
                    SettingsSection(title: "Notifications") {
                        SettingsButton(
                            icon: "bell.fill",
                            title: "Notification Settings",
                            action: { showNotificationSettings = true }
                        )
                    }

                    // House Section (for all members)
                    if authService.userProfile?.currentHouseId != nil {
                        SettingsSection(title: "House") {
                            SettingsButton(
                                icon: "house.fill",
                                title: "My House",
                                action: { showMyHouse = true }
                            )
                        }
                    }

                    // About Section
                    SettingsSection(title: "About") {
                        SettingsRow(
                            icon: "info.circle.fill",
                            title: "Version",
                            value: "1.0.0"
                        )
                    }

                    // Sign Out Button
                    HomiButton("Sign Out", icon: "arrow.right.square", style: .destructive) {
                        do {
                            try authService.signOut()
                            dismiss()
                        } catch {
                            print("Error signing out: \(error)")
                        }
                    }
                    .padding(.horizontal, Constants.Spacing.screenPadding)
                    .padding(.top, Constants.Spacing.medium)
                }
                .padding(.vertical, Constants.Spacing.medium)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Constants.Colors.primary)
                }
            }
            .sheet(isPresented: $showChangePassword) {
                ChangePasswordView()
            }
            .sheet(isPresented: $showThemeSelection) {
                ThemeSelectionView()
            }
            .sheet(isPresented: $showNotificationSettings) {
                NotificationSettingsView()
            }
            .sheet(isPresented: $showMyHouse) {
                MyHouseView()
            }
            .sheet(isPresented: $showAdminPanel) {
                AdminPanelView(house: $currentHouse)
            }
            .task {
                await loadHouse()
            }
        }
    }

    // MARK: - Data Loading

    private func loadHouse() async {
        guard let houseId = authService.userProfile?.currentHouseId else { return }

        do {
            if let house = try await FirestoreService.shared.getHouse(id: houseId) {
                await MainActor.run {
                    currentHouse = house
                }
            }
        } catch {
            print("Error loading house: \(error)")
        }
    }
}

// MARK: - Settings Section

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.small) {
            Text(title)
                .font(Constants.Typography.subheadline)
                .foregroundColor(Constants.Colors.textSecondary)
                .padding(.horizontal, Constants.Spacing.screenPadding)

            HomiCard(shadowStyle: .subtle) {
                VStack(spacing: 0) {
                    content
                }
            }
            .padding(.horizontal, Constants.Spacing.screenPadding)
        }
    }
}

// MARK: - Settings Row (Non-tappable)

struct SettingsRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: Constants.Spacing.medium) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Constants.Colors.primary)
                .frame(width: 28)

            Text(title)
                .font(Constants.Typography.body)

            Spacer()

            Text(value)
                .font(Constants.Typography.subheadline)
                .foregroundColor(Constants.Colors.textSecondary)
        }
        .padding(Constants.Spacing.cardPadding)
    }
}

// MARK: - Settings Button (Tappable)

struct SettingsButton: View {
    let icon: String
    let title: String
    var value: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Constants.Spacing.medium) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(Constants.Colors.primary)
                    .frame(width: 28)

                Text(title)
                    .font(Constants.Typography.body)
                    .foregroundColor(Constants.Colors.textPrimary)

                Spacer()

                if let value = value {
                    Text(value)
                        .font(Constants.Typography.subheadline)
                        .foregroundColor(Constants.Colors.textSecondary)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Constants.Colors.textSecondary)
            }
            .padding(Constants.Spacing.cardPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
