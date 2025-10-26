import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let isFromCurrentUser: Bool
    let showAvatar: Bool
    var onDelete: (() -> Void)?

    @State private var showTimestamp = false

    var body: some View {
        HStack(alignment: .bottom, spacing: Constants.Spacing.small) {
            if !isFromCurrentUser && showAvatar {
                // Avatar
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .overlay {
                        if let photoUrl = message.senderPhoto, !photoUrl.isEmpty {
                            // AsyncImage for profile photo
                            AsyncImage(url: URL(string: photoUrl)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Text(message.senderName.prefix(1).uppercased())
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            .clipShape(Circle())
                        } else {
                            Text(message.senderName.prefix(1).uppercased())
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
            } else if !isFromCurrentUser {
                // Spacer to align non-avatar messages
                Color.clear.frame(width: 32, height: 32)
            }

            if isFromCurrentUser {
                Spacer(minLength: 60)
            }

            // Message bubble
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: Constants.Spacing.xxSmall) {
                if !isFromCurrentUser && showAvatar {
                    Text(message.senderName)
                        .font(.caption2)
                        .foregroundColor(Constants.Colors.textSecondary)
                        .padding(.leading, Constants.Spacing.small)
                }

                if message.type == .system {
                    systemMessageView
                } else {
                    regularMessageView
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showTimestamp.toggle()
                            }
                        }
                }

                // Timestamp (only shown when tapped)
                if showTimestamp && message.type != .system {
                    Text(message.formattedTime)
                        .font(.caption2)
                        .foregroundColor(Constants.Colors.textSecondary)
                        .padding(isFromCurrentUser ? .trailing : .leading, Constants.Spacing.small)
                        .transition(.opacity)
                }
            }

            if !isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
        .contextMenu {
            if isFromCurrentUser && message.type != .system {
                Button(role: .destructive) {
                    onDelete?()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private var systemMessageView: some View {
        Text(message.content)
            .font(.caption)
            .foregroundColor(Constants.Colors.textSecondary)
            .padding(.horizontal, Constants.Spacing.medium)
            .padding(.vertical, Constants.Spacing.small)
            .background(Color(.systemGray6))
            .cornerRadius(Constants.CornerRadius.medium)
    }

    private var regularMessageView: some View {
        Text(message.content)
            .font(.body)
            .foregroundColor(isFromCurrentUser ? .white : Constants.Colors.textPrimary)
            .padding(.horizontal, Constants.Spacing.medium)
            .padding(.vertical, Constants.Spacing.small)
            .background(isFromCurrentUser ? Constants.Colors.primary : Color(.systemGray5))
            .cornerRadius(Constants.CornerRadius.medium)
            .cornerRadius(Constants.CornerRadius.medium, corners: isFromCurrentUser ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight])
    }
}

// MARK: - Custom Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        // Validate rect to prevent NaN errors in CoreGraphics
        guard rect.width.isFinite && rect.height.isFinite &&
              !rect.width.isNaN && !rect.height.isNaN &&
              rect.width >= 0 && rect.height >= 0 else {
            return Path()
        }

        // Ensure radius is valid
        let validRadius = radius.isFinite && !radius.isNaN ? radius : 0

        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: validRadius, height: validRadius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Preview
struct MessageBubbleView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: Constants.Spacing.medium) {
            MessageBubbleView(
                message: Message.sampleMessages[0],
                isFromCurrentUser: false,
                showAvatar: true
            )

            MessageBubbleView(
                message: Message.sampleMessages[1],
                isFromCurrentUser: true,
                showAvatar: false
            )

            MessageBubbleView(
                message: Message(
                    content: "Alice joined the house",
                    senderId: "system",
                    senderName: "System",
                    type: .system
                ),
                isFromCurrentUser: false,
                showAvatar: false
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
