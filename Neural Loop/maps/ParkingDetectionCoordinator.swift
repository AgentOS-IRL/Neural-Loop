import Combine
import CoreLocation
import CoreMotion
import Foundation
import Network
import SwiftData
import UIKit

@MainActor
final class ParkingDetectionCoordinator: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var phase: ParkingDetectionPhase = .idle
    @Published private(set) var session: ParkingSessionState?
    @Published private(set) var locationAuthorizationStatus: CLAuthorizationStatus
    @Published private(set) var motionAuthorizationStatus: CMAuthorizationStatus
    @Published private(set) var motionIsAvailable = CMMotionActivityManager.isActivityAvailable()
    @Published var latestOutcomeMessage: String?
    @Published private(set) var latestOutcomeNeedsSettings = false
    @Published var pendingDeepLinkClientEventID: UUID?

    private enum StorageKey {
        static let onboardingSeen = "parkingDetection.onboardingSeen"
        static let enabled = "parkingDetection.enabled"
        static let activeSession = "parkingDetection.activeSession.v1"
        static let latestOutcome = "parkingDetection.latestOutcome"
        static let latestOutcomeNeedsSettings = "parkingDetection.latestOutcomeNeedsSettings"
    }

    private let manager: DBManager
    private let mapsStore: MapsStore
    private let defaults: UserDefaults
    private let locationManager = CLLocationManager()
    private let motionManager = CMMotionActivityManager()
    private let monitorQueue = DispatchQueue(label: "parking-detection.connectivity")
    private let connectivityMonitor = NWPathMonitor()

    private var modelContext: ModelContext?
    private var locationTask: Task<Void, Never>?
    private var deadlineTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    private var backgroundActivitySession: CLBackgroundActivitySession?
    private var serviceSession: CLServiceSession?
    private var permissionContinuation: CheckedContinuation<Bool, Never>?
    private var isConfigured = false
    private var isSynchronizing = false

    init(
        manager: DBManager,
        mapsStore: MapsStore,
        defaults: UserDefaults = .standard
    ) {
        self.manager = manager
        self.mapsStore = mapsStore
        self.defaults = defaults
        locationAuthorizationStatus = CLLocationManager().authorizationStatus
        motionAuthorizationStatus = CMMotionActivityManager.authorizationStatus()
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.activityType = .automotiveNavigation
        locationManager.pausesLocationUpdatesAutomatically = false

        connectivityMonitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor [weak self] in
                await self?.retryPendingSynchronization(force: false)
            }
        }
        connectivityMonitor.start(queue: monitorQueue)
    }

    deinit {
        connectivityMonitor.cancel()
    }

    var onboardingSeen: Bool {
        defaults.bool(forKey: StorageKey.onboardingSeen)
    }

    var isEnabled: Bool {
        defaults.bool(forKey: StorageKey.enabled)
    }

    var shouldPresentOnboarding: Bool {
        !onboardingSeen
    }

    var permissionSummary: String {
        if !motionIsAvailable { return "Motion detection unavailable" }
        if locationAuthorizationStatus == .denied || locationAuthorizationStatus == .restricted {
            return "Location access is off"
        }
        if motionAuthorizationStatus == .denied || motionAuthorizationStatus == .restricted {
            return "Motion access is off"
        }
        if locationIsUsable,
           motionAuthorizationStatus == .authorized {
            return "Ready"
        }
        return "Permission not granted"
    }

    var locationIsUsable: Bool {
        locationAuthorizationStatus == .authorizedWhenInUse ||
        locationAuthorizationStatus == .authorizedAlways
    }

    func configure(modelContext: ModelContext) {
        guard !isConfigured else { return }
        isConfigured = true
        self.modelContext = modelContext
        latestOutcomeMessage = defaults.string(forKey: StorageKey.latestOutcome)
        latestOutcomeNeedsSettings = defaults.bool(forKey: StorageKey.latestOutcomeNeedsSettings)
        refreshPermissionStatuses()
        purgeOldDiagnostics()
        materializeLocalExpiry(at: .now)
        refreshMapsOverlay()
        restorePersistedSession()
        Task { await retryPendingSynchronization(force: false) }
    }

    func refreshPermissionStatuses() {
        locationAuthorizationStatus = locationManager.authorizationStatus
        motionAuthorizationStatus = CMMotionActivityManager.authorizationStatus()
        motionIsAvailable = CMMotionActivityManager.isActivityAvailable()
    }

    func enableFromUserAction() async -> Bool {
        defaults.set(true, forKey: StorageKey.onboardingSeen)
        motionIsAvailable = CMMotionActivityManager.isActivityAvailable()
        guard motionIsAvailable else {
            defaults.set(false, forKey: StorageKey.enabled)
            finishWithoutSession(reason: .motionUnavailable)
            return false
        }

        let locationGranted = await requestLocationWhenInUseIfNeeded()
        let motionGranted = await requestMotionIfNeeded()
        refreshPermissionStatuses()
        let granted = locationGranted && motionGranted
        defaults.set(granted, forKey: StorageKey.enabled)
        if !granted {
            finishWithoutSession(reason: .permissionDenied)
        }
        objectWillChange.send()
        return granted
    }

    func declineOnboarding() {
        defaults.set(true, forKey: StorageKey.onboardingSeen)
        defaults.set(false, forKey: StorageKey.enabled)
        objectWillChange.send()
    }

    func setEnabled(_ enabled: Bool) async {
        defaults.set(true, forKey: StorageKey.onboardingSeen)
        if enabled {
            _ = await enableFromUserAction()
        } else {
            defaults.set(false, forKey: StorageKey.enabled)
            if phase.isActive {
                stop(reason: .userCancelled)
            }
            objectWillChange.send()
        }
    }

    func openDirectly(_ place: MapPlaceItem, with provider: ExternalMapProvider) async {
        guard let url = provider.url(for: place) else { return }
        _ = await openExternalURL(url)
    }

    func openEligiblePlace(_ place: MapPlaceItem, with provider: ExternalMapProvider) async {
        guard place.kind == .saved, isEnabled else {
            await openDirectly(place, with: provider)
            return
        }

        refreshPermissionStatuses()
        guard locationIsUsable,
              motionAuthorizationStatus == .authorized,
              motionIsAvailable else {
            finishWithoutSession(reason: .permissionDenied)
            await openDirectly(place, with: provider)
            return
        }

        if phase == .driving || phase == .confirmingParking {
            await openDirectly(place, with: provider)
            return
        }

        guard let placeID = place.remoteID, let url = provider.url(for: place) else {
            await openDirectly(place, with: provider)
            return
        }

        if phase == .waitingForDrive {
            stop(reason: .supersededByNewOpen)
        }

        var prepared = ParkingSessionState(
            source: .place(placeID),
            provider: provider
        )
        prepared.phase = .preparing
        session = prepared
        phase = .preparing
        persistSession()
        startMonitoring()

        let didOpen = await openExternalURL(url)
        guard didOpen else {
            stop(reason: .externalOpenFailed)
            return
        }

        transition(to: .waitingForDrive) { state in
            state.waitingDeadline = Date().addingTimeInterval(30 * 60)
        }
    }

    func stopFromUser() {
        stop(reason: .userCancelled)
    }

    func dismissLatestOutcome() {
        latestOutcomeMessage = nil
        latestOutcomeNeedsSettings = false
        defaults.removeObject(forKey: StorageKey.latestOutcome)
        defaults.removeObject(forKey: StorageKey.latestOutcomeNeedsSettings)
    }

    func handleAppBecameActive() {
        refreshPermissionStatuses()
        if phase.isActive,
           (!locationIsUsable || motionAuthorizationStatus != .authorized || !motionIsAvailable) {
            stop(reason: .permissionDenied)
        }
        purgeOldDiagnostics()
        materializeLocalExpiry(at: .now)
        evaluateDeadlines(at: .now)
        Task { await retryPendingSynchronization(force: false) }
    }

    func resolveParkedPlace(clientEventID: UUID) -> MapPlaceItem? {
        mapsStore.place(reference: .client(clientEventID))
    }

    func retryPendingSynchronization(force: Bool = true) async {
        guard !isSynchronizing, let context = modelContext else { return }
        isSynchronizing = true
        defer { isSynchronizing = false }

        if let materialized = try? await manager.materializeExpiredParkedPlaces(at: .now) {
            materialized.forEach(mapsStore.applySyncedParkingPlace)
        }

        let descriptor = FetchDescriptor<ParkingOutboxRecord>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        guard let records = try? context.fetch(descriptor) else { return }

        for record in records {
            if !force, let nextRetryAt = record.nextRetryAt, nextRetryAt > .now {
                continue
            }

            do {
                try await synchronize(record)
                updateSyncDiagnostic(for: record, state: "synced")
                context.delete(record)
                try context.save()
                refreshMapsOverlay()
            } catch {
                record.attemptCount += 1
                record.lastErrorMessage = error.localizedDescription
                record.nextRetryAt = Date().addingTimeInterval(retryDelay(attempt: record.attemptCount))
                updateSyncDiagnostic(for: record, state: "pending")
                try? context.save()
                refreshMapsOverlay()
            }
        }

        scheduleNextRetry()
    }

    func savePermanently(
        _ place: MapPlaceItem,
        folderID: Int64,
        name: String
    ) throws {
        guard let clientEventID = place.clientEventID else { return }
        let record = try outboxRecord(for: clientEventID) ?? makeOutboxRecord(from: place)
        if record.modelContext == nil { modelContext?.insert(record) }
        record.remoteID = place.remoteID
        record.folderID = folderID
        record.name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Parked Car" : name
        record.desiredKind = .saved
        record.desiredAction = .convert
        record.updatedAt = .now
        record.nextRetryAt = nil
        try modelContext?.save()
        refreshMapsOverlay()
        Task { await retryPendingSynchronization(force: true) }
    }

    func deleteParkingPlace(_ place: MapPlaceItem) throws {
        guard let clientEventID = place.clientEventID else { return }
        let record = try outboxRecord(for: clientEventID) ?? makeOutboxRecord(from: place)
        if record.modelContext == nil { modelContext?.insert(record) }
        record.remoteID = place.remoteID
        record.desiredAction = .delete
        record.updatedAt = .now
        record.nextRetryAt = nil
        try modelContext?.save()
        refreshMapsOverlay()
        Task { await retryPendingSynchronization(force: true) }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationAuthorizationStatus = manager.authorizationStatus
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            permissionContinuation?.resume(returning: true)
            permissionContinuation = nil
        case .denied, .restricted:
            permissionContinuation?.resume(returning: false)
            permissionContinuation = nil
            if phase.isActive { stop(reason: .permissionDenied) }
        case .notDetermined:
            break
        @unknown default:
            permissionContinuation?.resume(returning: false)
            permissionContinuation = nil
        }
    }

    private func requestLocationWhenInUseIfNeeded() async -> Bool {
        refreshPermissionStatuses()
        switch locationAuthorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                permissionContinuation = continuation
                locationManager.requestWhenInUseAuthorization()
            }
        @unknown default:
            return false
        }
    }

    private func requestMotionIfNeeded() async -> Bool {
        guard CMMotionActivityManager.isActivityAvailable() else { return false }
        let status = CMMotionActivityManager.authorizationStatus()
        if status == .authorized { return true }
        if status == .denied || status == .restricted { return false }

        return await withCheckedContinuation { continuation in
            let now = Date()
            motionManager.queryActivityStarting(
                from: now.addingTimeInterval(-1),
                to: now,
                to: .main
            ) { _, error in
                continuation.resume(
                    returning: error == nil && CMMotionActivityManager.authorizationStatus() == .authorized
                )
            }
        }
    }

    private func startMonitoring() {
        stopSensors()
        serviceSession = CLServiceSession(authorization: .whenInUse)
        backgroundActivitySession = CLBackgroundActivitySession()

        locationTask = Task { [weak self] in
            do {
                let updates = CLLocationUpdate.liveUpdates(.automotiveNavigation)
                for try await update in updates {
                    guard !Task.isCancelled, let location = update.location else { continue }
                    await self?.handleLocation(location)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await self?.stop(reason: .locationUnavailable)
            }
        }

        motionManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let activity else { return }
            Task { @MainActor [weak self] in
                self?.handleMotion(activity)
            }
        }
        scheduleDeadlineCheck()
    }

    private func stopSensors() {
        locationTask?.cancel()
        locationTask = nil
        deadlineTask?.cancel()
        deadlineTask = nil
        motionManager.stopActivityUpdates()
        backgroundActivitySession?.invalidate()
        backgroundActivitySession = nil
        serviceSession?.invalidate()
        serviceSession = nil
    }

    private func handleLocation(_ location: CLLocation) {
        guard var state = session, state.phase.isActive else { return }
        guard location.horizontalAccuracy >= 0 else { return }

        let sample = ParkingLocationSample(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            horizontalAccuracy: location.horizontalAccuracy,
            speed: max(location.speed, 0),
            timestamp: location.timestamp
        )
        state.locationSamples.append(sample)
        state.lastEvidenceAt = max(state.lastEvidenceAt ?? .distantPast, location.timestamp)
        let cutoff = Date().addingTimeInterval(-10 * 60)
        state.locationSamples.removeAll { $0.timestamp < cutoff }
        if state.locationSamples.count > 240 {
            state.locationSamples = Array(state.locationSamples.suffix(240))
        }
        session = state
        persistSession()

        materializeLocalExpiry(at: .now)
        evaluateDeadlines(at: .now)
        if phase == .waitingForDrive { evaluateDrivingEvidence() }
        if phase == .confirmingParking { evaluateParkingConfirmation(at: .now) }
    }

    private func handleMotion(_ activity: CMMotionActivity) {
        guard var state = session, state.phase.isActive else { return }
        let kind = motionKind(activity)
        let confidence = motionConfidence(activity.confidence)
        state.currentMotion = kind
        state.currentMotionConfidence = confidence
        state.lastEvidenceAt = max(state.lastEvidenceAt ?? .distantPast, activity.startDate)
        session = state

        evaluateDeadlines(at: .now)
        switch phase {
        case .waitingForDrive:
            evaluateDrivingEvidence()
        case .driving, .confirmingParking:
            handleDrivingMotion(kind: kind, at: activity.startDate)
        case .idle, .preparing:
            break
        }
        persistSession()
    }

    private func evaluateDrivingEvidence() {
        guard let state = session,
              state.phase == .waitingForDrive,
              state.currentMotion == .automotive,
              state.currentMotionConfidence != .low else { return }

        let cutoff = Date().addingTimeInterval(-5 * 60)
        let accepted = state.locationSamples.filter {
            $0.timestamp >= cutoff && $0.horizontalAccuracy <= 50
        }
        let speedConfirmed = accepted.filter { $0.speed >= 4.5 }.count >= 2
        let displacementConfirmed: Bool
        if let first = accepted.min(by: { $0.timestamp < $1.timestamp }),
           let last = accepted.max(by: { $0.timestamp < $1.timestamp }) {
            displacementConfirmed = distance(from: first, to: last) >= 200
        } else {
            displacementConfirmed = false
        }

        guard speedConfirmed || displacementConfirmed else { return }
        confirmDriving(at: .now)
    }

    private func confirmDriving(at date: Date) {
        transition(to: .driving) { state in
            state.drivingStartedAt = date
            state.drivingDeadline = date.addingTimeInterval(12 * 60 * 60)
            state.waitingDeadline = nil
            state.exitTransitionAt = nil
            state.qualifyingSegmentStartedAt = nil
            state.accumulatedQualifyingDuration = 0
        }
        expirePriorParkingPlaces(at: date)
    }

    private func handleDrivingMotion(kind: ParkingMotionKind, at date: Date) {
        guard var state = session else { return }
        if kind == .automotive {
            let wasConfirmingParking = phase == .confirmingParking
            state.phase = .driving
            state.exitTransitionAt = nil
            state.qualifyingSegmentStartedAt = nil
            state.accumulatedQualifyingDuration = 0
            if wasConfirmingParking {
                state.phaseHistory.append(ParkingPhaseTransition(phase: .driving, date: date))
            }
            session = state
            phase = .driving
            return
        }

        if kind == .unknown {
            if let started = state.qualifyingSegmentStartedAt {
                state.accumulatedQualifyingDuration += max(0, date.timeIntervalSince(started))
                state.qualifyingSegmentStartedAt = nil
            }
            session = state
            return
        }

        let qualifies = kind == .walking || kind == .running || kind == .cycling ||
            (kind == .stationary && recentSpeed(in: state) < 1.5)
        guard qualifies else {
            state.qualifyingSegmentStartedAt = nil
            state.accumulatedQualifyingDuration = 0
            session = state
            return
        }

        if state.exitTransitionAt == nil {
            state.exitTransitionAt = date
        }
        if state.qualifyingSegmentStartedAt == nil {
            state.qualifyingSegmentStartedAt = date
        }
        state.phase = .confirmingParking
        if phase != .confirmingParking {
            state.phaseHistory.append(ParkingPhaseTransition(phase: .confirmingParking, date: date))
            phase = .confirmingParking
        }
        session = state
        evaluateParkingConfirmation(at: date)
    }

    private func evaluateParkingConfirmation(at date: Date) {
        guard let state = session, state.phase == .confirmingParking else { return }
        let currentSegment = state.qualifyingSegmentStartedAt.map { max(0, date.timeIntervalSince($0)) } ?? 0
        guard state.accumulatedQualifyingDuration + currentSegment >= 120 else { return }
        guard let exitDate = state.exitTransitionAt else {
            stop(reason: .interrupted)
            return
        }

        let transitionWindow = state.locationSamples.filter {
            abs($0.timestamp.timeIntervalSince(exitDate)) <= 180 && $0.horizontalAccuracy <= 100
        }
        let immediateWindow = transitionWindow.filter {
            abs($0.timestamp.timeIntervalSince(exitDate)) <= 30
        }
        let coordinate = immediateWindow.min(by: { $0.horizontalAccuracy < $1.horizontalAccuracy })
            ?? transitionWindow.min(by: { lhs, rhs in
                let lhsTime = abs(lhs.timestamp.timeIntervalSince(exitDate))
                let rhsTime = abs(rhs.timestamp.timeIntervalSince(exitDate))
                if lhsTime != rhsTime { return lhsTime < rhsTime }
                return lhs.horizontalAccuracy < rhs.horizontalAccuracy
            })
        guard let coordinate else {
            stop(reason: .insufficientLocationAccuracy)
            return
        }

        saveParkingResult(sample: coordinate, parkedAt: exitDate)
    }

    private func saveParkingResult(sample: ParkingLocationSample, parkedAt: Date) {
        guard let context = modelContext else {
            stop(reason: .persistenceFailure)
            return
        }
        let calendar = Calendar.autoupdatingCurrent
        guard let expiresAt = calendar.nextDate(
            after: parkedAt,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) else {
            stop(reason: .persistenceFailure)
            return
        }

        let clientEventID = UUID()
        let sourceSessionID = session?.sessionID
        let record = ParkingOutboxRecord(
            clientEventID: clientEventID,
            sourceSessionID: sourceSessionID,
            folderID: mapsStore.unfiledFolder?.id,
            latitude: sample.latitude,
            longitude: sample.longitude,
            parkedAt: parkedAt,
            expiresAt: expiresAt
        )
        context.insert(record)
        do {
            try context.save()
        } catch {
            stop(reason: .persistenceFailure)
            return
        }

        refreshMapsOverlay()
        stop(reason: .parkedDetected)

        Task {
            await NotificationManager.shared.scheduleImmediateParkingSuccess(
                clientEventID: clientEventID
            )
            await reverseGeocode(record: record)
            await retryPendingSynchronization(force: true)
        }
    }

    private func reverseGeocode(record: ParkingOutboxRecord) async {
        let location = CLLocation(latitude: record.latitude, longitude: record.longitude)
        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first else { return }
        let address = [
            placemark.name,
            placemark.locality,
            placemark.administrativeArea,
            placemark.postalCode
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: ", ")
        guard !address.isEmpty, record.desiredAction != .delete else { return }
        record.address = address
        record.updatedAt = .now
        record.nextRetryAt = nil
        try? modelContext?.save()
        refreshMapsOverlay()
    }

    private func expirePriorParkingPlaces(at date: Date) {
        guard let context = modelContext else { return }
        for place in mapsStore.activeParkingPlaces(at: date) {
            guard let clientEventID = place.clientEventID else { continue }
            let record = (try? outboxRecord(for: clientEventID)) ?? makeOutboxRecord(from: place)
            if record.modelContext == nil { context.insert(record) }
            record.expiresAt = min(record.expiresAt, date)
            record.expiredAt = date
            record.expiryReason = .newVehicleTrip
            record.desiredAction = .upsert
            record.updatedAt = date
            record.nextRetryAt = nil
        }
        try? context.save()
        refreshMapsOverlay()
        Task {
            if let expired = try? await manager.expireActiveParkedPlaces(
                at: date,
                reason: .newVehicleTrip
            ) {
                expired.forEach(mapsStore.applySyncedParkingPlace)
            }
            await retryPendingSynchronization(force: true)
        }
    }

    private func materializeLocalExpiry(at date: Date) {
        guard let context = modelContext else { return }
        for place in mapsStore.allPlaceItems where
            place.kind == .parked && place.expiredAt == nil && (place.expiresAt ?? .distantFuture) <= date {
            guard let clientEventID = place.clientEventID else { continue }
            let record = (try? outboxRecord(for: clientEventID)) ?? makeOutboxRecord(from: place)
            if record.modelContext == nil { context.insert(record) }
            record.expiredAt = place.expiresAt ?? date
            record.expiryReason = .endOfDay
            record.desiredAction = .upsert
            record.updatedAt = date
            record.nextRetryAt = nil
        }
        try? context.save()
        refreshMapsOverlay()
    }

    private func synchronize(_ record: ParkingOutboxRecord) async throws {
        if record.desiredAction == .delete {
            _ = try await manager.deleteParkedPlace(clientEventID: record.clientEventID)
            mapsStore.removeParkingPlace(clientEventID: record.clientEventID)
            return
        }

        var remote = try await manager.upsertParkedPlace(
            UpsertParkedPlaceParams(
                p_client_event_id: record.clientEventID,
                p_latitude: record.latitude,
                p_longitude: record.longitude,
                p_parked_at: record.parkedAt,
                p_expires_at: record.expiresAt,
                p_expired_at: record.expiredAt,
                p_expiry_reason: record.expiryReason?.rawValue,
                p_address: record.address
            )
        )

        if record.desiredAction == .convert {
            guard let folderID = record.folderID else { throw MapsStoreError.missingUnfiledFolder }
            remote = try await manager.convertParkedPlace(
                clientEventID: record.clientEventID,
                folderID: folderID,
                name: record.name
            )
        }
        mapsStore.applySyncedParkingPlace(remote)
    }

    private func restorePersistedSession() {
        guard let data = defaults.data(forKey: StorageKey.activeSession),
              let restored = try? JSONDecoder().decode(ParkingSessionState.self, from: data),
              restored.schemaVersion == ParkingSessionState.currentSchemaVersion,
              restored.phase != .preparing,
              restored.phase != .idle else {
            defaults.removeObject(forKey: StorageKey.activeSession)
            return
        }

        let now = Date()
        let deadline = restored.phase == .waitingForDrive
            ? restored.waitingDeadline
            : restored.drivingDeadline
        let confirmingIsTrustworthy = restored.phase != .confirmingParking || restored.exitTransitionAt != nil
        let evidenceGapIsTrustworthy: Bool
        if restored.phase == .waitingForDrive {
            evidenceGapIsTrustworthy = true
        } else if let lastEvidenceAt = restored.lastEvidenceAt {
            let maximumGap: TimeInterval = restored.phase == .confirmingParking ? 30 : 120
            evidenceGapIsTrustworthy = now.timeIntervalSince(lastEvidenceAt) <= maximumGap
        } else {
            evidenceGapIsTrustworthy = false
        }
        guard confirmingIsTrustworthy,
              evidenceGapIsTrustworthy,
              let deadline,
              deadline > now else {
            session = restored
            phase = restored.phase
            stop(reason: .interrupted)
            return
        }

        refreshPermissionStatuses()
        guard locationIsUsable,
              motionAuthorizationStatus == .authorized,
              motionIsAvailable else {
            session = restored
            phase = restored.phase
            stop(reason: .interrupted)
            return
        }

        session = restored
        phase = restored.phase
        startMonitoring()
    }

    private func transition(
        to newPhase: ParkingDetectionPhase,
        update: (inout ParkingSessionState) -> Void = { _ in }
    ) {
        guard var state = session else { return }
        state.phase = newPhase
        update(&state)
        state.phaseHistory.append(ParkingPhaseTransition(phase: newPhase, date: .now))
        session = state
        phase = newPhase
        persistSession()
        scheduleDeadlineCheck()
    }

    private func evaluateDeadlines(at date: Date) {
        guard let state = session else { return }
        if state.phase == .waitingForDrive,
           let deadline = state.waitingDeadline,
           date >= deadline {
            stop(reason: .noDrivingByDeadline)
        } else if state.phase != .waitingForDrive,
                  let deadline = state.drivingDeadline,
                  date >= deadline {
            stop(reason: .twelveHourLimit)
        }
    }

    private func scheduleDeadlineCheck() {
        deadlineTask?.cancel()
        guard let state = session else { return }
        let deadline = state.phase == .waitingForDrive ? state.waitingDeadline : state.drivingDeadline
        guard let deadline else { return }
        let delay = max(0, deadline.timeIntervalSinceNow)
        deadlineTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await self?.evaluateDeadlines(at: .now)
        }
    }

    private func persistSession() {
        guard let session,
              let data = try? JSONEncoder().encode(session) else { return }
        defaults.set(data, forKey: StorageKey.activeSession)
    }

    private func stop(reason: ParkingStopReason) {
        let stoppedSession = session
        stopSensors()
        session = nil
        phase = .idle
        defaults.removeObject(forKey: StorageKey.activeSession)

        if let message = reason.userMessage {
            latestOutcomeMessage = message
            latestOutcomeNeedsSettings = reason == .permissionDenied || reason == .motionUnavailable
            defaults.set(message, forKey: StorageKey.latestOutcome)
            defaults.set(latestOutcomeNeedsSettings, forKey: StorageKey.latestOutcomeNeedsSettings)
        }
        if let stoppedSession {
            writeDiagnostic(for: stoppedSession, reason: reason)
        }
    }

    private func finishWithoutSession(reason: ParkingStopReason) {
        if let message = reason.userMessage {
            latestOutcomeMessage = message
            latestOutcomeNeedsSettings = reason == .permissionDenied || reason == .motionUnavailable
            defaults.set(message, forKey: StorageKey.latestOutcome)
            defaults.set(latestOutcomeNeedsSettings, forKey: StorageKey.latestOutcomeNeedsSettings)
        }
    }

    private func writeDiagnostic(for state: ParkingSessionState, reason: ParkingStopReason) {
        guard let context = modelContext else { return }
        let data = (try? JSONEncoder().encode(state.phaseHistory)) ?? Data()
        let lastSample = state.locationSamples.max(by: { $0.timestamp < $1.timestamp })
        let bestAccuracy = state.locationSamples.map(\.horizontalAccuracy).min()
        context.insert(
            ParkingDiagnosticRecord(
                sessionID: state.sessionID,
                createdAt: state.preparedAt,
                completedAt: .now,
                stopReason: reason,
                phaseHistoryData: data,
                locationAuthorizationRaw: Int(locationAuthorizationStatus.rawValue),
                motionAuthorizationRaw: Int(motionAuthorizationStatus.rawValue),
                motionAvailable: motionIsAvailable,
                lastLocationAge: lastSample.map { Date().timeIntervalSince($0.timestamp) },
                bestHorizontalAccuracy: bestAccuracy,
                lastMotionKind: state.currentMotion,
                lastMotionConfidence: state.currentMotionConfidence,
                syncAttemptCount: 0,
                syncState: reason == .parkedDetected ? "pending" : "not_applicable"
            )
        )
        try? context.save()
    }

    private func purgeOldDiagnostics() {
        guard let context = modelContext else { return }
        let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        let predicate = #Predicate<ParkingDiagnosticRecord> { $0.completedAt < cutoff }
        guard let records = try? context.fetch(FetchDescriptor(predicate: predicate)) else { return }
        records.forEach(context.delete)
        try? context.save()
    }

    private func refreshMapsOverlay() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<ParkingOutboxRecord>()
        guard let records = try? context.fetch(descriptor) else { return }
        mapsStore.setParkingOverlay(
            items: records.compactMap { $0.displayItem() },
            deletedClientIDs: Set(records.filter { $0.desiredAction == .delete }.map(\.clientEventID))
        )
    }

    private func outboxRecord(for clientEventID: UUID) throws -> ParkingOutboxRecord? {
        guard let context = modelContext else { return nil }
        let predicate = #Predicate<ParkingOutboxRecord> { $0.clientEventID == clientEventID }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func makeOutboxRecord(from place: MapPlaceItem) -> ParkingOutboxRecord {
        ParkingOutboxRecord(
            clientEventID: place.clientEventID ?? UUID(),
            remoteID: place.remoteID,
            desiredKind: place.kind,
            folderID: place.folderID,
            name: place.name,
            latitude: place.latitude,
            longitude: place.longitude,
            address: place.address,
            parkedAt: place.parkedAt ?? place.createdAt,
            expiresAt: place.expiresAt ?? place.createdAt,
            expiredAt: place.expiredAt,
            expiryReason: place.expiryReason,
            createdAt: place.createdAt
        )
    }

    private func updateSyncDiagnostic(for record: ParkingOutboxRecord, state: String) {
        guard let context = modelContext, let sessionID = record.sourceSessionID else { return }
        let predicate = #Predicate<ParkingDiagnosticRecord> { $0.sessionID == sessionID }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        guard let diagnostic = try? context.fetch(descriptor).first else { return }
        diagnostic.syncAttemptCount = record.attemptCount + (state == "synced" ? 1 : 0)
        diagnostic.syncStateRaw = state
    }

    private func scheduleNextRetry() {
        retryTask?.cancel()
        guard let context = modelContext,
              let records = try? context.fetch(FetchDescriptor<ParkingOutboxRecord>()),
              let next = records.compactMap(\.nextRetryAt).min() else { return }
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, next.timeIntervalSinceNow)))
            guard !Task.isCancelled else { return }
            await self?.retryPendingSynchronization(force: false)
        }
    }

    private func retryDelay(attempt: Int) -> TimeInterval {
        min(60 * 60, max(5, pow(2, Double(min(attempt, 10))) * 5))
    }

    private func openExternalURL(_ url: URL) async -> Bool {
        await withCheckedContinuation { continuation in
            UIApplication.shared.open(url, options: [:]) { didOpen in
                continuation.resume(returning: didOpen)
            }
        }
    }

    private func motionKind(_ activity: CMMotionActivity) -> ParkingMotionKind {
        if activity.automotive { return .automotive }
        if activity.walking { return .walking }
        if activity.running { return .running }
        if activity.cycling { return .cycling }
        if activity.stationary { return .stationary }
        return .unknown
    }

    private func motionConfidence(_ confidence: CMMotionActivityConfidence) -> ParkingMotionConfidence {
        switch confidence {
        case .low: .low
        case .medium: .medium
        case .high: .high
        @unknown default: .low
        }
    }

    private func recentSpeed(in state: ParkingSessionState) -> Double {
        state.locationSamples
            .filter { Date().timeIntervalSince($0.timestamp) <= 60 && $0.horizontalAccuracy <= 100 }
            .max(by: { $0.timestamp < $1.timestamp })?
            .speed ?? .greatestFiniteMagnitude
    }

    private func distance(from first: ParkingLocationSample, to second: ParkingLocationSample) -> Double {
        CLLocation(latitude: first.latitude, longitude: first.longitude)
            .distance(from: CLLocation(latitude: second.latitude, longitude: second.longitude))
    }
}
