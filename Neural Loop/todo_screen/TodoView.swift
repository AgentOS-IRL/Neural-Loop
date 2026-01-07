//
//  TodoView.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 05/01/2026.
//

//
//  TodoView.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 05/01/2026.
//

import SwiftUI
import RRuleKit


func nextOccurrence(
    of rule: Calendar.RecurrenceRule,
    after now: Date = .now
) -> Date? {
    // The `recurrences(of:)` API yields an async sequence of future dates
    // starting from the given date.
    // Call `first(where:)` to get the first one strictly after `now`.
    
    return rule
        .recurrences(of: now)
        .first { $0 > now }
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



struct TodoView: View {

    @State private var tasks: [Tasks] = []
    @State private var tasksMapping: [Int64: Tasks] = [:]
    @State private var showAddTask = false
    @State private var error: String?
    @State private var dateBuckets: [DateBucket] = buildDateBuckets()
    
    @ViewBuilder
    private func upcomingTasks() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ForEach(dateBuckets) { bucket in
                    VStack(alignment: .leading, spacing: 14) {

                        // Section header (Today, Tomorrow, Thu 8 Jan, etc.)
                        bucket.title

                        // Tasks for this date bucket
                        ForEach(bucket.taskIds, id: \.self) { taskId in
                            if let task = tasksMapping[taskId] {
                                HStack(alignment: .top, spacing: 12) {

                                    // Checkbox placeholder
                                    Circle()
                                        .stroke(Color.secondary, lineWidth: 2)
                                        .frame(width: 22, height: 22)
                                        .padding(.top, 2)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(task.title)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        
                                        
                                        let start = task.start_date!
                                        let duration = task.duration!
                                        let end = start.addingTimeInterval(duration)

                                            Text(
                                                "\(start.formatted(date: .omitted, time: .shortened))–\(end.formatted(date: .omitted, time: .shortened))"
                                            )
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .contentShape(Rectangle()) // future tap support
                            }
                        }

                        // Add task row
                        HStack(spacing: 12) {
                            Circle()
                                .stroke(
                                    style: StrokeStyle(lineWidth: 2, dash: [4])
                                )
                                .foregroundColor(.secondary)
                                .frame(width: 22, height: 22)

                            Text("Add task")
                                .font(.body)
                                .foregroundColor(.secondary)

                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top)
        }
    }

    @ViewBuilder
    private func taskListView() -> some View {
        List(
            tasks,
            id: \.id
        ) { task in
            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(
                    task.title
                )
                .font(
                    .headline
                )
                
                if let description = task.description, !description.isEmpty {
                    Text(
                        description
                    )
                    .font(
                        .subheadline
                    )
                    .foregroundColor(
                        .secondary
                    )
                }
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
//                taskListView()
                upcomingTasks()
                
                // Floating Add Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            showAddTask = true
                        } label: {
                            Image(
                                systemName: "plus"
                            )
                            .font(
                                .system(
                                    size: 22,
                                    weight: .bold
                                )
                            )
                            .foregroundColor(
                                .black
                            )
                            .padding()
                            .background(
                                .white
                            )
                            .clipShape(
                                Circle()
                            )
                            .shadow(
                                radius: 8
                            )
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(
                "Todos"
            )
            .sheet(
                isPresented: $showAddTask
            ) {
                AddTodoView { newTask in
                    addTask(
                        newTask
                    )
                }
            }
            .onAppear {
                loadTasks()
                let _dateBuckets = buildDateBuckets()
                dateBuckets = attachTasksToBuckets(tasks: tasks, buckets: _dateBuckets)
                for dateBucket in dateBuckets {
                    print(
                        " \(dateBucket.start): \(dateBucket.end) -- \(dateBucket.taskIds.count) tasks"
                    )
                }
            }
        }
    }
    
    // MARK: - DB
    
    func loadTasks() {
        do {
            let manager = try DBManager.newInstance()
            tasks = try manager
                .fetchAllTasks()
            for task in tasks {
                tasksMapping[task.id!] = task
            }
            try manager
                .syncNow(
                    
                )
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func addTask(
        _ task_input: TaskInput
    ) {
        do {
            print(
                "saving task..."
            )
            let manager = try DBManager.newInstance()
            var rruleString = ""
            if task_input.schedule!.recurrence != nil {
                var rule = task_input.schedule!.recurrence!
                let formatter = RecurrenceRuleRFC5545FormatStyle(calendar: .current)
                rruleString = formatter.format(rule)
            }
            
            let task = Tasks(
                
                id: nil,
                title: task_input.title,
                description: task_input.description,
                priority: task_input.priority,
                is_completed: false,
                is_deadline: task_input.is_deadline,
                recursion_rule: rruleString,
                start_date: task_input.schedule?.timing?.start,
                duration: task_input.schedule?.timing?.duration,
                
                
            )
            
            let savedTask = try manager.addTask(
                task
            )
            
            print(
                "done saving"
            )
            print(
                savedTask.id ?? "no id"
            )   // ✅ now works
            if savedTask.id == nil {
                return
            }
            
            if task_input.schedule != nil {
                if task_input.schedule!.timing != nil && task_input.schedule!.recurrence != nil {
                    do {
                        var rule = task_input.schedule!.recurrence!
                        
                        try NeuralLoopCalendarService.shared
                            .addRecurringEvent(
                                taskId: Int(savedTask.id!) ,
                                title: task.title,
                                timing: task_input.schedule!.timing!,
                                recurrenceRule: rule,
                                notes: task.description,
                            )
                        if let next = nextOccurrence(of: rule) {
                            print("Next occurrence:", next)
                        } else {
                                print("No next occurrence found")
                            }
                    } catch {
                        print(
                            "❌ Calendar preview failed:",
                            error
                        )
                    }
                }
                else if task_input.schedule!.timing != nil  {
                    do {
                        try NeuralLoopCalendarService.shared
                            .addEvent(
                                taskId: Int(savedTask.id!) ,
                                title: task.title,
                                timing: task_input.schedule!.timing!,
                                
                                notes: task.description,
                            )
                    } catch {
                        print(
                            "❌ Calendar preview failed:",
                            error
                        )
                    }
                }
            }
            
            loadTasks()
        } catch {
            print(
                "Error saving task"
            )
            print(
                error
            )
            self.error = error.localizedDescription
        }
    }
}
