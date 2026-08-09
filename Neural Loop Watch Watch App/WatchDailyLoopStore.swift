import Combine
import Foundation

struct WatchDailyLoopPersistence {
    private let snapshotKey = "com.neuralloop.watch.dailyLoopSnapshot"
    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func loadSnapshot() -> DailyLoopWatchSnapshot? {
        guard
            let data = defaults.data(forKey: snapshotKey),
            let snapshot = try? decoder.decode(DailyLoopWatchSnapshot.self, from: data),
            snapshot.schemaVersion == DailyLoopWatchSnapshot.currentSchemaVersion
        else {
            return nil
        }
        return snapshot
    }

    func saveSnapshot(_ snapshot: DailyLoopWatchSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }
}

@MainActor
final class WatchDailyLoopStore: ObservableObject {
    @Published private(set) var snapshot: DailyLoopWatchSnapshot?

    private let persistence: WatchDailyLoopPersistence
    private var cancellables = Set<AnyCancellable>()

    init(
        connectivity: ConnectivityManager? = nil,
        persistence: WatchDailyLoopPersistence? = nil
    ) {
        let connectivity = connectivity ?? .shared
        let persistence = persistence ?? WatchDailyLoopPersistence()
        self.persistence = persistence
        self.snapshot = persistence.loadSnapshot()

        connectivity.$lastDailyLoopSnapshot
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .filter { $0.schemaVersion == DailyLoopWatchSnapshot.currentSchemaVersion }
            .sink { [weak self] snapshot in
                self?.snapshot = snapshot
                self?.persistence.saveSnapshot(snapshot)
            }
            .store(in: &cancellables)

        // Subscribe before checking context so a disconnected launch receives
        // the most recently delivered snapshot without a race.
        connectivity.checkApplicationContext()
    }
}
