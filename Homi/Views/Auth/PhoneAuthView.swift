import SwiftUI

struct PhoneAuthView: View {
    @ObservedObject var viewModel: AuthViewModel
    @FocusState private var isPhoneFocused: Bool
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

                if viewModel.currentAuthStep == .phoneEntry {
                    phoneEntryHeader
                } else {
                    verificationHeader
                }
            }
            .padding(.horizontal, Constants.Spacing.large)
            .padding(.top, Constants.Spacing.medium)

            ScrollView {
                VStack(spacing: Constants.Spacing.xLarge) {
                    if viewModel.currentAuthStep == .phoneEntry {
                        phoneEntryContent
                    } else {
                        verificationContent
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
        .onAppear {
            if viewModel.currentAuthStep == .phoneEntry {
                isPhoneFocused = true
            }
        }
    }

    // MARK: - Phone Entry Views

    private var phoneEntryHeader: some View {
        VStack(spacing: Constants.Spacing.small) {
            Text("Enter Phone Number")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Constants.Spacing.medium)

            Text("We'll send you a verification code")
                .font(.body)
                .foregroundColor(Constants.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var phoneEntryContent: some View {
        VStack(spacing: Constants.Spacing.large) {
            // Phone Number Input
            VStack(alignment: .leading, spacing: Constants.Spacing.small) {
                Text("Phone Number")
                    .font(.caption)
                    .foregroundColor(Constants.Colors.textSecondary)

                HStack(spacing: Constants.Spacing.small) {
                    // Country Code Picker
                    Menu {
                        Button("+1 USA") { viewModel.countryCode = "+1" }
                        Button("+44 UK") { viewModel.countryCode = "+44" }
                        Button("+91 India") { viewModel.countryCode = "+91" }
                        Button("+86 China") { viewModel.countryCode = "+86" }
                        Button("+61 Australia") { viewModel.countryCode = "+61" }
                    } label: {
                        HStack {
                            Text(viewModel.countryCode)
                                .foregroundColor(.primary)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(Constants.Colors.textSecondary)
                        }
                        .padding(.horizontal, Constants.Spacing.medium)
                        .frame(height: 56)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(Constants.CornerRadius.small)
                    }

                    // Phone Number Field
                    TextField("(555) 123-4567", text: $viewModel.phoneNumber)
                        .keyboardType(.phonePad)
                        .focused($isPhoneFocused)
                        .padding(.horizontal, Constants.Spacing.medium)
                        .frame(height: 56)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(Constants.CornerRadius.small)
                }
            }

            // Send Code Button
            Button(action: {
                Task {
                    await viewModel.sendPhoneVerification()
                }
            }) {
                Text("Send Verification Code")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Constants.Colors.primary)
                    .cornerRadius(Constants.CornerRadius.medium)
            }
            .disabled(viewModel.phoneNumber.isEmpty)
            .opacity(viewModel.phoneNumber.isEmpty ? 0.6 : 1)

            // Info Text
            Text("You may receive SMS messages for verification. Message and data rates may apply.")
                .font(.caption)
                .foregroundColor(Constants.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Verification Views

    private var verificationHeader: some View {
        VStack(spacing: Constants.Spacing.small) {
            Text("Verify Phone Number")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Constants.Spacing.medium)

            Text("Enter the 6-digit code sent to \(viewModel.countryCode)\(formatPhoneNumber(viewModel.phoneNumber))")
                .font(.body)
                .foregroundColor(Constants.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var verificationContent: some View {
        VStack(spacing: Constants.Spacing.xLarge) {
            // OTP Code Input
            HStack(spacing: Constants.Spacing.small) {
                ForEach(0..<6, id: \.self) { index in
                    CodeDigitField(
                        digit: $codeDigits[index],
                        onChanged: { newValue in
                            handleCodeInput(at: index, value: newValue)
                        }
                    )
                }
            }

            // Verify Button
            Button(action: {
                viewModel.verificationCode = codeDigits.joined()
                Task {
                    await viewModel.verifyPhoneCode()
                }
            }) {
                Text("Verify")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Constants.Colors.primary)
                    .cornerRadius(Constants.CornerRadius.medium)
            }
            .disabled(codeDigits.joined().count != 6)
            .opacity(codeDigits.joined().count != 6 ? 0.6 : 1)

            // Resend Code
            VStack(spacing: Constants.Spacing.small) {
                Text("Didn't receive a code?")
                    .font(.subheadline)
                    .foregroundColor(Constants.Colors.textSecondary)

                Button(action: {
                    Task {
                        await viewModel.sendPhoneVerification()
                    }
                }) {
                    Text("Resend Code")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Constants.Colors.primary)
                }

                Button(action: {
                    viewModel.currentAuthStep = .phoneEntry
                    codeDigits = Array(repeating: "", count: 6)
                }) {
                    Text("Change Phone Number")
                        .font(.caption)
                        .foregroundColor(Constants.Colors.textSecondary)
                }
                .padding(.top, Constants.Spacing.xSmall)
            }
        }
    }

    private func handleCodeInput(at index: Int, value: String) {
        // Handle backspace
        if value.isEmpty && index > 0 {
            // Move focus to previous field
            return
        }

        // Handle input
        if !value.isEmpty && index < 5 {
            // Move focus to next field
            return
        }

        // Auto-submit when all digits are entered
        if codeDigits.allSatisfy({ !$0.isEmpty }) {
            viewModel.verificationCode = codeDigits.joined()
            Task {
                await viewModel.verifyPhoneCode()
            }
        }
    }

    private func formatPhoneNumber(_ number: String) -> String {
        let cleaned = number.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        guard cleaned.count == 10 else { return number }

        let mask = "(XXX) XXX-XXXX"
        var result = ""
        var index = cleaned.startIndex

        for ch in mask where index < cleaned.endIndex {
            if ch == "X" {
                result.append(cleaned[index])
                index = cleaned.index(after: index)
            } else {
                result.append(ch)
            }
        }

        return result
    }
}

struct CodeDigitField: View {
    @Binding var digit: String
    var onChanged: (String) -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("", text: $digit)
            .keyboardType(.numberPad)
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
            .onChange(of: digit) { oldValue, newValue in
                if newValue.count > 1 {
                    digit = String(newValue.prefix(1))
                }
                onChanged(digit)
            }
    }
}
