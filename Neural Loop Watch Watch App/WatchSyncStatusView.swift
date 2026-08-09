import SwiftUI

/// Compact exception-only sync status for watch workout views.
enum WatchSyncStatus: Equatable {
    case connected
    case disconnected
    case syncing
    case queued(Int)
    case failed(String)

    var shouldDisplay: Bool {
        self != .connected
    }
}

struct WatchSyncStatusView: View {
    let status: WatchSyncStatus
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if status.shouldDisplay {
            HStack(spacing: 6) {
                statusIcon
                statusText
                Spacer(minLength: 0)
            }
            .font(.caption)
            .foregroundStyle(statusColor)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                statusColor.opacity(reduceTransparency ? 0.32 : 0.15),
                in: RoundedRectangle(cornerRadius: 9)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityText)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .connected:
            EmptyView()
        case .disconnected:
            Image(systemName: "iphone.slash")
        case .syncing, .queued:
            Image(systemName: "arrow.triangle.2.circlepath")
        case .failed:
            Image(systemName: "exclamationmark.triangle")
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch status {
        case .connected:
            EmptyView()
        case .disconnected:
            Text("Offline — changes will sync later")
        case .syncing:
            Text("Syncing changes…")
        case .queued(let count):
            Text("\(count) change\(count == 1 ? "" : "s") pending")
        case .failed(let message):
            Text(message)
                .lineLimit(2)
        }
    }

    private var accessibilityText: String {
        switch status {
        case .connected: return "Workout is synced"
        case .disconnected: return "iPhone offline. Changes will sync later"
        case .syncing: return "Syncing workout changes"
        case .queued(let count): return "\(count) workout changes pending"
        case .failed(let message): return "Workout sync failed. \(message)"
        }
    }

    private var statusColor: Color {
        switch status {
        case .connected: return .green
        case .disconnected: return .orange
        case .syncing: return .blue
        case .queued: return .yellow
        case .failed: return .red
        }
    }
}

extension WatchWorkoutStore {
    var syncStatus: WatchSyncStatus {
        if let error = finishError { return .failed(error) }
        if !connectivityManager.isReachable { return .disconnected }
        if isFlushing { return .syncing }
        if pendingActionCount > 0 { return .queued(pendingActionCount) }
        return .connected
    }
}

#Preview {
    VStack(spacing: 8) {
        WatchSyncStatusView(status: .connected)
        WatchSyncStatusView(status: .disconnected)
        WatchSyncStatusView(status: .syncing)
        WatchSyncStatusView(status: .queued(3))
        WatchSyncStatusView(status: .failed("Save failed"))
    }
}
