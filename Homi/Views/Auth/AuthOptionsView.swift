import SwiftUI
import AuthenticationServices

struct AuthOptionsView: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var isSignIn = false

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

                Text(isSignIn ? "Welcome Back" : "Create Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Constants.Spacing.medium)

                Text(isSignIn ? "Sign in to continue" : "Choose how you'd like to get started")
                    .font(.body)
                    .foregroundColor(Constants.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, Constants.Spacing.large)
            .padding(.top, Constants.Spacing.medium)

            ScrollView {
                VStack(spacing: Constants.Spacing.medium) {
                    // Sign in with Apple
                    SignInWithAppleButton(
                        .signIn,
                        onRequest: { request in
                            viewModel.handleSignInWithAppleRequest(request)
                        },
                        onCompletion: { result in
                            Task {
                                await viewModel.handleSignInWithAppleCompletion(result)
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 56)
                    .cornerRadius(Constants.CornerRadius.medium)

                    // Sign in with Google
                    Button(action: {
                        Task {
                            await viewModel.signInWithGoogle()
                        }
                    }) {
                        HStack {
                            Image(systemName: "globe")
                                .font(.title3)

                            Text("Continue with Google")
                                .font(.headline)

                            Spacer()
                        }
                        .foregroundColor(.primary)
                        .frame(height: 56)
                        .padding(.horizontal, Constants.Spacing.medium)
                        .background(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: Constants.CornerRadius.medium)
                                .stroke(Color(.separator), lineWidth: 1)
                        )
                    }

                    // Continue with Phone
                    Button(action: {
                        viewModel.navigateToPhoneAuth()
                    }) {
                        HStack {
                            Image(systemName: "phone.fill")
                                .font(.title3)

                            Text("Continue with Phone")
                                .font(.headline)

                            Spacer()
                        }
                        .foregroundColor(.primary)
                        .frame(height: 56)
                        .padding(.horizontal, Constants.Spacing.medium)
                        .background(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: Constants.CornerRadius.medium)
                                .stroke(Color(.separator), lineWidth: 1)
                        )
                    }

                    // Continue with Email
                    Button(action: {
                        if isSignIn {
                            viewModel.navigateToEmailSignIn()
                        } else {
                            viewModel.navigateToEmailSignUp()
                        }
                    }) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .font(.title3)

                            Text("Continue with Email")
                                .font(.headline)

                            Spacer()
                        }
                        .foregroundColor(.primary)
                        .frame(height: 56)
                        .padding(.horizontal, Constants.Spacing.medium)
                        .background(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: Constants.CornerRadius.medium)
                                .stroke(Color(.separator), lineWidth: 1)
                        )
                    }

                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color(.separator))
                            .frame(height: 1)

                        Text("or")
                            .font(.caption)
                            .foregroundColor(Constants.Colors.textSecondary)
                            .padding(.horizontal, Constants.Spacing.small)

                        Rectangle()
                            .fill(Color(.separator))
                            .frame(height: 1)
                    }
                    .padding(.vertical, Constants.Spacing.small)

                    // Toggle between Sign In and Sign Up
                    Button(action: {
                        withAnimation {
                            isSignIn.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text(isSignIn ? "Don't have an account?" : "Already have an account?")
                                .foregroundColor(Constants.Colors.textSecondary)

                            Text(isSignIn ? "Sign Up" : "Sign In")
                                .foregroundColor(Constants.Colors.primary)
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                    }

                    // Terms and Privacy
                    if !isSignIn {
                        Text("By continuing, you agree to our [Terms of Service](https://example.com/terms) and [Privacy Policy](https://example.com/privacy)")
                            .font(.caption)
                            .foregroundColor(Constants.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, Constants.Spacing.medium)
                    }
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
    }
}