import Foundation

enum ExternalMapProvider: String, Codable, CaseIterable, Sendable, Identifiable {
    case apple
    case google
    case waze

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .apple: "Apple Maps"
        case .google: "Google Maps"
        case .waze: "Waze"
        }
    }

    func url(name: String, latitude: Double, longitude: Double) -> URL? {
        var components = URLComponents()
        components.scheme = switch self {
        case .apple: "maps"
        case .google: "comgooglemaps"
        case .waze: "waze"
        }
        components.host = ""
        components.queryItems = switch self {
        case .apple:
            [
                URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"),
                URLQueryItem(name: "q", value: name)
            ]
        case .google:
            [URLQueryItem(name: "q", value: "\(latitude),\(longitude)")]
        case .waze:
            [URLQueryItem(name: "ll", value: "\(latitude),\(longitude)")]
        }
        return components.url
    }

    func url(for place: MapPlaceRecord) -> URL? {
        url(name: place.name, latitude: place.latitude, longitude: place.longitude)
    }

    func url(for place: MapPlaceItem) -> URL? {
        url(name: place.name, latitude: place.latitude, longitude: place.longitude)
    }

    static func canonicalAppleURL(
        name: String,
        latitude: Double,
        longitude: Double
    ) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "maps.apple.com"
        components.path = "/"
        components.queryItems = [
            URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"),
            URLQueryItem(name: "q", value: name)
        ]
        return components.url
    }

    static func canonicalAppleURL(for place: MapPlaceRecord) -> URL? {
        canonicalAppleURL(
            name: place.name,
            latitude: place.latitude,
            longitude: place.longitude
        )
    }

    static func canonicalAppleURL(for place: MapPlaceItem) -> URL? {
        canonicalAppleURL(
            name: place.name,
            latitude: place.latitude,
            longitude: place.longitude
        )
    }
}
