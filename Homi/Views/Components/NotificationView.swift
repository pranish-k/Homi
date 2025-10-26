//
//  NotificationView.swift
//  Homi
//
//  Notification center for viewing nudges and alerts
//

import SwiftUI
import FirebaseAuth

// MARK: - Notification View

struct NotificationView: View {
    @StateObject private var nudgeService = NudgeService.shared
    @StateObject private var authService = AuthService.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if nudgeService.recentNudges.isEmpty {
                    emptyStateView
                } else {
                    notificationsList
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if let userId = authService.user?.uid {
                nudgeService.startListening(userId: userId)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        HomiEmptyState(
            icon: "bell",
            title: "No Notifications",
            message: "You're all caught up! Notifications from nudges will appear here."
        )
        .padding()
    }

    // MARK: - Notifications List

    private var notificationsList: some View {
        ScrollView {
            LazyVStack(spacing: Constants.Spacing.medium) {
                ForEach(nudgeService.recentNudges) { nudge in
                    NotificationCard(nudge: nudge)
                }
            }
            .padding()
        }
    }
}

// MARK: - Notification Card

struct NotificationCard: View {
    let nudge: Nudge

    var body: some View {
        HomiCard(shadowStyle: .subtle) {
            HStack(spacing: Constants.Spacing.medium) {
                // Icon
                Image(systemName: iconName)
                    .font(.system(size: 24))
                    .foregroundColor(iconColor)
                    .frame(width: 40, height: 40)
                    .background(iconColor.opacity(0.1))
                    .clipShape(Circle())

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(nudge.notificationMessage)
                        .font(Constants.Typography.body)
                        .foregroundColor(Constants.Colors.textPrimary)
                        .lineLimit(2)

                    Text(nudge.timestamp.timeAgoDisplay)
                        .font(Constants.Typography.caption1)
                        .foregroundColor(Constants.Colors.textSecondary)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Constants.Colors.textSecondary)
            }
            .padding(Constants.Spacing.cardPadding)
        }
    }

    private var iconName: String {
        switch nudge.type {
        case .choreOverdue:
            return "checklist"
        case .paymentOverdue:
            return "dollarsign.circle.fill"
        }
    }

    private var iconColor: Color {
        switch nudge.type {
        case .choreOverdue:
            return Constants.Colors.warning
        case .paymentOverdue:
            return Constants.Colors.primary
        }
    }
}

// MARK: - Date Extension for Time Ago

extension Date {
    var timeAgoDisplay: String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day, .weekOfYear], from: self, to: now)

        if let weeks = components.weekOfYear, weeks > 0 {
            return weeks == 1 ? "1 week ago" : "\(weeks) weeks ago"
        } else if let days = components.day, days > 0 {
            return days == 1 ? "1 day ago" : "\(days) days ago"
        } else if let hours = components.hour, hours > 0 {
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        } else if let minutes = components.minute, minutes > 0 {
            return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago"
        } else {
            return "Just now"
        }
    }
}

// MARK: - Preview

#Preview {
    NotificationView()
}
