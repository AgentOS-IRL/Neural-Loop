//
//  DateBucket.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 06/01/2026.
//

import Foundation
import SwiftUI


struct DateBucket: Identifiable {
    let id = UUID()
    let title: AnyView
    let start: Date
    let end: Date
    var taskIds: [Int64] = []
}

extension Calendar {

    func startOfDay(_ date: Date) -> Date {
        startOfDay(for: date)
    }

    func endOfDay(_ date: Date) -> Date {
        self.date(
            byAdding: DateComponents(day: 1, second: -1),
            to: startOfDay(for: date)
        )!
    }

    func endOfMonth(_ date: Date) -> Date {
        let range = range(of: .day, in: .month, for: date)!
        let day = range.count
        return self.date(from: DateComponents(
            year: component(.year, from: date),
            month: component(.month, from: date),
            day: day,
            hour: 23,
            minute: 59,
            second: 59
        ))!
    }
}

func hasOccurrence(
    of rule: Calendar.RecurrenceRule,
    between start: Date,
    and end: Date
) -> Bool {
    
    rule
        .recurrences(of: start)
        .prefix { $0 <= end }
        .contains { $0 >= start && $0 <= end }
}

func occursInBucket(
    task: Tasks,
    bucket: DateBucket,
    now: Date = .now
) -> Bool {

    guard let start = task.start_date else { return false }

    // Non-recurring task
    if task.recursion_rule == nil {
        return start >= bucket.start && start <= bucket.end
    }

    // Recurring task
    do {
        let rule = try parse_rrule(rruleString: task.recursion_rule!)
        return hasOccurrence(
            of: rule,
            between: max(bucket.start, now),
            and: bucket.end
        )
    } catch {
        print("No rule in :", task.title ," \(task.start_date)",
              "\(max(bucket.start, now)) to \(bucket.end)", task.start_date! >= max(bucket.start, now) && task.start_date! <= bucket.end)
        return task.start_date! >= max(bucket.start, now) && task.start_date! <= bucket.end
    }
}

func attachTasksToBuckets(
    tasks: [Tasks],
    buckets: [DateBucket]
) -> [DateBucket] {

    var result = buckets

    for task in tasks {
        guard let taskId = task.id else { continue }

        for index in result.indices {
            if occursInBucket(task: task, bucket: result[index]) {
                result[index].taskIds.append(taskId)
            }
        }
    }

    return result
}

func buildDateBuckets(
    today: Date = Date(),
    calendar: Calendar = .current
) -> [DateBucket] {

    let todayStart = calendar.startOfDay(today)
//    todayStart = calendar.date(byAdding: .day, value: 20, to: todayStart)!
    var buckets: [DateBucket] = []
    
    

    // 1️⃣ Today
    buckets.append(
        DateBucket(
            title: AnyView( Text("Today")
                    .font(.title3.weight(.semibold))
                .foregroundColor(.primary))
                ,
            start: todayStart,
            end: calendar.endOfDay(todayStart)
        )
    )

    // 2️⃣ Tomorrow
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: todayStart)!
    buckets.append(
        DateBucket(
            title: AnyView( Text("Tomorrow")
                    .font(.title3.weight(.semibold))
                .foregroundColor(.primary)),
            start: tomorrow,
            end: calendar.endOfDay(tomorrow)
        )
    )

    // 3️⃣ Next 7 days (rolling, 1 bucket per day)
    for offset in 2...8 {
        let dayStart = calendar.date(byAdding: .day, value: offset, to: todayStart)!
        let dayEnd = calendar.endOfDay(dayStart)


        buckets.append(
            DateBucket(
                title: AnyView(HStack(spacing: 6) {
                    Text(dayStart.formatted(.dateTime.weekday(.abbreviated)))
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Text(dayStart.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.body)
                        .foregroundColor(.secondary)
                }),
                start: dayStart,
                end: dayEnd
            )
        )
    }

    // 4️⃣ Rest of current month
    let restOfMonthStart = calendar.date(byAdding: .day, value: 9, to: todayStart)!
    let monthEnd = calendar.endOfMonth(restOfMonthStart)

    if restOfMonthStart <= monthEnd {
        buckets.append(
            DateBucket(
                title: AnyView(HStack(spacing: 6) {
                    Text("Rest of \(restOfMonthStart.formatted(.dateTime.month(.wide)))")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.primary)

                    Text("\(restOfMonthStart.formatted(.dateTime.day()))–\(monthEnd.formatted(.dateTime.day()))")
                        .font(.body)
                        .foregroundColor(.secondary)
                }),
                start: restOfMonthStart,
                end: monthEnd
            )
        )
    }

    // 5️⃣ Future months until end of year
    var nextMonth = calendar.date(byAdding: .month, value: 1, to: monthEnd)!

    while calendar.component(.year, from: nextMonth)
            == calendar.component(.year, from: todayStart) {

        let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: nextMonth)
        )!

        let monthEnd = calendar.endOfMonth(monthStart)
//        monthStart.formatted(.dateTime.month(.wide)),
        buckets.append(
            DateBucket(
                title: AnyView(Text(monthStart.formatted(.dateTime.month(.wide)))
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary)),
                start: monthStart,
                end: monthEnd
            )
        )

        nextMonth = calendar.date(byAdding: .month, value: 1, to: nextMonth)!
    }

    // 6️⃣ Next year
    buckets.append(
        DateBucket(
            title: AnyView(Text(nextMonth.formatted(.dateTime.year()))
                .font(.title3.weight(.semibold))
                .foregroundColor(.primary)),
            start: calendar.date(
                from: DateComponents(
                    year: calendar.component(.year, from: nextMonth),
                    month: 1,
                    day: 1,
                    hour: 0,
                    minute: 0,
                    second: 0
                )
            )!,
            end: calendar.date(
                from: DateComponents(
                    year: calendar.component(.year, from: nextMonth),
                    month: 12,
                    day: 31,
                    hour: 23,
                    minute: 59,
                    second: 59
                )
            )!
        )
    )

    return buckets
}
