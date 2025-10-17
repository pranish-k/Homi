import SwiftUI

// MARK: - Upcoming Chores Widget

struct UpcomingChoresWidget: View {
    let chores: [Chore]
    let overdueCount: Int
    let dueTodayCount: Int
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.medium) {
            HStack {
                Label("Upcoming Chores", systemImage: "checklist")
                    .font(.headline)

                Spacer()

                if overdueCount > 0 {
                    Text("\(overdueCount) overdue")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Constants.Colors.danger)
                        .cornerRadius(12)
                }
            }

            if chores.isEmpty {
                EmptyWidgetState(
                    icon: "checkmark.circle",
                    message: "No upcoming chores"
                )
            } else {
                VStack(spacing: Constants.Spacing.small) {
                    ForEach(chores.prefix(3)) { chore in
                        ChoreRowCompact(chore: chore)
                    }
                }

                if chores.count > 3 {
                    Button(action: onTap) {
                        Text("View all chores")
                            .font(.caption)
                            .foregroundColor(Constants.Colors.primary)
                    }
                    .padding(.top, Constants.Spacing.xSmall)
                }
            }
        }
        .padding(Constants.Spacing.medium)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(Constants.CornerRadius.medium)
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Chore Row Compact

struct ChoreRowCompact: View {
    let chore: Chore

    var body: some View {
        HStack(spacing: Constants.Spacing.small) {
            Image(systemName: chore.category.icon)
                .font(.caption)
                .foregroundColor(chore.category.color)
                .frame(width: 24, height: 24)
                .background(chore.category.color.opacity(0.1))
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 2) {
                Text(chore.title)
                    .font(.subheadline)
                    .lineLimit(1)

                Text(chore.assignedToName)
                    .font(.caption)
                    .foregroundColor(Constants.Colors.textSecondary)
            }

            Spacer()

            Text(chore.dueDateDescription)
                .font(.caption)
                .foregroundColor(chore.isOverdue ? Constants.Colors.danger : Constants.Colors.textSecondary)
        }
        .padding(.vertical, Constants.Spacing.xSmall)
    }
}

// MARK: - Balance Summary Widget

struct BalanceSummaryWidget: View {
    let balance: Double
    let balanceText: String
    let balanceColor: Color
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.medium) {
            Label("Your Balance", systemImage: "dollarsign.circle")
                .font(.headline)

            HStack(alignment: .firstTextBaseline) {
                Text(balanceText)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(balanceColor)

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    if balance > 0 {
                        Text("You're owed")
                            .font(.caption)
                            .foregroundColor(Constants.Colors.textSecondary)
                    } else if balance < 0 {
                        Text("You owe")
                            .font(.caption)
                            .foregroundColor(Constants.Colors.textSecondary)
                    } else {
                        Text("All settled up")
                            .font(.caption)
                            .foregroundColor(Constants.Colors.textSecondary)
                    }
                }
            }

            Button(action: onTap) {
                Text("View expenses")
                    .font(.caption)
                    .foregroundColor(Constants.Colors.primary)
            }
        }
        .padding(Constants.Spacing.medium)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(Constants.CornerRadius.medium)
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Recent Messages Widget

struct RecentMessagesWidget: View {
    let messages: [Message]
    let unreadCount: Int
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.medium) {
            HStack {
                Label("Recent Messages", systemImage: "message")
                    .font(.headline)

                Spacer()

                if unreadCount > 0 {
                    Text("\(unreadCount) unread")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Constants.Colors.primary)
                        .cornerRadius(12)
                }
            }

            if messages.isEmpty {
                EmptyWidgetState(
                    icon: "message",
                    message: "No messages yet"
                )
            } else {
                VStack(spacing: Constants.Spacing.small) {
                    ForEach(messages.prefix(3)) { message in
                        MessageRowCompact(message: message)
                    }
                }

                if messages.count > 3 {
                    Button(action: onTap) {
                        Text("View all messages")
                            .font(.caption)
                            .foregroundColor(Constants.Colors.primary)
                    }
                    .padding(.top, Constants.Spacing.xSmall)
                }
            }
        }
        .padding(Constants.Spacing.medium)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(Constants.CornerRadius.medium)
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Message Row Compact

struct MessageRowCompact: View {
    let message: Message

    var body: some View {
        HStack(spacing: Constants.Spacing.small) {
            Circle()
                .fill(Color(UIColor.tertiarySystemBackground))
                .frame(width: 32, height: 32)
                .overlay(
                    Text(message.senderName.prefix(1))
                        .font(.caption)
                        .foregroundColor(Constants.Colors.primary)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(message.senderName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Text(message.formattedTime)
                        .font(.caption2)
                        .foregroundColor(Constants.Colors.textSecondary)
                }

                Text(message.content)
                    .font(.caption)
                    .foregroundColor(Constants.Colors.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, Constants.Spacing.xSmall)
    }
}

// MARK: - Quick Actions Card

struct QuickActionsCard: View {
    let onAddExpense: () -> Void
    let onAddChore: () -> Void
    let onSendMessage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.medium) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: Constants.Spacing.medium) {
                QuickActionButton(
                    icon: "plus.circle.fill",
                    title: "Add Expense",
                    color: Constants.Colors.success,
                    action: onAddExpense
                )

                QuickActionButton(
                    icon: "checklist",
                    title: "Add Chore",
                    color: Constants.Colors.primary,
                    action: onAddChore
                )

                QuickActionButton(
                    icon: "paperplane.fill",
                    title: "Send Message",
                    color: Constants.Colors.warning,
                    action: onSendMessage
                )
            }
        }
        .padding(Constants.Spacing.medium)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(Constants.CornerRadius.medium)
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Constants.Spacing.small) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 50, height: 50)
                    .background(color.opacity(0.1))
                    .cornerRadius(12)

                Text(title)
                    .font(.caption)
                    .foregroundColor(Constants.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Location Status Card

struct LocationStatusCard: View {
    let activeMembersCount: Int
    let isSharing: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: Constants.Spacing.medium) {
            Image(systemName: isSharing ? "location.fill" : "location.slash.fill")
                .font(.title2)
                .foregroundColor(isSharing ? Constants.Colors.success : Constants.Colors.textSecondary)
                .frame(width: 50, height: 50)
                .background((isSharing ? Constants.Colors.success : Color(UIColor.tertiarySystemBackground)).opacity(0.1))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 2) {
                Text("Location Sharing")
                    .font(.subheadline)
                    .fontWeight(.medium)

                if isSharing {
                    Text("\(activeMembersCount) member\(activeMembersCount == 1 ? "" : "s") sharing")
                        .font(.caption)
                        .foregroundColor(Constants.Colors.textSecondary)
                } else {
                    Text("Not sharing")
                        .font(.caption)
                        .foregroundColor(Constants.Colors.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Constants.Colors.textSecondary)
        }
        .padding(Constants.Spacing.medium)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(Constants.CornerRadius.medium)
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Empty Widget State

struct EmptyWidgetState: View {
    let icon: String
    let message: String

    var body: some View {
        VStack(spacing: Constants.Spacing.small) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(Constants.Colors.textSecondary.opacity(0.5))

            Text(message)
                .font(.caption)
                .foregroundColor(Constants.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Constants.Spacing.large)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: Constants.Spacing.medium) {
            UpcomingChoresWidget(
                chores: [],
                overdueCount: 2,
                dueTodayCount: 1,
                onTap: {}
            )

            BalanceSummaryWidget(
                balance: 45.50,
                balanceText: "+$45.50",
                balanceColor: Constants.Colors.success,
                onTap: {}
            )

            RecentMessagesWidget(
                messages: [],
                unreadCount: 3,
                onTap: {}
            )

            QuickActionsCard(
                onAddExpense: {},
                onAddChore: {},
                onSendMessage: {}
            )

            LocationStatusCard(
                activeMembersCount: 3,
                isSharing: true,
                onTap: {}
            )
        }
        .padding()
    }
}
