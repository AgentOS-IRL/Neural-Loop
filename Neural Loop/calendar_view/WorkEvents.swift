import Foundation
import EventKit


func fetchTodaysGenesysEvents(
    for date: Date = Date(),
    ignorePrefix: String = "sanjeev halyal",
    completion: @escaping ([SimpleEvent]) -> Void
) {
    let eventStore = EKEventStore()

    eventStore.requestAccess(to: .event) { granted, _ in
        guard granted else {
            completion([])
            return
        }

        let calendar = Calendar.current

        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            completion([])
            return
        }

        // 🔎 Find Genesys Exchange source (NO closures)
        var genesysSource: EKSource?
        for source in eventStore.sources {
            if source.sourceType == .exchange && source.title == "Genesys" {
                genesysSource = source
                break
            }
        }

        guard let source = genesysSource else {
            completion([])
            return
        }

        let calendars = Array(source.calendars(for: .event))

        let predicate = eventStore.predicateForEvents(
            withStart: startOfDay,
            end: endOfDay,
            calendars: calendars
        )

        let events = eventStore.events(matching: predicate)

        // 🎯 Find TimeOff event
        for event in events {
            print(event)
            if event.title.lowercased().hasPrefix(ignorePrefix) {
                completion([])
                return
            }
        }

        // 🧹 Filter overlaps
        let filtered: [EKEvent] = events

        // 📦 Map result
        let result = filtered
            .sorted { $0.startDate < $1.startDate }
            .map {
                SimpleEvent(
                    title: $0.title,
                    start: $0.startDate,
                    end: $0.endDate,
                    acceptanceStatus: acceptanceStatus(for: $0),
                    event_type: .workEvent
                )
            }

        completion(result)
    }
    
}


private func acceptanceStatus(for event: EKEvent) -> EKParticipantStatus? {
    guard let attendees = event.attendees else {
        return nil // Not a meeting / no invitees
    }

    for attendee in attendees {
        if attendee.isCurrentUser {
            return attendee.participantStatus
        }
    }

    return nil
}
