import Foundation

enum NeuralLoopDateContext {
    static var calendar: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.locale = .autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }

    static var locale: Locale {
        .autoupdatingCurrent
    }

    static var timeZone: TimeZone {
        .autoupdatingCurrent
    }
}

extension Calendar {
    static var neuralLoopDisplay: Calendar {
        NeuralLoopDateContext.calendar
    }

    func generateDates(
        inside interval: DateInterval,
        matching components: DateComponents
    ) -> [Date] {
        var dates: [Date] = []
        dates.append(interval.start)

        enumerateDates(
            startingAfter: interval.start,
            matching: components,
            matchingPolicy: .nextTime
        ) { date, _, stop in
            guard let date else { return }
            if date < interval.end {
                dates.append(date)
            } else {
                stop = true
            }
        }
        return dates
    }

    func neuralLoopDateComponents(from date: Date) -> DateComponents {
        dateComponents([.hour, .minute], from: date)
    }
}

extension Date {
    var startOfDay: Date {
        Calendar.neuralLoopDisplay.startOfDay(for: self)
    }

    func ISO8601FormatIfAvailable() -> String? {
        ISO8601DateFormatter().string(from: self)
    }
}

extension DateFormatter {
    static func neuralLoopDisplay(
        dateStyle: DateFormatter.Style = .none,
        timeStyle: DateFormatter.Style = .short,
        calendar: Calendar = .neuralLoopDisplay,
        locale: Locale = NeuralLoopDateContext.locale,
        timeZone: TimeZone = NeuralLoopDateContext.timeZone
    ) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        return formatter
    }
}
