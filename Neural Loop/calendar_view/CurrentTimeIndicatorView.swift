import SwiftUI
import Combine

struct CurrentTimeIndicatorView: View {
    let date: Date
    @State private var now = Date()

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        if Calendar.current.isDateInToday(date) {
            HStack(spacing: 0) {

                // Time capsule
                Text(timeString(from: now))
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(FleetingNotesTheme.accentGradient)
                    .clipShape(Capsule())

                // Continuous themed line
                Rectangle()
                    .fill(FleetingNotesTheme.accentGradient)
                    .frame(height: 1)
            }
            .offset(y: yOffset)
            .padding(.leading, 8)
            .onReceive(timer) { now = $0 }
        }
    }

    private var yOffset: CGFloat {
        let components = Calendar.current.dateComponents([.hour, .minute], from: now)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0

        return CGFloat(hour) * hourHeight + CGFloat(minute) / 60 * hourHeight + hourHeight/2
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

