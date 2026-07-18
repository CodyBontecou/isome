import SwiftUI
import MapKit
import CoreLocation

enum ManualVisitMode: Equatable {
    case saveCurrentPlace
    case addPlaceManually
    case addPastVisit

    var allowsImplicitCurrentLocation: Bool {
        self != .addPastVisit
    }

    var requestsCurrentLocation: Bool {
        self != .addPastVisit
    }

    var requiresDeparture: Bool {
        self == .addPastVisit
    }

    func resolvedCoordinate(
        selection: ManualLocationSelection?,
        currentLocation: CLLocation?
    ) -> CLLocationCoordinate2D? {
        if let selection, selection.coordinateIsValid {
            return selection.coordinate
        }
        guard allowsImplicitCurrentLocation,
              let currentLocation,
              CLLocationCoordinate2DIsValid(currentLocation.coordinate) else {
            return nil
        }
        return currentLocation.coordinate
    }
}

enum ManualLocationSelectionSource: Equatable {
    case currentLocation
    case savedPlace
    case appleMaps
    case mapPin
}

struct ManualLocationSelection {
    var name: String
    var address: String?
    var coordinate: CLLocationCoordinate2D
    var source: ManualLocationSelectionSource
    var savedPlaceID: UUID?
    var visitPlaceSource: VisitPlaceSource

    init(
        name: String,
        address: String?,
        coordinate: CLLocationCoordinate2D,
        source: ManualLocationSelectionSource,
        savedPlaceID: UUID? = nil,
        visitPlaceSource: VisitPlaceSource? = nil
    ) {
        self.name = name
        self.address = address
        self.coordinate = coordinate
        self.source = source
        self.savedPlaceID = savedPlaceID
        self.visitPlaceSource = visitPlaceSource ?? (source == .appleMaps ? .appleMaps : .userEntered)
    }

    mutating func updateUserEnteredMetadata(name: String, address: String?) {
        self.name = name
        self.address = address
        visitPlaceSource = .userEntered
    }

    var coordinateIsValid: Bool {
        CLLocationCoordinate2DIsValid(coordinate) &&
        coordinate.latitude.isFinite &&
        coordinate.longitude.isFinite
    }

    static func appleMapsResult(_ result: PlaceSearchResult) -> ManualLocationSelection {
        ManualLocationSelection(
            name: result.name,
            address: result.address,
            coordinate: result.coordinate,
            source: .appleMaps
        )
    }

    static func savedPlace(_ place: SavedPlace) -> ManualLocationSelection {
        ManualLocationSelection(
            name: place.name,
            address: place.address,
            coordinate: place.coordinate,
            source: .savedPlace,
            savedPlaceID: place.id,
            visitPlaceSource: .userEntered
        )
    }
}

struct PlaceSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var searchModel: PlaceSearchViewModel

    private let initialRegion: MKCoordinateRegion?
    private let geocodingService: GeocodingService
    private let onSelect: (ManualLocationSelection) -> Void

    @State private var selection: ManualLocationSelection?
    @State private var cameraPosition: MapCameraPosition
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var reverseGeocodingTask: Task<Void, Never>?
    @State private var isReverseGeocoding = false

    init(
        initialSelection: ManualLocationSelection? = nil,
        initialRegion: MKCoordinateRegion? = nil,
        searchService: any PlaceSearchServicing = PlaceSearchService.shared,
        geocodingService: GeocodingService = GeocodingService(),
        onSelect: @escaping (ManualLocationSelection) -> Void
    ) {
        self.initialRegion = initialRegion
        self.geocodingService = geocodingService
        self.onSelect = onSelect
        _selection = State(initialValue: initialSelection)
        _searchModel = StateObject(wrappedValue: PlaceSearchViewModel(service: searchService))

        if let initialSelection {
            _cameraPosition = State(initialValue: .region(Self.region(around: initialSelection.coordinate)))
        } else if let initialRegion {
            _cameraPosition = State(initialValue: .region(initialRegion))
        } else {
            _cameraPosition = State(initialValue: .automatic)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    locationMap
                        .frame(height: 260)
                        .listRowInsets(EdgeInsets())

                    Button {
                        guard let mapCenterCoordinate else { return }
                        selectMapPin(at: mapCenterCoordinate)
                    } label: {
                        Label("Drop Pin at Map Center", systemImage: "mappin")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .disabled(mapCenterCoordinate == nil)
                } footer: {
                    Text("Tap the map to place the pin exactly where the visit happened.")
                }

                if let selection {
                    Section("Selected Location") {
                        selectedLocationRow(selection)
                    }
                }

                searchStateContent
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Choose Location")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchModel.query, prompt: "Search places or addresses")
            .onSubmit(of: .search) {
                searchModel.submit(region: searchRegion)
            }
            .onChange(of: searchModel.query) { _, _ in
                searchModel.queryChanged(region: searchRegion)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use") {
                        guard let selection else { return }
                        onSelect(selection)
                        dismiss()
                    }
                    .disabled(selection?.coordinateIsValid != true)
                    .accessibilityLabel("Use This Location")
                }
            }
            .onDisappear {
                searchModel.clear()
                reverseGeocodingTask?.cancel()
            }
        }
    }

    private var searchRegion: MKCoordinateRegion? {
        visibleRegion ?? initialRegion
    }

    private var mapCenterCoordinate: CLLocationCoordinate2D? {
        visibleRegion?.center ?? initialRegion?.center ?? selection?.coordinate
    }

    private var locationMap: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) {
                if let selection, selection.coordinateIsValid {
                    Marker(
                        selection.name.isEmpty ? "Selected Location" : selection.name,
                        systemImage: "mappin",
                        coordinate: selection.coordinate
                    )
                    .tint(.red)
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                visibleRegion = context.region
            }
            .onTapGesture { point in
                guard let coordinate = proxy.convert(point, from: .local) else { return }
                selectMapPin(at: coordinate)
            }
            .accessibilityLabel("Location selection map")
            .accessibilityHint("Search for an accessible list of places, or tap the map to move the selected pin.")
        }
    }

    @ViewBuilder
    private var searchStateContent: some View {
        let trimmedQuery = searchModel.query.trimmingCharacters(in: .whitespacesAndNewlines)

        if searchModel.isSearching {
            Section {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Searching Apple Maps…")
                        .foregroundStyle(.secondary)
                }
            }
        } else if let errorMessage = searchModel.errorMessage {
            Section {
                ContentUnavailableView(
                    "Search Unavailable",
                    systemImage: "wifi.exclamationmark",
                    description: Text(errorMessage)
                )
                Button("Try Again") {
                    searchModel.submit(region: searchRegion)
                }
            }
        } else if !searchModel.results.isEmpty {
            Section("Search Results") {
                ForEach(searchModel.results) { result in
                    Button {
                        selectSearchResult(result)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.name)
                                .foregroundStyle(.primary)
                            if let address = result.address, !address.isEmpty {
                                Text(address)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(result.name)
                    .accessibilityValue(result.address ?? "")
                    .accessibilityHint("Selects this location for the past visit.")
                }
            }
        } else if trimmedQuery.count >= 2 {
            Section {
                ContentUnavailableView.search(text: trimmedQuery)
            }
        } else {
            Section {
                ContentUnavailableView(
                    "Find Where You Were",
                    systemImage: "magnifyingglass",
                    description: Text("Search for a business, landmark, or street address. You can also navigate and tap the map.")
                )
            }
        }
    }

    private func selectedLocationRow(_ selection: ManualLocationSelection) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Image(systemName: selection.source == .mapPin ? "mappin" : "checkmark.circle.fill")
                    .foregroundStyle(selection.source == .mapPin ? .red : .green)
                Text(selection.name.isEmpty ? "Pinned location" : selection.name)
                    .font(.headline)
            }

            if let address = selection.address, !address.isEmpty {
                Text(address)
                    .foregroundStyle(.secondary)
            } else if isReverseGeocoding {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Finding address…")
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Add a place name in the visit form.")
                    .foregroundStyle(.secondary)
            }

            Text(String(
                format: "%.6f, %.6f",
                selection.coordinate.latitude,
                selection.coordinate.longitude
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospaced()
        }
        .accessibilityElement(children: .combine)
    }

    private func selectSearchResult(_ result: PlaceSearchResult) {
        reverseGeocodingTask?.cancel()
        isReverseGeocoding = false
        selection = .appleMapsResult(result)
        cameraPosition = .region(Self.region(around: result.coordinate))
    }

    private func selectMapPin(at coordinate: CLLocationCoordinate2D) {
        guard CLLocationCoordinate2DIsValid(coordinate),
              coordinate.latitude.isFinite,
              coordinate.longitude.isFinite else {
            return
        }

        reverseGeocodingTask?.cancel()

        // Moving the pin starts a new selection. Do not carry a POI's metadata
        // onto a neighboring coordinate while reverse geocoding is in flight.
        selection = ManualLocationSelection(
            name: "",
            address: nil,
            coordinate: coordinate,
            source: .mapPin,
            visitPlaceSource: .userEntered
        )

        isReverseGeocoding = true
        let requestedLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        reverseGeocodingTask = Task {
            do {
                let result = try await geocodingService.reverseGeocode(location: requestedLocation)
                try Task.checkCancellation()
                guard let currentSelection = selection,
                      Self.coordinatesMatch(currentSelection.coordinate, coordinate) else {
                    return
                }

                let hasGeocodedMetadata = result.name?.isEmpty == false || result.address?.isEmpty == false
                selection = ManualLocationSelection(
                    name: result.name ?? currentSelection.name,
                    address: result.address?.isEmpty == false ? result.address : currentSelection.address,
                    coordinate: coordinate,
                    source: .mapPin,
                    visitPlaceSource: hasGeocodedMetadata ? .coreLocationGeocode : .userEntered
                )
            } catch is CancellationError {
                // The pin moved again before this lookup completed.
            } catch {
                // The coordinate remains valid even when an address cannot be found.
            }

            if let currentSelection = selection,
               Self.coordinatesMatch(currentSelection.coordinate, coordinate) {
                isReverseGeocoding = false
            }
        }
    }

    private static func coordinatesMatch(
        _ lhs: CLLocationCoordinate2D,
        _ rhs: CLLocationCoordinate2D
    ) -> Bool {
        abs(lhs.latitude - rhs.latitude) < 0.000_001 &&
        abs(lhs.longitude - rhs.longitude) < 0.000_001
    }

    private static func region(around coordinate: CLLocationCoordinate2D) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 1_000,
            longitudinalMeters: 1_000
        )
    }
}
