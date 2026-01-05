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

struct TodoView: View {

    @State private var tasks: [Tasks] = []
    @State private var showAddTask = false
    @State private var error: String?

    var body: some View {
        NavigationView {
            ZStack {
                List(tasks, id: \.id) { task in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.title)
                            .font(.headline)

                        if let description = task.description, !description.isEmpty {
                            Text(description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Floating Add Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            showAddTask = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.black)
                                .padding()
                                .background(.white)
                                .clipShape(Circle())
                                .shadow(radius: 8)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Todos")
            .sheet(isPresented: $showAddTask) {
                AddTodoView { newTask in
                    addTask(newTask)
                }
            }
            .onAppear {
                loadTasks()
            }
        }
    }

    // MARK: - DB

    func loadTasks() {
        do {
            let manager = try DBManager.newInstance()
            tasks = try manager.fetchAllTasks()
            try manager.syncNow()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func addTask(_ task_input: TaskInput) {
        do {
            print("saving task...")
            let manager = try DBManager.newInstance()

            let task = Tasks(
                id: nil,
                title: task_input.title,
                description: task_input.description,
                priority: task_input.priority,
                is_completed: false
            )

            let savedTask = try manager.addTask(task)

            print("done saving")
            print(savedTask.id ?? "no id")   // ✅ now works

            loadTasks()
        } catch {
            print("Error saving task")
            print(error)
            self.error = error.localizedDescription
        }
    }
}
