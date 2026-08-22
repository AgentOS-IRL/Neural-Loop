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
    case inProcess
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
            if recurringTaskOccurrenceStart(for: task, on: .now, calendar: calendar) != nil {
                today_bucket.appendTask(task)
            }
            _dateBuckets = attachTaskToBuckets(task: task, buckets: _dateBuckets)
        }
    }

    return [inbox_bucket, today_bucket, overdue_bucket, completed_bucket] + _dateBuckets
}

func buildInProcessTaskBucket(
    from tasks: [Tasks],
    excludingTaskIDs: Set<Int64> = []
) -> DateBucket {
    var inProcessBucket = DateBucket(
        title: AnyView(
            Text("In Process")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
        ),
        start: .distantPast,
        end: .distantFuture,
        type: .inProcess
    )

    var seenTaskIDs = excludingTaskIDs

    for task in tasks where !task.is_completed {
        if let taskID = task.id {
            guard seenTaskIDs.insert(taskID).inserted else { continue }
        }

        inProcessBucket.appendTask(task)
    }

    return inProcessBucket
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

// MARK: - Deadline Urgency

private enum DeadlineUrgency {
    case overdue          // past deadline
    case critical         // < 1 hour remaining
    case urgent           // < 6 hours remaining
    case approaching      // < 24 hours remaining
    case comfortable      // < 3 days remaining
    case relaxed          // 3+ days remaining

    var tintColor: Color {
        switch self {
        case .overdue:     return AppTheme.errorTint
        case .critical:    return Color(red: 0.85, green: 0.25, blue: 0.18)   // vivid red
        case .urgent:      return Color(red: 0.93, green: 0.55, blue: 0.14)   // warm orange
        case .approaching: return AppTheme.warningTint                         // amber
        case .comfortable: return AppTheme.accentColor                         // teal
        case .relaxed:     return AppTheme.successTint                         // green/mint
        }
    }

    var iconName: String {
        switch self {
        case .overdue:     return "exclamationmark.circle.fill"
        case .critical:    return "flame.fill"
        case .urgent:      return "clock.badge.exclamationmark.fill"
        case .approaching: return "clock.fill"
        case .comfortable: return "clock"
        case .relaxed:     return "checkmark.circle"
        }
    }
}

private struct TaskDeadlineCountdown {
    let text: String
    let urgency: DeadlineUrgency
}

/// Builds a compact, human-readable countdown string with hours and minutes,
/// a negative prefix when overdue, and urgency tier for color mapping.
private func compactDeadlineCountdown(
    targetDate: Date?,
    isDeadlineEnabled: Bool,
    now: Date = .now
) -> TaskDeadlineCountdown? {
    guard isDeadlineEnabled, let targetDate else {
        return nil
    }

    let delta = targetDate.timeIntervalSince(now)
    let isOverdue = delta < 0
    let totalSeconds = abs(delta)

    // Under a minute – show "now" or "<1m"
    if totalSeconds < 60 {
        return .init(
            text: isOverdue ? "now" : "<1m",
            urgency: isOverdue ? .overdue : .critical
        )
    }

    let totalMinutes = Int(totalSeconds / 60)
    let totalHours   = totalMinutes / 60
    let days         = totalHours / 24
    let hours        = totalHours % 24
    let minutes      = totalMinutes % 60

    // Build the time string showing both hours and minutes when relevant.
    var parts: [String] = []
    if days > 0   { parts.append("\(days)d") }
    if hours > 0  { parts.append("\(hours)h") }
    if minutes > 0 && days == 0 { parts.append("\(minutes)m") }  // omit minutes when days shown

    let core = parts.isEmpty ? "<1m" : parts.joined(separator: " ")

    // Determine urgency tier
    let urgency: DeadlineUrgency
    if isOverdue {
        urgency = .overdue
    } else if totalHours < 1 {
        urgency = .critical
    } else if totalHours < 6 {
        urgency = .urgent
    } else if totalHours < 24 {
        urgency = .approaching
    } else if days < 3 {
        urgency = .comfortable
    } else {
        urgency = .relaxed
    }

    let text = isOverdue ? "-\(core)" : core
    return .init(text: text, urgency: urgency)
}

func taskRowView(task: Tasks, strikeThrough: Bool = false, noteCount: Int = 0) -> some View {
    let deadlineCountdown = compactDeadlineCountdown(
        targetDate: task.start_date,
        isDeadlineEnabled: task.is_deadline
    )

    return HStack(alignment: .top, spacing: 14) {
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

            HStack(spacing: 8) {
                Text(todoDueDateText(start: task.start_date, duration: task.duration))
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)

                if noteCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "note.text")
                        Text("\(noteCount)")
                    }
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.accentColor.opacity(0.12), in: Capsule())
                    .accessibilityLabel("\(noteCount) linked \(noteCount == 1 ? "note" : "notes")")
                }
            }
        }

        Spacer()

        if let countdown = deadlineCountdown {
            HStack(spacing: 4) {
                Image(systemName: countdown.urgency.iconName)
                    .font(.system(size: 10, weight: .bold))
                Text(countdown.text)
                    .font(.system(.caption2, design: .rounded, weight: .bold))
            }
            .foregroundColor(countdown.urgency.tintColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(countdown.urgency.tintColor.opacity(0.12))
            )
            .overlay(
                Capsule()
                    .strokeBorder(countdown.urgency.tintColor.opacity(0.22), lineWidth: 0.5)
            )
        }

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
