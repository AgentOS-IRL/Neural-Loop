import SwiftUI

/// Compact sync status indicator for watch workout views.
/// Shows connectivity state, queue progress, and error conditions.
enum WatchSyncStatus: Equatable {
    case connected
    case disconnected
    case syncing
    case queued(Int)
    case failed(String)
}

struct WatchSyncStatusView: View {
    let status: WatchSyncStatus
    
    var body: some View {
        HStack(spacing: 6) {
            statusIcon
            statusText
        }
        .font(.caption2)
        .foregroundColor(statusColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.15))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .connected:
            Image(systemName: "checkmark.icloud")
        case .disconnected:
            Image(systemName: "iphone.slash")
        case .syncing:
            Image(systemName: "arrow.triangle.2.circlepath")
        case .queued:
            Image(systemName: "arrow.triangle.2.circlepath")
        case .failed:
            Image(systemName: "exclamationmark.triangle")
        }
    }
    
    @ViewBuilder
    private var statusText: some View {
        switch status {
        case .connected:
            Text("Connected")
        case .disconnected:
            Text("Disconnected")
        case .syncing:
            Text("Syncing…")
        case .queued(let count):
            Text("\(count) queued")
        case .failed(let message):
            Text(message)
                .lineLimit(1)
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

// MARK: - WatchWorkoutStore Sync Status Extension

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
