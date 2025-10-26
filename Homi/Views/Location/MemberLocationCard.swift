import SwiftUI

// MARK: - Member Location Card

struct MemberLocationCard: View {
    let location: UserLocation
    let isCurrentUser: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.selection()
            onTap()
        }) {
            HomiCard(shadowStyle: .subtle) {
                VStack(spacing: Constants.Spacing.small) {
                    // Avatar
                    ZStack(alignment: .bottomTrailing) {
                        if let photoURL = location.userPhotoURL, let url = URL(string: photoURL) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Circle()
                                    .fill(Color(UIColor.systemGray4))
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(Constants.Colors.textSecondary)
                                    )
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color(UIColor.systemGray4))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.title2)
                                        .foregroundColor(Constants.Colors.textSecondary)
                                )
                        }

                        // Active indicator
                        if location.isRecent {
                            Circle()
                                .fill(Constants.Colors.success)
                                .frame(width: 16, height: 16)
                                .overlay(
                                    Circle()
                                        .stroke(Constants.Colors.cardBackground, lineWidth: 2)
                                )
                        }
                    }

                    // Name
                    Text(isCurrentUser ? "You" : location.userName)
                        .font(Constants.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Constants.Colors.textPrimary)
                        .lineLimit(1)

                    // Last seen
                    HStack(spacing: 4) {
                        Image(systemName: locationStatusIcon)
                            .font(Constants.Typography.caption2)
                            .foregroundColor(locationStatusColor)

                        Text(location.lastSeenText)
                            .font(Constants.Typography.caption1)
                            .foregroundColor(Constants.Colors.textSecondary)
                    }
                }
                .frame(width: 100)
                .padding(Constants.Spacing.small)
                .overlay(
                    RoundedRectangle(cornerRadius: Constants.CornerRadius.card)
                        .stroke(
                            isCurrentUser ? Constants.Colors.primary.opacity(0.5) : Color.clear,
                            lineWidth: 2
                        )
                )
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Helpers

    private var locationStatusIcon: String {
        if location.isRecent {
            return "location.fill"
        } else if location.isStale {
            return "location.slash.fill"
        } else {
            return "clock.fill"
        }
    }

    private var locationStatusColor: Color {
        if location.isRecent {
            return Constants.Colors.success
        } else if location.isStale {
            return Constants.Colors.textSecondary
        } else {
            return Constants.Colors.warning
        }
    }
}

// MARK: - Preview

#Preview {
    HStack {
        MemberLocationCard(
            location: UserLocation.sample,
            isCurrentUser: false,
            onTap: {}
        )

        MemberLocationCard(
            location: UserLocation(
                userId: "user2",
                userName: "Current User",
                latitude: 37.7749,
                longitude: -122.4194,
                timestamp: Date(),
                isSharingEnabled: true
            ),
            isCurrentUser: true,
            onTap: {}
        )
    }
    .padding()
}
