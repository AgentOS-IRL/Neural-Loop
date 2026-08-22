import CoreLocation
import SwiftUI

struct ParkingDetectionSetupSheet: View {
    let provider: ExternalMapProvider
    let onEnable: () async -> Void
    let onOpenWithoutDetection: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "car.side.and.exclamationmark")
                    .font(.system(size: 44))
                    .foregroundStyle(AppTheme.accentColor)

                Text("Find your parked car automatically")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("After Neural Loop opens \(provider.displayName), it will use Location and Motion for this trip only. The iOS blue location indicator remains visible while detection is active.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)

                Label("Waits up to 30 minutes for a verified drive", systemImage: "clock")
                Label("Stops sensors immediately after parking is found", systemImage: "battery.100percent")
                Label("Never monitors trips you did not start here", systemImage: "hand.tap")

                Spacer()

                Button {
                    isWorking = true
                    Task {
                        await onEnable()
                        dismiss()
                    }
                } label: {
                    HStack {
                        if isWorking { ProgressView().tint(.white) }
                        Text("Enable Parking Detection and Open")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accentColor)
                .disabled(isWorking)

                Button("Open Without Parking Detection") {
                    isWorking = true
                    Task {
                        await onOpenWithoutDetection()
                        dismiss()
                    }
                }
                .frame(maxWidth: .infinity)
                .disabled(isWorking)
            }
            .padding(24)
            .navigationTitle("Parking Detection")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isWorking)
        }
        .presentationDetents([.large])
    }
}

struct ParkingDetectionBanner: View {
    let phase: ParkingDetectionPhase
    let stop: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: phase == .waitingForDrive ? "car.side" : "location.fill")
                .font(.title3)
                .foregroundStyle(AppTheme.accentColor)
            VStack(alignment: .leading, spacing: 3) {
                Text(phase.title)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(detail)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Button("Stop", action: stop)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .buttonStyle(.bordered)
                .tint(AppTheme.warningTint)
        }
        .padding(16)
        .background(AppTheme.sectionGradient)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                .strokeBorder(AppTheme.borderGradient, lineWidth: 1)
        }
    }

    private var detail: String {
        switch phase {
        case .preparing: "Starting Location and Motion…"
        case .waitingForDrive: "Detection stops if no verified drive begins within 30 minutes."
        case .driving: "Monitoring for the end of this vehicle trip."
        case .confirmingParking: "Confirming that the vehicle trip has ended."
        case .idle: ""
        }
    }
}

struct ParkingPlaceRow: View {
    let place: MapPlaceItem

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(place.name)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                if place.isSyncPending {
                    Label("Sync Pending", systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundStyle(AppTheme.warningTint)
                }
            }

            if let parkedAt = place.parkedAt {
                Text("Parked \(parkedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Text(place.address ?? MapsLocationTextFormatter.coordinates(
                latitude: place.latitude,
                longitude: place.longitude
            ))
            .font(.system(.caption, design: .rounded))
            .foregroundStyle(AppTheme.textSecondary)
            .lineLimit(2)
        }
        .padding(.vertical, 5)
    }
}

struct ParkingHistoryView: View {
    @ObservedObject var store: MapsStore
    @ObservedObject var coordinator: ParkingDetectionCoordinator
    @ObservedObject var locationService: MapsLocationService

    var body: some View {
        List {
            ForEach(store.parkingHistory()) { place in
                NavigationLink {
                    MapPlaceDetailView(
                        placeReference: place.id,
                        store: store,
                        coordinator: coordinator,
                        locationService: locationService
                    )
                } label: {
                    ParkingPlaceRow(place: place)
                }
            }
        }
        .navigationTitle("Parking History")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.backgroundGradient.ignoresSafeArea())
    }
}

struct SaveParkingPermanentlySheet: View {
    let place: MapPlaceItem
    let folders: [MapFolderRecord]
    let onSave: (Int64, String) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var folderID: Int64
    @State private var name: String
    @State private var errorMessage: String?

    init(
        place: MapPlaceItem,
        folders: [MapFolderRecord],
        initialFolderID: Int64,
        onSave: @escaping (Int64, String) throws -> Void
    ) {
        self.place = place
        self.folders = folders
        self.onSave = onSave
        _folderID = State(initialValue: initialFolderID)
        _name = State(initialValue: place.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Place") {
                    TextField("Name", text: $name)
                    Picker("Folder", selection: $folderID) {
                        ForEach(folders) { folder in
                            Text(folder.name).tag(folder.id)
                        }
                    }
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(AppTheme.errorTint)
                }
            }
            .navigationTitle("Save Permanently")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            try onSave(folderID, name)
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
