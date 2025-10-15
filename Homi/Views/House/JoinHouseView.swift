import SwiftUI

struct JoinHouseView: View {
    @ObservedObject var viewModel: HouseViewModel
    @FocusState private var isCodeFocused: Bool
    @State private var codeDigits: [String] = Array(repeating: "", count: 6)

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

                Text("Join a House")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Constants.Spacing.medium)

                Text("Enter the invite code from your housemates")
                    .font(.body)
                    .foregroundColor(Constants.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, Constants.Spacing.large)
            .padding(.top, Constants.Spacing.medium)

            ScrollView {
                VStack(spacing: Constants.Spacing.xLarge) {
                    // Envelope Icon
                    Image(systemName: "envelope.open.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Constants.Colors.success)
                        .padding(.top, Constants.Spacing.xLarge)

                    VStack(spacing: Constants.Spacing.large) {
                        // Invite Code Input
                        VStack(alignment: .leading, spacing: Constants.Spacing.small) {
                            Text("Invite Code")
                                .font(.caption)
                                .foregroundColor(Constants.Colors.textSecondary)

                            // 6-digit code input
                            HStack(spacing: Constants.Spacing.small) {
                                ForEach(0..<6, id: \.self) { index in
                                    CodeCharacterField(
                                        character: $codeDigits[index],
                                        onChanged: { newValue in
                                            handleCodeInput(at: index, value: newValue)
                                        }
                                    )
                                }
                            }

                            Text("Ask your housemates for the 6-character code")
                                .font(.caption2)
                                .foregroundColor(Constants.Colors.textSecondary)
                        }

                        // Or manual input option
                        VStack(spacing: Constants.Spacing.small) {
                            Text("or enter manually")
                                .font(.caption)
                                .foregroundColor(Constants.Colors.textSecondary)

                            TextField("Enter code", text: $viewModel.inviteCode)
                                .textCase(.uppercase)
                                .autocapitalization(.allCharacters)
                                .disableAutocorrection(true)
                                .padding(.horizontal, Constants.Spacing.medium)
                                .frame(height: 56)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(Constants.CornerRadius.small)
                                .onChange(of: viewModel.inviteCode) { oldValue, newValue in
                                    // Sync manual input with digit fields
                                    let chars = Array(newValue.prefix(6).uppercased())
                                    for i in 0..<6 {
                                        codeDigits[i] = i < chars.count ? String(chars[i]) : ""
                                    }
                                }
                        }
                    }

                    // Join Button
                    Button(action: {
                        if viewModel.inviteCode.isEmpty {
                            viewModel.inviteCode = codeDigits.joined()
                        }
                        Task {
                            await viewModel.joinHouse()
                        }
                    }) {
                        Text("Join House")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Constants.Colors.primary)
                            .cornerRadius(Constants.CornerRadius.medium)
                    }
                    .disabled(codeDigits.joined().count != 6 && viewModel.inviteCode.count < 6)
                    .opacity((codeDigits.joined().count != 6 && viewModel.inviteCode.count < 6) ? 0.6 : 1)

                    // Info Box
                    HStack(spacing: Constants.Spacing.small) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(Constants.Colors.warning)

                        VStack(alignment: .leading, spacing: Constants.Spacing.xSmall) {
                            Text("Don't have a code?")
                                .font(.caption)
                                .fontWeight(.semibold)

                            Text("Ask your housemates to share the invite code from their app, or create your own house instead.")
                                .font(.caption2)
                                .foregroundColor(Constants.Colors.textSecondary)
                        }
                    }
                    .padding(Constants.Spacing.medium)
                    .background(Constants.Colors.warning.opacity(0.1))
                    .cornerRadius(Constants.CornerRadius.small)
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

    private func handleCodeInput(at index: Int, value: String) {
        // Update the invite code in view model
        viewModel.inviteCode = codeDigits.joined()

        // Auto-submit when all characters are entered
        if codeDigits.allSatisfy({ !$0.isEmpty }) {
            viewModel.inviteCode = codeDigits.joined()
        }
    }
}

struct CodeCharacterField: View {
    @Binding var character: String
    var onChanged: (String) -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("", text: $character)
            .textCase(.uppercase)
            .autocapitalization(.allCharacters)
            .disableAutocorrection(true)
            .multilineTextAlignment(.center)
            .font(.title)
            .fontWeight(.semibold)
            .frame(width: 50, height: 60)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(Constants.CornerRadius.small)
            .overlay(
                RoundedRectangle(cornerRadius: Constants.CornerRadius.small)
                    .stroke(isFocused ? Constants.Colors.primary : Color.clear, lineWidth: 2)
            )
            .focused($isFocused)
            .onChange(of: character) { oldValue, newValue in
                if newValue.count > 1 {
                    character = String(newValue.prefix(1))
                }
                onChanged(character)
            }
    }
}