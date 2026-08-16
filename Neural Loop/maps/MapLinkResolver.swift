import CoreLocation
import Foundation
import MapKit

struct ImportedMapPlace {
    let coordinate: CLLocationCoordinate2D
    let suggestedName: String?
    let address: String?
}

protocol MapLinkResolving {
    func canResolve(_ url: URL) -> Bool
    func resolve(_ url: URL) async throws -> ImportedMapPlace
}

struct MapLinkImporter {
    private let resolvers: [any MapLinkResolving]

    init(resolvers: [any MapLinkResolving] = [AppleMapsLinkResolver()]) {
        self.resolvers = resolvers
    }

    func resolve(_ rawValue: String) async throws -> ImportedMapPlace {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), !trimmed.isEmpty else {
            throw AppleMapsImportError.invalidURL
        }

        let matches = resolvers.filter { $0.canResolve(url) }
        guard matches.count == 1, let resolver = matches.first else {
            throw AppleMapsImportError.unsupportedHost
        }

        return try await resolver.resolve(url)
    }
}

enum AppleMapsImportError: LocalizedError {
    case invalidURL
    case unsupportedHost
    case ambiguousLink
    case noResult

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "This is not a valid URL."
        case .unsupportedHost:
            return "Paste an Apple Maps link."
        case .ambiguousLink:
            return "The link contains more than one possible place."
        case .noResult:
            return "The place could not be resolved."
        }
    }
}

struct AppleMapsLinkResolver: MapLinkResolving {
    func canResolve(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased() else {
            return false
        }

        return Self.isAppleMapsHost(host)
    }

    func resolve(_ originalURL: URL) async throws -> ImportedMapPlace {
        guard canResolve(originalURL) else {
            throw AppleMapsImportError.unsupportedHost
        }

        let url = try await Self.expandShortURLIfNeeded(originalURL)
        guard canResolve(url),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw AppleMapsImportError.invalidURL
        }

        let firstPathComponent = url.pathComponents
            .dropFirst()
            .first?
            .lowercased()

        switch firstPathComponent {
        case "place", "look-around", "report-a-problem":
            return try await Self.resolvePlaceLikeURL(components)
        case "frame":
            guard let coordinate = try Self.singleCoordinate(
                Self.values(named: ["coordinate", "center"], in: components)
            ) else {
                throw AppleMapsImportError.noResult
            }
            return await Self.enrich(
                coordinate: coordinate,
                explicitName: Self.value(named: "name", in: components)
            )
        case "search":
            return try await Self.resolveSearchURL(components)
        case "directions":
            return try await Self.resolveDirectionsURL(components)
        default:
            return try await Self.resolveLegacyURL(components)
        }
    }

    private static func resolvePlaceLikeURL(_ components: URLComponents) async throws -> ImportedMapPlace {
        if let coordinate = try singleCoordinate(values(named: ["coordinate"], in: components)) {
            return await enrich(
                coordinate: coordinate,
                explicitName: value(named: "name", in: components)
            )
        }

        if let placeID = value(named: "place-id", in: components) {
            let item = try await mapItem(forPlaceID: placeID)
            return importedPlace(
                from: item,
                explicitName: value(named: "name", in: components)
            )
        }

        if let address = value(named: "address", in: components) {
            return try await geocodeExactlyOne(address)
        }

        throw AppleMapsImportError.noResult
    }

    private static func resolveSearchURL(_ components: URLComponents) async throws -> ImportedMapPlace {
        if let query = value(named: "query", in: components) {
            let bias = try singleCoordinate(values(named: ["center"], in: components))
            return try await searchExactlyOne(query, bias: bias)
        }

        guard let coordinate = try singleCoordinate(values(named: ["center"], in: components)) else {
            throw AppleMapsImportError.noResult
        }

        return await enrich(coordinate: coordinate, explicitName: nil)
    }

    private static func resolveDirectionsURL(_ components: URLComponents) async throws -> ImportedMapPlace {
        let endpointNames: Set<String> = ["source", "waypoint", "destination", "saddr", "daddr"]
        let endpoints = (components.queryItems ?? []).filter {
            endpointNames.contains($0.name.lowercased()) && !($0.value ?? "").isEmpty
        }

        guard endpoints.count == 1,
              let endpoint = endpoints.first,
              let endpointValue = endpoint.value else {
            throw AppleMapsImportError.ambiguousLink
        }

        let placeIDKey: String? = switch endpoint.name.lowercased() {
        case "source": "source-place-id"
        case "destination": "destination-place-id"
        case "waypoint": "waypoint-place-id"
        default: nil
        }

        if let placeIDKey, let placeID = value(named: placeIDKey, in: components) {
            let item = try await mapItem(forPlaceID: placeID)
            return importedPlace(from: item, explicitName: nil)
        }

        if let coordinate = parseCoordinate(endpointValue) {
            return await enrich(coordinate: coordinate, explicitName: nil)
        }

        return try await searchExactlyOne(endpointValue, bias: nil)
    }

    private static func resolveLegacyURL(_ components: URLComponents) async throws -> ImportedMapPlace {
        if let coordinate = try singleCoordinate(values(named: ["ll"], in: components)) {
            return await enrich(
                coordinate: coordinate,
                explicitName: value(named: "q", in: components)
            )
        }

        let directionValues = values(named: ["saddr", "daddr"], in: components)
        if !directionValues.isEmpty {
            guard directionValues.count == 1 else {
                throw AppleMapsImportError.ambiguousLink
            }

            if let coordinate = parseCoordinate(directionValues[0]) {
                return await enrich(coordinate: coordinate, explicitName: nil)
            }
            return try await searchExactlyOne(directionValues[0], bias: nil)
        }

        if let address = value(named: "address", in: components) {
            return try await geocodeExactlyOne(address)
        }

        if let query = value(named: "q", in: components) {
            let bias = try singleCoordinate(values(named: ["near", "sll"], in: components))
            return try await searchExactlyOne(query, bias: bias)
        }

        if let coordinate = try singleCoordinate(
            values(named: ["coordinate", "center"], in: components)
        ) {
            return await enrich(coordinate: coordinate, explicitName: nil)
        }

        throw AppleMapsImportError.noResult
    }

    private static func expandShortURLIfNeeded(_ url: URL) async throws -> URL {
        guard let host = url.host?.lowercased(),
              host == "maps.apple" || host.hasSuffix(".maps.apple") else {
            return url
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let finalURL = response.url else {
            throw AppleMapsImportError.noResult
        }
        return finalURL
    }

    private static func mapItem(forPlaceID rawValue: String) async throws -> MKMapItem {
        guard let identifier = MKMapItem.Identifier(rawValue: rawValue) else {
            throw AppleMapsImportError.noResult
        }

        return try await MKMapItemRequest(mapItemIdentifier: identifier).mapItem
    }

    private static func geocodeExactlyOne(_ address: String) async throws -> ImportedMapPlace {
        guard let request = MKGeocodingRequest(addressString: address) else {
            throw AppleMapsImportError.noResult
        }

        let items = try await request.mapItems
        return try importedPlace(fromExactlyOne: items)
    }

    private static func searchExactlyOne(
        _ query: String,
        bias: CLLocationCoordinate2D?
    ) async throws -> ImportedMapPlace {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query

        if let bias {
            request.region = MKCoordinateRegion(
                center: bias,
                latitudinalMeters: 25_000,
                longitudinalMeters: 25_000
            )
        }

        let response = try await MKLocalSearch(request: request).start()
        return try importedPlace(fromExactlyOne: response.mapItems)
    }

    private static func importedPlace(fromExactlyOne items: [MKMapItem]) throws -> ImportedMapPlace {
        if items.isEmpty {
            throw AppleMapsImportError.noResult
        }
        guard items.count == 1, let item = items.first else {
            throw AppleMapsImportError.ambiguousLink
        }
        return importedPlace(from: item, explicitName: nil)
    }

    private static func enrich(
        coordinate: CLLocationCoordinate2D,
        explicitName: String?
    ) async -> ImportedMapPlace {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var address: String?

        if let request = MKReverseGeocodingRequest(location: location),
           let items = try? await request.mapItems,
           let firstItem = items.first {
            address = formattedAddress(from: firstItem)
        }

        return ImportedMapPlace(
            coordinate: coordinate,
            suggestedName: nonempty(explicitName),
            address: address
        )
    }

    private static func importedPlace(from item: MKMapItem, explicitName: String?) -> ImportedMapPlace {
        ImportedMapPlace(
            coordinate: item.location.coordinate,
            suggestedName: nonempty(explicitName) ?? nonempty(item.name),
            address: formattedAddress(from: item)
        )
    }

    private static func formattedAddress(from item: MKMapItem) -> String? {
        item.addressRepresentations?.fullAddress(includingRegion: true, singleLine: true)
            ?? item.address?.fullAddress
    }

    private static func value(named name: String, in components: URLComponents) -> String? {
        let rawValue = components.queryItems?
            .first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?
            .value
        return nonempty(rawValue)
    }

    private static func values(named names: [String], in components: URLComponents) -> [String] {
        let accepted = Set(names.map { $0.lowercased() })
        return (components.queryItems ?? []).compactMap { item in
            guard accepted.contains(item.name.lowercased()) else { return nil }
            return nonempty(item.value)
        }
    }

    private static func singleCoordinate(_ rawValues: [String]) throws -> CLLocationCoordinate2D? {
        var coordinates: [CLLocationCoordinate2D] = []
        for rawValue in rawValues {
            if let coordinate = parseCoordinate(rawValue) {
                coordinates.append(coordinate)
            }
        }
        guard !coordinates.isEmpty else { return nil }

        let unique = coordinates.reduce(into: [CLLocationCoordinate2D]()) { result, coordinate in
            let isDuplicate = result.contains {
                $0.latitude == coordinate.latitude && $0.longitude == coordinate.longitude
            }
            if !isDuplicate {
                result.append(coordinate)
            }
        }

        guard unique.count == 1 else {
            throw AppleMapsImportError.ambiguousLink
        }
        return unique[0]
    }

    private static func parseCoordinate(_ rawValue: String) -> CLLocationCoordinate2D? {
        let parts = rawValue.split(separator: ",", maxSplits: 1)
        guard parts.count == 2,
              let latitude = Double(parts[0].trimmingCharacters(in: .whitespaces)),
              let longitude = Double(parts[1].trimmingCharacters(in: .whitespaces)) else {
            return nil
        }

        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        return CLLocationCoordinate2DIsValid(coordinate) ? coordinate : nil
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }

    private static func isAppleMapsHost(_ host: String) -> Bool {
        host == "maps.apple" ||
            host.hasSuffix(".maps.apple") ||
            host == "maps.apple.com" ||
            host.hasSuffix(".maps.apple.com")
    }
}
