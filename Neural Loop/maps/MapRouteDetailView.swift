import CoreLocation
import MapKit
import SwiftUI

struct MapRouteDetailView: View {
    let route: MapRouteRecord
    let waypoints: [MapRouteWaypointRecord]
    @ObservedObject var locationService: MapsLocationService
    @ObservedObject var store: MapsStore
    @EnvironmentObject private var model: UnifiedDataModel

    @State private var routeLegs: [MKRoute] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var position: MapCameraPosition
    @State private var selectedTask: Tasks?

    init(
        route: MapRouteRecord,
        waypoints: [MapRouteWaypointRecord],
        locationService: MapsLocationService,
        store: MapsStore
    ) {
        self.route = route
        self.waypoints = waypoints
        self.locationService = locationService
        self.store = store
        _position = State(initialValue: .rect(Self.mapRect(for: waypoints)))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $position) {
                ForEach(routeLegs.indices, id: \.self) { index in
                    MapPolyline(routeLegs[index].polyline)
                        .stroke(AppTheme.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                }

                ForEach(Array(waypoints.enumerated()), id: \.element.id) { index, waypoint in
                    Annotation(
                        markerAccessibilityLabel(index: index),
                        coordinate: waypoint.coordinate
                    ) {
                        RouteWaypointMarker(
                            style: markerStyle(index: index),
                            accessibilityLabel: markerAccessibilityLabel(index: index)
                        )
                    }
                }

                if locationService.isAuthorized {
                    UserAnnotation()
                }
            }
            .mapControls {
                MapCompass()
                MapScaleView()
                MapUserLocationButton()
            }
            .ignoresSafeArea(edges: .bottom)

            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Calculating route…")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 108)
            } else if let errorMessage {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Route unavailable", systemImage: "exclamationmark.triangle")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Text(errorMessage)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                    Button("Retry") {
                        Task { await loadRoutePreview() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accentColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }

            VStack {
                TaskMapLinkBadge(
                    links: store.taskLinks(forRouteID: route.id),
                    onSelectTask: { taskID in
                        selectedTask = model.getTask(by: taskID)
                    }
                )
                .padding(.top, 12)
                Spacer()
            }
        }
        .navigationTitle(route.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: route.id) {
            await loadRoutePreview()
        }
        .sheet(item: $selectedTask) { task in
            IndividualTodoView(task: task)
        }
    }

    private func loadRoutePreview() async {
        isLoading = true
        errorMessage = nil
        routeLegs = []
        position = .rect(Self.mapRect(for: waypoints))

        do {
            let calculated = try await MultiLegRouteCalculator.calculate(
                waypoints: waypoints.map(\.coordinate),
                transportType: route.transport_mode.mapKitTransportType
            )

            guard !Task.isCancelled else { return }
            routeLegs = calculated
            position = .rect(Self.mapRect(for: waypoints, routes: calculated))
        } catch is CancellationError {
            return
        } catch {
            routeLegs = []
            errorMessage = error.localizedDescription
            position = .rect(Self.mapRect(for: waypoints))
        }

        isLoading = false
    }

    private func markerStyle(index: Int) -> RouteWaypointMarkerStyle {
        if index == 0 {
            return RouteWaypointMarkerStyle(color: .green, emoji: waypoints[index].emoji ?? "▶️")
        }
        if index == waypoints.count - 1 {
            return RouteWaypointMarkerStyle(color: .red, emoji: waypoints[index].emoji ?? "🏁")
        }
        return RouteWaypointMarkerStyle(color: AppTheme.accentColor, emoji: waypoints[index].emoji)
    }

    private func markerAccessibilityLabel(index: Int) -> String {
        if index == 0 { return "Route start" }
        if index == waypoints.count - 1 { return "Route end" }
        return "Route waypoint"
    }

    private static func mapRect(
        for waypoints: [MapRouteWaypointRecord],
        routes: [MKRoute] = []
    ) -> MKMapRect {
        var rect = MKMapRect.null

        for waypoint in waypoints {
            let point = MKMapPoint(waypoint.coordinate)
            let pointRect = MKMapRect(x: point.x, y: point.y, width: 1, height: 1)
            rect = rect.isNull ? pointRect : rect.union(pointRect)
        }

        for route in routes {
            rect = rect.isNull ? route.polyline.boundingMapRect : rect.union(route.polyline.boundingMapRect)
        }

        if rect.isNull {
            return MKMapRect.world
        }

        let minimumPadding = 2_000.0
        let horizontalPadding = max(rect.size.width * 0.18, minimumPadding)
        let verticalPadding = max(rect.size.height * 0.18, minimumPadding)
        return rect.insetBy(dx: -horizontalPadding, dy: -verticalPadding)
    }
}

private struct RouteWaypointMarkerStyle {
    let color: Color
    let emoji: String?
}

private struct RouteWaypointMarker: View {
    let style: RouteWaypointMarkerStyle
    let accessibilityLabel: String

    var body: some View {
        ZStack {
            Circle()
                .fill(style.color)
                .frame(width: 38, height: 38)
                .overlay {
                    Circle()
                        .strokeBorder(.white, lineWidth: 3)
                }
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)

            if let emoji = style.emoji, !emoji.isEmpty {
                Text(String(emoji.prefix(1)))
                    .font(.system(size: 18))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }
}

private extension MapRouteWaypointRecord {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
