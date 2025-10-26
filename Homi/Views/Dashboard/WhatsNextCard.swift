import SwiftUI

// MARK: - What's Next Item Type

enum WhatsNextItemType {
    case overdueChore(Chore)
    case dueToday(Chore)
    case overduePayment(amount: Double, person: String)
    case allCaughtUp

    var icon: String {
        switch self {
        case .overdueChore:
            return "exclamationmark.triangle.fill"
        case .dueToday:
            return "clock.fill"
        case .overduePayment:
            return "dollarsign.circle.fill"
        case .allCaughtUp:
            return "checkmark.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .overdueChore, .overduePayment:
            return Constants.Colors.danger
        case .dueToday:
            return Constants.Colors.warning
        case .allCaughtUp:
            return Constants.Colors.success
        }
    }

    var title: String {
        switch self {
        case .overdueChore(let chore):
            return chore.title
        case .dueToday(let chore):
            return chore.title
        case .overduePayment(_, let person):
            return "Pay \(person)"
        case .allCaughtUp:
            return "You're all caught up!"
        }
    }

    var subtitle: String {
        switch self {
        case .overdueChore:
            return "Overdue - needs attention"
        case .dueToday:
            return "Due today"
        case .overduePayment(let amount, _):
            return "You owe \(CurrencyFormatter.format(amount: amount))"
        case .allCaughtUp:
            return "No urgent tasks or payments"
        }
    }

    var actionTitle: String? {
        switch self {
        case .overdueChore, .dueToday:
            return "View Chore"
        case .overduePayment:
            return "Settle Up"
        case .allCaughtUp:
            return nil
        }
    }
}

// MARK: - What's Next Card

struct WhatsNextCard: View {
    let item: WhatsNextItemType
    let onTap: () -> Void

    var body: some View {
        HomiCard(shadowStyle: .medium) {
            HStack(spacing: Constants.Spacing.medium) {
                // Icon
                ZStack {
                    Circle()
                        .fill(item.iconColor.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: item.icon)
                        .font(.system(size: 24))
                        .foregroundColor(item.iconColor)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(Constants.Typography.headline)
                        .foregroundColor(Constants.Colors.textPrimary)
                        .lineLimit(1)

                    Text(item.subtitle)
                        .font(Constants.Typography.subheadline)
                        .foregroundColor(Constants.Colors.textSecondary)
                }

                Spacer()

                // Action indicator
                if item.actionTitle != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Constants.Colors.textSecondary)
                }
            }
            .padding(Constants.Spacing.cardPadding)
            .contentShape(Rectangle())
        }
        .onTapGesture {
            if item.actionTitle != nil {
                HapticManager.selection()
                onTap()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: Constants.Spacing.medium) {
        WhatsNextCard(
            item: .overdueChore(Chore(
                houseId: "house1",
                title: "Take out trash",
                description: "Take trash bins to curb",
                assignedTo: "user1",
                assignedToName: "John",
                createdBy: "user1",
                dueDate: Date().addingTimeInterval(-86400),
                category: .cleaning
            )),
            onTap: {}
        )

        WhatsNextCard(
            item: .dueToday(Chore(
                houseId: "house1",
                title: "Vacuum living room",
                description: "Vacuum the living room carpet",
                assignedTo: "user1",
                assignedToName: "John",
                createdBy: "user1",
                dueDate: Date(),
                category: .cleaning
            )),
            onTap: {}
        )

        WhatsNextCard(
            item: .overduePayment(amount: 45.50, person: "Sarah"),
            onTap: {}
        )

        WhatsNextCard(
            item: .allCaughtUp,
            onTap: {}
        )
    }
    .padding()
}
