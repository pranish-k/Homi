import SwiftUI
import FirebaseAuth

// MARK: - Nudge Button Component

struct NudgeButton: View {
    let targetUserId: String
    let targetUserName: String
    let itemId: String
    let itemTitle: String
    let nudgeType: NudgeType

    @State private var showingConfirmation = false
    @State private var canNudge = true
    @State private var timeRemaining: String?
    @State private var isLoading = false

    @StateObject private var nudgeService = NudgeService.shared
    @StateObject private var authService = AuthService.shared

    var body: some View {
        Button(action: {
            if canNudge {
                showingConfirmation = true
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 12))

                Text(canNudge ? "Nudge" : timeRemaining ?? "Nudged")
                    .font(Constants.Typography.caption1)
                    .fontWeight(.semibold)
            }
            .foregroundColor(canNudge ? Constants.Colors.warning : Constants.Colors.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                canNudge ?
                Constants.Colors.warning.opacity(0.15) :
                Constants.Colors.tertiaryBackground
            )
            .cornerRadius(Constants.CornerRadius.small)
        }
        .disabled(!canNudge || isLoading)
        .task {
            await checkNudgeEligibility()
        }
        .sheet(isPresented: $showingConfirmation) {
            NudgeConfirmationSheet(
                targetUserName: targetUserName,
                itemTitle: itemTitle,
                nudgeType: nudgeType,
                onConfirm: {
                    Task {
                        await sendNudge()
                    }
                }
            )
        }
    }

    // MARK: - Check Eligibility

    private func checkNudgeEligibility() async {
        guard let currentUserId = authService.user?.uid else { return }

        canNudge = await nudgeService.canSendNudge(
            fromUserId: currentUserId,
            toUserId: targetUserId,
            itemId: itemId
        )

        if !canNudge {
            timeRemaining = await nudgeService.timeUntilNextNudge(
                fromUserId: currentUserId,
                toUserId: targetUserId,
                itemId: itemId
            )
        }
    }

    // MARK: - Send Nudge

    private func sendNudge() async {
        guard let currentUserId = authService.user?.uid,
              let currentUserName = authService.userProfile?.displayName,
              let houseId = authService.userProfile?.currentHouseId else {
            return
        }

        isLoading = true

        do {
            try await nudgeService.sendNudge(
                houseId: houseId,
                fromUserId: currentUserId,
                fromUserName: currentUserName,
                toUserId: targetUserId,
                toUserName: targetUserName,
                type: nudgeType,
                itemId: itemId,
                itemTitle: itemTitle
            )

            HapticManager.success()
            await checkNudgeEligibility()
        } catch {
            HapticManager.error()
            print("Error sending nudge: \(error.localizedDescription)")
        }

        isLoading = false
    }
}

// MARK: - Nudge Confirmation Sheet

struct NudgeConfirmationSheet: View {
    @Environment(\.dismiss) private var dismiss

    let targetUserName: String
    let itemTitle: String
    let nudgeType: NudgeType
    let onConfirm: () -> Void

    @State private var isSending = false

    var body: some View {
        NavigationStack {
            VStack(spacing: Constants.Spacing.large) {
                // Icon
                Image(systemName: nudgeIcon)
                    .font(.system(size: 60))
                    .foregroundColor(Constants.Colors.warning)
                    .padding(.top, Constants.Spacing.xxLarge)

                // Message
                VStack(spacing: Constants.Spacing.small) {
                    Text("Send a Nudge?")
                        .font(Constants.Typography.title2)

                    Text(nudgeMessage)
                        .font(Constants.Typography.body)
                        .foregroundColor(Constants.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Constants.Spacing.xLarge)
                }

                Spacer()

                // Actions
                VStack(spacing: Constants.Spacing.medium) {
                    HomiButton(
                        "Send Nudge",
                        icon: "bell.fill",
                        style: .primary,
                        isLoading: isSending
                    ) {
                        isSending = true
                        onConfirm()
                        dismiss()
                    }

                    Button("Cancel") {
                        dismiss()
                    }
                    .font(Constants.Typography.bodyMedium)
                    .foregroundColor(Constants.Colors.textSecondary)
                }
                .padding(.horizontal, Constants.Spacing.screenPadding)
                .padding(.bottom, Constants.Spacing.large)
            }
            .navigationTitle("Nudge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Constants.Colors.primary)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var nudgeIcon: String {
        switch nudgeType {
        case .choreOverdue:
            return "bell.badge.fill"
        case .paymentOverdue:
            return "dollarsign.circle.fill"
        }
    }

    private var nudgeMessage: String {
        switch nudgeType {
        case .choreOverdue:
            return "This will send \(targetUserName) a friendly reminder about the overdue chore: \"\(itemTitle)\""
        case .paymentOverdue:
            return "This will send \(targetUserName) a friendly reminder about their outstanding balance"
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: Constants.Spacing.medium) {
        NudgeButton(
            targetUserId: "user1",
            targetUserName: "John",
            itemId: "chore1",
            itemTitle: "Take out trash",
            nudgeType: .choreOverdue
        )

        NudgeButton(
            targetUserId: "user2",
            targetUserName: "Sarah",
            itemId: "expense1",
            itemTitle: "Groceries",
            nudgeType: .paymentOverdue
        )
    }
    .padding()
}
