import SwiftUI

struct TimeGridView: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<hoursInDay, id: \.self) { hour in
                HStack(alignment: .top) {
                    Text(timeLabel(for: hour))
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(FleetingNotesTheme.textSecondary)
                        .frame(width: 50, alignment: .trailing)

                    Rectangle()
                        .fill(FleetingNotesTheme.textSecondary.opacity(0.15))
                        .frame(height: 0.5)
                }
                .frame(height: hourHeight)
                .id(hour)
            }
        }
    }

    private func timeLabel(for hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
        return formatter.string(from: date)
    }
}

