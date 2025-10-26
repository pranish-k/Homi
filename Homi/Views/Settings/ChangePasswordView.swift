import SwiftUI
import FirebaseAuth

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""

    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Constants.Spacing.large) {
                    // Instructions
                    Text("Enter your current password and choose a new one. Your new password must be at least 8 characters long.")
                        .font(Constants.Typography.subheadline)
                        .foregroundColor(Constants.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Constants.Spacing.screenPadding)
                        .padding(.top, Constants.Spacing.medium)

                    // Form
                    VStack(spacing: Constants.Spacing.medium) {
                        HomiTextField(
                            "Current Password",
                            placeholder: "Enter current password",
                            icon: "lock",
                            style: .password,
                            text: $currentPassword
                        )

                        HomiTextField(
                            "New Password",
                            placeholder: "Enter new password",
                            icon: "lock.fill",
                            style: .password,
                            text: $newPassword,
                            errorMessage: newPasswordError
                        )

                        HomiTextField(
                            "Confirm New Password",
                            placeholder: "Re-enter new password",
                            icon: "lock.fill",
                            style: .password,
                            text: $confirmPassword,
                            errorMessage: confirmPasswordError
                        )
                    }
                    .padding(.horizontal, Constants.Spacing.screenPadding)

                    // Error Message
                    if let errorMessage = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 16))

                            Text(errorMessage)
                                .font(Constants.Typography.subheadline)
                        }
                        .foregroundColor(Constants.Colors.danger)
                        .padding(.horizontal, Constants.Spacing.screenPadding)
                    }

                    // Change Password Button
                    HomiButton(
                        "Change Password",
                        icon: "key.fill",
                        style: .primary,
                        isLoading: isLoading
                    ) {
                        changePassword()
                    }
                    .padding(.horizontal, Constants.Spacing.screenPadding)
                    .padding(.top, Constants.Spacing.medium)
                    .disabled(!isFormValid)

                    Spacer()
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Constants.Colors.primary)
                }
            }
            .alert("Password Changed", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your password has been successfully changed.")
            }
        }
    }

    // MARK: - Computed Properties

    private var isFormValid: Bool {
        !currentPassword.isEmpty &&
        !newPassword.isEmpty &&
        !confirmPassword.isEmpty &&
        newPassword.count >= Constants.Validation.minPasswordLength &&
        newPassword == confirmPassword
    }

    private var newPasswordError: String? {
        guard !newPassword.isEmpty else { return nil }

        if newPassword.count < Constants.Validation.minPasswordLength {
            return "Password must be at least \(Constants.Validation.minPasswordLength) characters"
        }
        return nil
    }

    private var confirmPasswordError: String? {
        guard !confirmPassword.isEmpty else { return nil }

        if confirmPassword != newPassword {
            return "Passwords don't match"
        }
        return nil
    }

    // MARK: - Change Password

    private func changePassword() {
        guard let user = Auth.auth().currentUser,
              let email = user.email else {
            errorMessage = "Unable to verify user"
            return
        }

        isLoading = true
        errorMessage = nil

        // Re-authenticate user with current password
        let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)

        user.reauthenticate(with: credential) { _, error in
            if let error = error {
                isLoading = false
                errorMessage = "Current password is incorrect"
                HapticManager.error()
                return
            }

            // Update password
            user.updatePassword(to: newPassword) { error in
                isLoading = false

                if let error = error {
                    errorMessage = error.localizedDescription
                    HapticManager.error()
                } else {
                    HapticManager.success()
                    showSuccess = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ChangePasswordView()
}
