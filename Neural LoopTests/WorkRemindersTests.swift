import XCTest
import EventKit
import CodexCore
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

    func testCreateInfersDueDateWhenDueDateIsNil() async throws {
        let inferredDate = Self.date("2026-04-17T14:00:00Z")
        let now = Self.date("2026-04-15T09:00:00Z")
        let resolver = FakeGenesysReminderDateResolver(result: inferredDate)
        let store = FakeReminderStore(
            authorizationStatus: .fullAccess,
            sources: [.init(title: "Genesys", sourceType: .exchange, calendars: [Self.genesysCalendar])]
        )
        let service = GenesysReminderService(
            store: store,
            dateResolver: resolver,
            now: { now },
            timeZone: { TimeZone(identifier: "Europe/Dublin")! }
        )

        let reminder = try await service.createGenesysReminder(
            title: "  Follow up Friday  ",
            notes: "  after the account review  "
        )

        XCTAssertEqual(resolver.requests, [
            .init(
                title: "Follow up Friday",
                notes: "after the account review",
                currentDate: now,
                timeZoneIdentifier: "Europe/Dublin"
            )
        ])
        XCTAssertEqual(store.createdRequests.map(\.dueDate), [inferredDate])
        XCTAssertEqual(reminder.dueDate, inferredDate)
    }

    func testCreateDoesNotInferDueDateWhenExplicitDueDateIsProvided() async throws {
        let explicitDate = Self.date("2026-04-18T10:30:00Z")
        let resolver = FakeGenesysReminderDateResolver(result: Self.date("2026-04-19T10:30:00Z"))
        let store = FakeReminderStore(
            authorizationStatus: .fullAccess,
            sources: [.init(title: "Genesys", sourceType: .exchange, calendars: [Self.genesysCalendar])]
        )
        let service = GenesysReminderService(store: store, dateResolver: resolver)

        let reminder = try await service.createGenesysReminder(
            title: "Follow up with customer",
            dueDate: explicitDate
        )

        XCTAssertTrue(resolver.requests.isEmpty)
        XCTAssertEqual(store.createdRequests.map(\.dueDate), [explicitDate])
        XCTAssertEqual(reminder.dueDate, explicitDate)
    }

    func testCreateSavesWithoutDueDateWhenResolverReturnsNil() async throws {
        let resolver = FakeGenesysReminderDateResolver(result: nil)
        let store = FakeReminderStore(
            authorizationStatus: .fullAccess,
            sources: [.init(title: "Genesys", sourceType: .exchange, calendars: [Self.genesysCalendar])]
        )
        let service = GenesysReminderService(store: store, dateResolver: resolver)

        let reminder = try await service.createGenesysReminder(title: "Follow up with customer")

        XCTAssertEqual(resolver.requests.count, 1)
        XCTAssertEqual(store.createdRequests.count, 1)
        XCTAssertNil(store.createdRequests.first?.dueDate)
        XCTAssertNil(reminder.dueDate)
    }

    func testCreateSavesWithoutDueDateWhenResolverThrows() async throws {
        let resolver = FakeGenesysReminderDateResolver(error: TestResolverError.failure)
        let store = FakeReminderStore(
            authorizationStatus: .fullAccess,
            sources: [.init(title: "Genesys", sourceType: .exchange, calendars: [Self.genesysCalendar])]
        )
        let service = GenesysReminderService(store: store, dateResolver: resolver)

        let reminder = try await service.createGenesysReminder(title: "Follow up with customer")

        XCTAssertEqual(resolver.requests.count, 1)
        XCTAssertEqual(store.createdRequests.count, 1)
        XCTAssertNil(store.createdRequests.first?.dueDate)
        XCTAssertNil(reminder.dueDate)
    }

    func testCreateRejectsBlankTitleBeforeCallingResolver() async {
        let resolver = FakeGenesysReminderDateResolver(result: Self.date("2026-04-17T14:00:00Z"))
        let store = FakeReminderStore(
            authorizationStatus: .fullAccess,
            sources: [.init(title: "Genesys", sourceType: .exchange, calendars: [Self.genesysCalendar])]
        )
        let service = GenesysReminderService(store: store, dateResolver: resolver)

        do {
            _ = try await service.createGenesysReminder(title: "   ")
            XCTFail("Expected empty title error")
        } catch {
            XCTAssertEqual(error as? GenesysReminderServiceError, .emptyTitle)
            XCTAssertTrue(resolver.requests.isEmpty)
            XCTAssertTrue(store.createdRequests.isEmpty)
        }
    }

    func testCodexResolverParsesISODueDateFromToolCall() async throws {
        let dueDate = Self.date("2026-04-20T15:00:00Z")
        let client = FakeGenesysReminderCodexClient(
            action: .callTool(
                name: "resolve_genesys_reminder_due_date",
                arguments: ["due_date": "2026-04-20T15:00:00Z"]
            )
        )
        let resolver = CodexGenesysReminderDateResolver(codexClient: client)

        let resolvedDate = try await resolver.inferDueDate(
            title: "Follow up next Monday",
            notes: nil,
            currentDate: Self.date("2026-04-15T09:00:00Z"),
            timeZone: TimeZone(identifier: "Europe/Dublin")!
        )

        XCTAssertEqual(resolvedDate, dueDate)
        XCTAssertEqual(client.converseCallCount, 1)
        XCTAssertTrue(client.capturedInstructions?.contains("CURRENT DATE AND TIME") == true)
        XCTAssertTrue(client.capturedInstructions?.contains("Europe/Dublin") == true)
    }

    func testCodexResolverReturnsNilForNullDueDate() async throws {
        let client = FakeGenesysReminderCodexClient(
            action: .callTool(
                name: "resolve_genesys_reminder_due_date",
                arguments: ["due_date": NSNull()]
            )
        )
        let resolver = CodexGenesysReminderDateResolver(codexClient: client)

        let resolvedDate = try await resolver.inferDueDate(
            title: "Follow up with customer",
            notes: nil,
            currentDate: Self.date("2026-04-15T09:00:00Z"),
            timeZone: TimeZone(identifier: "Europe/Dublin")!
        )

        XCTAssertNil(resolvedDate)
    }

    func testCodexResolverThrowsForMalformedDueDate() async {
        let client = FakeGenesysReminderCodexClient(
            action: .callTool(
                name: "resolve_genesys_reminder_due_date",
                arguments: ["due_date": "not a date"]
            )
        )
        let resolver = CodexGenesysReminderDateResolver(codexClient: client)

        do {
            _ = try await resolver.inferDueDate(
                title: "Follow up eventually",
                notes: nil,
                currentDate: Self.date("2026-04-15T09:00:00Z"),
                timeZone: TimeZone(identifier: "Europe/Dublin")!
            )
            XCTFail("Expected malformed due date error")
        } catch {
            XCTAssertNotNil(error)
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

private enum TestResolverError: Error {
    case failure
}

private final class FakeGenesysReminderDateResolver: GenesysReminderDateResolving {
    struct Request: Equatable {
        let title: String
        let notes: String?
        let currentDate: Date
        let timeZoneIdentifier: String
    }

    private let result: Date?
    private let error: Error?
    private(set) var requests: [Request] = []

    init(result: Date?) {
        self.result = result
        self.error = nil
    }

    init(error: Error) {
        self.result = nil
        self.error = error
    }

    func inferDueDate(title: String, notes: String?, currentDate: Date, timeZone: TimeZone) async throws -> Date? {
        requests.append(.init(
            title: title,
            notes: notes,
            currentDate: currentDate,
            timeZoneIdentifier: timeZone.identifier
        ))

        if let error {
            throw error
        }

        return result
    }
}

private final class FakeGenesysReminderCodexClient: GenesysReminderCodexExecuting {
    private let action: CodexAction
    private(set) var converseCallCount = 0
    private(set) var capturedInstructions: String?

    init(action: CodexAction) {
        self.action = action
    }

    func converse(
        messages: [CodexInputMessage],
        state: CodexConversationState,
        tools: [CodexTool],
        instructions: String
    ) async throws -> CodexIntentResult {
        converseCallCount += 1
        capturedInstructions = instructions
        return CodexIntentResult(action: action, state: state)
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
