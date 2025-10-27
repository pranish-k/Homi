//
//  MyHouseView.swift
//  Homi
//
//  House information and management for all members
//

import SwiftUI
import FirebaseFirestore
import OSLog

struct MyHouseView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = AuthService.shared
    @StateObject private var firestoreService = FirestoreService.shared

    @State private var house: House?
    @State private var houseMembers: [HouseMember] = []
    @State private var isLoading = false
    @State private var showLeaveConfirmation = false
    @State private var showInviteCode = false
    @State private var errorMessage: String?
    @State private var showError = false

    // Admin-only states
    @State private var showRenameHouse = false
    @State private var showRemoveMember = false
    @State private var selectedMember: HouseMember?

    private let logger = Logger(subsystem: "com.homi.app", category: "MyHouseView")

    private var isAdmin: Bool {
        guard let userId = authService.userProfile?.id,
              let house = house else { return false }
        return house.createdBy == userId
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Constants.Spacing.large) {
                    // House Information
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
                                icon: "qrcode",
                                title: "View Invite Code",
                                action: { showInviteCode = true }
                            )

                            // Admin only: Rename house
                            if isAdmin {
                                SettingsButton(
                                    icon: "pencil",
                                    title: "Rename House",
                                    action: { showRenameHouse = true }
                                )
                            }
                        }
                    }

                    // Members List
                    SettingsSection(title: "Members") {
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
                                HouseMemberRow(
                                    member: member,
                                    isCurrentUser: member.id == authService.userProfile?.id,
                                    isAdmin: isAdmin,
                                    onLeave: {
                                        showLeaveConfirmation = true
                                    },
                                    onRemove: isAdmin ? {
                                        selectedMember = member
                                        showRemoveMember = true
                                    } : nil
                                )
                            }
                        }
                    }
                }
                .padding(.vertical, Constants.Spacing.medium)
            }
            .navigationTitle("My House")
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
                await loadHouseData()
            }
            .alert("Leave House", isPresented: $showLeaveConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Leave", role: .destructive) {
                    Task {
                        await leaveHouse()
                    }
                }
            } message: {
                Text("Are you sure you want to leave this house? Make sure you've settled all your balances first.")
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
            .sheet(isPresented: $showInviteCode) {
                if let house = house {
                    InviteCodeView(inviteCode: house.inviteCode)
                }
            }
            .sheet(isPresented: $showRenameHouse) {
                RenameHouseView(house: Binding(
                    get: { house },
                    set: { house = $0 }
                ))
            }
        }
    }

    // MARK: - Data Loading

    private func loadHouseData() async {
        guard let houseId = authService.userProfile?.currentHouseId else { return }

        isLoading = true

        do {
            // Load house
            if let fetchedHouse = try await firestoreService.getHouse(id: houseId) {
                await MainActor.run {
                    house = fetchedHouse
                }
            }

            // Load members
            let members = try await firestoreService.getHouseMembers(houseId: houseId)
            await MainActor.run {
                houseMembers = members
            }
        } catch {
            logger.error("Error loading house data: \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = "Failed to load house data"
                showError = true
            }
        }

        await MainActor.run {
            isLoading = false
        }
    }

    // MARK: - Actions

    private func leaveHouse() async {
        guard let userId = authService.userProfile?.id,
              let houseId = house?.id else { return }

        do {
            try await firestoreService.removeMemberFromHouse(houseId: houseId, memberId: userId)
            await MainActor.run {
                dismiss()
            }
        } catch {
            logger.error("Error leaving house: \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = "Failed to leave house: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    private func removeMember(_ member: HouseMember) async {
        guard let houseId = house?.id else { return }

        do {
            try await firestoreService.removeMemberFromHouse(houseId: houseId, memberId: member.id)
            await loadHouseData() // Reload to reflect changes
        } catch {
            logger.error("Error removing member: \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = "Failed to remove member: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

// MARK: - House Member Row

struct HouseMemberRow: View {
    let member: HouseMember
    let isCurrentUser: Bool
    let isAdmin: Bool
    var onLeave: (() -> Void)?
    var onRemove: (() -> Void)?

    private var isHouseAdmin: Bool {
        member.role == .admin
    }

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

            // Name and role
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(member.displayName)
                        .font(Constants.Typography.body)
                        .foregroundColor(Constants.Colors.textPrimary)

                    if isCurrentUser {
                        Text("(You)")
                            .font(Constants.Typography.caption1)
                            .foregroundColor(Constants.Colors.textSecondary)
                    }
                }

                HStack(spacing: 4) {
                    if isHouseAdmin {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Constants.Colors.warning)
                    }

                    Text(isHouseAdmin ? "Admin" : "Member")
                        .font(Constants.Typography.caption1)
                        .foregroundColor(Constants.Colors.textSecondary)
                }
            }

            Spacer()

            // Action buttons
            if isCurrentUser {
                // Leave button for current user
                Button(action: {
                    onLeave?()
                }) {
                    Text("Leave")
                        .font(Constants.Typography.caption1)
                        .foregroundColor(Constants.Colors.danger)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Constants.Colors.danger.opacity(0.1))
                        .cornerRadius(Constants.CornerRadius.small)
                }
            } else if isAdmin, let onRemove = onRemove {
                // Remove button for admins (on other members)
                Button(action: onRemove) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Constants.Colors.danger)
                }
            }
        }
        .padding(.vertical, Constants.Spacing.xSmall)
    }
}

// MARK: - Invite Code View

struct InviteCodeView: View {
    @Environment(\.dismiss) private var dismiss
    let inviteCode: String

    var body: some View {
        NavigationStack {
            VStack(spacing: Constants.Spacing.large) {
                Spacer()

                // QR Code or Large Code Display
                VStack(spacing: Constants.Spacing.medium) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 80))
                        .foregroundColor(Constants.Colors.primary)

                    Text(inviteCode)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(Constants.Colors.textPrimary)
                        .padding()
                        .background(Constants.Colors.tertiaryBackground)
                        .cornerRadius(Constants.CornerRadius.medium)

                    Text("Share this code with people you want to invite")
                        .font(Constants.Typography.body)
                        .foregroundColor(Constants.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Copy Button
                Button(action: {
                    UIPasteboard.general.string = inviteCode
                }) {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("Copy Code")
                    }
                    .font(Constants.Typography.bodyMedium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Constants.Colors.primary)
                    .cornerRadius(Constants.CornerRadius.medium)
                }
                .padding(.horizontal, Constants.Spacing.screenPadding)

                Spacer()
            }
            .navigationTitle("Invite Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Constants.Colors.primary)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MyHouseView()
}
