import SwiftUI

struct DateBarView: View {
    let today = Date()
    let day = Calendar.current.component(.day, from: Date())

    @State private var selectedDate: Date
    let onSelect: (Date) -> Void

    private let calendar = Calendar.current

    init(selectedDate: Date, onSelect: @escaping (Date) -> Void) {
        _selectedDate = State(initialValue: selectedDate)
        self.onSelect = onSelect
    }

    private var dates: [Date] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: selectedDate)
        else { return [] }

        return calendar.generateDates(
            inside: monthInterval,
            matching: DateComponents(hour: 0)
        )
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(dates, id: \.self) { date in
                        let day = date.startOfDay
                        dateCell(day)
                            .id(day)
                    }
                }
                .padding(.horizontal)
            }
            .onAppear {
                DispatchQueue.main.async {
                    proxy.scrollTo(selectedDate.startOfDay, anchor: .center)
                }
            }
            .onChange(of: selectedDate) { _, newValue in
                withAnimation(.easeInOut) {
                    proxy.scrollTo(newValue.startOfDay, anchor: .center)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text(selectedDate.formatted(.dateTime.month(.wide)))
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(FleetingNotesTheme.textPrimary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)
                    .padding(.horizontal, 12)
            }

            // Trailing actions: calendar + plus
            ToolbarItem(placement: .automatic) {
                Button {
                    selectedDate = today
                    onSelect(today)
                } label: {
                    Image(systemName: "\(Calendar.current.component(.day, from: today)).calendar")
                        .font(.system(size: 21, weight: .ultraLight))
                        .foregroundStyle(FleetingNotesTheme.textSecondary)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { } label: {
                        Label("Add Task", systemImage: "checkmark.circle")
                    }
                    Button { } label: {
                        Label("Add Habit", systemImage: "repeat")
                    }
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(FleetingNotesTheme.textSecondary)
                }
            }
        }
    }

    func todayButton() -> some View {
        let today = Date()
        let day = Calendar.current.component(.day, from: today)

        return ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(FleetingNotesTheme.sectionGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(FleetingNotesTheme.borderGradient, lineWidth: 1)
                )

            Image(systemName: "\(day).calendar")
                .font(.system(size: 26, weight: .light))
                .foregroundColor(FleetingNotesTheme.textPrimary.opacity(0.5))
        }
        .frame(width: 50, height: 50)
        .onTapGesture {
            selectedDate = today
            onSelect(today)
        }
    }

    func dateCell(_ date: Date) -> some View {
        let isToday = calendar.isDateInToday(date)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)

        return VStack(spacing: 4) {
            Text(date.formatted(.dateTime.weekday(.short)))
                .font(.system(.caption, design: .rounded))
                .foregroundColor(isSelected ? .white : FleetingNotesTheme.textSecondary)

            Text(date.formatted(.dateTime.day()))
                .font(.system(.headline, design: .rounded))
        }
        .frame(width: 44, height: 60)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    isSelected
                    ? AnyShapeStyle(FleetingNotesTheme.accentGradient)
                    : isToday
                    ? AnyShapeStyle(FleetingNotesTheme.sectionGradient)
                    : AnyShapeStyle(Color.clear)
                )
        )
        .foregroundColor(isSelected ? .white : FleetingNotesTheme.textPrimary)
        .onTapGesture {
            selectedDate = date
            onSelect(date)
        }
    }
}

