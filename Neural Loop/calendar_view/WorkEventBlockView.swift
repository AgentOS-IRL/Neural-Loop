import SwiftUI
import EventKit

struct WorkEventBlockView: View {
    let event: SimpleEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            HStack(alignment: .top, spacing: 6) {
                if let icon = statusIcon {
                    Image(systemName: icon)
                        .font(.caption2)
                        .opacity(0.9)
                }

                Text(event.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .strikethrough(isDeclined)
            }

            if let statusLabel {
                Text(statusLabel)
                    .font(.caption2)
                    .opacity(0.75)
            }
        }
        .padding(10)
        .frame(height: eventHeight, alignment: .topLeading)
        .background(background)
        .overlay(border)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Visuals

    private var background: some View {
        LinearGradient(
            colors: backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: 10)
            .strokeBorder(borderColor, style: StrokeStyle(
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
            return [.purple, .purple.opacity(0.8)]
        case .tentative:
            return [.purple.opacity(0.7), .purple.opacity(0.5)]
        case .declined:
            return [.gray.opacity(0.6), .gray.opacity(0.4)]
        case .pending:
            return [.purple.opacity(0.4), .purple.opacity(0.3)]
        default:
            return [event.event_type.color.opacity(0.5), event.event_type.color.opacity(0.35)]
        }
    }

    private var borderColor: Color {
        isDeclined ? .gray.opacity(0.6) : .white.opacity(0.25)
    }

    // MARK: - Layout

    private var eventHeight: CGFloat {
        let duration = max(300, Int(event.end.timeIntervalSince(event.start)))
        return CGFloat(duration) / 3600 * hourHeight
    }
}
