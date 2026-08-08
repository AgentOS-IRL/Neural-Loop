import Foundation
import WidgetKit

struct WatchWorkoutDisplayStateWriter {
    private let defaults: UserDefaults?
    private let widgetKind = "WorkoutComplicationWidget"

    init(defaults: UserDefaults? = UserDefaults(suiteName: WorkoutDisplayState.appGroupSuite)) {
        self.defaults = defaults
    }

    func write(snapshot: ActiveWorkoutSnapshot?) {
        guard let snapshot else {
            clear()
            return
        }

        guard let defaults else {
            print("WatchWorkoutDisplayStateWriter: App Group suite defaults unavailable")
            return
        }

        do {
            let state = snapshot.displayState(
                restEndDate: snapshot.restEndDate,
                restTotalSeconds: snapshot.restTotalSeconds
            )
            defaults.set(try JSONEncoder().encode(state), forKey: WorkoutDisplayState.userDefaultsKey)
        } catch {
            print("WatchWorkoutDisplayStateWriter: Failed to persist display state: \(error)")
        }

        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }

    func clear() {
        defaults?.removeObject(forKey: WorkoutDisplayState.userDefaultsKey)
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }
}
