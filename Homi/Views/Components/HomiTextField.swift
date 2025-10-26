import SwiftUI

// MARK: - Text Field Style

enum HomiTextFieldStyle {
    case standard
    case email
    case password
    case number
    case phone
}

// MARK: - Homi TextField Component

struct HomiTextField: View {
    let title: String
    let placeholder: String
    let icon: String?
    let style: HomiTextFieldStyle
    @Binding var text: String
    var errorMessage: String?

    @State private var isSecure: Bool = true
    @FocusState private var isFocused: Bool

    init(
        _ title: String = "",
        placeholder: String,
        icon: String? = nil,
        style: HomiTextFieldStyle = .standard,
        text: Binding<String>,
        errorMessage: String? = nil
    ) {
        self.title = title
        self.placeholder = placeholder
        self.icon = icon
        self.style = style
        self._text = text
        self.errorMessage = errorMessage
        self._isSecure = State(initialValue: style == .password)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.xSmall) {
            // Title
            if !title.isEmpty {
                Text(title)
                    .font(Constants.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Constants.Colors.textPrimary)
            }

            // Text Field Container
            HStack(spacing: Constants.Spacing.small) {
                // Leading Icon
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(isFocused ? Constants.Colors.primary : Constants.Colors.textSecondary)
                }

                // Text Field
                Group {
                    if style == .password && isSecure {
                        SecureField(placeholder, text: $text)
                            .textContentType(textContentType)
                    } else {
                        TextField(placeholder, text: $text)
                            .keyboardType(keyboardType)
                            .textContentType(textContentType)
                            .textInputAutocapitalization(autocapitalization)
                    }
                }
                .font(Constants.Typography.body)
                .focused($isFocused)

                // Password Toggle
                if style == .password {
                    Button(action: {
                        isSecure.toggle()
                    }) {
                        Image(systemName: isSecure ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Constants.Colors.textSecondary)
                    }
                }
            }
            .padding(Constants.Spacing.medium)
            .background(Constants.Colors.secondaryBackground)
            .cornerRadius(Constants.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Constants.CornerRadius.medium)
                    .stroke(borderColor, lineWidth: 1.5)
            )
            .animation(Constants.Animation.quick, value: isFocused)

            // Error Message
            if let errorMessage = errorMessage, !errorMessage.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))

                    Text(errorMessage)
                        .font(Constants.Typography.caption1)
                }
                .foregroundColor(Constants.Colors.danger)
            }
        }
    }

    // MARK: - Style Properties

    private var borderColor: Color {
        if let errorMessage = errorMessage, !errorMessage.isEmpty {
            return Constants.Colors.danger
        }
        return isFocused ? Constants.Colors.primary : Color.clear
    }

    private var keyboardType: UIKeyboardType {
        switch style {
        case .email:
            return .emailAddress
        case .number:
            return .decimalPad
        case .phone:
            return .phonePad
        default:
            return .default
        }
    }

    private var textContentType: UITextContentType? {
        switch style {
        case .email:
            return .emailAddress
        case .password:
            return .password
        case .phone:
            return .telephoneNumber
        default:
            return nil
        }
    }

    private var autocapitalization: TextInputAutocapitalization {
        switch style {
        case .email:
            return .never
        default:
            return .sentences
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: Constants.Spacing.large) {
        HomiTextField(
            "Email",
            placeholder: "Enter your email",
            icon: "envelope",
            style: .email,
            text: .constant("")
        )

        HomiTextField(
            "Password",
            placeholder: "Enter your password",
            icon: "lock",
            style: .password,
            text: .constant("")
        )

        HomiTextField(
            "Name",
            placeholder: "Enter your name",
            icon: "person",
            text: .constant("")
        )

        HomiTextField(
            "Phone",
            placeholder: "Enter phone number",
            icon: "phone",
            style: .phone,
            text: .constant("")
        )

        HomiTextField(
            "Amount",
            placeholder: "0.00",
            icon: "dollarsign.circle",
            style: .number,
            text: .constant(""),
            errorMessage: "Amount is required"
        )
    }
    .padding()
}
