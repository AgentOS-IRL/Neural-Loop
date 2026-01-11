//
//  TodoViewUtils.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 10/01/2026.
//

import SwiftUI
import RRuleKit

func nextOccurrence(
    of rule: Calendar.RecurrenceRule,
    after now: Date = .now
) -> Date? {
    print("In nextOccurrence, Interval: \(rule.interval)")

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
}



func deleteTask(task: Tasks) async {
    guard let id = task.id else { return }
    do {
        let manager = DBManager.newInstance()
        try await manager.deleteTask(id: id)
        
    } catch {
        print("Error deleting task", error)
        
    }
}

func saveTask(_ task: Tasks) async {
    do {
        let manager = DBManager.newInstance()
        try await manager.addTask(task)
    }
    catch {
        print("Error saving task", error)
    }
}

func updateTask(task: Tasks, modified_task: Tasks) async {
    do {
        let manager = DBManager.newInstance()
        if task != modified_task {
            try await manager.updateTask(modified_task)
        }
    }
    catch {
        print("Error updating task", error)
    }
}

func rebuildDateBuckets(tasks: [Tasks]) -> [DateBucket] {
    var _dateBuckets = buildShortRangeDateBuckets()

    var inbox_bucket = DateBucket(title: AnyView( Text("Inbox")
        .font(.title3.weight(.semibold))
        .foregroundColor(.primary)), start: .distantPast, end: .now, type: .inbox)

    var overdue_bucket = DateBucket(title: AnyView( Text("Overdue")
        .font(.title3.weight(.semibold))
        .foregroundColor(.primary)), start: .distantPast, end: .now, type: .overdue)
    var completed_bucket = DateBucket(title: AnyView( Text("Completed")
        .font(.title3.weight(.semibold))
        .foregroundColor(.primary)), start: .distantPast, end: .distantFuture, type: .completed)

    for task in tasks {
        if task.start_date == nil {
            inbox_bucket.ids.append(task.id!)
        }
        else if task.is_completed {
            completed_bucket.ids.append(task.id!)
        }
        else if (task.recursion_rule == "" || task.recursion_rule == nil) && task.start_date != nil && task.start_date! < Date() {
                overdue_bucket.ids.append(task.id!)

        }
        else {
            _dateBuckets = attachTaskToBuckets(task: task, buckets: _dateBuckets)
        }
    }

    return [inbox_bucket, overdue_bucket, completed_bucket] + _dateBuckets
}

func addTaskRowView() -> some View {
    HStack(spacing: 12) {
        Circle()
            .stroke(
                style: StrokeStyle(lineWidth: 2, dash: [4])
            )
            .foregroundColor(.secondary)
            .frame(width: 18, height: 18)
        
        Text("Add task")
            .font(.body)
            .foregroundColor(.secondary)
        
        Spacer()
    }
    .padding(.vertical, 8)
}


func taskRowView(task: Tasks, strikeThrough: Bool = false) -> some View {
    
    HStack(alignment: .top, spacing: 12) {
        
        // Checkbox placeholder
        Circle()
            .stroke(Color.secondary, lineWidth: 2)
            .frame(width: 22, height: 22)
            .padding(.top, 2)
        
        VStack(alignment: .leading, spacing: 4) {
            Text(task.title)
                .font(.body)
                .strikethrough(strikeThrough)
                .foregroundColor(.primary)
            
            
            let start = task.start_date ?? nil
            let duration = task.duration ?? nil
            var end: Date? {
                guard let start = task.start_date,
                      let duration = task.duration else {
                    return nil
                }
                return start.addingTimeInterval(duration)
            }
            
            if end == nil {
                Text("no due date")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            else {
                
                HStack(spacing: 4) {
                    Text(start!.formatted(date: .omitted, time: .shortened))
                    Text("–")
                    Text(end!.formatted(date: .omitted, time: .shortened))
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
        }
        
        Spacer()
    }
    .padding(.vertical, 8)
    .contentShape(Rectangle()) // future tap support
    
}
