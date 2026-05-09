import SwiftUI
import MapKit
import SwiftData

struct VisitDetailView: View {
    @Bindable var visit: Visit
    @Bindable var viewModel: LocationViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var notesText: String = ""
    @State private var subPurposeText: String = ""
    @FocusState private var isNotesFieldFocused: Bool
    @FocusState private var isSubPurposeFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Map
                mapSection

                // Location Info
                locationInfoSection

                // Time Info
                timeInfoSection

                // Classification
                classificationSection

                // Vehicle
                vehicleSection

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
            subPurposeText = visit.subPurpose ?? ""
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
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isNotesFieldFocused = false
                    isSubPurposeFieldFocused = false
                    saveNotes()
                    saveClassification()
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
                .tint(visit.purpose.mapTint)
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
                }
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

    private var vehicleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Vehicle")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if visit.isVehicleAutoDetected {
                    HStack(spacing: 4) {
                        Image(systemName: "bluetooth")
                        Text("Auto")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
                }
            }

            Picker("Vehicle", selection: Binding<UUID?>(
                get: { visit.vehicleID },
                set: { viewModel.assignVehicle($0, to: visit) }
            )) {
                Text("No Vehicle").tag(nil as UUID?)
                ForEach(viewModel.activeVehicles) { vehicle in
                    Text(vehicle.name).tag(Optional(vehicle.id))
                }
                if let vehicle = viewModel.vehicle(for: visit.vehicleID), vehicle.isArchived {
                    Text("\(vehicle.name) (Archived)").tag(Optional(vehicle.id))
                }
            }
            .pickerStyle(.menu)

            if visit.isVehicleAutoDetected, let portName = visit.vehicleBluetoothPortName {
                Label("Detected via \(portName)", systemImage: "bluetooth")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !viewModel.recentVehicles.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.recentVehicles) { vehicle in
                            Button {
                                viewModel.assignVehicle(vehicle.id, to: visit)
                            } label: {
                                Text(vehicle.name)
                                    .font(.caption)
                                    .fontWeight(visit.vehicleID == vehicle.id ? .semibold : .regular)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(visit.vehicleID == vehicle.id ? Color.accentColor.opacity(0.16) : Color(.tertiarySystemBackground), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            viewModel.loadVehicles()
        }
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

    private var classificationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Classification")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Classification", selection: Binding(
                get: { visit.purpose },
                set: { newPurpose in
                    viewModel.updateVisitClassification(visit, purpose: newPurpose, subPurpose: subPurposeText)
                    if newPurpose != .business {
                        subPurposeText = ""
                    }
                }
            )) {
                ForEach(TripPurpose.allCases) { purpose in
                    Label(purpose.label, systemImage: purpose.iconName)
                        .tag(purpose)
                }
            }
            .pickerStyle(.segmented)

            if visit.purpose == .business {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Sub-purpose, e.g. Client Visit", text: $subPurposeText)
                        .textFieldStyle(.roundedBorder)
                        .focused($isSubPurposeFieldFocused)
                        .submitLabel(.done)
                        .onSubmit { saveClassification() }
                        .onChange(of: isSubPurposeFieldFocused) { _, focused in
                            if !focused {
                                saveClassification()
                            }
                        }

                    if !viewModel.frequentBusinessSubPurposes.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(viewModel.frequentBusinessSubPurposes, id: \.self) { subPurpose in
                                    Button(subPurpose) {
                                        subPurposeText = subPurpose
                                        saveClassification()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            // Open in Maps
            Button {
                openInMaps()
            } label: {
                HStack {
                    Image(systemName: "map")
                    Text("Open in Maps")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            // Delete
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Visit")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }

    // MARK: - Actions

    private func saveNotes() {
        viewModel.updateVisitNotes(visit, notes: notesText)
    }

    private func saveClassification() {
        viewModel.updateVisitClassification(visit, purpose: visit.purpose, subPurpose: subPurposeText)
    }

    private func openInMaps() {
        let placemark = MKPlacemark(coordinate: visit.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = visit.displayName
        mapItem.openInMaps(launchOptions: nil)
    }
}

extension TripPurpose {
    var mapTint: Color {
        switch self {
        case .business: return TE.success
        case .personal: return TE.accent
        case .unclassified: return TE.warning
        }
    }
}

#Preview {
    NavigationStack {
        VisitDetailView(
            visit: Visit.preview,
            viewModel: LocationViewModel(
                modelContext: try! ModelContainer(for: Visit.self).mainContext,
                locationManager: LocationManager()
            )
        )
    }
}
