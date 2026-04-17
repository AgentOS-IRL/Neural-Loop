//
//  CalendarDayView.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 15/01/2026.
//

import SwiftUI

struct CalendarDayView: View {
    @State private var date: Date = .now
    @State private var tasks: [SimpleEvent] = []
    @State private var habits: [SimpleEvent] = []
    @State private var workEvents: [SimpleEvent] = []

    @EnvironmentObject var model: UnifiedDataModel

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in

                DateBarView(selectedDate: date) { newDate in
                    date = newDate
                    fetchTodaysGenesysEvents(for: date) { events in
                        workEvents = events
                    }
                }

                ScrollView {
                    ZStack(alignment: .topLeading) {
                        TimeGridView()
                        WorkEventsOverlayView(date: date, events: workEvents)
                        WorkEventsOverlayView(date: date, events: tasks)
                        WorkEventsOverlayView(date: date, events: habits)
//                        TaskOverlayView(date: date, tasks: tasks)
//                        HabitOverlayView(date: date, habits: habits)
                        CurrentTimeIndicatorView(date: date)
                    }
                    .frame(height: CGFloat(hoursInDay) * hourHeight)
                }
                .onAppear {
                    DispatchQueue.main.async {
                        let hour = Calendar.neuralLoopDisplay.component(.hour, from: Date())
                        proxy.scrollTo(hour, anchor: .top)
                    }
                }

            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: SAFE_AREA_INSET)
            }
        }
        .background(AppTheme.backgroundGradient.ignoresSafeArea())
        .onAppear {
            Task {
                tasks = []
                
                for task in await model.getTasks(date: date){
                    tasks.append(SimpleEvent(
                        title: task.title, start: task.start_date!, end: task.start_date!.addingTimeInterval(task.duration ?? 900) , acceptanceStatus: nil, event_type: .task
                    ))
                }
                var _habits : [String: [Date]] = [:]
                
                _habits.merge(WaterAutoScheduling.shared.get_calendar_data()) { existing, new in
                    existing + new
                }
                
                
                
                _habits = _habits.mapValues { dates in
                    Array(Set(dates))
                }
                
                habits = []
                for (habit, dates) in _habits {
                    for date in dates {
                        habits.append(SimpleEvent(title: habit, start: date, end: date.addingTimeInterval(900), acceptanceStatus: nil, event_type: .habit))
                    }
                    
                }
                
                
                fetchTodaysGenesysEvents(for: date) { events in
                    workEvents = events
                }
            }
        }
        .environment(\.calendar, Calendar.neuralLoopDisplay)
        .environment(\.timeZone, NeuralLoopDateContext.timeZone)
    }
}
