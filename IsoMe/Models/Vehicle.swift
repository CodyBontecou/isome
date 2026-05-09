import Foundation
import SwiftData

@Model
final class Vehicle {
    var id: UUID
    var name: String
    var make: String?
    var model: String?
    var year: Int?
    var licensePlate: String?
    var odometerStart: Int?
    var odometerCurrent: Int?
    var isDefault: Bool
    var bluetoothPortName: String?
    var bluetoothPortType: String?
    var createdAt: Date
    var archivedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        make: String? = nil,
        model: String? = nil,
        year: Int? = nil,
        licensePlate: String? = nil,
        odometerStart: Int? = nil,
        odometerCurrent: Int? = nil,
        isDefault: Bool = false,
        bluetoothPortName: String? = nil,
        bluetoothPortType: String? = nil,
        createdAt: Date = Date(),
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.make = make
        self.model = model
        self.year = year
        self.licensePlate = licensePlate
        self.odometerStart = odometerStart
        self.odometerCurrent = odometerCurrent
        self.isDefault = isDefault
        self.bluetoothPortName = bluetoothPortName
        self.bluetoothPortType = bluetoothPortType
        self.createdAt = createdAt
        self.archivedAt = archivedAt
    }

    var isArchived: Bool {
        archivedAt != nil
    }

    var hasBluetoothPairing: Bool {
        bluetoothPortName?.isEmpty == false
    }

    var displaySubtitle: String {
        [year.map(String.init), make, model]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " ")
    }
}

extension Vehicle {
    static var preview: Vehicle {
        Vehicle(
            name: "Work Truck",
            make: "Ford",
            model: "F-150",
            year: 2022,
            licensePlate: "ISO-123",
            odometerStart: 42_000,
            odometerCurrent: 48_250,
            isDefault: true
        )
    }
}
