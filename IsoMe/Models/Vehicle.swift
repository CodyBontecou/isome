import Foundation
import SwiftData

@Model
final class Vehicle {
    var id: UUID
    var name: String
    var bluetoothPortName: String?
    var bluetoothPortType: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        bluetoothPortName: String? = nil,
        bluetoothPortType: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.bluetoothPortName = bluetoothPortName
        self.bluetoothPortType = bluetoothPortType
        self.createdAt = createdAt
    }

    var hasBluetoothPairing: Bool {
        bluetoothPortName?.isEmpty == false
    }
}
