import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("pushNotificationsEnabled") private var pushNotificationsEnabled = true
    @AppStorage("nudgeNotificationsEnabled") private var nudgeNotificationsEnabled = true
    @AppStorage("quietHoursEnabled") private var quietHoursEnabled = false
    @AppStorage("quietHoursStart") private var quietHoursStart = 22 // 10 PM
    @AppStorage("quietHoursEnd") private var quietHoursEnd = 8 // 8 AM

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        NavigationStack {
            List {
                // Push Notifications Section
                Section {
                    Toggle(isOn: $pushNotificationsEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Push Notifications")
                                .font(Constants.Typography.body)

                            Text("Receive notifications for messages, chores, and expenses")
                                .font(Constants.Typography.caption1)
                                .foregroundColor(Constants.Colors.textSecondary)
                        }
                    }
                    .tint(Constants.Colors.primary)
                    .onChange(of: pushNotificationsEnabled) { _, newValue in
                        if newValue {
                            requestNotificationPermission()
                        }
                    }

                    if notificationStatus == .denied {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Constants.Colors.warning)

                            Text("Notifications are disabled in Settings")
                                .font(Constants.Typography.caption1)
                                .foregroundColor(Constants.Colors.textSecondary)
                        }
                    }
                } header: {
                    Text("Notifications")
                }

                // Nudge Settings Section
                Section {
                    Toggle(isOn: $nudgeNotificationsEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Nudge Notifications")
                                .font(Constants.Typography.body)

                            Text("Allow housemates to send you friendly reminders")
                                .font(Constants.Typography.caption1)
                                .foregroundColor(Constants.Colors.textSecondary)
                        }
                    }
                    .tint(Constants.Colors.primary)
                    .disabled(!pushNotificationsEnabled)
                } header: {
                    Text("Nudges")
                } footer: {
                    Text("Nudges are gentle reminders from housemates about overdue chores or unpaid expenses.")
                }

                // Quiet Hours Section
                Section {
                    Toggle(isOn: $quietHoursEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Quiet Hours")
                                .font(Constants.Typography.body)

                            Text("Mute nudge notifications during specific hours")
                                .font(Constants.Typography.caption1)
                                .foregroundColor(Constants.Colors.textSecondary)
                        }
                    }
                    .tint(Constants.Colors.primary)
                    .disabled(!nudgeNotificationsEnabled || !pushNotificationsEnabled)

                    if quietHoursEnabled {
                        HStack {
                            Text("Start Time")
                            Spacer()
                            Text(formatHour(quietHoursStart))
                                .foregroundColor(Constants.Colors.textSecondary)
                        }

                        HStack {
                            Text("End Time")
                            Spacer()
                            Text(formatHour(quietHoursEnd))
                                .foregroundColor(Constants.Colors.textSecondary)
                        }
                    }
                } header: {
                    Text("Do Not Disturb")
                } footer: {
                    if quietHoursEnabled {
                        Text("Nudge notifications will be muted from \(formatHour(quietHoursStart)) to \(formatHour(quietHoursEnd)).")
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Constants.Colors.primary)
                }
            }
            .onAppear {
                checkNotificationStatus()
            }
        }
    }

    // MARK: - Helper Methods

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:00 a"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }

    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationStatus = settings.authorizationStatus
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    notificationStatus = .authorized
                } else {
                    pushNotificationsEnabled = false
                    notificationStatus = .denied
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NotificationSettingsView()
}
