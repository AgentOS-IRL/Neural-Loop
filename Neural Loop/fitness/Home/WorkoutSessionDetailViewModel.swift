import Foundation
import SwiftUI

@MainActor
class WorkoutSessionDetailViewModel: ObservableObject {
    enum State {
        case loading
        case loaded(WorkoutSessionDetail)
        case error(String)
    }

    @Published var state: State = .loading
    let sessionId: Int64
    private let dataManager: WorkoutDataManaging

    init(sessionId: Int64, dataManager: WorkoutDataManaging) {
        self.sessionId = sessionId
        self.dataManager = dataManager
    }

    func load() async {
        state = .loading
        do {
            let detail = try await dataManager.fetchWorkoutSessionDetail(sessionId: sessionId)
            state = .loaded(detail)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}
