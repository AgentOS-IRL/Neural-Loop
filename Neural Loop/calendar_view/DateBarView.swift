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
                    .font(.title3.weight(.semibold))
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
                        .foregroundStyle(.secondary.opacity(0.8))
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
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    func todayButton() -> some View {
        let today = Date()
        let day = Calendar.current.component(.day, from: today)

        return ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)

            Image(systemName: "\(day).calendar")
                .font(.system(size: 26, weight: .light))
                .foregroundColor(.white.opacity(0.5))
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
                .font(.caption)
                .foregroundColor(.gray)

            Text(date.formatted(.dateTime.day()))
                .font(.headline)
        }
        .frame(width: 44, height: 60)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    isSelected
                    ? Color.blue
                    : isToday
                    ? Color.blue.opacity(0.3)
                    : Color.clear
                )
        )
        .foregroundColor(isSelected ? .white : .primary)
        .onTapGesture {
            selectedDate = date
            onSelect(date)
        }
    }
}

