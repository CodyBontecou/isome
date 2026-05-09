import SwiftUI
import SwiftData

private enum MileageOutputFormat: String, CaseIterable, Identifiable {
    case csv
    case pdf

    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
}

struct MileageReportView: View {
    @Bindable var viewModel: LocationViewModel
    @State private var vehicles = MileageVehicleStore.load()
    @State private var options = MileageReportOptions()
    @State private var outputFormat: MileageOutputFormat = .csv
    @State private var useDefaultExportFolder = ExportFolderManager.shared.hasDefaultFolder
    @State private var successMessage: String?
    @State private var showingSuccess = false
    @State private var showingVehicleEditor = false

    private var report: MileageReport {
        var resolved = options
        if resolved.includedVehicleIDs.isEmpty {
            resolved.includedVehicleIDs = Set(vehicles.map(\.id))
        }
        return MileageReportBuilder.build(
            visits: viewModel.allVisits,
            points: viewModel.locationPoints,
            vehicles: vehicles,
            options: resolved
        )
    }

    var body: some View {
        ZStack {
            TE.surface.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    rangeSection
                    vehicleSection
                    purposeSection
                    rateSection
                    previewSection
                    exportSection
                }
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Mileage Report")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingVehicleEditor) {
            MileageVehicleEditorView(vehicles: $vehicles, year: options.year)
        }
        .alert("Export Complete", isPresented: $showingSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(successMessage ?? "Mileage report exported.")
        }
    }

    private var rangeSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "DATE RANGE")
            TECard {
                VStack(spacing: 0) {
                    TERow {
                        HStack {
                            Text("YEAR")
                                .font(TE.mono(.caption, weight: .medium))
                                .tracking(1)
                            Spacer()
                            Picker("", selection: $options.year) {
                                ForEach((2021...Calendar.current.component(.year, from: Date())).reversed(), id: \.self) { year in
                                    Text(year == 2025 ? "Tax Year 2025" : "\(year)").tag(year)
                                }
                            }
                            .labelsHidden()
                        }
                    }
                    TERow(showDivider: false) {
                        Picker("Preset", selection: $options.preset) {
                            ForEach(MileageReportPreset.allCases) { preset in
                                Text(preset.label).tag(preset)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .padding(.horizontal, 16)
            TESectionFooter(text: "Presets cover full tax years and Q1/Q2/Q3/Q4 ranges.")
        }
    }

    private var vehicleSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "VEHICLES")
            TECard {
                VStack(spacing: 0) {
                    ForEach(Array(vehicles.enumerated()), id: \.element.id) { index, vehicle in
                        TERow(showDivider: index != vehicles.count - 1) {
                            Toggle(isOn: vehicleBinding(vehicle.id)) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(vehicle.name.uppercased())
                                        .font(TE.mono(.caption, weight: .medium))
                                        .tracking(1)
                                    Text("SERVICE \(vehicle.placedInService.formatted(date: .numeric, time: .omitted))")
                                        .font(TE.mono(.caption2))
                                        .foregroundStyle(TE.textMuted)
                                }
                            }
                            .toggleStyle(TEToggleStyle())
                        }
                    }
                    TERow(showDivider: false) {
                        Button {
                            showingVehicleEditor = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "car")
                                Text("EDIT VEHICLES")
                                Spacer()
                                Image(systemName: "arrow.right")
                            }
                            .font(TE.mono(.caption, weight: .medium))
                            .tracking(1)
                            .foregroundStyle(TE.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var purposeSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "PURPOSES")
            TECard {
                VStack(spacing: 0) {
                    ForEach(TripClassification.allCases.filter { $0 != .unclassified }) { classification in
                        TERow(showDivider: classification != .commuting) {
                            Toggle(isOn: classificationBinding(classification)) {
                                Text(classification.label.uppercased())
                                    .font(TE.mono(.caption, weight: .medium))
                                    .tracking(1)
                            }
                            .toggleStyle(TEToggleStyle())
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            TESectionFooter(text: "Business is selected by default. Unclassified trips are never included.")
        }
    }

    private var rateSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "DEDUCTION RATE")
            TECard {
                VStack(spacing: 0) {
                    TERow {
                        HStack {
                            Text("CENTS / MILE")
                                .font(TE.mono(.caption, weight: .medium))
                                .tracking(1)
                            Spacer()
                            TextField("Rate", value: Binding(
                                get: { options.overrideCentsPerMile ?? MileageReportBuilder.standardRateCents(for: options.year) },
                                set: { options.overrideCentsPerMile = $0 }
                            ), format: .number.precision(.fractionLength(1)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                            .textFieldStyle(.roundedBorder)
                        }
                    }
                    TERow(showDivider: false) {
                        Button("RESET TO IRS BAKED-IN RATE") {
                            options.overrideCentsPerMile = nil
                        }
                        .font(TE.mono(.caption2, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(TE.accent)
                    }
                }
            }
            .padding(.horizontal, 16)
            TESectionFooter(text: "Includes IRS business mileage rates for 2021-2026, including the 2022 mid-year change.")
        }
    }

    private var previewSection: some View {
        let currentReport = report
        return VStack(spacing: 0) {
            TESectionHeader(title: "PREVIEW")
            TECard {
                VStack(spacing: 0) {
                    metricRow("BUSINESS MILES", value: String(format: "%.1f", currentReport.totalBusinessMiles))
                    metricRow("DEDUCTION", value: String(format: "$%.2f", currentReport.deductionAmount))
                    metricRow("TRIPS INCLUDED", value: "\(currentReport.trips.count)")
                    metricRow("UNCLASSIFIED OMITTED", value: "\(currentReport.unclassifiedTripCount)", showDivider: false)
                }
            }
            .padding(.horizontal, 16)

            if currentReport.unclassifiedTripCount > 0 {
                TESectionFooter(text: "\(currentReport.unclassifiedTripCount) unclassified trips are not included. Classify visits before filing.")
            }

            if !currentReport.trips.isEmpty {
                TECard {
                    VStack(spacing: 0) {
                        ForEach(currentReport.trips.prefix(5)) { trip in
                            TERow(showDivider: trip.id != currentReport.trips.prefix(5).last?.id) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(trip.date.formatted(date: .abbreviated, time: .omitted).uppercased())
                                        Spacer()
                                        Text("\(String(format: "%.1f", trip.miles)) MI")
                                    }
                                    .font(TE.mono(.caption2, weight: .semibold))
                                    .tracking(1)
                                    Text(trip.endAddress)
                                        .font(.caption)
                                        .foregroundStyle(TE.textPrimary)
                                        .lineLimit(2)
                                    Text(trip.purpose.isEmpty ? "No purpose entered" : trip.purpose)
                                        .font(.caption2)
                                        .foregroundStyle(TE.textMuted)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
    }

    private var exportSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "EXPORT")
            TECard {
                VStack(spacing: 0) {
                    TERow {
                        Picker("Format", selection: $outputFormat) {
                            ForEach(MileageOutputFormat.allCases) { format in
                                Text(format.label).tag(format)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    if ExportFolderManager.shared.hasDefaultFolder {
                        TERow {
                            Toggle(isOn: $useDefaultExportFolder) {
                                Text("SAVE TO DEFAULT FOLDER")
                                    .font(TE.mono(.caption, weight: .medium))
                                    .tracking(1)
                            }
                            .toggleStyle(TEToggleStyle())
                        }
                    }
                    TERow(showDivider: false) {
                        Button {
                            runExport()
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("EXPORT \(outputFormat.label)")
                                Spacer()
                            }
                            .font(TE.mono(.caption, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(TE.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            TESectionFooter(text: "CSV is accountant-friendly; PDF is printable with a signature line.")
        }
    }

    private func metricRow(_ label: String, value: String, showDivider: Bool = true) -> some View {
        TERow(showDivider: showDivider) {
            HStack {
                Text(label)
                    .font(TE.mono(.caption, weight: .medium))
                    .tracking(1)
                Spacer()
                Text(value)
                    .font(TE.mono(.caption, weight: .semibold))
                    .foregroundStyle(TE.textMuted)
            }
        }
    }

    private func vehicleBinding(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { options.includedVehicleIDs.isEmpty || options.includedVehicleIDs.contains(id) },
            set: { isOn in
                if options.includedVehicleIDs.isEmpty {
                    options.includedVehicleIDs = Set(vehicles.map(\.id))
                }
                if isOn {
                    options.includedVehicleIDs.insert(id)
                } else {
                    options.includedVehicleIDs.remove(id)
                }
            }
        )
    }

    private func classificationBinding(_ classification: TripClassification) -> Binding<Bool> {
        Binding(
            get: { options.includedClassifications.contains(classification) },
            set: { isOn in
                if isOn {
                    options.includedClassifications.insert(classification)
                } else {
                    options.includedClassifications.remove(classification)
                }
            }
        )
    }

    private func runExport() {
        do {
            let exportFormat: ExportFormat = outputFormat == .csv ? .csv : .markdown
            if useDefaultExportFolder && ExportFolderManager.shared.hasDefaultFolder {
                let url = try ExportService.saveMileageReportToDefaultFolder(report, format: exportFormat)
                successMessage = "Saved to \(url.lastPathComponent)"
                showingSuccess = true
            } else {
                try ExportService.shareMileageReport(report, format: exportFormat)
            }
        } catch {
            viewModel.exportError = error.localizedDescription
        }
    }
}

private struct MileageVehicleEditorView: View {
    @Binding var vehicles: [MileageVehicle]
    let year: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                ForEach($vehicles) { $vehicle in
                    Section(vehicle.name.isEmpty ? "Vehicle" : vehicle.name) {
                        TextField("Vehicle name", text: $vehicle.name)
                        DatePicker("Placed in service", selection: $vehicle.placedInService, displayedComponents: .date)
                        TextField("Year-start odometer", value: odometerBinding(vehicleID: vehicle.id, isStart: true), format: .number.precision(.fractionLength(1)))
                            .keyboardType(.decimalPad)
                        TextField("Year-end odometer", value: odometerBinding(vehicleID: vehicle.id, isStart: false), format: .number.precision(.fractionLength(1)))
                            .keyboardType(.decimalPad)
                    }
                }
                Section {
                    Button {
                        vehicles.append(MileageVehicle(name: "Vehicle \(vehicles.count + 1)", placedInService: Date()))
                    } label: {
                        Label("Add Vehicle", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Vehicles")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        MileageVehicleStore.save(vehicles)
                        dismiss()
                    }
                }
            }
        }
    }

    private func odometerBinding(vehicleID: UUID, isStart: Bool) -> Binding<Double?> {
        Binding<Double?>(
            get: {
                guard let index = vehicles.firstIndex(where: { $0.id == vehicleID }) else { return nil }
                return isStart ? vehicles[index].yearStartOdometer[year] : vehicles[index].yearEndOdometer[year]
            },
            set: { value in
                guard let index = vehicles.firstIndex(where: { $0.id == vehicleID }) else { return }
                if isStart {
                    vehicles[index].yearStartOdometer[year] = value
                } else {
                    vehicles[index].yearEndOdometer[year] = value
                }
            }
        )
    }
}

#Preview {
    MileageReportView(viewModel: LocationViewModel(
        modelContext: try! ModelContainer(for: Visit.self, LocationPoint.self).mainContext,
        locationManager: LocationManager()
    ))
}
