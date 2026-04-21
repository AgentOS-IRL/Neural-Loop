//
//  TodoViewUtils.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 10/01/2026.
//

import Foundation
import SwiftUI
import RRuleKit
import SwiftData

func nextOccurrence(
    of rule: Calendar.RecurrenceRule,
    after now: Date = .now
) -> Date? {

    for date in rule.recurrences(of: now) {
        if date > now {
            return date
        }
    }
    return nil
}

func rrule_to_string(rule: Calendar.RecurrenceRule) -> String{
    let formatter = RecurrenceRuleRFC5545FormatStyle(calendar: .neuralLoopDisplay)
    let rruleString = formatter.format(rule)
    
    return rruleString
}

func parse_rrule(rruleString: String) throws -> Calendar.RecurrenceRule {
    let parser = RecurrenceRuleRFC5545FormatStyle(calendar: .neuralLoopDisplay)
    
    return try parser.parse(rruleString)
}

enum ViewMode: Equatable {
    case menu
    case today
    case upcoming
    case all
    case inbox
    case completed
    case new
}


func rebuildDateBuckets(tasks: [Tasks]) -> [DateBucket] {
    let calendar = Calendar.neuralLoopDisplay

    let todayStart = calendar.startOfDay(.now)
    let todayEnd = calendar.endOfDay(.now)
    var _dateBuckets = buildShortRangeDateBuckets()
    
    var today_bucket = DateBucket(
        title: AnyView( Text("Today")
                .font(.system(.title3, design: .rounded, weight: .bold))
            .foregroundColor(AppTheme.textPrimary))
            ,
        start: todayStart,
        end: todayEnd,
        type: .today
    )

    var inbox_bucket = DateBucket(title: AnyView( Text("Inbox")
        .font(.system(.title3, design: .rounded, weight: .bold))
        .foregroundColor(AppTheme.textPrimary)), start: .distantPast, end: .now, type: .inbox)

    var overdue_bucket = DateBucket(title: AnyView( Text("Overdue")
        .font(.system(.title3, design: .rounded, weight: .bold))
        .foregroundColor(AppTheme.errorTint)), start: .distantPast, end: .now, type: .overdue)
    var completed_bucket = DateBucket(title: AnyView( Text("Completed")
        .font(.system(.title3, design: .rounded, weight: .bold))
        .foregroundColor(AppTheme.textPrimary)), start: .distantPast, end: .distantFuture, type: .completed)

    for task in tasks {
        if task.is_completed {
            completed_bucket.appendTask(task)
        }
        else if task.start_date == nil {
            inbox_bucket.appendTask(task)
        }
        else if (task.recursion_rule == "" || task.recursion_rule == nil) && task.start_date != nil {
            if task.start_date! < todayStart {
                overdue_bucket.appendTask(task)
            }
            else if task.start_date! < todayEnd {
                today_bucket.appendTask(task)
            }
            else{
                _dateBuckets = attachTaskToBuckets(task: task, buckets: _dateBuckets)
            }

        }
        else {
            _dateBuckets = attachTaskToBuckets(task: task, buckets: _dateBuckets)
        }
    }

    return [inbox_bucket, today_bucket, overdue_bucket, completed_bucket] + _dateBuckets
}

func buildNewTaskBucket(from tasks: [Tasks]) -> DateBucket {
    var newBucket = DateBucket(
        title: AnyView(
            Text("New")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
        ),
        start: .distantPast,
        end: .distantFuture,
        type: .new
    )

    for task in tasks where !task.is_completed {
        newBucket.appendTask(task)
    }

    return newBucket
}

func addTaskRowView() -> some View {
    HStack(spacing: 12) {
        Circle()
            .stroke(
                AppTheme.textSecondary,
                style: StrokeStyle(lineWidth: 1.5, dash: [4])
            )
            .frame(width: 18, height: 18)
        
        Text("Add task")
            .font(.system(.body, design: .rounded, weight: .medium))
            .foregroundColor(AppTheme.textSecondary)
        
        Spacer()
    }
    .padding(20)
    .background(
        RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
            .fill(AppTheme.sectionGradient)
    )
    .overlay {
        RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
            .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
    }
}

func todoDueDateText(
    start: Date?,
    duration: TimeInterval?,
    calendar: Calendar = .neuralLoopDisplay,
    locale: Locale = .autoupdatingCurrent,
    timeZone: TimeZone = .autoupdatingCurrent
) -> String {
    guard let start else {
        return "no due date"
    }

    let dateTimeFormatter = DateFormatter.neuralLoopDisplay(
        dateStyle: .medium,
        timeStyle: .short,
        calendar: calendar,
        locale: locale,
        timeZone: timeZone
    )

    guard let duration, duration > 0 else {
        return dateTimeFormatter.string(from: start)
    }

    let end = start.addingTimeInterval(duration)

    if calendar.isDate(start, inSameDayAs: end) {
        let dateFormatter = DateFormatter.neuralLoopDisplay(
            dateStyle: .medium,
            timeStyle: .none,
            calendar: calendar,
            locale: locale,
            timeZone: timeZone
        )
        let timeFormatter = DateFormatter.neuralLoopDisplay(
            dateStyle: .none,
            timeStyle: .short,
            calendar: calendar,
            locale: locale,
            timeZone: timeZone
        )

        return "\(dateFormatter.string(from: start)), \(timeFormatter.string(from: start)) - \(timeFormatter.string(from: end))"
    }

    return "\(dateTimeFormatter.string(from: start)) - \(dateTimeFormatter.string(from: end))"
}

func taskRowView(task: Tasks, strikeThrough: Bool = false) -> some View {
    HStack(alignment: .top, spacing: 14) {
        // Checkbox placeholder
        Circle()
            .stroke(AppTheme.accentGradient, lineWidth: 2)
            .frame(width: 22, height: 22)
            .padding(.top, 2)
        
        VStack(alignment: .leading, spacing: 6) {
            Text(task.title)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .strikethrough(strikeThrough)
                .foregroundColor(AppTheme.textPrimary)
            
            Text(todoDueDateText(start: task.start_date, duration: task.duration))
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
        }
        
        Spacer()
    }
    .padding(20)
    .background(
        RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
            .fill(AppTheme.cardGradient)
    )
    .overlay {
        RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
            .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
    }
    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous))
    .shadow(color: .black.opacity(0.06), radius: 10, y: 6)
    .contentShape(Rectangle())
}
