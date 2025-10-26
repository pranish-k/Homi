import SwiftUI

// MARK: - Homi Empty State Component

struct HomiEmptyState: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: Constants.Spacing.large) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(Constants.Colors.textSecondary.opacity(0.5))

            // Text Content
            VStack(spacing: Constants.Spacing.xSmall) {
                Text(title)
                    .font(Constants.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(Constants.Colors.textPrimary)

                Text(message)
                    .font(Constants.Typography.body)
                    .foregroundColor(Constants.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Action Button
            if let actionTitle = actionTitle, let action = action {
                HomiButton(actionTitle, style: .secondary, action: action)
                    .frame(maxWidth: 200)
            }
        }
        .padding(Constants.Spacing.xLarge)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: Constants.Spacing.xxLarge) {
        // Without action
        HomiEmptyState(
            icon: "tray",
            title: "No Expenses Yet",
            message: "Add your first expense to start tracking your shared costs with your housemates."
        )

        Divider()

        // With action
        HomiEmptyState(
            icon: "message",
            title: "No Messages",
            message: "Send a message to start chatting with your housemates.",
            actionTitle: "Send Message",
            action: {
                print("Action tapped")
            }
        )
    }
}
