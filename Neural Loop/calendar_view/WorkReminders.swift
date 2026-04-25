import Foundation
import EventKit

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

final class GenesysReminderService {
    private let store: any EventKitReminderStore
    private let sourceTitle: String
    private let sourceType: EKSourceType
    private let preferredCalendarTitle: String?

    init(
        store: any EventKitReminderStore = EKEventStoreReminderStore(),
        sourceTitle: String = "Genesys",
        sourceType: EKSourceType = .exchange,
        preferredCalendarTitle: String? = nil
    ) {
        self.store = store
        self.sourceTitle = sourceTitle
        self.sourceType = sourceType
        self.preferredCalendarTitle = preferredCalendarTitle
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
        dueDate: Date? = nil
    ) async throws -> WorkReminder {
        _ = try await requestReminderAccess()

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw GenesysReminderServiceError.emptyTitle
        }

        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let calendar = try writableGenesysCalendar()

        do {
            let snapshot = try await store.createReminder(
                title: trimmedTitle,
                notes: trimmedNotes?.isEmpty == true ? nil : trimmedNotes,
                dueDate: dueDate,
                calendarID: calendar.id
            )
            return Self.makeWorkReminder(snapshot)
        } catch let error as GenesysReminderServiceError {
            throw error
        } catch {
            throw GenesysReminderServiceError.saveFailed(error.localizedDescription)
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
