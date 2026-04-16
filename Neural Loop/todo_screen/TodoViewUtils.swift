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
    let formatter = RecurrenceRuleRFC5545FormatStyle(calendar: .current)
    let rruleString = formatter.format(rule)
    
    return rruleString
}

func parse_rrule(rruleString: String) throws -> Calendar.RecurrenceRule {
    let parser = RecurrenceRuleRFC5545FormatStyle(calendar: .current)
    
    return try parser.parse(rruleString)
}

enum ViewMode {
    case menu
    case today
    case upcoming
    case all
    case inbox
    case completed
    case new
}


func rebuildDateBuckets(tasks: [Tasks]) -> [DateBucket] {
    let calendar = Calendar.current

    let todayStart = calendar.startOfDay(.now)
    let todayEnd = calendar.endOfDay(.now)
    var _dateBuckets = buildShortRangeDateBuckets()
    
    var today_bucket = DateBucket(
        title: AnyView( Text("Today")
                .font(.system(.title3, design: .rounded, weight: .bold))
            .foregroundColor(FleetingNotesTheme.textPrimary))
            ,
        start: todayStart,
        end: todayEnd,
        type: .today
    )

    var inbox_bucket = DateBucket(title: AnyView( Text("Inbox")
        .font(.system(.title3, design: .rounded, weight: .bold))
        .foregroundColor(FleetingNotesTheme.textPrimary)), start: .distantPast, end: .now, type: .inbox)

    var overdue_bucket = DateBucket(title: AnyView( Text("Overdue")
        .font(.system(.title3, design: .rounded, weight: .bold))
        .foregroundColor(FleetingNotesTheme.errorTint)), start: .distantPast, end: .now, type: .overdue)
    var completed_bucket = DateBucket(title: AnyView( Text("Completed")
        .font(.system(.title3, design: .rounded, weight: .bold))
        .foregroundColor(FleetingNotesTheme.textPrimary)), start: .distantPast, end: .distantFuture, type: .completed)

    for task in tasks {
        if task.start_date == nil {
            inbox_bucket.appendTask(task)
        }
        else if task.is_completed {
            completed_bucket.appendTask(task)
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
                .foregroundColor(FleetingNotesTheme.textPrimary)
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
                FleetingNotesTheme.textSecondary,
                style: StrokeStyle(lineWidth: 1.5, dash: [4])
            )
            .frame(width: 18, height: 18)
        
        Text("Add task")
            .font(.system(.body, design: .rounded, weight: .medium))
            .foregroundColor(FleetingNotesTheme.textSecondary)
        
        Spacer()
    }
    .padding(20)
    .background(
        RoundedRectangle(cornerRadius: FleetingNotesTheme.Metrics.cardCornerRadius, style: .continuous)
            .fill(FleetingNotesTheme.sectionGradient)
    )
    .overlay {
        RoundedRectangle(cornerRadius: FleetingNotesTheme.Metrics.cardCornerRadius, style: .continuous)
            .strokeBorder(FleetingNotesTheme.borderGradient, lineWidth: 1)
    }
}


func taskRowView(task: Tasks, strikeThrough: Bool = false) -> some View {
    HStack(alignment: .top, spacing: 14) {
        // Checkbox placeholder
        Circle()
            .stroke(FleetingNotesTheme.accentGradient, lineWidth: 2)
            .frame(width: 22, height: 22)
            .padding(.top, 2)
        
        VStack(alignment: .leading, spacing: 6) {
            Text(task.title)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .strikethrough(strikeThrough)
                .foregroundColor(FleetingNotesTheme.textPrimary)
            
            let start = task.start_date
            let duration = task.duration
            var end: Date? {
                guard let start = start,
                      let duration = duration else {
                    return nil
                }
                return start.addingTimeInterval(duration)
            }
            
            if end == nil {
                Text("no due date")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundColor(FleetingNotesTheme.textSecondary)
            }
            else {
                HStack(spacing: 4) {
                    Text(start!.formatted(date: .omitted, time: .shortened))
                    Text("–")
                    Text(end!.formatted(date: .omitted, time: .shortened))
                }
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundColor(FleetingNotesTheme.textSecondary)
            }
        }
        
        Spacer()
    }
    .padding(20)
    .background(
        RoundedRectangle(cornerRadius: FleetingNotesTheme.Metrics.cardCornerRadius, style: .continuous)
            .fill(FleetingNotesTheme.cardGradient)
    )
    .overlay {
        RoundedRectangle(cornerRadius: FleetingNotesTheme.Metrics.cardCornerRadius, style: .continuous)
            .strokeBorder(FleetingNotesTheme.borderGradient, lineWidth: 1)
    }
    .clipShape(RoundedRectangle(cornerRadius: FleetingNotesTheme.Metrics.cardCornerRadius, style: .continuous))
    .shadow(color: .black.opacity(0.06), radius: 10, y: 6)
    .contentShape(Rectangle())
}
