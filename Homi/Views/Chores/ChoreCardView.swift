import SwiftUI

// MARK: - Redesigned Chore Card (Clean & Minimal)

struct ChoreCardView: View {
    let chore: Chore
    let currentUserId: String
    var onComplete: (() -> Void)?
    var onUncomplete: (() -> Void)?
    var onDelete: (() -> Void)?

    private var isAssignedToCurrentUser: Bool {
        chore.assignedTo == currentUserId
    }

    var body: some View {
        HomiCard(shadowStyle: .subtle) {
            HStack(spacing: Constants.Spacing.medium) {
                // Category Icon
                ZStack {
                    Circle()
                        .fill(chore.category.color.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: chore.category.icon)
                        .font(.system(size: 20))
                        .foregroundColor(chore.category.color)
                }

                // Title & Assignee
                VStack(alignment: .leading, spacing: 4) {
                    Text(chore.title)
                        .font(Constants.Typography.headline)
                        .foregroundColor(Constants.Colors.textPrimary)
                        .lineLimit(1)

                    Text(isAssignedToCurrentUser ? "You" : chore.assignedToName)
                        .font(Constants.Typography.caption1)
                        .foregroundColor(isAssignedToCurrentUser ? Constants.Colors.primary : Constants.Colors.textSecondary)
                }

                Spacer()

                // Status & Actions
                VStack(alignment: .trailing, spacing: 8) {
                    // Due date badge
                    if !chore.isCompleted {
                        HomiBadge(
                            chore.dueDateDescription,
                            icon: dueDateIcon,
                            style: dueDateBadgeStyle,
                            size: .small
                        )
                    } else {
                        HomiBadge(
                            "Done",
                            icon: "checkmark",
                            style: .success,
                            size: .small
                        )
                    }

                    // Nudge button (if overdue and not assigned to current user and not completed)
                    if chore.isOverdue && !isAssignedToCurrentUser && !chore.isCompleted {
                        NudgeButton(
                            targetUserId: chore.assignedTo,
                            targetUserName: chore.assignedToName,
                            itemId: chore.id,
                            itemTitle: chore.title,
                            nudgeType: .choreOverdue
                        )
                    }

                    // Complete checkbox (if assigned to current user)
                    if isAssignedToCurrentUser {
                        Button(action: {
                            HapticManager.impact(style: .light)
                            if chore.isCompleted {
                                onUncomplete?()
                            } else {
                                onComplete?()
                            }
                        }) {
                            Image(systemName: chore.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 24))
                                .foregroundColor(chore.isCompleted ? Constants.Colors.success : Constants.Colors.textSecondary)
                        }
                    }
                }
            }
            .padding(Constants.Spacing.cardPadding)
        }
        .overlay(
            RoundedRectangle(cornerRadius: Constants.CornerRadius.card)
                .stroke(chore.isOverdue && !chore.isCompleted ? Constants.Colors.danger.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if isAssignedToCurrentUser {
                if chore.isCompleted {
                    Button {
                        onUncomplete?()
                    } label: {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                    }
                    .tint(Constants.Colors.warning)
                } else {
                    Button {
                        onComplete?()
                    } label: {
                        Label("Complete", systemImage: "checkmark")
                    }
                    .tint(Constants.Colors.success)
                }
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if chore.createdBy == currentUserId {
                Button(role: .destructive) {
                    onDelete?()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private var dueDateIcon: String {
        if chore.isOverdue {
            return "exclamationmark.triangle.fill"
        } else if chore.isDueToday {
            return "clock.fill"
        } else {
            return "calendar"
        }
    }

    private var dueDateBadgeStyle: HomiBadgeStyle {
        if chore.isOverdue {
            return .danger
        } else if chore.isDueToday {
            return .warning
        } else {
            return .neutral
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: Constants.Spacing.medium) {
        ChoreCardView(
            chore: Chore.sampleChores[0],
            currentUserId: "user1"
        )

        ChoreCardView(
            chore: Chore.sampleChores[1],
            currentUserId: "user2"
        )

        ChoreCardView(
            chore: Chore.sampleChores[2],
            currentUserId: "user3"
        )
    }
    .padding()
}
