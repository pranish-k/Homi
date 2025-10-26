import SwiftUI

// MARK: - Button Style Enum

enum HomiButtonStyle {
    case primary
    case secondary
    case outline
    case destructive
    case ghost
}

// MARK: - Homi Button Component

struct HomiButton: View {
    let title: String
    let icon: String?
    let style: HomiButtonStyle
    let isLoading: Bool
    let action: () -> Void

    @State private var isPressed = false

    init(
        _ title: String,
        icon: String? = nil,
        style: HomiButtonStyle = .primary,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: {
            HapticManager.impact(style: .light)
            action()
        }) {
            HStack(spacing: Constants.Spacing.xSmall) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: textColor))
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: Constants.ButtonStyle.iconSize, weight: .semibold))
                    }

                    Text(title)
                        .font(Constants.Typography.headline)
                }
            }
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity)
            .frame(height: Constants.ButtonStyle.height)
            .background(backgroundColor)
            .cornerRadius(Constants.CornerRadius.button)
            .overlay(
                RoundedRectangle(cornerRadius: Constants.CornerRadius.button)
                    .stroke(borderColor, lineWidth: style == .outline ? 1.5 : 0)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isLoading)
    }

    // MARK: - Style Properties

    private var backgroundColor: Color {
        switch style {
        case .primary:
            return Constants.Colors.primary
        case .secondary:
            return Constants.Colors.primaryLight
        case .outline:
            return Color.clear
        case .destructive:
            return Constants.Colors.danger
        case .ghost:
            return Color.clear
        }
    }

    private var textColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return Constants.Colors.primary
        case .outline:
            return Constants.Colors.primary
        case .destructive:
            return .white
        case .ghost:
            return Constants.Colors.textPrimary
        }
    }

    private var borderColor: Color {
        switch style {
        case .outline:
            return Constants.Colors.primary
        default:
            return Color.clear
        }
    }
}

// MARK: - Scale Button Style (Press Animation)

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(Constants.Animation.buttonPress, value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: Constants.Spacing.medium) {
        HomiButton("Primary Button", icon: "checkmark", style: .primary) {}

        HomiButton("Secondary Button", style: .secondary) {}

        HomiButton("Outline Button", style: .outline) {}

        HomiButton("Destructive Button", icon: "trash", style: .destructive) {}

        HomiButton("Ghost Button", style: .ghost) {}

        HomiButton("Loading", style: .primary, isLoading: true) {}
    }
    .padding()
}
