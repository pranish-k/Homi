import SwiftUI

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
        VStack(alignment: .leading, spacing: Constants.Spacing.small) {
            // Header
            HStack(alignment: .top) {
                // Category icon
                Image(systemName: chore.category.icon)
                    .font(.title3)
                    .foregroundColor(chore.category.color)
                    .frame(width: 36, height: 36)
                    .background(chore.category.color.opacity(0.1))
                    .cornerRadius(Constants.CornerRadius.small)

                VStack(alignment: .leading, spacing: 4) {
                    Text(chore.title)
                        .font(.headline)
                        .foregroundColor(Constants.Colors.textPrimary)

                    Text(chore.category.rawValue)
                        .font(.caption)
                        .foregroundColor(Constants.Colors.textSecondary)
                }

                Spacer()

                // Points badge
                if chore.points > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)

                        Text("\(chore.points)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Constants.Colors.textPrimary)
                    }
                    .padding(.horizontal, Constants.Spacing.small)
                    .padding(.vertical, Constants.Spacing.xxSmall)
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(Constants.CornerRadius.small)
                }
            }

            // Description
            if let description = chore.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(Constants.Colors.textSecondary)
                    .lineLimit(2)
            }

            Divider()
                .padding(.vertical, Constants.Spacing.xxSmall)

            // Info row
            HStack {
                // Assignee
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.caption)
                        .foregroundColor(Constants.Colors.textSecondary)

                    if isAssignedToCurrentUser {
                        Text("You")
                            .font(.subheadline)
                            .foregroundColor(Constants.Colors.primary)
                            .fontWeight(.medium)
                    } else {
                        Text(chore.assignedToName)
                            .font(.subheadline)
                            .foregroundColor(Constants.Colors.textSecondary)
                    }

                    // Rotation indicator
                    if chore.rotationEnabled {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundColor(Constants.Colors.textSecondary)
                    }
                }

                Spacer()

                // Due date
                HStack(spacing: 4) {
                    Image(systemName: dueDateIcon)
                        .font(.caption)
                        .foregroundColor(dueDateColor)

                    Text(chore.dueDateDescription)
                        .font(.subheadline)
                        .foregroundColor(dueDateColor)
                }
            }

            // Frequency
            if chore.frequency != .once {
                HStack(spacing: 4) {
                    Image(systemName: "repeat")
                        .font(.caption)
                        .foregroundColor(Constants.Colors.textSecondary)

                    Text(chore.frequency.rawValue)
                        .font(.caption)
                        .foregroundColor(Constants.Colors.textSecondary)
                }
            }

            // Completed status
            if chore.isCompleted {
                HStack {
                    Spacer()
                    Label {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Completed")
                                .font(.caption)
                                .fontWeight(.semibold)

                            if let completedByName = chore.completedByName {
                                Text("by \(completedByName)")
                                    .font(.caption2)
                            }
                        }
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                    }
                    .foregroundColor(Constants.Colors.success)
                    .padding(.horizontal, Constants.Spacing.small)
                    .padding(.vertical, Constants.Spacing.xxSmall)
                    .background(Constants.Colors.success.opacity(0.1))
                    .cornerRadius(Constants.CornerRadius.small)
                }
            }
        }
        .padding(Constants.Spacing.medium)
        .background(Color(.systemBackground))
        .cornerRadius(Constants.CornerRadius.medium)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: Constants.CornerRadius.medium)
                .stroke(chore.isOverdue ? Constants.Colors.danger.opacity(0.3) : Color.clear, lineWidth: 2)
        )
        .contextMenu {
            if !chore.isCompleted && isAssignedToCurrentUser {
                Button {
                    onComplete?()
                } label: {
                    Label("Mark as Complete", systemImage: "checkmark.circle")
                }
            }

            if chore.isCompleted && isAssignedToCurrentUser {
                Button {
                    onUncomplete?()
                } label: {
                    Label("Mark as Incomplete", systemImage: "arrow.uturn.backward.circle")
                }
            }

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

    private var dueDateColor: Color {
        if chore.isOverdue {
            return Constants.Colors.danger
        } else if chore.isDueToday {
            return Constants.Colors.warning
        } else {
            return Constants.Colors.textSecondary
        }
    }
}

// MARK: - Preview

struct ChoreCardView_Previews: PreviewProvider {
    static var previews: some View {
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
        .background(Color(.systemGroupedBackground))
    }
}
