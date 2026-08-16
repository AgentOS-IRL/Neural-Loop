import CoreLocation
import MapKit

enum MultiLegRouteError: LocalizedError {
    case tooFewWaypoints
    case noRouteForLeg

    var errorDescription: String? {
        switch self {
        case .tooFewWaypoints:
            return "This route needs at least two waypoints."
        case .noRouteForLeg:
            return "MapKit could not calculate every leg of this route."
        }
    }
}

enum MultiLegRouteCalculator {
    static func calculate(
        waypoints: [CLLocationCoordinate2D],
        transportType: MKDirectionsTransportType
    ) async throws -> [MKRoute] {
        guard waypoints.count >= 2 else {
            throw MultiLegRouteError.tooFewWaypoints
        }

        var completedLegs: [MKRoute] = []

        for (source, destination) in zip(waypoints, waypoints.dropFirst()) {
            try Task.checkCancellation()

            let request = MKDirections.Request()
            request.source = MKMapItem(
                location: CLLocation(latitude: source.latitude, longitude: source.longitude),
                address: nil
            )
            request.destination = MKMapItem(
                location: CLLocation(latitude: destination.latitude, longitude: destination.longitude),
                address: nil
            )
            request.transportType = transportType
            request.requestsAlternateRoutes = false

            let response = try await MKDirections(request: request).calculate()
            guard let route = response.routes.first else {
                throw MultiLegRouteError.noRouteForLeg
            }
            completedLegs.append(route)
        }

        return completedLegs
    }
}

extension MapRouteTransportMode {
    var mapKitTransportType: MKDirectionsTransportType {
        switch self {
        case .automobile:
            return .automobile
        case .walking:
            return .walking
        case .cycling:
            return .cycling
        case .transit:
            return .transit
        }
    }
}
