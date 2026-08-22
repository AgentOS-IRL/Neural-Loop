import Combine
import CoreLocation
import Foundation
import UIKit

@MainActor
final class MapsLocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var errorMessage: String?

    private let manager: CLLocationManager

    override init() {
        let manager = CLLocationManager()
        self.manager = manager
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var isDeniedOrRestricted: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    func handleMapsOpen() {
        authorizationStatus = manager.authorizationStatus

        switch authorizationStatus {
        case .notDetermined:
            break
        case .authorizedAlways, .authorizedWhenInUse:
            requestFreshLocation()
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    func requestFreshLocation() {
        guard isAuthorized else { return }
        errorMessage = nil
        manager.requestLocation()
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if isAuthorized {
            requestFreshLocation()
        } else if isDeniedOrRestricted {
            currentLocation = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
        errorMessage = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let locationError = error as? CLError
        guard locationError?.code != .locationUnknown else { return }
        errorMessage = error.localizedDescription
    }
}

enum MapsLocationTextFormatter {
    static func subtitle(
        latitude: Double,
        longitude: Double,
        address: String?,
        currentLocation: CLLocation?
    ) -> String {
        if let currentLocation {
            let destination = CLLocation(latitude: latitude, longitude: longitude)
            return distance(currentLocation.distance(from: destination))
        }

        if let address = address?.trimmingCharacters(in: .whitespacesAndNewlines), !address.isEmpty {
            return address
        }

        return coordinates(latitude: latitude, longitude: longitude)
    }

    static func distance(_ meters: CLLocationDistance, locale: Locale = .current) -> String {
        let usesKilometres = locale.measurementSystem == .metric
        let divisor = usesKilometres ? 1_000.0 : 1_609.344
        let value = meters / divisor
        let formatted = value.formatted(
            .number.precision(.fractionLength(value < 10 ? 1 : 0))
        )
        return "\(formatted) \(usesKilometres ? "km" : "mi")"
    }

    static func coordinates(latitude: Double, longitude: Double) -> String {
        String(
            format: "%.5f, %.5f",
            locale: Locale(identifier: "en_US_POSIX"),
            latitude,
            longitude
        )
    }
}
