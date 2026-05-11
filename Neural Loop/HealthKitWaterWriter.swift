import Foundation
@preconcurrency import HealthKit

enum HealthKitWaterWriterError: Error {
    case waterTypeUnavailable
    case authorizationDenied
    case authorizationFailed
}

@MainActor
final class HealthKitWaterWriter {
    static let shared = HealthKitWaterWriter()

    private let healthStore = HKHealthStore()

    private init() {}

    func saveWater(milliliters: Double, date: Date) async throws {
        guard milliliters > 0 else { return }
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else {
            throw HealthKitWaterWriterError.waterTypeUnavailable
        }

        try await requestAuthorizationIfNeeded(for: waterType)

        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: milliliters)
        let sample = HKQuantitySample(
            type: waterType,
            quantity: quantity,
            start: date,
            end: date,
            metadata: [HKMetadataKeyWasUserEntered: true]
        )

        try await save(sample)
    }

    private func requestAuthorizationIfNeeded(for quantityType: HKQuantityType) async throws {
        switch healthStore.authorizationStatus(for: quantityType) {
        case .sharingAuthorized:
            return
        case .sharingDenied:
            throw HealthKitWaterWriterError.authorizationDenied
        case .notDetermined:
            try await requestAuthorization(for: quantityType)
        @unknown default:
            return
        }
    }

    private func requestAuthorization(for quantityType: HKQuantityType) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: [quantityType], read: []) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitWaterWriterError.authorizationFailed)
                }
            }
        }

        if healthStore.authorizationStatus(for: quantityType) == .sharingDenied {
            throw HealthKitWaterWriterError.authorizationDenied
        }
    }

    private func save(_ sample: HKQuantitySample) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.save(sample) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitWaterWriterError.authorizationFailed)
                }
            }
        }
    }
}
