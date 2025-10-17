import Foundation

struct CurrencyFormatter {
    /// Format a number as currency based on the currency code
    static func format(amount: Double, currencyCode: String = "USD") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2

        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }

    /// Get currency symbol for a currency code
    static func symbol(for currencyCode: String) -> String {
        let locale = Locale.availableIdentifiers
            .map { Locale(identifier: $0) }
            .first { $0.currency?.identifier == currencyCode }

        return locale?.currencySymbol ?? "$"
    }

    /// Common currency codes
    static let commonCurrencies: [(code: String, name: String)] = [
        ("USD", "US Dollar"),
        ("EUR", "Euro"),
        ("GBP", "British Pound"),
        ("JPY", "Japanese Yen"),
        ("CAD", "Canadian Dollar"),
        ("AUD", "Australian Dollar"),
        ("CHF", "Swiss Franc"),
        ("CNY", "Chinese Yuan"),
        ("INR", "Indian Rupee"),
        ("MXN", "Mexican Peso"),
        ("BRL", "Brazilian Real"),
        ("ZAR", "South African Rand"),
        ("KRW", "South Korean Won"),
        ("SGD", "Singapore Dollar"),
        ("NZD", "New Zealand Dollar")
    ]
}
