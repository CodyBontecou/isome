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
                        HStack(spacing: 0) {
                            ForEach(Array(MileageReportPreset.allCases.enumerated()), id: \.element.id) { index, preset in
                                segmentedButton(preset.label.uppercased(), value: preset, selection: $options.preset)
                                if index < MileageReportPreset.allCases.count - 1 {
                                    Rectangle()
                                        .fill(TE.border)
                                        .frame(width: 1)
                                }
                            }
                        }
                        .frame(height: 44)
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
                        HStack(spacing: 0) {
                            ForEach(Array(MileageOutputFormat.allCases.enumerated()), id: \.element.id) { index, format in
                                segmentedButton(format.label, value: format, selection: $outputFormat)
                                if index < MileageOutputFormat.allCases.count - 1 {
                                    Rectangle()
                                        .fill(TE.border)
                                        .frame(width: 1)
                                }
                            }
                        }
                        .frame(height: 44)
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

    private func segmentedButton<Value: Hashable>(_ title: String, value: Value, selection: Binding<Value>) -> some View {
        let isSelected = selection.wrappedValue == value
        return Button {
            selection.wrappedValue = value
        } label: {
            Text(title)
                .font(TE.mono(.caption2, weight: isSelected ? .bold : .medium))
                .tracking(1.5)
                .foregroundStyle(isSelected ? TE.accent : TE.textMuted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(isSelected ? TE.accent.opacity(0.08) : Color.clear)
        }
        .buttonStyle(.plain)
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
            ZStack {
                TE.surface.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach($vehicles) { $vehicle in
                            vehicleSection(vehicle: $vehicle)
                        }

                        addVehicleSection
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Vehicles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        MileageVehicleStore.save(vehicles)
                        dismiss()
                    }
                    .foregroundStyle(TE.accent)
                }
            }
        }
    }

    private func vehicleSection(vehicle: Binding<MileageVehicle>) -> some View {
        let sectionTitle = vehicle.wrappedValue.name.isEmpty ? "VEHICLE" : vehicle.wrappedValue.name.uppercased()
        return VStack(spacing: 0) {
            TESectionHeader(title: LocalizedStringKey(sectionTitle))

            TECard {
                textFieldRow("NAME", text: vehicle.name, placeholder: "Vehicle name")
                dateRow("PLACED IN SERVICE", date: vehicle.placedInService)
                numberFieldRow("YEAR-START ODOMETER", value: odometerBinding(vehicleID: vehicle.wrappedValue.id, isStart: true))
                numberFieldRow("YEAR-END ODOMETER", value: odometerBinding(vehicleID: vehicle.wrappedValue.id, isStart: false), showDivider: false)
            }
            .padding(.horizontal, 16)
        }
    }

    private var addVehicleSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "ACTIONS")

            TECard {
                TERow(showDivider: false) {
                    Button {
                        vehicles.append(MileageVehicle(name: "Vehicle \(vehicles.count + 1)", placedInService: Date()))
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(TE.accent)
                            Text("ADD VEHICLE")
                                .font(TE.mono(.caption, weight: .medium))
                                .tracking(1)
                                .foregroundStyle(TE.accent)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(TE.accent.opacity(0.5))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func textFieldRow(_ label: String, text: Binding<String>, placeholder: String, showDivider: Bool = true) -> some View {
        TERow(showDivider: showDivider) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(label)
                    .font(TE.mono(.caption, weight: .medium))
                    .tracking(1)
                    .foregroundStyle(TE.textPrimary)
                Spacer(minLength: 12)
                TextField(placeholder, text: text)
                    .font(TE.mono(.caption, weight: .medium))
                    .foregroundStyle(TE.textMuted)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.plain)
            }
        }
    }

    private func dateRow(_ label: String, date: Binding<Date>, showDivider: Bool = true) -> some View {
        TERow(showDivider: showDivider) {
            HStack(spacing: 12) {
                Text(label)
                    .font(TE.mono(.caption, weight: .medium))
                    .tracking(1)
                    .foregroundStyle(TE.textPrimary)
                Spacer()
                DatePicker("", selection: date, displayedComponents: .date)
                    .labelsHidden()
                    .tint(TE.accent)
            }
        }
    }

    private func numberFieldRow(_ label: String, value: Binding<Double?>, showDivider: Bool = true) -> some View {
        TERow(showDivider: showDivider) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(label)
                    .font(TE.mono(.caption, weight: .medium))
                    .tracking(1)
                    .foregroundStyle(TE.textPrimary)
                Spacer(minLength: 12)
                TextField("Optional", value: value, format: .number.precision(.fractionLength(1)))
                    .keyboardType(.decimalPad)
                    .font(TE.mono(.caption, weight: .medium))
                    .foregroundStyle(TE.textMuted)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.plain)
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
