import SwiftUI

// MARK: - Badge Style

enum HomiBadgeStyle {
    case primary
    case success
    case warning
    case danger
    case neutral
}

// MARK: - Badge Size

enum HomiBadgeSize {
    case small
    case medium
    case large

    var fontSize: Font {
        switch self {
        case .small:
            return Constants.Typography.caption2
        case .medium:
            return Constants.Typography.caption1
        case .large:
            return Constants.Typography.footnote
        }
    }

    var padding: EdgeInsets {
        switch self {
        case .small:
            return EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6)
        case .medium:
            return EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
        case .large:
            return EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        }
    }
}

// MARK: - Homi Badge Component

struct HomiBadge: View {
    let text: String
    let icon: String?
    let style: HomiBadgeStyle
    let size: HomiBadgeSize

    init(
        _ text: String,
        icon: String? = nil,
        style: HomiBadgeStyle = .primary,
        size: HomiBadgeSize = .medium
    ) {
        self.text = text
        self.icon = icon
        self.style = style
        self.size = size
    }

    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }

            Text(text)
                .font(size.fontSize)
                .fontWeight(.semibold)
        }
        .foregroundColor(textColor)
        .padding(size.padding)
        .background(backgroundColor)
        .cornerRadius(Constants.CornerRadius.badge)
    }

    // MARK: - Style Properties

    private var backgroundColor: Color {
        switch style {
        case .primary:
            return Constants.Colors.primary.opacity(0.15)
        case .success:
            return Constants.Colors.success.opacity(0.15)
        case .warning:
            return Constants.Colors.warning.opacity(0.15)
        case .danger:
            return Constants.Colors.danger.opacity(0.15)
        case .neutral:
            return Constants.Colors.tertiaryBackground
        }
    }

    private var textColor: Color {
        switch style {
        case .primary:
            return Constants.Colors.primary
        case .success:
            return Constants.Colors.success
        case .warning:
            return Constants.Colors.warning
        case .danger:
            return Constants.Colors.danger
        case .neutral:
            return Constants.Colors.textSecondary
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: Constants.Spacing.medium) {
        // Styles
        Text("Badge Styles").font(Constants.Typography.headline)

        HStack(spacing: Constants.Spacing.small) {
            HomiBadge("Primary", style: .primary)
            HomiBadge("Success", style: .success)
            HomiBadge("Warning", style: .warning)
        }

        HStack(spacing: Constants.Spacing.small) {
            HomiBadge("Danger", style: .danger)
            HomiBadge("Neutral", style: .neutral)
        }

        Divider().padding(.vertical)

        // Sizes
        Text("Badge Sizes").font(Constants.Typography.headline)

        HStack(spacing: Constants.Spacing.small) {
            HomiBadge("Small", size: .small)
            HomiBadge("Medium", size: .medium)
            HomiBadge("Large", size: .large)
        }

        Divider().padding(.vertical)

        // With Icons
        Text("With Icons").font(Constants.Typography.headline)

        HStack(spacing: Constants.Spacing.small) {
            HomiBadge("Overdue", icon: "exclamationmark", style: .danger)
            HomiBadge("Complete", icon: "checkmark", style: .success)
            HomiBadge("Pending", icon: "clock", style: .warning)
        }
    }
    .padding()
}
