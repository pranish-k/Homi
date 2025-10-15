import SwiftUI

struct HouseSetupCompleteView: View {
    @ObservedObject var viewModel: HouseViewModel
    @State private var copiedToClipboard = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Success Animation
            VStack(spacing: Constants.Spacing.xLarge) {
                // Checkmark Circle
                ZStack {
                    Circle()
                        .fill(Constants.Colors.success.opacity(0.1))
                        .frame(width: 120, height: 120)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(Constants.Colors.success)
                }

                VStack(spacing: Constants.Spacing.medium) {
                    Text("All Set!")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    if let houseName = viewModel.createdHouse?.name {
                        Text("Welcome to \(houseName)")
                            .font(.title3)
                            .foregroundColor(Constants.Colors.textSecondary)
                    }
                }

                // Invite Code Section
                VStack(spacing: Constants.Spacing.medium) {
                    Text("Share this code with your housemates")
                        .font(.subheadline)
                        .foregroundColor(Constants.Colors.textSecondary)

                    // Invite Code Display
                    VStack(spacing: Constants.Spacing.small) {
                        HStack(spacing: Constants.Spacing.xSmall) {
                            ForEach(Array(viewModel.generatedInviteCode), id: \.self) { char in
                                Text(String(char))
                                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                                    .foregroundColor(Constants.Colors.primary)
                                    .frame(width: 40, height: 50)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(Constants.CornerRadius.small)
                            }
                        }

                        Button(action: {
                            UIPasteboard.general.string = viewModel.generatedInviteCode
                            copiedToClipboard = true

                            // Reset after 2 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                copiedToClipboard = false
                            }
                        }) {
                            HStack {
                                Image(systemName: copiedToClipboard ? "checkmark" : "doc.on.doc")
                                Text(copiedToClipboard ? "Copied!" : "Copy Code")
                            }
                            .font(.subheadline)
                            .foregroundColor(copiedToClipboard ? Constants.Colors.success : Constants.Colors.primary)
                        }
                    }
                    .padding(Constants.Spacing.large)
                    .background(Constants.Colors.primary.opacity(0.05))
                    .cornerRadius(Constants.CornerRadius.medium)
                }

                // Share Button
                Button(action: shareInvite) {
                    Label("Share Invite", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Constants.Colors.primary)
                        .cornerRadius(Constants.CornerRadius.medium)
                }
                .padding(.horizontal, Constants.Spacing.large)
            }
            .padding(.horizontal, Constants.Spacing.large)

            Spacer()

            // Continue Button
            VStack(spacing: Constants.Spacing.medium) {
                Button(action: {
                    // This will trigger ContentView to show MainTabView
                    // since user now has a house
                }) {
                    Text("Continue to App")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Constants.Colors.success)
                        .cornerRadius(Constants.CornerRadius.medium)
                }

                Text("You can always find the invite code in settings")
                    .font(.caption)
                    .foregroundColor(Constants.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Constants.Spacing.large)
            .padding(.bottom, Constants.Spacing.xLarge)
        }
        .background(Color(.systemBackground))
    }

    private func shareInvite() {
        let houseName = viewModel.createdHouse?.name ?? "our house"
        let message = """
        Join me on Homi! 🏠

        I've created a house called "\(houseName)" on Homi, the app for managing our shared living space.

        Use this invite code to join: \(viewModel.generatedInviteCode)

        Download Homi and let's stay organized together!
        """

        let activityVC = UIActivityViewController(
            activityItems: [message],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}