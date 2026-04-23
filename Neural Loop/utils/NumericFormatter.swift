import Foundation

enum NumericFormatter {
    private static var formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        f.groupingSeparator = "" // Avoid commas for thousands in input fields
        return f
    }()

    static func format(_ value: Decimal) -> String {
        return formatter.string(from: value as NSDecimalNumber) ?? ""
    }

    static func parse(_ text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        // Try parsing with current locale
        if let number = formatter.number(from: trimmed) {
            return number.decimalValue
        }
        
        // Fallback: try parsing with dot if it failed (in case user pasted or typed dot on comma locale)
        let dotFormatter = NumberFormatter()
        dotFormatter.numberStyle = .decimal
        dotFormatter.locale = Locale(identifier: "en_US_POSIX")
        if let number = dotFormatter.number(from: trimmed) {
            return number.decimalValue
        }
        
        return nil
    }
}
