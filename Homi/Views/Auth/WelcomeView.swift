import SwiftUI

struct WelcomeView: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo and App Name
            VStack(spacing: Constants.Spacing.large) {
                Image(systemName: "house.fill")
                    .font(.system(size: 80))
                    .foregroundColor(Constants.Colors.primary)
                    .padding(.bottom, Constants.Spacing.small)

                Text("Homi")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(Constants.Colors.textPrimary)

                Text("Living together, made easy")
                    .font(.title3)
                    .foregroundColor(Constants.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Constants.Spacing.xLarge)

            Spacer()

            // Bottom Section
            VStack(spacing: Constants.Spacing.medium) {
                // Get Started Button
                Button(action: {
                    viewModel.navigateToAuthOptions()
                }) {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Constants.Colors.primary)
                        .cornerRadius(Constants.CornerRadius.medium)
                }

                // Sign In Link
                Button(action: {
                    viewModel.currentAuthStep = .authOptions
                }) {
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .foregroundColor(Constants.Colors.textSecondary)

                        Text("Sign In")
                            .foregroundColor(Constants.Colors.primary)
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                }
                .padding(.top, Constants.Spacing.small)
            }
            .padding(.horizontal, Constants.Spacing.large)
            .padding(.bottom, 50)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.white,
                    Constants.Colors.background
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}