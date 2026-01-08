//
//  DateBucket.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 06/01/2026.
//

import Foundation
import SwiftUI

enum bucketType: String, CaseIterable {
    case inbox, today, overdue, upcoming, completed
    
}

struct DateBucket: Identifiable {
    let id = UUID()
    let title: AnyView
    let start: Date
    let end: Date
    var taskIds: [Int64] = []
    let type: bucketType
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
    and end: Date,
    anchor: Date
) -> Bool {
    let has_occ =  rule
        .recurrences(of: anchor)
        .prefix { $0 <= end }
        .contains { $0 >= start && $0 <= end }
//    print("Start date:\(start), End date:\(end), Occurrence:\(has_occ)")
    return has_occ
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
            and: bucket.end,
            anchor: task.start_date!
        )
    } catch {
        
        return false
    }
}

func attachTaskToBuckets(
    task: Tasks,
    buckets: [DateBucket]
) -> [DateBucket] {

    var result = buckets

    guard let taskId = task.id else { return result }
    
    let now = Date()

    for index in result.indices {
        let bucket: DateBucket = result[index]
        if occursInBucket(task: task, bucket: bucket) {
            result[index].taskIds.append(taskId)
        }
        else if task.start_date! >= max(bucket.start, now) && task.start_date! <= bucket.end {
            print("No rule in :", task.title ," \(task.start_date)",
                  "\(max(bucket.start, now)) to \(bucket.end)", task.start_date! >= max(bucket.start, now) && task.start_date! <= bucket.end)
            result[index].taskIds.append(taskId)
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
            end: calendar.endOfDay(todayStart),
            type: .today
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
            end: calendar.endOfDay(tomorrow),
            type: .upcoming
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
                end: dayEnd,
                type: .upcoming
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
                end: monthEnd,
                type: .upcoming
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
                end: monthEnd,
                type: .upcoming
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
            )!,
            type: .upcoming
        )
    )

    return buckets
}
