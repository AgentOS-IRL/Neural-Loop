//
//  CalendarDayView.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 15/01/2026.
//

import SwiftUI

struct CalendarDayView: View {
    @State private var date: Date = .now
    @State private var tasks: [Tasks] = []
    @State private var habits: [String: [Date]] = [:]
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
                        TaskOverlayView(date: date, tasks: tasks)
                        HabitOverlayView(date: date, habits: habits)
                        CurrentTimeIndicatorView(date: date)
                    }
                    .frame(height: CGFloat(hoursInDay) * hourHeight)
                }
                .onAppear {
                    DispatchQueue.main.async {
                        let hour = Calendar.current.component(.hour, from: Date())
                        proxy.scrollTo(hour, anchor: .top)
                    }
                }

            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: SAFE_AREA_INSET)
            }
        }
        .background(Color.black)
        .onAppear {
            Task {
                tasks = await model.getTasks(date: date)
                habits = WaterAutoScheduling.shared.get_calendar_data()
                fetchTodaysGenesysEvents() { events in
                    workEvents = events
                }
            }
        }
    }
}
