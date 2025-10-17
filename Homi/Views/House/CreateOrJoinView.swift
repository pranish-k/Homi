import SwiftUI
import OSLog

struct CreateOrJoinView: View {
    @ObservedObject var viewModel: HouseViewModel
    @StateObject private var authService = AuthService.shared

    private let logger = Logger(subsystem: "com.homi.app", category: "CreateOrJoinView")

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: Constants.Spacing.medium) {
                Image(systemName: "house.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Constants.Colors.primary)
                    .padding(.top, Constants.Spacing.xxLarge)

                Text("Set Up Your House")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Create a new house or join an existing one")
                    .font(.body)
                    .foregroundColor(Constants.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Constants.Spacing.large)
            }

            Spacer()

            // Options
            VStack(spacing: Constants.Spacing.large) {
                // Create House Button
                Button(action: {
                    viewModel.navigateToCreateHouse()
                }) {
                    VStack(spacing: Constants.Spacing.medium) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(Constants.Colors.primary)

                        Text("Create a New House")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("Start fresh and invite your housemates")
                            .font(.caption)
                            .foregroundColor(Constants.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Constants.Spacing.xLarge)
                    .background(Color(.systemBackground))
                    .cornerRadius(Constants.CornerRadius.large)
                    .overlay(
                        RoundedRectangle(cornerRadius: Constants.CornerRadius.large)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
                }

                // Join House Button
                Button(action: {
                    viewModel.navigateToJoinHouse()
                }) {
                    VStack(spacing: Constants.Spacing.medium) {
                        Image(systemName: "envelope.open.fill")
                            .font(.system(size: 50))
                            .foregroundColor(Constants.Colors.success)

                        Text("Join Existing House")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("Enter an invite code from your housemates")
                            .font(.caption)
                            .foregroundColor(Constants.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Constants.Spacing.xLarge)
                    .background(Color(.systemBackground))
                    .cornerRadius(Constants.CornerRadius.large)
                    .overlay(
                        RoundedRectangle(cornerRadius: Constants.CornerRadius.large)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, Constants.Spacing.large)

            Spacer()

            // Sign Out Option
            Button(action: {
                do {
                    try authService.signOut()
                } catch {
                    logger.error("Error signing out: \(error.localizedDescription)")
                }
            }) {
                Text("Sign Out")
                    .font(.footnote)
                    .foregroundColor(Constants.Colors.textSecondary)
            }
            .padding(.bottom, Constants.Spacing.large)
        }
        .background(Color(.secondarySystemBackground))
    }
}