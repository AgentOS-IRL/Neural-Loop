import Foundation
import SwiftData

enum ParkingTriggerSource: Codable, Equatable, Sendable {
    case place(Int64)
    case route(Int64)
}

enum ParkingDetectionPhase: String, Codable, CaseIterable, Sendable {
    case idle
    case preparing
    case waitingForDrive
    case driving
    case confirmingParking

    var isActive: Bool {
        self != .idle
    }

    var title: String {
        switch self {
        case .idle:
            return "Parking detection idle"
        case .preparing:
            return "Preparing parking detection"
        case .waitingForDrive:
            return "Waiting for drive"
        case .driving:
            return "Driving detected"
        case .confirmingParking:
            return "Confirming parking"
        }
    }
}

enum ParkingStopReason: String, Codable, CaseIterable, Sendable {
    case userCancelled
    case noDrivingByDeadline
    case parkedDetected
    case supersededByNewOpen
    case permissionDenied
    case motionUnavailable
    case locationUnavailable
    case externalOpenFailed
    case interrupted
    case insufficientLocationAccuracy
    case twelveHourLimit
    case persistenceFailure

    var userMessage: String? {
        switch self {
        case .noDrivingByDeadline:
            return "Parking detection stopped because no vehicle trip began within 30 minutes."
        case .permissionDenied:
            return "Parking detection is unavailable because Location or Motion access is off."
        case .motionUnavailable:
            return "Parking detection is unavailable on this device."
        case .locationUnavailable:
            return "Parking wasn’t saved because location became unavailable."
        case .externalOpenFailed:
            return "Parking detection stopped because the maps app could not be opened."
        case .interrupted:
            return "Parking detection was interrupted and no location was saved."
        case .insufficientLocationAccuracy:
            return "Parking wasn’t saved because location accuracy was insufficient."
        case .twelveHourLimit:
            return "Parking detection stopped after reaching its 12-hour safety limit."
        case .persistenceFailure:
            return "Parking wasn’t saved because local storage was unavailable."
        case .userCancelled, .parkedDetected, .supersededByNewOpen:
            return nil
        }
    }
}

enum ParkingMotionKind: String, Codable, CaseIterable, Sendable {
    case automotive
    case walking
    case running
    case cycling
    case stationary
    case unknown
}

enum ParkingMotionConfidence: String, Codable, CaseIterable, Sendable {
    case low
    case medium
    case high
}

struct ParkingLocationSample: Codable, Equatable, Sendable {
    let latitude: Double
    let longitude: Double
    let horizontalAccuracy: Double
    let speed: Double
    let timestamp: Date
}

struct ParkingPhaseTransition: Codable, Equatable, Sendable {
    let phase: ParkingDetectionPhase
    let date: Date
}

struct ParkingSessionState: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion = currentSchemaVersion
    let sessionID: UUID
    let source: ParkingTriggerSource
    let provider: ExternalMapProvider
    var phase: ParkingDetectionPhase
    let preparedAt: Date
    var waitingDeadline: Date?
    var drivingStartedAt: Date?
    var drivingDeadline: Date?
    var exitTransitionAt: Date?
    var qualifyingSegmentStartedAt: Date?
    var accumulatedQualifyingDuration: TimeInterval
    var currentMotion: ParkingMotionKind
    var currentMotionConfidence: ParkingMotionConfidence
    var lastEvidenceAt: Date?
    var locationSamples: [ParkingLocationSample]
    var phaseHistory: [ParkingPhaseTransition]

    init(
        sessionID: UUID = UUID(),
        source: ParkingTriggerSource,
        provider: ExternalMapProvider,
        preparedAt: Date = .now
    ) {
        self.sessionID = sessionID
        self.source = source
        self.provider = provider
        self.phase = .preparing
        self.preparedAt = preparedAt
        self.accumulatedQualifyingDuration = 0
        self.currentMotion = .unknown
        self.currentMotionConfidence = .low
        self.locationSamples = []
        self.phaseHistory = [ParkingPhaseTransition(phase: .preparing, date: preparedAt)]
    }
}

enum ParkingPlaceReference: Hashable, Codable, Sendable, Identifiable {
    case remote(Int64)
    case client(UUID)

    var id: String {
        switch self {
        case .remote(let id): "remote-\(id)"
        case .client(let id): "client-\(id.uuidString)"
        }
    }
}

struct MapPlaceItem: Identifiable, Equatable, Sendable {
    let id: ParkingPlaceReference
    let remoteID: Int64?
    let folderID: Int64?
    let name: String
    let latitude: Double
    let longitude: Double
    let address: String?
    let kind: MapPlaceKind
    let clientEventID: UUID?
    let parkedAt: Date?
    let expiresAt: Date?
    let expiredAt: Date?
    let expiryReason: ParkingExpiryReason?
    let createdAt: Date
    let updatedAt: Date
    let isSyncPending: Bool

    init(record: MapPlaceRecord, isSyncPending: Bool = false) {
        id = record.client_event_id.map(ParkingPlaceReference.client) ?? .remote(record.id)
        remoteID = record.id
        folderID = record.folder_id
        name = record.name
        latitude = record.latitude
        longitude = record.longitude
        address = record.address
        kind = record.kind
        clientEventID = record.client_event_id
        parkedAt = record.parked_at
        expiresAt = record.expires_at
        expiredAt = record.expired_at
        expiryReason = record.expiry_reason
        createdAt = record.created_at
        updatedAt = record.updated_at
        self.isSyncPending = isSyncPending
    }

    init(
        clientEventID: UUID,
        remoteID: Int64?,
        folderID: Int64?,
        name: String,
        latitude: Double,
        longitude: Double,
        address: String?,
        kind: MapPlaceKind,
        parkedAt: Date?,
        expiresAt: Date?,
        expiredAt: Date?,
        expiryReason: ParkingExpiryReason?,
        createdAt: Date,
        updatedAt: Date,
        isSyncPending: Bool
    ) {
        id = .client(clientEventID)
        self.remoteID = remoteID
        self.folderID = folderID
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.kind = kind
        self.clientEventID = clientEventID
        self.parkedAt = parkedAt
        self.expiresAt = expiresAt
        self.expiredAt = expiredAt
        self.expiryReason = expiryReason
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isSyncPending = isSyncPending
    }

    func isActiveParked(at date: Date = .now) -> Bool {
        kind == .parked && expiredAt == nil && (expiresAt.map { $0 > date } ?? false)
    }

    func isExpiredParked(at date: Date = .now) -> Bool {
        kind == .parked && (expiredAt != nil || (expiresAt.map { $0 <= date } ?? false))
    }
}

enum ParkingSyncDesiredAction: String, Codable, CaseIterable, Sendable {
    case upsert
    case convert
    case delete
}

@Model
final class ParkingOutboxRecord {
    @Attribute(.unique) var clientEventID: UUID
    var sourceSessionID: UUID?
    var remoteID: Int64?
    var desiredActionRaw: String
    var desiredKindRaw: String
    var folderID: Int64?
    var name: String
    var latitude: Double
    var longitude: Double
    var address: String?
    var parkedAt: Date
    var expiresAt: Date
    var expiredAt: Date?
    var expiryReasonRaw: String?
    var createdAt: Date
    var updatedAt: Date
    var attemptCount: Int
    var nextRetryAt: Date?
    var lastErrorMessage: String?

    init(
        clientEventID: UUID,
        sourceSessionID: UUID? = nil,
        remoteID: Int64? = nil,
        desiredAction: ParkingSyncDesiredAction = .upsert,
        desiredKind: MapPlaceKind = .parked,
        folderID: Int64?,
        name: String = "Parked Car",
        latitude: Double,
        longitude: Double,
        address: String? = nil,
        parkedAt: Date,
        expiresAt: Date,
        expiredAt: Date? = nil,
        expiryReason: ParkingExpiryReason? = nil,
        createdAt: Date = .now
    ) {
        self.clientEventID = clientEventID
        self.sourceSessionID = sourceSessionID
        self.remoteID = remoteID
        desiredActionRaw = desiredAction.rawValue
        desiredKindRaw = desiredKind.rawValue
        self.folderID = folderID
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.parkedAt = parkedAt
        self.expiresAt = expiresAt
        self.expiredAt = expiredAt
        expiryReasonRaw = expiryReason?.rawValue
        self.createdAt = createdAt
        updatedAt = createdAt
        attemptCount = 0
    }

    var desiredAction: ParkingSyncDesiredAction {
        get { ParkingSyncDesiredAction(rawValue: desiredActionRaw) ?? .upsert }
        set { desiredActionRaw = newValue.rawValue }
    }

    var desiredKind: MapPlaceKind {
        get { MapPlaceKind(rawValue: desiredKindRaw) ?? .parked }
        set { desiredKindRaw = newValue.rawValue }
    }

    var expiryReason: ParkingExpiryReason? {
        get { expiryReasonRaw.flatMap(ParkingExpiryReason.init(rawValue:)) }
        set { expiryReasonRaw = newValue?.rawValue }
    }

    func displayItem() -> MapPlaceItem? {
        guard desiredAction != .delete else { return nil }

        return MapPlaceItem(
            clientEventID: clientEventID,
            remoteID: remoteID,
            folderID: folderID,
            name: name,
            latitude: latitude,
            longitude: longitude,
            address: address,
            kind: desiredKind,
            parkedAt: desiredKind == .parked ? parkedAt : nil,
            expiresAt: desiredKind == .parked ? expiresAt : nil,
            expiredAt: desiredKind == .parked ? expiredAt : nil,
            expiryReason: desiredKind == .parked ? expiryReason : nil,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isSyncPending: true
        )
    }
}

@Model
final class ParkingDiagnosticRecord {
    @Attribute(.unique) var sessionID: UUID
    var createdAt: Date
    var completedAt: Date
    var stopReasonRaw: String
    var phaseHistoryData: Data
    var locationAuthorizationRaw: Int
    var motionAuthorizationRaw: Int
    var motionAvailable: Bool
    var lastLocationAge: TimeInterval?
    var bestHorizontalAccuracy: Double?
    var lastMotionKindRaw: String?
    var lastMotionConfidenceRaw: String?
    var syncAttemptCount: Int
    var syncStateRaw: String

    init(
        sessionID: UUID,
        createdAt: Date,
        completedAt: Date,
        stopReason: ParkingStopReason,
        phaseHistoryData: Data,
        locationAuthorizationRaw: Int,
        motionAuthorizationRaw: Int,
        motionAvailable: Bool,
        lastLocationAge: TimeInterval?,
        bestHorizontalAccuracy: Double?,
        lastMotionKind: ParkingMotionKind?,
        lastMotionConfidence: ParkingMotionConfidence?,
        syncAttemptCount: Int = 0,
        syncState: String = "not_applicable"
    ) {
        self.sessionID = sessionID
        self.createdAt = createdAt
        self.completedAt = completedAt
        stopReasonRaw = stopReason.rawValue
        self.phaseHistoryData = phaseHistoryData
        self.locationAuthorizationRaw = locationAuthorizationRaw
        self.motionAuthorizationRaw = motionAuthorizationRaw
        self.motionAvailable = motionAvailable
        self.lastLocationAge = lastLocationAge
        self.bestHorizontalAccuracy = bestHorizontalAccuracy
        lastMotionKindRaw = lastMotionKind?.rawValue
        lastMotionConfidenceRaw = lastMotionConfidence?.rawValue
        self.syncAttemptCount = syncAttemptCount
        syncStateRaw = syncState
    }
}
