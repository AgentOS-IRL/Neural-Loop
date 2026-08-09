import Foundation

// Transport models shared by the iPhone and watch targets. The iPhone remains
// authoritative; the watch snapshot is deliberately presentation-focused.

public nonisolated struct DailyLoopTaskIdentity: Codable, Hashable, Identifiable, Sendable {
    public var id: String {
        if let occurrenceStart {
            return "\(taskID):\(occurrenceStart.timeIntervalSinceReferenceDate)"
        }
        return String(taskID)
    }

    public let taskID: Int64
    /// The resolved scheduled start for a recurring occurrence. Nil for a
    /// non-recurring task, whose task ID is already its stable identity.
    public let occurrenceStart: Date?

    public init(taskID: Int64, occurrenceStart: Date? = nil) {
        self.taskID = taskID
        self.occurrenceStart = occurrenceStart
    }
}

public nonisolated struct DailyLoopWatchTaskSummary: Codable, Hashable, Identifiable, Sendable {
    public let identity: DailyLoopTaskIdentity
    public var id: String { identity.id }
    public let title: String
    public let startDate: Date?
    public let duration: TimeInterval?
    public let priority: Int
    public let recurrenceRule: String?
    public let isCompleted: Bool

    public init(
        identity: DailyLoopTaskIdentity,
        title: String,
        startDate: Date?,
        duration: TimeInterval?,
        priority: Int,
        recurrenceRule: String?,
        isCompleted: Bool
    ) {
        self.identity = identity
        self.title = title
        self.startDate = startDate
        self.duration = duration
        self.priority = priority
        self.recurrenceRule = recurrenceRule
        self.isCompleted = isCompleted
    }

    public var isRecurring: Bool {
        recurrenceRule?.isEmpty == false
    }
}

public nonisolated struct DailyLoopWatchHabitSummary: Codable, Hashable, Identifiable, Sendable {
    public let id: Int64
    public let title: String
    public let current: Int
    public let target: Int
    public let label: String?
    public let priority: Int
    public let isSkipped: Bool

    public init(
        id: Int64,
        title: String,
        current: Int,
        target: Int,
        label: String?,
        priority: Int,
        isSkipped: Bool
    ) {
        self.id = id
        self.title = title
        self.current = current
        self.target = target
        self.label = label
        self.priority = priority
        self.isSkipped = isSkipped
    }

    public var isComplete: Bool {
        current >= target
    }

    public var progress: Double {
        guard target > 0 else { return 0 }
        return min(max(Double(current) / Double(target), 0), 1)
    }
}

public nonisolated struct DailyLoopWatchSnapshot: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let generatedAt: Date
    public let tasks: [DailyLoopWatchTaskSummary]
    public let habits: [DailyLoopWatchHabitSummary]

    public init(
        schemaVersion: Int = DailyLoopWatchSnapshot.currentSchemaVersion,
        generatedAt: Date = .now,
        tasks: [DailyLoopWatchTaskSummary],
        habits: [DailyLoopWatchHabitSummary]
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.tasks = tasks
        self.habits = habits
    }
}

// Phase 4 defines the future mutation protocol but intentionally does not send
// or execute these actions. Phase 5 owns queueing and authoritative handling.

public nonisolated struct DailyLoopTaskCompletionAction: Codable, Hashable, Sendable {
    public let identity: DailyLoopTaskIdentity
    public let isCompleted: Bool

    public init(identity: DailyLoopTaskIdentity, isCompleted: Bool) {
        self.identity = identity
        self.isCompleted = isCompleted
    }
}

public nonisolated struct DailyLoopHabitProgressAction: Codable, Hashable, Sendable {
    public let habitID: Int64
    public let minimumValue: Int

    public init(habitID: Int64, minimumValue: Int) {
        self.habitID = habitID
        self.minimumValue = minimumValue
    }
}

public nonisolated struct DailyLoopHabitSkipAction: Codable, Hashable, Sendable {
    public let habitID: Int64
    public let isSkipped: Bool

    public init(habitID: Int64, isSkipped: Bool) {
        self.habitID = habitID
        self.isSkipped = isSkipped
    }
}

public nonisolated struct DailyLoopNoteCaptureAction: Codable, Hashable, Sendable {
    public let text: String

    public init(text: String) {
        self.text = text
    }
}

public nonisolated enum DailyLoopWatchActionPayload: Codable, Hashable, Sendable {
    case setTaskCompletion(DailyLoopTaskCompletionAction)
    case setHabitProgressAtLeast(DailyLoopHabitProgressAction)
    case setHabitSkipped(DailyLoopHabitSkipAction)
    case createFleetingNote(DailyLoopNoteCaptureAction)
}

public nonisolated struct DailyLoopWatchAction: Codable, Hashable, Identifiable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let id: UUID
    public let createdAt: Date
    public let sequence: Int
    public let payload: DailyLoopWatchActionPayload

    public init(
        schemaVersion: Int = DailyLoopWatchAction.currentSchemaVersion,
        id: UUID = UUID(),
        createdAt: Date = .now,
        sequence: Int,
        payload: DailyLoopWatchActionPayload
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.createdAt = createdAt
        self.sequence = sequence
        self.payload = payload
    }
}

public nonisolated enum DailyLoopWatchActionResultStatus: String, Codable, Hashable, Sendable {
    case succeeded
    case failed
}

public nonisolated struct DailyLoopWatchActionResult: Codable, Hashable, Identifiable, Sendable {
    public static let currentSchemaVersion = 1

    public var id: UUID { actionID }
    public let schemaVersion: Int
    public let actionID: UUID
    public let processedSequence: Int
    public let processedAt: Date
    public let status: DailyLoopWatchActionResultStatus
    public let message: String?
    public let authoritativeSnapshot: DailyLoopWatchSnapshot?

    public init(
        schemaVersion: Int = DailyLoopWatchActionResult.currentSchemaVersion,
        actionID: UUID,
        processedSequence: Int,
        processedAt: Date = .now,
        status: DailyLoopWatchActionResultStatus,
        message: String? = nil,
        authoritativeSnapshot: DailyLoopWatchSnapshot? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.actionID = actionID
        self.processedSequence = processedSequence
        self.processedAt = processedAt
        self.status = status
        self.message = message
        self.authoritativeSnapshot = authoritativeSnapshot
    }
}
