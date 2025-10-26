import UIKit

// MARK: - Haptic Manager

struct HapticManager {
    // MARK: - Impact Feedback

    static func impact(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    // MARK: - Notification Feedback

    static func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }

    // MARK: - Selection Feedback

    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    // MARK: - Common Patterns

    static func success() {
        notification(type: .success)
    }

    static func error() {
        notification(type: .error)
    }

    static func warning() {
        notification(type: .warning)
    }
}
