import SwiftUI
import SwiftData

struct VehiclesSettingsView: View {
    @Bindable var viewModel: LocationViewModel
    @State private var showingAddVehicle = false

    private var activeVehicles: [Vehicle] {
        viewModel.activeVehicles
    }

    private var archivedVehicles: [Vehicle] {
        viewModel.vehicles.filter(\.isArchived)
    }

    var body: some View {
        ZStack {
            TE.surface.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    activeSection

                    if !archivedVehicles.isEmpty {
                        archivedSection
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Vehicles")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddVehicle = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(TE.accent)
                }
            }
        }
        .sheet(isPresented: $showingAddVehicle) {
            NavigationStack {
                VehicleFormView(viewModel: viewModel)
            }
        }
        .onAppear {
            viewModel.loadVehicles()
        }
    }

    private var activeSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "ACTIVE")

            TECard {
                if activeVehicles.isEmpty {
                    TERow(showDivider: false) {
                        emptyVehicleState
                    }
                } else {
                    ForEach(Array(activeVehicles.enumerated()), id: \.element.id) { index, vehicle in
                        TERow(showDivider: index != activeVehicles.count - 1) {
                            NavigationLink {
                                VehicleDetailView(vehicle: vehicle, viewModel: viewModel)
                            } label: {
                                vehicleRow(vehicle)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)

            TESectionFooter(text: "New drives use your default vehicle unless a paired Bluetooth route is detected.")
        }
    }

    private var archivedSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "ARCHIVED")

            TECard {
                ForEach(Array(archivedVehicles.enumerated()), id: \.element.id) { index, vehicle in
                    TERow(showDivider: index != archivedVehicles.count - 1) {
                        NavigationLink {
                            VehicleDetailView(vehicle: vehicle, viewModel: viewModel)
                        } label: {
                            vehicleRow(vehicle)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)

            TESectionFooter(text: "Archived vehicles remain attached to past trips and exports.")
        }
    }

    private var emptyVehicleState: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "car")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(TE.textMuted)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text("NO VEHICLES")
                    .font(TE.mono(.caption, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(TE.textPrimary)
                Text("Add a vehicle to tag new drives automatically.")
                    .font(TE.mono(.caption2))
                    .foregroundStyle(TE.textMuted)
            }

            Spacer()
        }
    }

    private func vehicleRow(_ vehicle: Vehicle) -> some View {
        HStack(spacing: 12) {
            Image(systemName: vehicle.isArchived ? "archivebox" : "car.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(vehicle.isArchived ? TE.textMuted : TE.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(vehicle.name.uppercased())
                        .font(TE.mono(.caption, weight: .medium))
                        .tracking(1)
                        .foregroundStyle(TE.textPrimary)

                    if vehicle.isDefault {
                        Text("DEFAULT")
                            .font(TE.mono(.caption2, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(TE.accent, in: Capsule())
                    }

                    if vehicle.hasBluetoothPairing {
                        Image(systemName: "bluetooth")
                            .font(.caption2)
                            .foregroundStyle(TE.accent)
                    }
                }

                if !vehicle.displaySubtitle.isEmpty {
                    Text(vehicle.displaySubtitle)
                        .font(TE.mono(.caption2))
                        .foregroundStyle(TE.textMuted)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(TE.accent.opacity(0.5))
        }
    }
}

private struct VehicleDetailView: View {
    @Bindable var vehicle: Vehicle
    @Bindable var viewModel: LocationViewModel
    @State private var showingEditVehicle = false
    @State private var showingArchiveConfirmation = false

    private var vehicleVisits: [Visit] {
        viewModel.allVisits.filter { $0.vehicleID == vehicle.id }
    }

    private var vehiclePoints: [LocationPoint] {
        viewModel.locationPoints.filter { $0.vehicleID == vehicle.id }
    }

    private var totalMeters: Double {
        guard vehiclePoints.count > 1 else { return 0 }
        let sorted = vehiclePoints.sorted { $0.timestamp < $1.timestamp }
        return zip(sorted, sorted.dropFirst()).reduce(0) { total, pair in
            total + pair.0.distance(to: pair.1)
        }
    }

    var body: some View {
        ZStack {
            TE.surface.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    summarySection
                    mileageSection
                    activitySection

                    if !vehicle.isArchived {
                        bluetoothSection
                        actionsSection
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(vehicle.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEditVehicle = true
                }
                .foregroundStyle(TE.accent)
            }
        }
        .sheet(isPresented: $showingEditVehicle) {
            NavigationStack {
                VehicleFormView(viewModel: viewModel, vehicle: vehicle)
            }
        }
        .alert("Archive Vehicle?", isPresented: $showingArchiveConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Archive", role: .destructive) {
                viewModel.archiveVehicle(vehicle)
            }
        } message: {
            Text("Archived vehicles are hidden from new drives but remain on past drives and exports.")
        }
    }

    private var summarySection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "VEHICLE")

            TECard {
                infoRow("NAME", value: vehicle.name)

                if !vehicle.displaySubtitle.isEmpty {
                    infoRow("VEHICLE", value: vehicle.displaySubtitle)
                }

                if let plate = vehicle.licensePlate, !plate.isEmpty {
                    infoRow("PLATE", value: plate)
                }

                infoRow("STATUS", value: statusText, showDivider: false, valueColor: vehicle.isArchived ? TE.textMuted : TE.accent)
            }
            .padding(.horizontal, 16)
        }
    }

    private var mileageSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "MILEAGE")

            TECard {
                infoRow("TRACKED MILES", value: DistanceFormatter.format(meters: totalMeters, usesMetric: false))
                infoRow("BUSINESS", value: DistanceFormatter.format(meters: totalMeters, usesMetric: false))
                infoRow("PERSONAL", value: DistanceFormatter.format(meters: 0, usesMetric: false))

                if let odometerStart = vehicle.odometerStart {
                    infoRow("YEAR-START ODOMETER", value: "\(odometerStart)")
                }

                if let odometerCurrent = vehicle.odometerCurrent {
                    infoRow("CURRENT ODOMETER", value: "\(odometerCurrent)")
                }

                if vehicle.odometerStart == nil && vehicle.odometerCurrent == nil {
                    infoRow("ODOMETER", value: "Not set", showDivider: false)
                } else {
                    Divider()
                        .background(Color.clear)
                        .frame(height: 0)
                }
            }
            .padding(.horizontal, 16)

            TESectionFooter(text: "Mileage totals are calculated from tagged GPS points for this vehicle.")
        }
    }

    private var activitySection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "ACTIVITY")

            TECard {
                infoRow("VISITS", value: "\(vehicleVisits.count)")
                infoRow("GPS POINTS", value: "\(vehiclePoints.count)", showDivider: false)
            }
            .padding(.horizontal, 16)
        }
    }

    private var bluetoothSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "BLUETOOTH AUTO-DETECTION")

            TECard {
                if let portName = vehicle.bluetoothPortName, !portName.isEmpty {
                    infoRow("PAIRED ROUTE", value: portName)
                } else {
                    TERow {
                        Text("Pair with a CarPlay, hands-free, or Bluetooth audio route to auto-tag drives for this vehicle.")
                            .font(TE.mono(.caption2))
                            .foregroundStyle(TE.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                TERow(showDivider: vehicle.hasBluetoothPairing || viewModel.vehiclePairingMessage != nil) {
                    actionLabel(
                        title: vehicle.hasBluetoothPairing ? "PAIR DIFFERENT BLUETOOTH ROUTE" : "PAIR BLUETOOTH ROUTE",
                        icon: "bluetooth",
                        color: TE.accent
                    ) {
                        viewModel.pairVehicleWithBluetooth(vehicle)
                    }
                }

                if vehicle.hasBluetoothPairing {
                    TERow(showDivider: viewModel.vehiclePairingMessage != nil) {
                        actionLabel(title: "CLEAR BLUETOOTH PAIRING", icon: "xmark.circle", color: TE.danger) {
                            viewModel.clearBluetoothPairing(for: vehicle)
                        }
                    }
                }

                if let message = viewModel.vehiclePairingMessage {
                    TERow(showDivider: false) {
                        Text(message)
                            .font(TE.mono(.caption2))
                            .foregroundStyle(TE.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
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
                if !vehicle.isDefault {
                    TERow {
                        actionLabel(title: "MAKE DEFAULT", icon: "checkmark.circle", color: TE.accent) {
                            viewModel.setDefaultVehicle(vehicle)
                        }
                    }
                }

                TERow(showDivider: false) {
                    actionLabel(title: "ARCHIVE VEHICLE", icon: "archivebox", color: TE.danger) {
                        showingArchiveConfirmation = true
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var statusText: String {
        if vehicle.isArchived { return "Archived" }
        if vehicle.isDefault { return "Default" }
        return "Active"
    }

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

    private func actionLabel(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
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
}

private struct VehicleFormView: View {
    @Bindable var viewModel: LocationViewModel
    var vehicle: Vehicle?
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var make: String
    @State private var model: String
    @State private var year: String
    @State private var licensePlate: String
    @State private var odometerStart: String
    @State private var odometerCurrent: String
    @State private var isDefault: Bool

    init(viewModel: LocationViewModel, vehicle: Vehicle? = nil) {
        self.viewModel = viewModel
        self.vehicle = vehicle

        _name = State(initialValue: vehicle?.name ?? "")
        _make = State(initialValue: vehicle?.make ?? "")
        _model = State(initialValue: vehicle?.model ?? "")
        _year = State(initialValue: vehicle?.year.map(String.init) ?? "")
        _licensePlate = State(initialValue: vehicle?.licensePlate ?? "")
        _odometerStart = State(initialValue: vehicle?.odometerStart.map(String.init) ?? "")
        _odometerCurrent = State(initialValue: vehicle?.odometerCurrent.map(String.init) ?? "")
        _isDefault = State(initialValue: vehicle?.isDefault ?? viewModel.activeVehicles.isEmpty)
    }

    var body: some View {
        ZStack {
            TE.surface.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    vehicleFieldsSection
                    odometerSection
                    defaultSection
                }
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(vehicle == nil ? "Add Vehicle" : "Edit Vehicle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(TE.textMuted)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .foregroundStyle(TE.accent)
            }
        }
    }

    private var vehicleFieldsSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "VEHICLE")

            TECard {
                textFieldRow("NAME", text: $name, placeholder: "Required")
                textFieldRow("MAKE", text: $make, placeholder: "Optional")
                textFieldRow("MODEL", text: $model, placeholder: "Optional")
                textFieldRow("YEAR", text: $year, placeholder: "Optional", keyboardType: .numberPad)
                textFieldRow("LICENSE PLATE", text: $licensePlate, placeholder: "Optional", keyboardType: .asciiCapable, capitalization: .characters, showDivider: false)
            }
            .padding(.horizontal, 16)
        }
    }

    private var odometerSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "ODOMETER")

            TECard {
                textFieldRow("YEAR-START", text: $odometerStart, placeholder: "Optional", keyboardType: .numberPad)
                textFieldRow("CURRENT", text: $odometerCurrent, placeholder: "Optional", keyboardType: .numberPad, showDivider: false)
            }
            .padding(.horizontal, 16)

            TESectionFooter(text: "Odometer values are optional and used for review/reference.")
        }
    }

    private var defaultSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "DEFAULT")

            TECard {
                TERow(showDivider: false) {
                    Toggle(isOn: $isDefault) {
                        Text("DEFAULT VEHICLE")
                            .font(TE.mono(.caption, weight: .medium))
                            .tracking(1)
                            .foregroundStyle(TE.textPrimary)
                    }
                    .toggleStyle(TEToggleStyle())
                }
            }
            .padding(.horizontal, 16)

            TESectionFooter(text: "New drives use the default vehicle unless Bluetooth auto-detection finds another match.")
        }
    }

    private func textFieldRow(
        _ label: String,
        text: Binding<String>,
        placeholder: String,
        keyboardType: UIKeyboardType = .default,
        capitalization: TextInputAutocapitalization = .sentences,
        showDivider: Bool = true
    ) -> some View {
        TERow(showDivider: showDivider) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(label)
                    .font(TE.mono(.caption, weight: .medium))
                    .tracking(1)
                    .foregroundStyle(TE.textPrimary)
                Spacer(minLength: 12)
                TextField(placeholder, text: text)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(capitalization)
                    .autocorrectionDisabled()
                    .font(TE.mono(.caption, weight: .medium))
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(TE.textMuted)
                    .textFieldStyle(.plain)
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsedYear = Int(year.trimmingCharacters(in: .whitespacesAndNewlines))
        let parsedStart = Int(odometerStart.trimmingCharacters(in: .whitespacesAndNewlines))
        let parsedCurrent = Int(odometerCurrent.trimmingCharacters(in: .whitespacesAndNewlines))

        if let vehicle {
            viewModel.updateVehicle(
                vehicle,
                name: trimmedName,
                make: optional(make),
                model: optional(model),
                year: parsedYear,
                licensePlate: optional(licensePlate),
                odometerStart: parsedStart,
                odometerCurrent: parsedCurrent,
                isDefault: isDefault
            )
        } else {
            viewModel.addVehicle(
                name: trimmedName,
                make: optional(make),
                model: optional(model),
                year: parsedYear,
                licensePlate: optional(licensePlate),
                odometerStart: parsedStart,
                odometerCurrent: parsedCurrent,
                isDefault: isDefault
            )
        }
    }

    private func optional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
