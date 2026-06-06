import SwiftUI
import MapKit
import SwiftData

struct VisitDetailView: View {
    @Bindable var visit: Visit
    @Bindable var viewModel: LocationViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var showingCorrectionSheet = false
    @State private var showingTimeEditor = false
    @State private var errorMessage: String?
    @State private var notesText: String = ""
    @FocusState private var isNotesFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Map
                mapSection

                // Location Info
                locationInfoSection

                // Time Info
                timeInfoSection

                // Notes
                notesSection

                // Actions
                actionsSection
            }
            .padding()
        }
        .navigationTitle("Visit Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            notesText = visit.notes ?? ""
        }
        .alert("Delete Visit?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                viewModel.deleteVisit(visit)
                dismiss()
            }
        } message: {
            Text("This visit will be permanently deleted.")
        }
        .alert("Visit Update Failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let errorMessage {
                Text(errorMessage)
            }
        }
        .sheet(isPresented: $showingCorrectionSheet) {
            PlaceCorrectionSheet(visit: visit, viewModel: viewModel) { update in
                do {
                    try viewModel.correctVisit(visit, with: update)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
        .sheet(isPresented: $showingTimeEditor) {
            VisitTimeEditSheet(visit: visit, viewModel: viewModel) { error in
                errorMessage = error.localizedDescription
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isNotesFieldFocused = false
                    saveNotes()
                }
            }
        }
    }

    // MARK: - Sections

    private var mapSection: some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: visit.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        ))) {
            Marker(visit.displayName, coordinate: visit.coordinate)
                .tint(visit.isCurrentVisit ? .blue : .red)
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel("Visit map")
        .accessibilityValue("\(visit.accessibilityLabel). \(visit.accessibilityValue)")
    }

    private var locationInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(visit.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                if visit.isCurrentVisit {
                    Text("Now")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .accessibilityLabel("Current visit")
                }
            }

            HStack(spacing: 8) {
                VisitBadge(text: visit.source.displayName, color: visit.source.badgeColor)
                VisitBadge(text: visit.confirmationStatus.displayName, color: visit.confirmationStatus.badgeColor)
            }

            if let address = visit.address {
                Text(address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Coordinates (for debugging/reference)
            Text(String(format: "%.6f, %.6f", visit.latitude, visit.longitude))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .monospaced()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var timeInfoSection: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Arrived")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(visit.arrivedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.body)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Departed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let departed = visit.departedAt {
                        Text(departed.formatted(date: .abbreviated, time: .shortened))
                            .font(.body)
                    } else {
                        Text("Still here")
                            .font(.body)
                            .foregroundStyle(.blue)
                    }
                }
            }
            .padding()

            Divider()

            HStack {
                Text("Duration")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(visit.formattedDuration)
                    .font(.title3)
                    .fontWeight(.medium)
            }
            .padding()
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Add notes about this visit...", text: $notesText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(3...6)
                .focused($isNotesFieldFocused)
                .onChange(of: isNotesFieldFocused) { _, focused in
                    if !focused {
                        saveNotes()
                    }
                }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            if visit.confirmationStatus == .unconfirmed {
                Button {
                    viewModel.confirmVisit(visit)
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .accessibilityHidden(true)
                        Text("Confirm Place")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Confirm place")
                .accessibilityValue(visit.displayName)
            }

            Button {
                showingCorrectionSheet = true
            } label: {
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .accessibilityHidden(true)
                    Text("Correct Place")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Correct place")
            .accessibilityValue(visit.displayName)

            if visit.canUndoCorrection {
                Button {
                    do {
                        try viewModel.undoVisitCorrection(visit)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.uturn.backward")
                            .accessibilityHidden(true)
                        Text("Undo Correction")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Undo place correction")
            }

            Button {
                showingTimeEditor = true
            } label: {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .accessibilityHidden(true)
                    Text("Edit Times")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Edit arrival and departure times")

            // Open in Maps
            Button {
                openInMaps()
            } label: {
                HStack {
                    Image(systemName: "map")
                        .accessibilityHidden(true)
                    Text("Open in Maps")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Open visit in Maps")
            .accessibilityValue(visit.displayName)
            .accessibilityHint("Opens this location in Apple Maps.")

            // Delete
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                        .accessibilityHidden(true)
                    Text("Delete Visit")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .accessibilityHint("Deletes this visit after confirmation.")
        }
    }

    // MARK: - Actions

    private func saveNotes() {
        viewModel.updateVisitNotes(visit, notes: notesText)
    }

    private func openInMaps() {
        let placemark = MKPlacemark(coordinate: visit.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = visit.displayName
        mapItem.openInMaps(launchOptions: nil)
    }
}

private struct VisitBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(color.opacity(0.16))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

struct PlaceCorrectionSheet: View {
    let visit: Visit
    @Bindable var viewModel: LocationViewModel
    let onApply: (VisitPlaceUpdate) -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("allowNetworkGeocoding") private var allowNetworkGeocoding = true
    @State private var query = ""
    @State private var customName = ""
    @State private var customAddress = ""
    @State private var candidates: [PlaceCandidate] = []
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Search") {
                    TextField("Restaurant, bookstore, cafe...", text: $query)
                        .textInputAutocapitalization(.words)
                    Button {
                        Task { await search() }
                    } label: {
                        Label("Search Nearby", systemImage: "magnifyingglass")
                    }
                    .disabled(!allowNetworkGeocoding || isSearching)

                    if allowNetworkGeocoding {
                        Text("Apple Maps search may send the approximate coordinate and query to Apple.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Location Names is off in Settings, so Apple Maps search is disabled.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !candidates.isEmpty {
                    Section("Candidates") {
                        ForEach(candidates) { candidate in
                            Button {
                                onApply(candidate.placeUpdate)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(candidate.name)
                                    HStack(spacing: 8) {
                                        if let distance = candidate.distanceMeters {
                                            Text(distanceLabel(distance))
                                        }
                                        if let address = candidate.address {
                                            Text(address)
                                                .lineLimit(1)
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityLabel("Use \(candidate.name)")
                            .accessibilityValue(candidate.address ?? "")
                        }
                    }
                }

                Section("Custom") {
                    TextField("Name at this coordinate", text: $customName)
                        .textInputAutocapitalization(.words)
                    TextField("Address", text: $customAddress)
                        .textInputAutocapitalization(.words)
                    Button {
                        let update = VisitPlaceUpdate(
                            latitude: visit.latitude,
                            longitude: visit.longitude,
                            locationName: customName,
                            address: customAddress,
                            placeSource: .userEntered,
                            placeDistanceMeters: 0,
                            placeConfidence: 0.5
                        )
                        onApply(update)
                        dismiss()
                    } label: {
                        Label("Use Custom Name", systemImage: "text.cursor")
                    }
                    .disabled(customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Correct Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                customName = visit.displayName == "Unknown Location" ? "" : visit.displayName
                customAddress = visit.address ?? ""
                if allowNetworkGeocoding {
                    await search()
                }
            }
        }
    }

    private func search() async {
        isSearching = true
        candidates = await viewModel.searchPlaceCandidates(
            near: visit.coordinate,
            query: query
        )
        isSearching = false
    }

    private func distanceLabel(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters.rounded())) m"
        }
        return String(format: "%.1f km", meters / 1000)
    }
}

struct VisitTimeEditSheet: View {
    @Bindable var visit: Visit
    @Bindable var viewModel: LocationViewModel
    let onError: (Error) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var arrivedAt: Date
    @State private var hasDeparture: Bool
    @State private var departedAt: Date

    init(
        visit: Visit,
        viewModel: LocationViewModel,
        onError: @escaping (Error) -> Void
    ) {
        self.visit = visit
        self.viewModel = viewModel
        self.onError = onError
        _arrivedAt = State(initialValue: visit.arrivedAt)
        _hasDeparture = State(initialValue: visit.departedAt != nil)
        _departedAt = State(initialValue: visit.departedAt ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Times") {
                    DatePicker("Arrived", selection: $arrivedAt)
                    Toggle("Departed", isOn: $hasDeparture)
                    if hasDeparture {
                        DatePicker("Departure Time", selection: $departedAt)
                    }
                }
            }
            .navigationTitle("Edit Times")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            try viewModel.updateVisitTimes(
                                visit,
                                arrivedAt: arrivedAt,
                                departedAt: hasDeparture ? departedAt : nil
                            )
                            dismiss()
                        } catch {
                            onError(error)
                        }
                    }
                }
            }
        }
    }
}

private extension VisitSource {
    var badgeColor: Color {
        switch self {
        case .automatic: return .blue
        case .manual: return .green
        case .imported: return .purple
        }
    }
}

private extension VisitConfirmationStatus {
    var badgeColor: Color {
        switch self {
        case .unconfirmed: return .orange
        case .confirmed: return .green
        case .corrected: return .purple
        }
    }
}

#Preview {
    NavigationStack {
        VisitDetailView(
            visit: Visit.preview,
            viewModel: LocationViewModel(
                modelContext: try! ModelContainer(for: Visit.self, LocationPoint.self).mainContext,
                locationManager: LocationManager()
            )
        )
    }
}
