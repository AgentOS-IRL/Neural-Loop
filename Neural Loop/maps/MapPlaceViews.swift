import CoreLocation
import MapKit
import SwiftUI
import UIKit

struct AddMapPlaceSheet: View {
    let folders: [MapFolderRecord]
    let onSave: (CreateMapPlaceRequest) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var urlText = ""
    @State private var folderID: Int64
    @State private var importedPlace: ImportedMapPlace?
    @State private var name = ""
    @State private var isResolving = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let importer = MapLinkImporter()

    init(
        folders: [MapFolderRecord],
        initialFolderID: Int64,
        onSave: @escaping (CreateMapPlaceRequest) async throws -> Void
    ) {
        self.folders = folders
        self.onSave = onSave
        _folderID = State(initialValue: initialFolderID)
    }

    private var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Maps URL") {
                    TextField("Apple Maps or Google Maps URL", text: $urlText, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .lineLimit(2...5)
                        .onChange(of: urlText) {
                            importedPlace = nil
                            name = ""
                            errorMessage = nil
                        }

                    HStack {
                        PasteButton(payloadType: String.self) { values in
                            if let value = values.first {
                                urlText = value
                            }
                        }

                        Spacer()

                        Button(importedPlace == nil ? "Resolve" : "Resolve Again") {
                            Task { await resolve() }
                        }
                        .disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isResolving || isSaving)
                    }

                    if isResolving {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Resolving place…")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Folder") {
                    Picker("Folder", selection: $folderID) {
                        ForEach(folders) { folder in
                            Text(folder.name).tag(folder.id)
                        }
                    }
                }

                if let importedPlace {
                    Section("Place Preview") {
                        TextField("Name", text: $name)
                            .onChange(of: name) { _, value in
                                if value.count > 100 {
                                    name = String(value.prefix(100))
                                }
                            }

                        if let address = importedPlace.address, !address.isEmpty {
                            Text(address)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(
                                MapsLocationTextFormatter.coordinates(
                                    latitude: importedPlace.coordinate.latitude,
                                    longitude: importedPlace.coordinate.longitude
                                )
                            )
                            .foregroundStyle(.secondary)
                        }

                        PlaceImportPreviewMap(coordinate: importedPlace.coordinate)
                            .frame(height: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .id("\(importedPlace.coordinate.latitude),\(importedPlace.coordinate.longitude)")
                    }
                }

                if let errorMessage {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(errorMessage)
                                .foregroundStyle(AppTheme.errorTint)
                            Button("Retry") {
                                Task { await resolve() }
                            }
                            .disabled(isResolving || isSaving)
                        }
                    }
                }
            }
            .navigationTitle("Add Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isResolving || isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(
                        importedPlace == nil ||
                        normalizedName.isEmpty ||
                        normalizedName.count > 100 ||
                        isResolving ||
                        isSaving
                    )
                }
            }
            .interactiveDismissDisabled(isResolving || isSaving)
        }
    }

    private func resolve() async {
        isResolving = true
        errorMessage = nil
        importedPlace = nil
        defer { isResolving = false }

        do {
            let result = try await importer.resolve(urlText)
            importedPlace = result
            name = result.suggestedName ?? ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        guard let importedPlace, !normalizedName.isEmpty else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            try await onSave(
                CreateMapPlaceRequest(
                    folder_id: folderID,
                    name: normalizedName,
                    latitude: importedPlace.coordinate.latitude,
                    longitude: importedPlace.coordinate.longitude,
                    address: importedPlace.address
                )
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct PlaceImportPreviewMap: View {
    let coordinate: CLLocationCoordinate2D
    @State private var position: MapCameraPosition

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        _position = State(
            initialValue: .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
                )
            )
        )
    }

    var body: some View {
        Map(position: $position) {
            Marker("Imported place", coordinate: coordinate)
                .tint(AppTheme.accentColor)
        }
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .accessibilityLabel("Map preview with a fixed pin")
    }
}

struct MapPlaceDetailView: View {
    let placeID: Int64
    @ObservedObject var store: MapsStore
    @ObservedObject var locationService: MapsLocationService

    @State private var isOpenPlacePresented = false

    private var place: MapPlaceRecord? {
        store.snapshot?.places.first { $0.id == placeID }
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            if let place {
                VStack(spacing: 0) {
                    SavedPlaceMap(place: place, showsUserLocation: locationService.isAuthorized)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(place.name)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text(place.address ?? MapsLocationTextFormatter.coordinates(
                            latitude: place.latitude,
                            longitude: place.longitude
                        ))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)

                        Button {
                            isOpenPlacePresented = true
                        } label: {
                            Label("Open Place", systemImage: "arrow.up.right.square")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accentColor)
                    }
                    .padding(18)
                    .padding(.bottom, 84)
                    .background(.ultraThinMaterial)
                }
            } else {
                ContentUnavailableView(
                    "Place unavailable",
                    systemImage: "mappin.slash",
                    description: Text("Return to the folder and refresh.")
                )
            }
        }
        .navigationTitle(place?.name ?? "Place")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Open Place",
            isPresented: $isOpenPlacePresented,
            titleVisibility: .visible
        ) {
            if let place {
                Button("Apple Maps") { open(place, with: .apple) }
                    .disabled(!MapAppAvailability.isAppleMapsInstalled)
                Button("Google Maps") { open(place, with: .google) }
                    .disabled(!MapAppAvailability.isGoogleMapsInstalled)
                Button("Waze") { open(place, with: .waze) }
                    .disabled(!MapAppAvailability.isWazeInstalled)
                if let shareURL = ExternalMapProvider.canonicalAppleURL(for: place) {
                    ShareLink("Send to Mercedes-Benz", item: shareURL)
                }
                Button("Copy Place Details") { copyDetails(for: place) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func open(_ place: MapPlaceRecord, with provider: ExternalMapProvider) {
        guard let url = provider.url(for: place) else { return }
        UIApplication.shared.open(url)
    }

    private func copyDetails(for place: MapPlaceRecord) {
        guard let canonicalURL = ExternalMapProvider.canonicalAppleURL(for: place) else { return }
        UIPasteboard.general.string = """
        \(place.name)
        \(place.latitude),\(place.longitude)
        \(canonicalURL.absoluteString)
        """
    }
}

private struct SavedPlaceMap: View {
    let place: MapPlaceRecord
    let showsUserLocation: Bool
    @State private var position: MapCameraPosition

    init(place: MapPlaceRecord, showsUserLocation: Bool) {
        self.place = place
        self.showsUserLocation = showsUserLocation
        let coordinate = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
        _position = State(
            initialValue: .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
                )
            )
        )
    }

    var body: some View {
        Map(position: $position) {
            Marker(
                place.name,
                coordinate: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
            )
            .tint(AppTheme.accentColor)

            if showsUserLocation {
                UserAnnotation()
            }
        }
        .mapControls {
            MapCompass()
            MapScaleView()
            MapUserLocationButton()
        }
    }
}

private enum ExternalMapProvider {
    case apple
    case google
    case waze

    func url(for place: MapPlaceRecord) -> URL? {
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
                URLQueryItem(name: "ll", value: "\(place.latitude),\(place.longitude)"),
                URLQueryItem(name: "q", value: place.name)
            ]
        case .google:
            [URLQueryItem(name: "q", value: "\(place.latitude),\(place.longitude)")]
        case .waze:
            [URLQueryItem(name: "ll", value: "\(place.latitude),\(place.longitude)")]
        }
        return components.url
    }

    static func canonicalAppleURL(for place: MapPlaceRecord) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "maps.apple.com"
        components.path = "/"
        components.queryItems = [
            URLQueryItem(name: "ll", value: "\(place.latitude),\(place.longitude)"),
            URLQueryItem(name: "q", value: place.name)
        ]
        return components.url
    }
}
