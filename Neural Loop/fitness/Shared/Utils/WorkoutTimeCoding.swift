import Foundation

enum WorkoutTimeCoding {
    private static func makeTimeOnlyFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }

    static func string(from date: Date) -> String {
        makeTimeOnlyFormatter().string(from: date)
    }

    static func normalize(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return value }

        if let date = ISO8601DateFormatter().date(from: value) {
            return string(from: date)
        }

        return value
    }
}
