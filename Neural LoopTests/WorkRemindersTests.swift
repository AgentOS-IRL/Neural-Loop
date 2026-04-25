import XCTest
import EventKit
@testable import Neural_Loop

@MainActor
final class WorkRemindersTests: XCTestCase {
    func testPermissionDeniedMapsToAccessDenied() async {
        let store = FakeReminderStore(authorizationStatus: .denied)
        let service = GenesysReminderService(store: store)

        do {
            _ = try await service.fetchIncompleteGenesysReminders()
            XCTFail("Expected access denied")
        } catch {
            XCTAssertEqual(error as? GenesysReminderServiceError, .accessDenied)
        }
    }

    func testGenesysSourceLookupRequiresExchangeSourceNamedGenesys() throws {
        let store = FakeReminderStore(
            authorizationStatus: .fullAccess,
            sources: [
                .init(title: "Genesys", sourceType: .local, calendars: [Self.genesysCalendar]),
                .init(title: "Personal", sourceType: .exchange, calendars: [Self.personalCalendar])
            ]
        )
        let service = GenesysReminderService(store: store)

        XCTAssertThrowsError(try service.genesysReminderSource()) { error in
            XCTAssertEqual(error as? GenesysReminderServiceError, .sourceNotFound)
        }
    }

    func testMissingGenesysCalendarReturnsCalendarError() throws {
        let store = FakeReminderStore(
            authorizationStatus: .fullAccess,
            sources: [
                .init(title: "Genesys", sourceType: .exchange, calendars: [])
            ]
        )
        let service = GenesysReminderService(store: store)

        XCTAssertThrowsError(try service.genesysReminderCalendars()) { error in
            XCTAssertEqual(error as? GenesysReminderServiceError, .calendarNotFound)
        }
    }

    func testFetchMapsIncompleteRemindersAndSortsNewestFirst() async throws {
        let olderDate = Self.date("2026-04-15T08:00:00Z")
        let newerDate = Self.date("2026-04-15T10:00:00Z")
        let store = FakeReminderStore(
            authorizationStatus: .fullAccess,
            sources: [.init(title: "Genesys", sourceType: .exchange, calendars: [Self.genesysCalendar])],
            reminders: [
                .init(
                    id: "older",
                    fallbackID: nil,
                    title: "Older work note",
                    notes: nil,
                    creationDate: olderDate,
                    dueDate: nil,
                    calendarTitle: "Reminders",
                    sourceTitle: "Genesys",
                    isCompleted: false
                ),
                .init(
                    id: "completed",
                    fallbackID: nil,
                    title: "Completed work note",
                    notes: nil,
                    creationDate: newerDate.addingTimeInterval(100),
                    dueDate: nil,
                    calendarTitle: "Reminders",
                    sourceTitle: "Genesys",
                    isCompleted: true
                ),
                .init(
                    id: "newer",
                    fallbackID: nil,
                    title: "Newer work note",
                    notes: "Details",
                    creationDate: newerDate,
                    dueDate: nil,
                    calendarTitle: "Reminders",
                    sourceTitle: "Genesys",
                    isCompleted: false
                )
            ]
        )
        let service = GenesysReminderService(store: store)

        let reminders = try await service.fetchIncompleteGenesysReminders()

        XCTAssertEqual(reminders.map { $0.id }, ["newer", "older"])
        XCTAssertEqual(reminders.first?.title, "Newer work note")
        XCTAssertEqual(reminders.first?.notes, "Details")
    }

    func testCreateTrimsTitleAndWritesToGenesysCalendar() async throws {
        let store = FakeReminderStore(
            authorizationStatus: .fullAccess,
            sources: [.init(title: "Genesys", sourceType: .exchange, calendars: [Self.genesysCalendar])],
            defaultCalendar: Self.personalCalendar
        )
        let service = GenesysReminderService(store: store)

        let reminder = try await service.createGenesysReminder(title: "  Follow up with customer  ")

        XCTAssertEqual(reminder.title, "Follow up with customer")
        XCTAssertEqual(store.createdRequests.map(\.calendarID), ["genesys-reminders"])
    }

    func testCreateRejectsBlankTitle() async {
        let store = FakeReminderStore(
            authorizationStatus: .fullAccess,
            sources: [.init(title: "Genesys", sourceType: .exchange, calendars: [Self.genesysCalendar])]
        )
        let service = GenesysReminderService(store: store)

        do {
            _ = try await service.createGenesysReminder(title: "   ")
            XCTFail("Expected empty title error")
        } catch {
            XCTAssertEqual(error as? GenesysReminderServiceError, .emptyTitle)
            XCTAssertTrue(store.createdRequests.isEmpty)
        }
    }

    private static let genesysCalendar = ReminderCalendarSnapshot(
        id: "genesys-reminders",
        title: "Reminders",
        sourceTitle: "Genesys",
        sourceType: .exchange,
        allowsContentModifications: true
    )

    private static let personalCalendar = ReminderCalendarSnapshot(
        id: "personal-reminders",
        title: "Personal",
        sourceTitle: "Personal",
        sourceType: .local,
        allowsContentModifications: true
    )

    fileprivate static func date(_ isoString: String) -> Date {
        ISO8601DateFormatter().date(from: isoString)!
    }
}

private final class FakeReminderStore: EventKitReminderStore {
    struct CreatedRequest: Equatable {
        let title: String
        let notes: String?
        let dueDate: Date?
        let calendarID: String
    }

    var authorizationStatus: EKAuthorizationStatus
    var sources: [ReminderSourceSnapshot]
    var reminders: [ReminderSnapshot]
    var defaultCalendar: ReminderCalendarSnapshot?
    private(set) var createdRequests: [CreatedRequest] = []

    init(
        authorizationStatus: EKAuthorizationStatus,
        sources: [ReminderSourceSnapshot] = [],
        reminders: [ReminderSnapshot] = [],
        defaultCalendar: ReminderCalendarSnapshot? = nil
    ) {
        self.authorizationStatus = authorizationStatus
        self.sources = sources
        self.reminders = reminders
        self.defaultCalendar = defaultCalendar
    }

    var reminderAuthorizationStatus: EKAuthorizationStatus {
        authorizationStatus
    }

    func requestFullAccessToReminders() async throws -> Bool {
        authorizationStatus == .fullAccess || authorizationStatus == .authorized
    }

    func defaultCalendarForNewReminders() -> ReminderCalendarSnapshot? {
        defaultCalendar
    }

    func fetchIncompleteReminders(calendarIDs: [String]) async throws -> [ReminderSnapshot] {
        reminders
    }

    func createReminder(
        title: String,
        notes: String?,
        dueDate: Date?,
        calendarID: String
    ) async throws -> ReminderSnapshot {
        createdRequests.append(.init(title: title, notes: notes, dueDate: dueDate, calendarID: calendarID))
        return ReminderSnapshot(
            id: "created-id",
            fallbackID: nil,
            title: title,
            notes: notes,
            creationDate: WorkRemindersTests.date("2026-04-15T12:00:00Z"),
            dueDate: dueDate,
            calendarTitle: "Reminders",
            sourceTitle: "Genesys",
            isCompleted: false
        )
    }

    func updateReminder(id: String, title: String, notes: String?) async throws -> ReminderSnapshot {
        ReminderSnapshot(
            id: id,
            fallbackID: nil,
            title: title,
            notes: notes,
            creationDate: WorkRemindersTests.date("2026-04-15T12:00:00Z"),
            dueDate: nil,
            calendarTitle: "Reminders",
            sourceTitle: "Genesys",
            isCompleted: false
        )
    }

    func deleteReminder(id: String) async throws {}
}
