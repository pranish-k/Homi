import SwiftUI

struct MessageInputView: View {
    @Binding var messageText: String
    var onSend: () -> Void
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: Constants.Spacing.small) {
            // Text input
            HStack(spacing: Constants.Spacing.xSmall) {
                TextField("Message...", text: $messageText, axis: .vertical)
                    .focused($isTextFieldFocused)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .padding(.horizontal, Constants.Spacing.medium)
                    .padding(.vertical, Constants.Spacing.small)
                    .background(Color(.systemGray6))
                    .cornerRadius(Constants.CornerRadius.large)
                    .overlay(
                        RoundedRectangle(cornerRadius: Constants.CornerRadius.large)
                            .stroke(Color(.systemGray4), lineWidth: 0.5)
                    )
            }

            // Send button
            Button(action: {
                onSend()
                isTextFieldFocused = true
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color(.systemGray3) : Constants.Colors.primary)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, Constants.Spacing.medium)
        .padding(.vertical, Constants.Spacing.small)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5),
            alignment: .top
        )
    }
}

// MARK: - Preview
struct MessageInputView_Previews: PreviewProvider {
    @State static var messageText = ""

    static var previews: some View {
        VStack {
            Spacer()
            MessageInputView(messageText: $messageText) {
                print("Send message: \(messageText)")
            }
        }
        .previewLayout(.sizeThatFits)
    }
}
