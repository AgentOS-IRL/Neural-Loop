import Foundation

enum WorkoutDatabaseError: LocalizedError, Equatable {
    case insertReturnedNoRows
    case updateReturnedNoRows
    case missingIdentifier

    var errorDescription: String? {
        switch self {
        case .insertReturnedNoRows:
            return "Workout record could not be saved."
        case .updateReturnedNoRows:
            return "Workout record could not be updated."
        case .missingIdentifier:
            return "Workout record is missing its database identifier."
        }
    }
}

enum WorkoutDateCoding {
    private static func makeDateOnlyFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    static func date(from value: String) -> Date? {
        if let date = makeDateOnlyFormatter().date(from: value) {
            return date
        }
        return ISO8601DateFormatter().date(from: value)
    }

    static func string(from date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard
            let year = components.year,
            let month = components.month,
            let day = components.day
        else {
            return makeDateOnlyFormatter().string(from: date)
        }

        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func decodeDate<Key: CodingKey>(
        from container: KeyedDecodingContainer<Key>,
        forKey key: Key
    ) throws -> Date {
        let value = try container.decode(String.self, forKey: key)
        if let date = makeDateOnlyFormatter().date(from: value) {
            return date
        }
        if let date = ISO8601DateFormatter().date(from: value) {
            return date
        }

        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: container,
            debugDescription: "Expected a yyyy-MM-dd or ISO-8601 date string."
        )
    }

    static func decodeDateIfPresent<Key: CodingKey>(
        from container: KeyedDecodingContainer<Key>,
        forKey key: Key
    ) throws -> Date? {
        guard try container.contains(key), !(try container.decodeNil(forKey: key)) else {
            return nil
        }

        return try decodeDate(from: container, forKey: key)
    }
}

extension KeyedEncodingContainer {
    mutating func encodeNullable<T: Encodable>(_ value: T?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }
}

