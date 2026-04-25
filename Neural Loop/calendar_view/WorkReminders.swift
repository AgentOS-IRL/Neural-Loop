import Foundation
import EventKit
import CodexCore

struct WorkReminder: Identifiable, Equatable {
    let id: String
    let title: String
    let notes: String?
    let createdAt: Date
    let dueDate: Date?
    let calendarTitle: String
    let sourceTitle: String
}

struct CreateWorkReminderRequest: Equatable {
    let title: String
    let notes: String?
    let dueDate: Date?

    init(title: String, notes: String? = nil, dueDate: Date? = nil) {
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
    }
}

enum GenesysReminderServiceError: LocalizedError, Equatable {
    case accessDenied
    case sourceNotFound
    case calendarNotFound
    case emptyTitle
    case reminderNotFound
    case saveFailed(String)
    case updateFailed(String)
    case deleteFailed(String)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Reminders access is needed to create and show Genesys work notes."
        case .sourceNotFound:
            return "The Genesys Exchange reminder source could not be found."
        case .calendarNotFound:
            return "A writable Genesys reminders calendar could not be found."
        case .emptyTitle:
            return "Work note content cannot be empty."
        case .reminderNotFound:
            return "The Genesys work note could not be found."
        case .saveFailed(let message):
            return "Work note could not be saved. \(message)"
        case .updateFailed(let message):
            return "Work note could not be updated. \(message)"
        case .deleteFailed(let message):
            return "Work note could not be deleted. \(message)"
        }
    }
}

struct ReminderCalendarSnapshot: Equatable {
    let id: String
    let title: String
    let sourceTitle: String
    let sourceType: EKSourceType
    let allowsContentModifications: Bool
}

struct ReminderSourceSnapshot: Equatable {
    let title: String
    let sourceType: EKSourceType
    let calendars: [ReminderCalendarSnapshot]
}

struct ReminderSnapshot: Equatable {
    let id: String
    let fallbackID: String?
    let title: String
    let notes: String?
    let creationDate: Date?
    let dueDate: Date?
    let calendarTitle: String
    let sourceTitle: String
    let isCompleted: Bool
}

protocol EventKitReminderStore {
    var reminderAuthorizationStatus: EKAuthorizationStatus { get }
    var sources: [ReminderSourceSnapshot] { get }

    func requestFullAccessToReminders() async throws -> Bool
    func defaultCalendarForNewReminders() -> ReminderCalendarSnapshot?
    func fetchIncompleteReminders(calendarIDs: [String]) async throws -> [ReminderSnapshot]
    func createReminder(title: String, notes: String?, dueDate: Date?, calendarID: String) async throws -> ReminderSnapshot
    func updateReminder(id: String, title: String, notes: String?) async throws -> ReminderSnapshot
    func deleteReminder(id: String) async throws
}

protocol GenesysReminderDateResolving {
    func inferDueDate(title: String, notes: String?, currentDate: Date, timeZone: TimeZone) async throws -> Date?
}

protocol GenesysReminderCodexExecuting {
    func converse(
        messages: [CodexInputMessage],
        state: CodexConversationState,
        tools: [CodexTool],
        instructions: String
    ) async throws -> CodexIntentResult
}

final class GenesysReminderService {
    private let store: any EventKitReminderStore
    private let sourceTitle: String
    private let sourceType: EKSourceType
    private let preferredCalendarTitle: String?
    private let dateResolver: (any GenesysReminderDateResolving)?
    private let now: () -> Date
    private let timeZone: () -> TimeZone

    init(
        store: any EventKitReminderStore = EKEventStoreReminderStore(),
        sourceTitle: String = "Genesys",
        sourceType: EKSourceType = .exchange,
        preferredCalendarTitle: String? = nil,
        dateResolver: (any GenesysReminderDateResolving)? = nil,
        now: @escaping () -> Date = Date.init,
        timeZone: @escaping () -> TimeZone = { .current }
    ) {
        self.store = store
        self.sourceTitle = sourceTitle
        self.sourceType = sourceType
        self.preferredCalendarTitle = preferredCalendarTitle
        self.dateResolver = dateResolver
        self.now = now
        self.timeZone = timeZone
    }

    func requestReminderAccess() async throws -> Bool {
        switch store.reminderAuthorizationStatus {
        case .authorized, .fullAccess:
            return true
        case .denied, .restricted, .writeOnly:
            throw GenesysReminderServiceError.accessDenied
        case .notDetermined:
            let granted = try await store.requestFullAccessToReminders()
            guard granted else {
                throw GenesysReminderServiceError.accessDenied
            }
            return true
        @unknown default:
            throw GenesysReminderServiceError.accessDenied
        }
    }

    func fetchIncompleteGenesysReminders() async throws -> [WorkReminder] {
        _ = try await requestReminderAccess()
        let calendars = try genesysReminderCalendars()
        let snapshots = try await store.fetchIncompleteReminders(calendarIDs: calendars.map(\.id))

        return snapshots
            .filter { !$0.isCompleted }
            .map(Self.makeWorkReminder)
            .sorted(by: Self.sortNewestFirst)
    }

    func createGenesysReminder(
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        dateResolver: (any GenesysReminderDateResolving)? = nil
    ) async throws -> WorkReminder {
        _ = try await requestReminderAccess()

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw GenesysReminderServiceError.emptyTitle
        }

        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNotes = trimmedNotes?.isEmpty == true ? nil : trimmedNotes
        let calendar = try writableGenesysCalendar()

        let resolvedDueDate: Date?
        if let dueDate {
            resolvedDueDate = dueDate
        } else {
            resolvedDueDate = await inferDueDateIfPossible(
                title: trimmedTitle,
                notes: normalizedNotes,
                resolver: dateResolver ?? self.dateResolver
            )
        }

        do {
            let snapshot = try await store.createReminder(
                title: trimmedTitle,
                notes: normalizedNotes,
                dueDate: resolvedDueDate,
                calendarID: calendar.id
            )
            return Self.makeWorkReminder(snapshot)
        } catch let error as GenesysReminderServiceError {
            throw error
        } catch {
            throw GenesysReminderServiceError.saveFailed(error.localizedDescription)
        }
    }

    private func inferDueDateIfPossible(
        title: String,
        notes: String?,
        resolver: (any GenesysReminderDateResolving)?
    ) async -> Date? {
        guard let resolver else {
            return nil
        }

        do {
            return try await resolver.inferDueDate(
                title: title,
                notes: notes,
                currentDate: now(),
                timeZone: timeZone()
            )
        } catch {
            return nil
        }
    }

    func updateGenesysReminder(id: String, title: String, notes: String?) async throws -> WorkReminder {
        _ = try await requestReminderAccess()

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw GenesysReminderServiceError.emptyTitle
        }

        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let snapshot = try await store.updateReminder(
                id: id,
                title: trimmedTitle,
                notes: trimmedNotes?.isEmpty == true ? nil : trimmedNotes
            )
            return Self.makeWorkReminder(snapshot)
        } catch let error as GenesysReminderServiceError {
            throw error
        } catch {
            throw GenesysReminderServiceError.updateFailed(error.localizedDescription)
        }
    }

    func deleteGenesysReminder(id: String) async throws {
        _ = try await requestReminderAccess()

        do {
            try await store.deleteReminder(id: id)
        } catch let error as GenesysReminderServiceError {
            throw error
        } catch {
            throw GenesysReminderServiceError.deleteFailed(error.localizedDescription)
        }
    }

    func genesysReminderSource() throws -> ReminderSourceSnapshot {
        guard let source = store.sources.first(where: { $0.sourceType == sourceType && $0.title == sourceTitle }) else {
            throw GenesysReminderServiceError.sourceNotFound
        }
        return source
    }

    func genesysReminderCalendars() throws -> [ReminderCalendarSnapshot] {
        let calendars = try genesysReminderSource().calendars
        guard !calendars.isEmpty else {
            throw GenesysReminderServiceError.calendarNotFound
        }
        return calendars
    }

    func writableGenesysCalendar() throws -> ReminderCalendarSnapshot {
        let calendars = try genesysReminderCalendars().filter(\.allowsContentModifications)
        guard !calendars.isEmpty else {
            throw GenesysReminderServiceError.calendarNotFound
        }

        if let preferredCalendarTitle,
           let preferred = calendars.first(where: { $0.title == preferredCalendarTitle }) {
            return preferred
        }

        if let defaultCalendar = store.defaultCalendarForNewReminders(),
           defaultCalendar.sourceTitle == sourceTitle,
           defaultCalendar.sourceType == sourceType,
           defaultCalendar.allowsContentModifications {
            return defaultCalendar
        }

        return calendars[0]
    }

    private static func makeWorkReminder(_ snapshot: ReminderSnapshot) -> WorkReminder {
        WorkReminder(
            id: snapshot.id.isEmpty ? (snapshot.fallbackID ?? snapshot.title) : snapshot.id,
            title: snapshot.title,
            notes: snapshot.notes,
            createdAt: snapshot.creationDate ?? snapshot.dueDate ?? Date.distantPast,
            dueDate: snapshot.dueDate,
            calendarTitle: snapshot.calendarTitle,
            sourceTitle: snapshot.sourceTitle
        )
    }

    private static func sortNewestFirst(_ lhs: WorkReminder, _ rhs: WorkReminder) -> Bool {
        if lhs.createdAt == rhs.createdAt {
            if lhs.dueDate == rhs.dueDate {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }

            return (lhs.dueDate ?? .distantPast) > (rhs.dueDate ?? .distantPast)
        }

        return lhs.createdAt > rhs.createdAt
    }
}

final class CodexStructuredToolGenesysReminderDateAdapter: GenesysReminderCodexExecuting {
    private let tool: CodexStructuredTool

    init(tool: CodexStructuredTool) {
        self.tool = tool
    }

    func converse(
        messages: [CodexInputMessage],
        state: CodexConversationState,
        tools: [CodexTool],
        instructions: String
    ) async throws -> CodexIntentResult {
        try await tool.converse(
            messages: messages,
            state: state,
            tools: tools,
            instructions: instructions
        )
    }
}

final class CodexGenesysReminderDateResolver: GenesysReminderDateResolving {
    private let codexClient: any GenesysReminderCodexExecuting

    init(codexClient: any GenesysReminderCodexExecuting) {
        self.codexClient = codexClient
    }

    convenience init(accessToken: String, accountID: String) {
        self.init(
            codexClient: CodexStructuredToolGenesysReminderDateAdapter(
                tool: CodexStructuredTool(access_token: accessToken, account_id: accountID)
            )
        )
    }

    func inferDueDate(title: String, notes: String?, currentDate: Date, timeZone: TimeZone) async throws -> Date? {
        let result = try await codexClient.converse(
            messages: [
                CodexInputMessage(
                    role: "user",
                    content: [
                        CodexInputContent(
                            type: "input_text",
                            text: Self.prompt(title: title, notes: notes, currentDate: currentDate, timeZone: timeZone)
                        )
                    ]
                )
            ],
            state: CodexConversationState(),
            tools: [Self.dueDateTool],
            instructions: Self.instructions(currentDate: currentDate, timeZone: timeZone)
        )

        switch result.action {
        case .callTool(let name, let arguments):
            guard Self.normalizedToolName(name) == Self.dueDateToolName else {
                throw CodexGenesysReminderDateResolverError.unexpectedTool(name)
            }
            return try Self.parseDueDate(from: arguments, timeZone: timeZone)

        case .clarify:
            throw CodexGenesysReminderDateResolverError.missingToolCall
        }
    }

    private static let dueDateToolName = "resolve_genesys_reminder_due_date"

    private static let dueDateTool = CodexTool(
        name: dueDateToolName,
        description: "Return the inferred Genesys work reminder due date, or null when the title and notes do not contain an explicit or strongly implied date.",
        parameters: .object([
            "type": .string("object"),
            "properties": .object([
                "due_date": .object([
                    "type": .array([.string("string"), .string("null")]),
                    "description": .string("Optional ISO-8601 due date. Use null if no date can be inferred.")
                ])
            ]),
            "required": .array([.string("due_date")])
        ])
    )

    private static func instructions(currentDate: Date, timeZone: TimeZone) -> String {
        """
        Infer a due date for a Genesys work reminder.
        CURRENT DATE AND TIME: \(isoString(from: currentDate, timeZone: timeZone)).
        LOCAL TIME ZONE: \(timeZone.identifier).
        Rules:
        - Infer a due date only from explicit or strongly implied date language in the reminder title or notes.
        - Use CURRENT DATE AND TIME as the anchor for relative phrases like tomorrow, next Monday, or Friday afternoon.
        - If the text contains a date but no time, default to 15:00:00 in the provided time zone.
        - If the text contains no date clue, call \(dueDateToolName) with due_date: null.
        - Do not rewrite the reminder title or notes.
        - Return exactly one due date or null.
        """
    }

    private static func prompt(title: String, notes: String?, currentDate: Date, timeZone: TimeZone) -> String {
        var lines = [
            "CURRENT DATE AND TIME: \(isoString(from: currentDate, timeZone: timeZone))",
            "LOCAL TIME ZONE: \(timeZone.identifier)",
            "REMINDER TITLE: \(title)"
        ]

        if let notes, !notes.isEmpty {
            lines.append("REMINDER NOTES: \(notes)")
        } else {
            lines.append("REMINDER NOTES: null")
        }

        return lines.joined(separator: "\n")
    }

    private static func parseDueDate(from arguments: [String: Any], timeZone: TimeZone) throws -> Date? {
        guard let rawValue = arguments["due_date"] ?? arguments["dueDate"] else {
            return nil
        }

        if rawValue is NSNull {
            return nil
        }

        guard let dueDateString = rawValue as? String else {
            throw CodexGenesysReminderDateResolverError.malformedDueDate(String(describing: rawValue))
        }

        let trimmedDueDate = dueDateString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDueDate.isEmpty else {
            return nil
        }

        if let date = parseISODate(trimmedDueDate, timeZone: timeZone) {
            return date
        }

        if let date = parseDateOnly(trimmedDueDate, timeZone: timeZone) {
            return date
        }

        throw CodexGenesysReminderDateResolverError.malformedDueDate(trimmedDueDate)
    }

    private static func parseISODate(_ value: String, timeZone: TimeZone) -> Date? {
        for formatter in iso8601DateFormatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }

        for format in localISODateTimeFormats {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = timeZone
            formatter.dateFormat = format

            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }

    private static func parseDateOnly(_ value: String, timeZone: TimeZone) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"

        guard let date = formatter.date(from: value) else {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return calendar.date(from: DateComponents(
            timeZone: timeZone,
            year: components.year,
            month: components.month,
            day: components.day,
            hour: 15,
            minute: 0,
            second: 0
        ))
    }

    private static func isoString(from date: Date, timeZone: TimeZone) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }

    private static func normalizedToolName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static let iso8601DateFormatters: [ISO8601DateFormatter] = {
        let withFractionalSeconds = ISO8601DateFormatter()
        withFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let withoutFractionalSeconds = ISO8601DateFormatter()
        withoutFractionalSeconds.formatOptions = [.withInternetDateTime]

        return [withFractionalSeconds, withoutFractionalSeconds]
    }()

    private static let localISODateTimeFormats = [
        "yyyy-MM-dd'T'HH:mm:ss.SSS",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm"
    ]
}

private enum CodexGenesysReminderDateResolverError: LocalizedError, Equatable {
    case unexpectedTool(String)
    case missingToolCall
    case malformedDueDate(String)

    var errorDescription: String? {
        switch self {
        case .unexpectedTool(let name):
            return "Codex returned an unexpected Genesys reminder date tool: \(name)"
        case .missingToolCall:
            return "Codex did not return a Genesys reminder date tool call."
        case .malformedDueDate(let value):
            return "Codex returned an invalid Genesys reminder due date: \(value)"
        }
    }
}

final class EKEventStoreReminderStore: EventKitReminderStore {
    private let eventStore: EKEventStore

    init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    var reminderAuthorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .reminder)
    }

    var sources: [ReminderSourceSnapshot] {
        eventStore.sources.map { source in
            ReminderSourceSnapshot(
                title: source.title,
                sourceType: source.sourceType,
                calendars: source.calendars(for: .reminder).map { calendar in
                    ReminderCalendarSnapshot(
                        id: calendar.calendarIdentifier,
                        title: calendar.title,
                        sourceTitle: source.title,
                        sourceType: source.sourceType,
                        allowsContentModifications: calendar.allowsContentModifications
                    )
                }
            )
        }
    }

    func requestFullAccessToReminders() async throws -> Bool {
        try await eventStore.requestFullAccessToReminders()
    }

    func defaultCalendarForNewReminders() -> ReminderCalendarSnapshot? {
        guard let calendar = eventStore.defaultCalendarForNewReminders(),
              let source = calendar.source else {
            return nil
        }

        return ReminderCalendarSnapshot(
            id: calendar.calendarIdentifier,
            title: calendar.title,
            sourceTitle: source.title,
            sourceType: source.sourceType,
            allowsContentModifications: calendar.allowsContentModifications
        )
    }

    func fetchIncompleteReminders(calendarIDs: [String]) async throws -> [ReminderSnapshot] {
        let calendars = eventStore.sources
            .flatMap { Array($0.calendars(for: .reminder)) }
            .filter { calendarIDs.contains($0.calendarIdentifier) }

        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: calendars
        )

        return try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: (reminders ?? []).map(Self.makeSnapshot))
            }
        }
    }

    func createReminder(
        title: String,
        notes: String?,
        dueDate: Date?,
        calendarID: String
    ) async throws -> ReminderSnapshot {
        guard let calendar = calendar(withID: calendarID) else {
            throw GenesysReminderServiceError.calendarNotFound
        }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.notes = notes
        reminder.calendar = calendar

        if let dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        }

        do {
            try eventStore.save(reminder, commit: true)
            return Self.makeSnapshot(reminder)
        } catch {
            throw GenesysReminderServiceError.saveFailed(error.localizedDescription)
        }
    }

    func updateReminder(id: String, title: String, notes: String?) async throws -> ReminderSnapshot {
        guard let reminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw GenesysReminderServiceError.reminderNotFound
        }

        reminder.title = title
        reminder.notes = notes

        do {
            try eventStore.save(reminder, commit: true)
            return Self.makeSnapshot(reminder)
        } catch {
            throw GenesysReminderServiceError.updateFailed(error.localizedDescription)
        }
    }

    func deleteReminder(id: String) async throws {
        guard let reminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw GenesysReminderServiceError.reminderNotFound
        }

        do {
            try eventStore.remove(reminder, commit: true)
        } catch {
            throw GenesysReminderServiceError.deleteFailed(error.localizedDescription)
        }
    }

    private func calendar(withID id: String) -> EKCalendar? {
        eventStore.sources
            .flatMap { Array($0.calendars(for: .reminder)) }
            .first { $0.calendarIdentifier == id }
    }

    private static func makeSnapshot(_ reminder: EKReminder) -> ReminderSnapshot {
        ReminderSnapshot(
            id: reminder.calendarItemIdentifier,
            fallbackID: reminder.calendarItemExternalIdentifier,
            title: reminder.title ?? "",
            notes: reminder.notes,
            creationDate: reminder.creationDate,
            dueDate: reminder.dueDateComponents?.date,
            calendarTitle: reminder.calendar.title,
            sourceTitle: reminder.calendar.source.title,
            isCompleted: reminder.isCompleted
        )
    }
}
