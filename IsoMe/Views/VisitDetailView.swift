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
        ZStack {
            TE.surface.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    mapSection
                    locationInfoSection
                    timeInfoSection
                    classificationSection
                    vehicleSection
                    notesSection
                    actionsSection
                }
                .padding(.bottom, 32)
            }
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
        VStack(spacing: 0) {
            TESectionHeader(title: "MAP")

            Map(initialPosition: .region(MKCoordinateRegion(
                center: visit.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            ))) {
                Marker(visit.displayName, coordinate: visit.coordinate)
                    .tint(visit.purpose.mapTint)
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(TE.border, lineWidth: 1)
            )
            .padding(.horizontal, 16)
        }
    }

    private var locationInfoSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "LOCATION")

            TECard {
                TERow(showDivider: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(visit.displayName.uppercased())
                                    .font(TE.mono(.caption, weight: .semibold))
                                    .tracking(1)
                                    .foregroundStyle(TE.textPrimary)

                                if let address = visit.address {
                                    Text(address)
                                        .font(TE.mono(.caption2))
                                        .foregroundStyle(TE.textMuted)
                                }
                            }

                            Spacer()

                            if visit.isCurrentVisit {
                                Text("NOW")
                                    .font(TE.mono(.caption2, weight: .bold))
                                    .tracking(1)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(TE.accent, in: Capsule())
                            }
                        }

                        Text(String(format: "%.6f, %.6f", visit.latitude, visit.longitude))
                            .font(TE.mono(.caption2))
                            .foregroundStyle(TE.textMuted.opacity(0.75))
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var timeInfoSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "TIME")

            TECard {
                infoRow("ARRIVED", value: visit.arrivedAt.formatted(date: .abbreviated, time: .shortened))
                infoRow("DEPARTED", value: visit.departedAt?.formatted(date: .abbreviated, time: .shortened) ?? "Still here", valueColor: visit.departedAt == nil ? TE.accent : TE.textMuted)
                infoRow("DURATION", value: visit.formattedDuration, showDivider: false, valueColor: TE.textPrimary)
            }
            .padding(.horizontal, 16)
        }
    }

    private var classificationSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "CLASSIFICATION")

            TECard {
                TERow(showDivider: visit.purpose == .business) {
                    HStack(spacing: 0) {
                        ForEach(Array(TripPurpose.allCases.enumerated()), id: \.element.id) { index, purpose in
                            purposeSegment(purpose)
                            if index < TripPurpose.allCases.count - 1 {
                                Rectangle()
                                    .fill(TE.border)
                                    .frame(width: 1)
                            }
                        }
                    }
                    .frame(height: 44)
                }

                if visit.purpose == .business {
                    TERow(showDivider: !viewModel.frequentBusinessSubPurposes.isEmpty) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text("PURPOSE")
                                .font(TE.mono(.caption, weight: .medium))
                                .tracking(1)
                                .foregroundStyle(TE.textPrimary)
                            Spacer(minLength: 12)
                            TextField("Client Visit", text: $subPurposeText)
                                .font(TE.mono(.caption, weight: .medium))
                                .foregroundStyle(TE.textMuted)
                                .multilineTextAlignment(.trailing)
                                .textFieldStyle(.plain)
                                .focused($isSubPurposeFieldFocused)
                                .submitLabel(.done)
                                .onSubmit { saveClassification() }
                                .onChange(of: isSubPurposeFieldFocused) { _, focused in
                                    if !focused {
                                        saveClassification()
                                    }
                                }
                        }
                    }

                    if !viewModel.frequentBusinessSubPurposes.isEmpty {
                        TERow(showDivider: false) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(viewModel.frequentBusinessSubPurposes, id: \.self) { subPurpose in
                                        Button {
                                            subPurposeText = subPurpose
                                            saveClassification()
                                        } label: {
                                            Text(subPurpose.uppercased())
                                                .font(TE.mono(.caption2, weight: .semibold))
                                                .tracking(1)
                                                .foregroundStyle(TE.accent)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(TE.accent.opacity(0.08), in: Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)

            TESectionFooter(text: "Business trips can include a sub-purpose for accountant-ready exports.")
        }
    }

    private var vehicleSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "VEHICLE")

            TECard {
                TERow(showDivider: visit.isVehicleAutoDetected || !viewModel.recentVehicles.isEmpty) {
                    HStack(spacing: 12) {
                        Text("ASSIGNED")
                            .font(TE.mono(.caption, weight: .medium))
                            .tracking(1)
                            .foregroundStyle(TE.textPrimary)

                        Spacer()

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
                        .tint(TE.accent)
                    }
                }

                if visit.isVehicleAutoDetected, let portName = visit.vehicleBluetoothPortName {
                    TERow(showDivider: !viewModel.recentVehicles.isEmpty) {
                        HStack(spacing: 8) {
                            Image(systemName: "bluetooth")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(TE.accent)
                            Text("DETECTED VIA \(portName.uppercased())")
                                .font(TE.mono(.caption2, weight: .semibold))
                                .tracking(1)
                                .foregroundStyle(TE.textMuted)
                            Spacer()
                        }
                    }
                }

                if !viewModel.recentVehicles.isEmpty {
                    TERow(showDivider: false) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(viewModel.recentVehicles) { vehicle in
                                    recentVehicleButton(vehicle)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .onAppear {
                viewModel.loadVehicles()
            }
        }
    }

    private var notesSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "NOTES")

            TECard {
                TERow(showDivider: false) {
                    TextField("Add notes about this visit...", text: $notesText, axis: .vertical)
                        .font(TE.mono(.caption, weight: .medium))
                        .foregroundStyle(TE.textPrimary)
                        .lineLimit(3...6)
                        .textFieldStyle(.plain)
                        .focused($isNotesFieldFocused)
                        .onChange(of: isNotesFieldFocused) { _, focused in
                            if !focused {
                                saveNotes()
                            }
                        }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "ACTIONS")

            TECard {
                TERow {
                    actionButton(title: "OPEN IN MAPS", icon: "map", color: TE.accent) {
                        openInMaps()
                    }
                }

                TERow(showDivider: false) {
                    actionButton(title: "DELETE VISIT", icon: "trash", color: TE.danger) {
                        showingDeleteConfirmation = true
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Reusable Components

    private func infoRow(_ label: String, value: String, showDivider: Bool = true, valueColor: Color = TE.textMuted) -> some View {
        TERow(showDivider: showDivider) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(TE.mono(.caption, weight: .medium))
                    .tracking(1)
                    .foregroundStyle(TE.textPrimary)
                Spacer(minLength: 16)
                Text(value)
                    .font(TE.mono(.caption2, weight: .medium))
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(valueColor)
            }
        }
    }

    private func purposeSegment(_ purpose: TripPurpose) -> some View {
        let isSelected = visit.purpose == purpose
        return Button {
            viewModel.updateVisitClassification(visit, purpose: purpose, subPurpose: subPurposeText)
            if purpose != .business {
                subPurposeText = ""
            }
        } label: {
            Text(purpose.label.uppercased())
                .font(TE.mono(.caption2, weight: isSelected ? .bold : .medium))
                .tracking(1)
                .foregroundStyle(isSelected ? purpose.mapTint : TE.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(isSelected ? purpose.mapTint.opacity(0.08) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private func recentVehicleButton(_ vehicle: Vehicle) -> some View {
        let isSelected = visit.vehicleID == vehicle.id
        return Button {
            viewModel.assignVehicle(vehicle.id, to: visit)
        } label: {
            Text(vehicle.name.uppercased())
                .font(TE.mono(.caption2, weight: isSelected ? .bold : .semibold))
                .tracking(1)
                .foregroundStyle(isSelected ? TE.accent : TE.textMuted)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? TE.accent.opacity(0.08) : TE.border.opacity(0.35), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(color)
                Text(title)
                    .font(TE.mono(.caption, weight: .medium))
                    .tracking(1)
                    .foregroundStyle(color)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(color.opacity(0.5))
            }
        }
        .buttonStyle(.plain)
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
        case .commuting: return .blue
        case .unclassified: return TE.warning
        }
    }
}

#Preview {
    NavigationStack {
        VisitDetailView(
            visit: Visit.preview,
            viewModel: LocationViewModel(
                modelContext: try! ModelContainer(for: Visit.self, LocationPoint.self, Vehicle.self).mainContext,
                locationManager: LocationManager()
            )
        )
    }
}
