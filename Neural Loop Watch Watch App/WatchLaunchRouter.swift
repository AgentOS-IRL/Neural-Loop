import Combine
import Foundation

enum WatchLaunchRoute: String, Hashable {
    case capture
    case dailyLoop
    case workout
}

@MainActor
final class WatchLaunchRouter: ObservableObject {
    @Published private(set) var requestedRoute: WatchLaunchRoute?

    private let defaults = UserDefaults(suiteName: WorkoutDisplayState.appGroupSuite)
    private let pendingRouteKey = "com.neuralloop.watch.pendingLauncherRoute.v1"

    func consumePendingRoute() {
        guard
            let rawValue = defaults?.string(forKey: pendingRouteKey),
            let route = WatchLaunchRoute(rawValue: rawValue)
        else { return }

        defaults?.removeObject(forKey: pendingRouteKey)
        requestedRoute = route
    }

    func didHandleRequestedRoute() {
        requestedRoute = nil
    }
}
