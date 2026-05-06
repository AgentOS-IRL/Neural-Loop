import Foundation

public struct NeuralLoopWidgetTask: Codable, Hashable, Identifiable {
    public let id: Int64?
    public let title: String
    public let startDate: Date?
    public let duration: TimeInterval?
    public let priority: Int

    public init(
        id: Int64?,
        title: String,
        startDate: Date?,
        duration: TimeInterval?,
        priority: Int
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.duration = duration
        self.priority = priority
    }
}

public struct NeuralLoopWidgetHabit: Codable, Hashable, Identifiable {
    public let id: Int64?
    public let title: String
    public let current: Int
    public let target: Int
    public let label: String?
    public let priority: Int
    public let isSkippedToday: Bool

    public init(
        id: Int64?,
        title: String,
        current: Int,
        target: Int,
        label: String?,
        priority: Int,
        isSkippedToday: Bool
    ) {
        self.id = id
        self.title = title
        self.current = current
        self.target = target
        self.label = label
        self.priority = priority
        self.isSkippedToday = isSkippedToday
    }

    public var isComplete: Bool {
        current >= target
    }

    public var ratio: Double {
        guard target > 0 else { return 0 }
        return min(Double(current) / Double(target), 1)
    }
}

public struct NeuralLoopWidgetSnapshot: Codable, Hashable {
    public static let widgetKind = "NeuralLoopCalendarWidget"

    public let updatedAt: Date
    public let tasks: [NeuralLoopWidgetTask]
    public let habits: [NeuralLoopWidgetHabit]

    public init(
        updatedAt: Date = Date(),
        tasks: [NeuralLoopWidgetTask],
        habits: [NeuralLoopWidgetHabit]
    ) {
        self.updatedAt = updatedAt
        self.tasks = tasks
        self.habits = habits
    }
}

public enum NeuralLoopWidgetSnapshotStore {
    public static let userDefaultsKey = "com.neuralloop.todayWidgetSnapshot"
    public static let appGroupSuite = "group.com.sanjeevhalyal.Neural-Loop"

    public static func load(
        defaults: UserDefaults? = UserDefaults(suiteName: appGroupSuite)
    ) -> NeuralLoopWidgetSnapshot? {
        guard let data = defaults?.data(forKey: userDefaultsKey) else { return nil }
        return try? JSONDecoder.neuralLoopWidget.decode(NeuralLoopWidgetSnapshot.self, from: data)
    }

    public static func save(
        _ snapshot: NeuralLoopWidgetSnapshot,
        defaults: UserDefaults? = UserDefaults(suiteName: appGroupSuite)
    ) {
        guard let data = try? JSONEncoder.neuralLoopWidget.encode(snapshot) else { return }
        defaults?.set(data, forKey: userDefaultsKey)
    }
}

private extension JSONDecoder {
    static var neuralLoopWidget: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension JSONEncoder {
    static var neuralLoopWidget: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
