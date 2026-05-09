import AVFoundation
import Foundation

struct BluetoothVehicleRoute: Equatable {
    let portName: String
    let portType: String
}

@MainActor
final class BluetoothVehicleDetector: ObservableObject {
    static let shared = BluetoothVehicleDetector()

    @Published private(set) var currentRoute: BluetoothVehicleRoute?
    @Published private(set) var pendingPairingVehicleID: UUID?

    private var pairingHandler: ((BluetoothVehicleRoute) -> Void)?

    init(notificationCenter: NotificationCenter = .default) {
        updateCurrentRoute()
        notificationCenter.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleRouteChange()
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func beginPairing(vehicleID: UUID, onDetected: @escaping (BluetoothVehicleRoute) -> Void) {
        pendingPairingVehicleID = vehicleID
        pairingHandler = onDetected

        if let currentRoute {
            completePairing(with: currentRoute)
        }
    }

    func cancelPairing() {
        pendingPairingVehicleID = nil
        pairingHandler = nil
    }

    func refresh() {
        updateCurrentRoute()
    }

    static func isSupportedPortType(_ portType: AVAudioSession.Port) -> Bool {
        switch portType {
        case .carAudio, .bluetoothHFP, .bluetoothA2DP, .bluetoothLE:
            return true
        default:
            return false
        }
    }

    private func handleRouteChange() {
        updateCurrentRoute()
        guard let currentRoute, pendingPairingVehicleID != nil else { return }
        completePairing(with: currentRoute)
    }

    private func completePairing(with route: BluetoothVehicleRoute) {
        let handler = pairingHandler
        pendingPairingVehicleID = nil
        pairingHandler = nil
        handler?(route)
    }

    private func updateCurrentRoute() {
        currentRoute = Self.detectVehicleRoute(in: AVAudioSession.sharedInstance().currentRoute)
    }

    private static func detectVehicleRoute(in routeDescription: AVAudioSessionRouteDescription) -> BluetoothVehicleRoute? {
        routeDescription.outputs
            .first { isSupportedPortType($0.portType) }
            .map {
                BluetoothVehicleRoute(
                    portName: $0.portName.trimmingCharacters(in: .whitespacesAndNewlines),
                    portType: $0.portType.rawValue
                )
            }
    }
}
