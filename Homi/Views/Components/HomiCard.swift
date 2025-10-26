import SwiftUI

// MARK: - Card Shadow Style

enum CardShadowStyle {
    case none
    case subtle
    case medium
    case elevated
}

// MARK: - Homi Card Component

struct HomiCard<Content: View>: View {
    let shadowStyle: CardShadowStyle
    let content: Content

    init(
        shadowStyle: CardShadowStyle = .subtle,
        @ViewBuilder content: () -> Content
    ) {
        self.shadowStyle = shadowStyle
        self.content = content()
    }

    var body: some View {
        content
            .background(Constants.Colors.cardBackground)
            .cornerRadius(Constants.CornerRadius.card)
            .applyShadow(shadowStyle)
    }
}

// MARK: - Shadow View Modifier

struct CardShadowModifier: ViewModifier {
    let shadowStyle: CardShadowStyle

    func body(content: Content) -> some View {
        switch shadowStyle {
        case .none:
            content

        case .subtle:
            content
                .shadow(
                    color: Constants.Shadow.subtle.color,
                    radius: Constants.Shadow.subtle.radius,
                    x: Constants.Shadow.subtle.x,
                    y: Constants.Shadow.subtle.y
                )

        case .medium:
            content
                .shadow(
                    color: Constants.Shadow.medium.color,
                    radius: Constants.Shadow.medium.radius,
                    x: Constants.Shadow.medium.x,
                    y: Constants.Shadow.medium.y
                )

        case .elevated:
            content
                .shadow(
                    color: Constants.Shadow.elevated.color,
                    radius: Constants.Shadow.elevated.radius,
                    x: Constants.Shadow.elevated.x,
                    y: Constants.Shadow.elevated.y
                )
        }
    }
}

extension View {
    func applyShadow(_ style: CardShadowStyle) -> some View {
        modifier(CardShadowModifier(shadowStyle: style))
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: Constants.Spacing.large) {
            HomiCard(shadowStyle: .none) {
                VStack(alignment: .leading, spacing: Constants.Spacing.small) {
                    Text("No Shadow Card")
                        .font(Constants.Typography.headline)

                    Text("This card has no shadow")
                        .font(Constants.Typography.subheadline)
                        .foregroundColor(Constants.Colors.textSecondary)
                }
                .padding(Constants.Spacing.cardPadding)
            }

            HomiCard(shadowStyle: .subtle) {
                VStack(alignment: .leading, spacing: Constants.Spacing.small) {
                    Text("Subtle Shadow Card")
                        .font(Constants.Typography.headline)

                    Text("This card has a subtle shadow (default)")
                        .font(Constants.Typography.subheadline)
                        .foregroundColor(Constants.Colors.textSecondary)
                }
                .padding(Constants.Spacing.cardPadding)
            }

            HomiCard(shadowStyle: .medium) {
                VStack(alignment: .leading, spacing: Constants.Spacing.small) {
                    Text("Medium Shadow Card")
                        .font(Constants.Typography.headline)

                    Text("This card has a medium shadow")
                        .font(Constants.Typography.subheadline)
                        .foregroundColor(Constants.Colors.textSecondary)
                }
                .padding(Constants.Spacing.cardPadding)
            }

            HomiCard(shadowStyle: .elevated) {
                VStack(alignment: .leading, spacing: Constants.Spacing.small) {
                    Text("Elevated Shadow Card")
                        .font(Constants.Typography.headline)

                    Text("This card has an elevated shadow (for modals)")
                        .font(Constants.Typography.subheadline)
                        .foregroundColor(Constants.Colors.textSecondary)
                }
                .padding(Constants.Spacing.cardPadding)
            }
        }
        .padding()
    }
}
