//
//  CompletedRecursiveTask.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 07/01/2026.
//

import Foundation
import RRuleKit
import SwiftData

@Model
final class CompletedRecurringTask {
    var taskId: Int64
    /// The scheduled start that identifies this specific recurring occurrence.
    /// Optional so existing records from the former day-based model migrate safely.
    var occurrenceStart: Date?
    /// The time the user actually completed the occurrence.
    var completedAt: Date

    init(taskId: Int64, occurrenceStart: Date, completedAt: Date = .now) {
        self.taskId = taskId
        self.occurrenceStart = occurrenceStart
        self.completedAt = completedAt
    }
}

/// Returns the first scheduled occurrence in `[rangeStart, rangeEnd)`.
func recurringTaskOccurrenceStart(
    for task: Tasks,
    between rangeStart: Date,
    and rangeEnd: Date
) -> Date? {
    guard
        rangeStart < rangeEnd,
        let anchor = task.start_date,
        let ruleString = task.recursion_rule,
        !ruleString.isEmpty,
        let rule = try? parse_rrule(rruleString: ruleString)
    else {
        return nil
    }

    for occurrence in rule.recurrences(of: anchor) {
        if occurrence >= rangeEnd {
            return nil
        }
        if occurrence >= rangeStart {
            return occurrence
        }
    }

    return nil
}

func recurringTaskOccurrenceStart(
    for task: Tasks,
    on date: Date,
    calendar: Calendar = .neuralLoopDisplay
) -> Date? {
    let dayStart = calendar.startOfDay(for: date)
    guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
        return nil
    }

    return recurringTaskOccurrenceStart(
        for: task,
        between: dayStart,
        and: dayEnd
    )
}

private func completionRecords(
    taskId: Int64,
    context: ModelContext
) throws -> [CompletedRecurringTask] {
    let descriptor = FetchDescriptor<CompletedRecurringTask>(
        predicate: #Predicate<CompletedRecurringTask> {
            $0.taskId == taskId
        }
    )

    return try context.fetch(descriptor)
}

private func recordMatchesOccurrence(
    _ record: CompletedRecurringTask,
    occurrenceStart: Date,
    calendar: Calendar = .neuralLoopDisplay
) -> Bool {
    if let storedOccurrenceStart = record.occurrenceStart {
        return storedOccurrenceStart == occurrenceStart
    }

    // Legacy records stored only the tap time and were matched by calendar day.
    return calendar.isDate(record.completedAt, inSameDayAs: occurrenceStart)
}

func isRecurringTaskCompleted(
    taskId: Int64,
    occurrenceStart: Date,
    completions: [CompletedRecurringTask]
) -> Bool {
    completions.contains {
        $0.taskId == taskId &&
        recordMatchesOccurrence($0, occurrenceStart: occurrenceStart)
    }
}

func isRecurringTaskCompleted(
    taskId: Int64,
    occurrenceStart: Date,
    context: ModelContext
) -> Bool {
    guard let records = try? completionRecords(taskId: taskId, context: context) else {
        return false
    }

    return records.contains {
        recordMatchesOccurrence($0, occurrenceStart: occurrenceStart)
    }
}

/// Sets one occurrence to the requested state. Repeating the same request is a no-op.
///
/// A future Supabase replacement is documented in
/// `docs/recurring-task-completion-supabase-migration.md`.
@discardableResult
func setRecurringTaskCompleted(
    taskId: Int64,
    occurrenceStart: Date,
    completed: Bool,
    context: ModelContext
) throws -> Bool {
    let matchingRecords = try completionRecords(taskId: taskId, context: context)
        .filter { recordMatchesOccurrence($0, occurrenceStart: occurrenceStart) }

    if completed {
        if let retainedRecord = matchingRecords.first {
            // Lazily upgrade a legacy day-based record to the exact occurrence key.
            retainedRecord.occurrenceStart = occurrenceStart
            for duplicate in matchingRecords.dropFirst() {
                context.delete(duplicate)
            }
        } else {
            context.insert(CompletedRecurringTask(
                taskId: taskId,
                occurrenceStart: occurrenceStart
            ))
        }
    } else {
        for record in matchingRecords {
            context.delete(record)
        }
    }

    try context.save()
    return completed
}

@discardableResult
func toggleRecurringTaskCompleted(
    taskId: Int64,
    occurrenceStart: Date,
    context: ModelContext
) throws -> Bool {
    let newState = !isRecurringTaskCompleted(
        taskId: taskId,
        occurrenceStart: occurrenceStart,
        context: context
    )

    return try setRecurringTaskCompleted(
        taskId: taskId,
        occurrenceStart: occurrenceStart,
        completed: newState,
        context: context
    )
}

func deleteRecurringTaskCompletions(
    taskId: Int64,
    context: ModelContext
) throws {
    for record in try completionRecords(taskId: taskId, context: context) {
        context.delete(record)
    }

    try context.save()
}
