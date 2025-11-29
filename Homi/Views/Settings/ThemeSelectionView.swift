import SwiftUI

struct ThemeSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Constants.Spacing.large) {
                    // Theme Mode Section
                    VStack(alignment: .leading, spacing: Constants.Spacing.small) {
                        Text("Theme Mode")
                            .font(Constants.Typography.subheadline)
                            .foregroundColor(Constants.Colors.textSecondary)
                            .padding(.horizontal, Constants.Spacing.screenPadding)

                        HomiCard(shadowStyle: .subtle) {
                            VStack(spacing: 0) {
                                ForEach(Array(ThemeMode.allCases.enumerated()), id: \.element) { index, mode in
                                    Button(action: {
                                        themeManager.setThemeMode(mode)
                                        HapticManager.selection()
                                    }) {
                                        HStack(spacing: Constants.Spacing.medium) {
                                            Image(systemName: mode == .light ? "sun.max.fill" : "moon.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(Constants.Colors.primary)
                                                .frame(width: 28)

                                            Text(mode.displayName)
                                                .font(Constants.Typography.body)
                                                .foregroundColor(Constants.Colors.textPrimary)

                                            Spacer()

                                            if themeManager.themeMode == mode {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 20))
                                                    .foregroundColor(Constants.Colors.primary)
                                            }
                                        }
                                        .padding(Constants.Spacing.cardPadding)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(PlainButtonStyle())

                                    if index < ThemeMode.allCases.count - 1 {
                                        Divider()
                                            .padding(.leading, Constants.Spacing.screenPadding + 44)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, Constants.Spacing.screenPadding)
                    }

                    // Color Section
                    VStack(alignment: .leading, spacing: Constants.Spacing.small) {
                        Text("Color")
                            .font(Constants.Typography.subheadline)
                            .foregroundColor(Constants.Colors.textSecondary)
                            .padding(.horizontal, Constants.Spacing.screenPadding)

                        VStack(spacing: Constants.Spacing.medium) {
                            ForEach(AppTheme.allThemes) { theme in
                                ThemeOptionCard(
                                    theme: theme,
                                    isSelected: themeManager.currentTheme.id == theme.id,
                                    onSelect: {
                                        themeManager.setTheme(theme)
                                        HapticManager.selection()
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, Constants.Spacing.screenPadding)
                    }

                    Spacer()
                }
                .padding(.top, Constants.Spacing.medium)
            }
            .navigationTitle("Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Constants.Colors.primary)
                }
            }
        }
    }
}

// MARK: - Theme Option Card

struct ThemeOptionCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HomiCard(shadowStyle: isSelected ? .medium : .subtle) {
                HStack(spacing: Constants.Spacing.medium) {
                    // Theme Color Preview
                    VStack(spacing: 8) {
                        Circle()
                            .fill(theme.primaryColor)
                            .frame(width: 50, height: 50)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                            .shadow(color: theme.primaryColor.opacity(0.3), radius: 8)

                        // Color dots
                        HStack(spacing: 4) {
                            Circle()
                                .fill(theme.primaryColor)
                                .frame(width: 8, height: 8)

                            Circle()
                                .fill(theme.primaryColor.opacity(0.6))
                                .frame(width: 8, height: 8)

                            Circle()
                                .fill(theme.primaryColor.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }

                    // Theme Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(theme.name)
                            .font(Constants.Typography.headline)
                            .foregroundColor(Constants.Colors.textPrimary)

                        Text("App theme")
                            .font(Constants.Typography.subheadline)
                            .foregroundColor(Constants.Colors.textSecondary)
                    }

                    Spacer()

                    // Selection Indicator
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(theme.primaryColor)
                    }
                }
                .padding(Constants.Spacing.cardPadding)
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    ThemeSelectionView()
}
