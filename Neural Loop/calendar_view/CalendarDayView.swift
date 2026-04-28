//
//  CalendarDayView.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 15/01/2026.
//

import SwiftUI

struct CalendarDayView: View {
    @State private var date: Date = .now
    @State private var events: [SimpleEvent] = []

    @EnvironmentObject var model: UnifiedDataModel

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in

                DateBarView(selectedDate: date) { newDate in
                    date = newDate
                    reloadEvents(for: newDate)
                }

                ScrollView {
                    ZStack(alignment: .topLeading) {
                        TimeGridView()
                        CalendarEventsOverlayView(date: date, events: events)
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
            reloadEvents(for: date)
        }
        .environment(\.calendar, Calendar.neuralLoopDisplay)
        .environment(\.timeZone, NeuralLoopDateContext.timeZone)
    }

    private func reloadEvents(for date: Date) {
        Task {
            events = await model.getCalendarEvents(for: date)
        }
    }
}
