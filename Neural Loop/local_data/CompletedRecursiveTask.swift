//
//  CompletedRecursiveTask.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 07/01/2026.
//

import Foundation
import SwiftData

@Model
final class CompletedRecurringTask {
    var taskId: Int64
    var completedAt: Date

    init(taskId: Int64, completedAt: Date) {
        self.taskId = taskId
        self.completedAt = completedAt
    }
}

func markRecurringTaskCompleted(
    taskId: Int64,
    date: Date,
    context: ModelContext
) {
    let record = CompletedRecurringTask(
        taskId: taskId,
        completedAt: date
    )

    context.insert(record)
    try? context.save()
}

func completedTasks(
    on date: Date,
    context: ModelContext
) -> [Int64] {

    let start = Calendar.current.startOfDay(for: date)
    let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!

    let descriptor = FetchDescriptor<CompletedRecurringTask>(
        predicate: #Predicate<CompletedRecurringTask> {
            $0.completedAt >= start &&
            $0.completedAt < end
        }
    )

    return (try? context.fetch(descriptor))?.map(\.taskId) ?? []
}

func deleteCompletion(
    taskId: Int64,
    on date: Date,
    context: ModelContext
) throws {

    let start = Calendar.current.startOfDay(for: date)
    let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!

    let descriptor = FetchDescriptor<CompletedRecurringTask>(
        predicate: #Predicate<CompletedRecurringTask> {
            $0.taskId == taskId &&
            $0.completedAt >= start &&
            $0.completedAt < end
        }
    )

    let records = try context.fetch(descriptor)

    for record in records {
        context.delete(record)
    }

    try context.save()
}
