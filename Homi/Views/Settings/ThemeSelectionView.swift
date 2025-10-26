import SwiftUI

struct ThemeSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Constants.Spacing.large) {
                    // Description
                    Text("Choose your preferred color theme. The theme will be applied throughout the app.")
                        .font(Constants.Typography.subheadline)
                        .foregroundColor(Constants.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Constants.Spacing.screenPadding)
                        .padding(.top, Constants.Spacing.medium)

                    // Theme Options
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

                    Spacer()
                }
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
