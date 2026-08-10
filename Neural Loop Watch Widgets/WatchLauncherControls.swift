import AppIntents
import Foundation
import SwiftUI
import WidgetKit

private enum WatchLauncherRoute: String {
    case capture
    case dailyLoop
    case workout

    static let appGroupSuite = "group.com.sanjeevhalyal.Neural-Loop"
    static let pendingRouteKey = "com.neuralloop.watch.pendingLauncherRoute.v1"

    func persist() {
        UserDefaults(suiteName: Self.appGroupSuite)?.set(rawValue, forKey: Self.pendingRouteKey)
    }
}

struct LaunchCaptureIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Capture"
    static let description = IntentDescription("Opens note capture in Neural Loop.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        WatchLauncherRoute.capture.persist()
        return .result()
    }
}

struct LaunchDailyLoopIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Daily Loop"
    static let description = IntentDescription("Opens tasks and habits in Neural Loop.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        WatchLauncherRoute.dailyLoop.persist()
        return .result()
    }
}

struct LaunchWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Workout"
    static let description = IntentDescription("Opens the workout experience in Neural Loop.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        WatchLauncherRoute.workout.persist()
        return .result()
    }
}

struct CaptureLauncherControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "NeuralLoopCaptureControl") {
            ControlWidgetButton(action: LaunchCaptureIntent()) {
                Label("Capture", systemImage: "square.and.pencil")
            }
            .tint(.orange)
        }
        .displayName("Capture")
        .description("Open Neural Loop capture.")
    }
}

struct DailyLoopLauncherControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "NeuralLoopDailyLoopControl") {
            ControlWidgetButton(action: LaunchDailyLoopIntent()) {
                Label("Daily Loop", systemImage: "checklist")
            }
            .tint(.cyan)
        }
        .displayName("Daily Loop")
        .description("Open today's tasks and habits.")
    }
}

struct WorkoutLauncherControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "NeuralLoopWorkoutControl") {
            ControlWidgetButton(action: LaunchWorkoutIntent()) {
                Label("Workout", systemImage: "figure.strengthtraining.traditional")
            }
            .tint(.green)
        }
        .displayName("Workout")
        .description("Open the Neural Loop workout experience.")
    }
}
