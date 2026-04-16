import SwiftUI
import EventKit

struct WorkEventBlockView: View {
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

            if let statusLabel {
                Text(statusLabel)
                    .font(.system(.caption2, design: .rounded))
                    .opacity(0.75)
            }
        }
        .padding(10)
        .frame(height: eventHeight, alignment: .topLeading)
        .background(background)
        .overlay(border)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Visuals

    private var background: some View {
        ZStack {
            FleetingNotesTheme.cardGradient
            
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
            .strokeBorder(FleetingNotesTheme.borderGradient, style: StrokeStyle(
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
            return [Color(red: 0.14, green: 0.49, blue: 0.53), Color(red: 0.22, green: 0.67, blue: 0.60)]
        case .tentative:
            return [Color(red: 0.14, green: 0.49, blue: 0.53).opacity(0.6), Color(red: 0.22, green: 0.67, blue: 0.60).opacity(0.4)]
        case .declined:
            return [FleetingNotesTheme.errorTint.opacity(0.8), FleetingNotesTheme.errorTint.opacity(0.6)]
        case .pending:
            return [FleetingNotesTheme.textSecondary.opacity(0.5), FleetingNotesTheme.textSecondary.opacity(0.3)]
        default:
            return [event.event_type.color.opacity(0.7), event.event_type.color.opacity(0.5)]
        }
    }

    // MARK: - Layout

    private var eventHeight: CGFloat {
        let duration = max(300, Int(event.end.timeIntervalSince(event.start)))
        return CGFloat(duration) / 3600 * hourHeight
    }
}
