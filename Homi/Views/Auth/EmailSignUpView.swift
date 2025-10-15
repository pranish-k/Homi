import SwiftUI

struct EmailSignUpView: View {
    @ObservedObject var viewModel: AuthViewModel
    @FocusState private var focusedField: Field?
    @State private var showPassword = false
    @State private var showConfirmPassword = false

    enum Field {
        case name, email, password, confirmPassword
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: Constants.Spacing.small) {
                HStack {
                    Button(action: {
                        viewModel.navigateBack()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(Constants.Colors.textPrimary)
                    }

                    Spacer()
                }

                Text(viewModel.currentAuthStep == .emailSignUp ? "Create Account" : "Welcome Back")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Constants.Spacing.medium)

                Text(viewModel.currentAuthStep == .emailSignUp ? "Sign up to get started" : "Sign in to continue")
                    .font(.body)
                    .foregroundColor(Constants.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, Constants.Spacing.large)
            .padding(.top, Constants.Spacing.medium)

            ScrollView {
                VStack(spacing: Constants.Spacing.large) {
                    if viewModel.currentAuthStep == .emailSignUp {
                        signUpFields
                    } else {
                        signInFields
                    }

                    // Submit Button
                    Button(action: {
                        Task {
                            if viewModel.currentAuthStep == .emailSignUp {
                                await viewModel.signUpWithEmail()
                            } else {
                                await viewModel.signInWithEmail()
                            }
                        }
                    }) {
                        Text(viewModel.currentAuthStep == .emailSignUp ? "Create Account" : "Sign In")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Constants.Colors.primary)
                            .cornerRadius(Constants.CornerRadius.medium)
                    }
                    .disabled(!isFormValid)
                    .opacity(isFormValid ? 1 : 0.6)

                    if viewModel.currentAuthStep == .emailSignIn {
                        // Forgot Password
                        Button(action: {
                            Task {
                                await viewModel.sendPasswordReset()
                            }
                        }) {
                            Text("Forgot Password?")
                                .font(.subheadline)
                                .foregroundColor(Constants.Colors.primary)
                        }
                    }

                    // Toggle between Sign In and Sign Up
                    Button(action: {
                        withAnimation {
                            if viewModel.currentAuthStep == .emailSignUp {
                                viewModel.currentAuthStep = .emailSignIn
                            } else {
                                viewModel.currentAuthStep = .emailSignUp
                            }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text(viewModel.currentAuthStep == .emailSignUp ? "Already have an account?" : "Don't have an account?")
                                .foregroundColor(Constants.Colors.textSecondary)

                            Text(viewModel.currentAuthStep == .emailSignUp ? "Sign In" : "Sign Up")
                                .foregroundColor(Constants.Colors.primary)
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                    }
                    .padding(.top, Constants.Spacing.small)
                }
                .padding(.horizontal, Constants.Spacing.large)
                .padding(.vertical, Constants.Spacing.xLarge)
            }
        }
        .background(Color(.systemBackground))
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .overlay {
            if viewModel.isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    }
            }
        }
        .onAppear {
            focusedField = viewModel.currentAuthStep == .emailSignUp ? .name : .email
        }
    }

    // MARK: - Sign Up Fields

    private var signUpFields: some View {
        VStack(spacing: Constants.Spacing.large) {
            // Full Name
            VStack(alignment: .leading, spacing: Constants.Spacing.small) {
                Text("Full Name")
                    .font(.caption)
                    .foregroundColor(Constants.Colors.textSecondary)

                TextField("John Doe", text: $viewModel.fullName)
                    .textContentType(.name)
                    .autocapitalization(.words)
                    .focused($focusedField, equals: .name)
                    .padding(.horizontal, Constants.Spacing.medium)
                    .frame(height: 56)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(Constants.CornerRadius.small)
            }

            // Email
            VStack(alignment: .leading, spacing: Constants.Spacing.small) {
                Text("Email")
                    .font(.caption)
                    .foregroundColor(Constants.Colors.textSecondary)

                TextField("john@example.com", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .focused($focusedField, equals: .email)
                    .padding(.horizontal, Constants.Spacing.medium)
                    .frame(height: 56)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(Constants.CornerRadius.small)
            }

            // Password
            VStack(alignment: .leading, spacing: Constants.Spacing.small) {
                Text("Password")
                    .font(.caption)
                    .foregroundColor(Constants.Colors.textSecondary)

                HStack {
                    if showPassword {
                        TextField("Password", text: $viewModel.password)
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .password)
                    } else {
                        SecureField("Password", text: $viewModel.password)
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .password)
                    }

                    Button(action: {
                        showPassword.toggle()
                    }) {
                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(Constants.Colors.textSecondary)
                    }
                }
                .padding(.horizontal, Constants.Spacing.medium)
                .frame(height: 56)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(Constants.CornerRadius.small)

                Text("At least 8 characters")
                    .font(.caption2)
                    .foregroundColor(viewModel.password.count >= 8 ? Constants.Colors.success : Constants.Colors.textSecondary)
            }

            // Confirm Password
            VStack(alignment: .leading, spacing: Constants.Spacing.small) {
                Text("Confirm Password")
                    .font(.caption)
                    .foregroundColor(Constants.Colors.textSecondary)

                HStack {
                    if showConfirmPassword {
                        TextField("Confirm Password", text: $viewModel.confirmPassword)
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .confirmPassword)
                    } else {
                        SecureField("Confirm Password", text: $viewModel.confirmPassword)
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .confirmPassword)
                    }

                    Button(action: {
                        showConfirmPassword.toggle()
                    }) {
                        Image(systemName: showConfirmPassword ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(Constants.Colors.textSecondary)
                    }
                }
                .padding(.horizontal, Constants.Spacing.medium)
                .frame(height: 56)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(Constants.CornerRadius.small)

                if !viewModel.confirmPassword.isEmpty && viewModel.password != viewModel.confirmPassword {
                    Text("Passwords don't match")
                        .font(.caption2)
                        .foregroundColor(Constants.Colors.danger)
                }
            }
        }
    }

    // MARK: - Sign In Fields

    private var signInFields: some View {
        VStack(spacing: Constants.Spacing.large) {
            // Email
            VStack(alignment: .leading, spacing: Constants.Spacing.small) {
                Text("Email")
                    .font(.caption)
                    .foregroundColor(Constants.Colors.textSecondary)

                TextField("john@example.com", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .focused($focusedField, equals: .email)
                    .padding(.horizontal, Constants.Spacing.medium)
                    .frame(height: 56)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(Constants.CornerRadius.small)
            }

            // Password
            VStack(alignment: .leading, spacing: Constants.Spacing.small) {
                Text("Password")
                    .font(.caption)
                    .foregroundColor(Constants.Colors.textSecondary)

                HStack {
                    if showPassword {
                        TextField("Password", text: $viewModel.password)
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                    } else {
                        SecureField("Password", text: $viewModel.password)
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                    }

                    Button(action: {
                        showPassword.toggle()
                    }) {
                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(Constants.Colors.textSecondary)
                    }
                }
                .padding(.horizontal, Constants.Spacing.medium)
                .frame(height: 56)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(Constants.CornerRadius.small)
            }
        }
    }

    private var isFormValid: Bool {
        if viewModel.currentAuthStep == .emailSignUp {
            return !viewModel.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !viewModel.email.isEmpty &&
                   viewModel.password.count >= 8 &&
                   viewModel.password == viewModel.confirmPassword
        } else {
            return !viewModel.email.isEmpty && !viewModel.password.isEmpty
        }
    }
}