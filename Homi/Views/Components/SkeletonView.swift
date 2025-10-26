import SwiftUI

// MARK: - Skeleton View Component

struct SkeletonView: View {
    let height: CGFloat
    let cornerRadius: CGFloat

    @State private var animating = false

    init(height: CGFloat = 20, cornerRadius: CGFloat = 8) {
        self.height = height
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Constants.Colors.tertiaryBackground,
                        Constants.Colors.tertiaryBackground.opacity(0.6),
                        Constants.Colors.tertiaryBackground
                    ]),
                    startPoint: animating ? .leading : .trailing,
                    endPoint: animating ? .trailing : .leading
                )
            )
            .frame(height: height)
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                ) {
                    animating.toggle()
                }
            }
    }
}

// MARK: - Skeleton Card (Common Pattern)

struct SkeletonCard: View {
    var body: some View {
        HomiCard {
            VStack(alignment: .leading, spacing: Constants.Spacing.small) {
                SkeletonView(height: 24, cornerRadius: 6)
                    .frame(width: 150)

                SkeletonView(height: 16, cornerRadius: 4)
                    .frame(width: 200)

                SkeletonView(height: 16, cornerRadius: 4)
                    .frame(width: 100)
            }
            .padding(Constants.Spacing.cardPadding)
        }
    }
}

// MARK: - Skeleton List Item

struct SkeletonListItem: View {
    var body: some View {
        HStack(spacing: Constants.Spacing.medium) {
            // Avatar skeleton
            Circle()
                .fill(Constants.Colors.tertiaryBackground)
                .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 8) {
                SkeletonView(height: 18, cornerRadius: 4)
                    .frame(width: 120)

                SkeletonView(height: 14, cornerRadius: 4)
                    .frame(width: 180)
            }

            Spacer()
        }
        .padding(Constants.Spacing.medium)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: Constants.Spacing.large) {
        Text("Skeleton Views")
            .font(Constants.Typography.title2)

        SkeletonView(height: 40)
        SkeletonView(height: 20)
        SkeletonView(height: 16)

        Divider()

        Text("Skeleton Card")
            .font(Constants.Typography.title2)

        SkeletonCard()

        Divider()

        Text("Skeleton List Items")
            .font(Constants.Typography.title2)

        VStack(spacing: 0) {
            SkeletonListItem()
            Divider()
            SkeletonListItem()
            Divider()
            SkeletonListItem()
        }
        .background(Constants.Colors.cardBackground)
        .cornerRadius(Constants.CornerRadius.card)
    }
    .padding()
}
