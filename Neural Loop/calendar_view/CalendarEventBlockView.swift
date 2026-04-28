import SwiftUI
import EventKit

struct CalendarEventBlockView: View {
    let event: SimpleEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            HStack(alignment: .top, spacing: 6) {
                if let icon = statusIcon {
                    Image(systemName: icon)
                        .font(.system(.caption2, design: .rounded))
                        .opacity(0.9)
                }

                Text(event.title)
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .strikethrough(isDeclined)
            }

            Text(timeRangeText)
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .opacity(0.9)

            if let statusLabel {
                Text(statusLabel)
                    .font(.system(.caption2, design: .rounded))
                    .opacity(0.75)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: eventHeight, alignment: .topLeading)
        .background(background)
        .overlay(border)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Visuals

    private var background: some View {
        ZStack {
            AppTheme.cardGradient
            
            LinearGradient(
                colors: backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.7)
        }
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(AppTheme.borderGradient, style: StrokeStyle(
                lineWidth: 1,
                dash: isTentative ? [5] : []
            ))
    }

    // MARK: - Status logic

    private var isDeclined: Bool {
        event.acceptanceStatus == .declined
    }

    private var isTentative: Bool {
        event.acceptanceStatus == .tentative
    }

    private var statusIcon: String? {
        switch event.acceptanceStatus {
        case .accepted: return "checkmark.circle.fill"
        case .tentative: return "questionmark.circle"
        case .declined: return "xmark.circle"
        case .pending: return "clock"
        default: return nil
        }
    }

    private var statusLabel: String? {
        switch event.acceptanceStatus {
        case .accepted: return "Accepted"
        case .tentative: return "Tentative"
        case .declined: return "Declined"
        case .pending: return "No response"
        default: return nil
        }
    }

    private var backgroundColors: [Color] {
        switch event.acceptanceStatus {
        case .accepted:
            return AppTheme.workEventGradientColors
        case .tentative:
            return [AppTheme.workEventGradientColors[0].opacity(0.6), AppTheme.workEventGradientColors[1].opacity(0.4)]
        case .declined:
            return [AppTheme.errorTint.opacity(0.8), AppTheme.errorTint.opacity(0.6)]
        case .pending:
            return [AppTheme.textSecondary.opacity(0.5), AppTheme.textSecondary.opacity(0.3)]
        default:
            return [event.event_type.color.opacity(0.7), event.event_type.color.opacity(0.5)]
        }
    }

    // MARK: - Layout

    private var eventHeight: CGFloat {
        let duration = max(300, Int(event.end.timeIntervalSince(event.start)))
        return max(48, CGFloat(duration) / 3600 * hourHeight)
    }

    private var timeRangeText: String {
        let calendar = Calendar.neuralLoopDisplay
        let start = eventTimeText(from: event.start)
        let end = eventTimeText(from: event.end)

        if calendar.isDate(event.start, inSameDayAs: event.end) {
            return "\(start)-\(end)"
        }

        let dateFormatter = DateFormatter.neuralLoopDisplay(dateStyle: .short, timeStyle: .none)
        return "\(start) \(dateFormatter.string(from: event.start))-\(end) \(dateFormatter.string(from: event.end))"
    }

    private func eventTimeText(from date: Date) -> String {
        let formatter = DateFormatter.neuralLoopDisplay(dateStyle: .none, timeStyle: .none)
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}
