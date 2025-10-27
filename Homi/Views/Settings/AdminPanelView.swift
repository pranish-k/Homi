//
//  AdminPanelView.swift
//  Homi
//
//  Admin panel for house creators/admins
//

import SwiftUI
import FirebaseFirestore
import OSLog

struct AdminPanelView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var house: House?

    @StateObject private var authService = AuthService.shared
    @StateObject private var firestoreService = FirestoreService.shared

    @State private var houseMembers: [HouseMember] = []
    @State private var showRenameHouse = false
    @State private var showTransferOwnership = false
    @State private var showManageInvites = false
    @State private var showRemoveMember = false
    @State private var selectedMember: HouseMember?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false

    private let logger = Logger(subsystem: "com.homi.app", category: "AdminPanel")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Constants.Spacing.large) {
                    // House Info Section
                    if let house = house {
                        SettingsSection(title: "House Information") {
                            SettingsRow(
                                icon: "house.fill",
                                title: "House Name",
                                value: house.name
                            )

                            SettingsRow(
                                icon: "person.3.fill",
                                title: "Members",
                                value: "\(house.memberCount)"
                            )

                            SettingsButton(
                                icon: "pencil",
                                title: "Rename House",
                                action: { showRenameHouse = true }
                            )
                        }
                    }

                    // Members Management
                    SettingsSection(title: "Manage Members") {
                        if isLoading {
                            ProgressView()
                                .padding()
                        } else if houseMembers.isEmpty {
                            Text("No members found")
                                .font(Constants.Typography.body)
                                .foregroundColor(Constants.Colors.textSecondary)
                                .padding()
                        } else {
                            ForEach(houseMembers) { member in
                                MemberManagementRow(
                                    member: member,
                                    isCurrentUser: member.id == authService.userProfile?.id,
                                    onRemove: {
                                        selectedMember = member
                                        showRemoveMember = true
                                    }
                                )
                            }
                        }
                    }

                    // Advanced Actions
                    SettingsSection(title: "Advanced") {
                        SettingsButton(
                            icon: "arrow.triangle.2.circlepath",
                            title: "Transfer Ownership",
                            action: { showTransferOwnership = true }
                        )

                        SettingsButton(
                            icon: "qrcode",
                            title: "Manage Invite Codes",
                            action: { showManageInvites = true }
                        )
                    }
                }
                .padding(.vertical, Constants.Spacing.medium)
            }
            .navigationTitle("House Management")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Constants.Colors.primary)
                }
            }
            .task {
                await loadMembers()
            }
            .alert("Remove Member", isPresented: $showRemoveMember) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) {
                    if let member = selectedMember {
                        Task {
                            await removeMember(member)
                        }
                    }
                }
            } message: {
                if let member = selectedMember {
                    Text("Are you sure you want to remove \(member.displayName) from the house? They must settle all balances before leaving.")
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
            .sheet(isPresented: $showRenameHouse) {
                RenameHouseView(house: $house)
            }
            .sheet(isPresented: $showTransferOwnership) {
                TransferOwnershipView(house: $house, members: houseMembers)
            }
            .sheet(isPresented: $showManageInvites) {
                ManageInvitesView(house: house)
            }
        }
    }

    // MARK: - Data Loading

    private func loadMembers() async {
        guard let houseId = house?.id else { return }

        isLoading = true

        do {
            let members = try await firestoreService.getHouseMembers(houseId: houseId)
            await MainActor.run {
                houseMembers = members
                isLoading = false
            }
        } catch {
            logger.error("Error loading members: \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = "Failed to load members"
                showError = true
                isLoading = false
            }
        }
    }

    // MARK: - Member Management

    private func removeMember(_ member: HouseMember) async {
        guard let houseId = house?.id else { return }

        // TODO: Check if member has outstanding balances
        // For now, we'll just show a warning

        do {
            // Remove member from house
            try await firestoreService.removeMemberFromHouse(houseId: houseId, memberId: member.id)

            await MainActor.run {
                HapticManager.success()
                // Reload members
                Task {
                    await loadMembers()
                }
            }

            logger.info("Member removed successfully: \(member.displayName)")
        } catch {
            logger.error("Error removing member: \(error.localizedDescription)")
            await MainActor.run {
                HapticManager.error()
                errorMessage = "Failed to remove member: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

// MARK: - Member Management Row

struct MemberManagementRow: View {
    let member: HouseMember
    let isCurrentUser: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: Constants.Spacing.medium) {
            // Avatar
            Circle()
                .fill(Constants.Colors.tertiaryBackground)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(member.displayName.prefix(1).uppercased())
                        .font(Constants.Typography.headline)
                        .foregroundColor(Constants.Colors.primary)
                )

            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName + (isCurrentUser ? " (You)" : ""))
                    .font(Constants.Typography.body)
                    .foregroundColor(Constants.Colors.textPrimary)

                Text(member.role.rawValue.capitalized)
                    .font(Constants.Typography.caption1)
                    .foregroundColor(Constants.Colors.textSecondary)
            }

            Spacer()

            // Remove button (not for current user)
            if !isCurrentUser {
                Button(action: onRemove) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Constants.Colors.danger)
                }
            }
        }
        .padding(Constants.Spacing.cardPadding)
    }
}

// MARK: - Rename House View

struct RenameHouseView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var house: House?

    @State private var newName: String = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            VStack(spacing: Constants.Spacing.large) {
                TextField("House Name", text: $newName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                Spacer()
            }
            .navigationTitle("Rename House")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await renameHouse()
                        }
                    }
                    .disabled(newName.isEmpty || isLoading)
                }
            }
            .onAppear {
                newName = house?.name ?? ""
            }
        }
    }

    private func renameHouse() async {
        guard let houseId = house?.id, !newName.isEmpty else { return }

        isLoading = true

        do {
            try await FirestoreService.shared.updateHouseName(houseId: houseId, name: newName)

            await MainActor.run {
                house?.name = newName
                isLoading = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - Transfer Ownership View (Placeholder)

struct TransferOwnershipView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var house: House?
    let members: [HouseMember]

    var body: some View {
        NavigationStack {
            Text("Transfer Ownership - Coming Soon")
                .navigationTitle("Transfer Ownership")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

// MARK: - Manage Invites View (Placeholder)

struct ManageInvitesView: View {
    @Environment(\.dismiss) private var dismiss
    let house: House?

    var body: some View {
        NavigationStack {
            Text("Manage Invite Codes - Coming Soon")
                .navigationTitle("Manage Invites")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

// MARK: - Preview

#Preview {
    AdminPanelView(house: .constant(nil))
}
