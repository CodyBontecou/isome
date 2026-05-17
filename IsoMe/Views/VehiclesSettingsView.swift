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
        List {
            Section("Active") {
                if activeVehicles.isEmpty {
                    ContentUnavailableView("No Vehicles", systemImage: "car", description: Text("Add a vehicle to tag new drives automatically."))
                } else {
                    ForEach(activeVehicles) { vehicle in
                        NavigationLink {
                            VehicleDetailView(vehicle: vehicle, viewModel: viewModel)
                        } label: {
                            vehicleRow(vehicle)
                        }
                    }
                }
            }

            if !archivedVehicles.isEmpty {
                Section("Archived") {
                    ForEach(archivedVehicles) { vehicle in
                        NavigationLink {
                            VehicleDetailView(vehicle: vehicle, viewModel: viewModel)
                        } label: {
                            vehicleRow(vehicle)
                        }
                    }
                }
            }
        }
        .navigationTitle("Vehicles")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddVehicle = true
                } label: {
                    Image(systemName: "plus")
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

    private func vehicleRow(_ vehicle: Vehicle) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(vehicle.name)
                if vehicle.isDefault {
                    Text("Default")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor, in: Capsule())
                }
            }

            if !vehicle.displaySubtitle.isEmpty {
                Text(vehicle.displaySubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
        List {
            Section {
                LabeledContent("Name", value: vehicle.name)
                if !vehicle.displaySubtitle.isEmpty {
                    LabeledContent("Vehicle", value: vehicle.displaySubtitle)
                }
                if let plate = vehicle.licensePlate, !plate.isEmpty {
                    LabeledContent("Plate", value: plate)
                }
                LabeledContent("Status", value: vehicle.isArchived ? "Archived" : (vehicle.isDefault ? "Default" : "Active"))
            }

            Section("Mileage") {
                LabeledContent("Tracked miles", value: DistanceFormatter.format(meters: totalMeters, usesMetric: false))
                LabeledContent("Business", value: DistanceFormatter.format(meters: totalMeters, usesMetric: false))
                LabeledContent("Personal", value: DistanceFormatter.format(meters: 0, usesMetric: false))
                if let odometerStart = vehicle.odometerStart {
                    LabeledContent("Year-start odometer", value: "\(odometerStart)")
                }
                if let odometerCurrent = vehicle.odometerCurrent {
                    LabeledContent("Current odometer", value: "\(odometerCurrent)")
                }
            }

            Section("Activity") {
                LabeledContent("Visits", value: "\(vehicleVisits.count)")
                LabeledContent("GPS points", value: "\(vehiclePoints.count)")
            }

            if !vehicle.isArchived {
                Section {
                    if !vehicle.isDefault {
                        Button("Make Default") {
                            viewModel.setDefaultVehicle(vehicle)
                        }
                    }
                    Button("Archive Vehicle", role: .destructive) {
                        showingArchiveConfirmation = true
                    }
                }
            }
        }
        .navigationTitle(vehicle.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEditVehicle = true
                }
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
        Form {
            Section("Vehicle") {
                TextField("Name", text: $name)
                TextField("Make", text: $make)
                TextField("Model", text: $model)
                TextField("Year", text: $year)
                    .keyboardType(.numberPad)
                TextField("License Plate", text: $licensePlate)
                    .textInputAutocapitalization(.characters)
            }

            Section("Odometer") {
                TextField("Year-start odometer", text: $odometerStart)
                    .keyboardType(.numberPad)
                TextField("Current odometer", text: $odometerCurrent)
                    .keyboardType(.numberPad)
            }

            Section {
                Toggle("Default vehicle", isOn: $isDefault)
            }
        }
        .navigationTitle(vehicle == nil ? "Add Vehicle" : "Edit Vehicle")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
