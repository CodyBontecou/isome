import Foundation
import Security

/// Tracks cumulative usage hours in the Keychain so the counter survives app uninstall/reinstall.
@MainActor
final class UsageTracker: ObservableObject {
    static let shared = UsageTracker()

    /// Free usage limit in seconds (10 hours)
    static let freeUsageLimitSeconds: TimeInterval = 10 * 3600

    private let keychainKey = "com.bontecou.Spotted.cumulativeTrackingSeconds"
    private let sessionStartKey = "com.bontecou.Spotted.sessionStartDate"

    /// Accumulated seconds from previous sessions (persisted in Keychain)
    @Published private(set) var storedSeconds: TimeInterval = 0

    /// Start date of the current tracking session (persisted in Keychain so a kill+relaunch still counts)
    @Published private(set) var currentSessionStart: Date?

    /// Timer that periodically flushes elapsed time to Keychain during active tracking
    private var flushTimer: Timer?

    private init() {
        storedSeconds = readDouble(key: keychainKey)

        // Recover in-progress session after a crash/kill
        if let startInterval = readOptionalDouble(key: sessionStartKey) {
            let start = Date(timeIntervalSince1970: startInterval)
            // Only recover if the start date is in the past and within a reasonable window (48h)
            if start < Date() && Date().timeIntervalSince(start) < 48 * 3600 {
                currentSessionStart = start
            } else {
                // Stale session — flush whatever time we can salvage
                let elapsed = max(0, Date().timeIntervalSince(start))
                storedSeconds += elapsed
                writeDouble(key: keychainKey, value: storedSeconds)
                deleteItem(key: sessionStartKey)
            }
        }
    }

    // MARK: - Public API

    /// Total usage so far, including any in-progress session.
    var totalUsageSeconds: TimeInterval {
        var total = storedSeconds
        if let start = currentSessionStart {
            total += Date().timeIntervalSince(start)
        }
        return total
    }

    var totalUsageHours: Double {
        totalUsageSeconds / 3600
    }

    var remainingFreeSeconds: TimeInterval {
        max(0, Self.freeUsageLimitSeconds - totalUsageSeconds)
    }

    var hasExceededFreeLimit: Bool {
        totalUsageSeconds >= Self.freeUsageLimitSeconds
    }

    /// Call when a tracking session begins.
    func sessionStarted() {
        guard currentSessionStart == nil else { return }
        let now = Date()
        currentSessionStart = now
        writeDouble(key: sessionStartKey, value: now.timeIntervalSince1970)
        startFlushTimer()
        objectWillChange.send()
    }

    /// Call when a tracking session ends.
    func sessionEnded() {
        guard let start = currentSessionStart else { return }
        let elapsed = max(0, Date().timeIntervalSince(start))
        storedSeconds += elapsed
        writeDouble(key: keychainKey, value: storedSeconds)
        deleteItem(key: sessionStartKey)
        currentSessionStart = nil
        stopFlushTimer()
        objectWillChange.send()
    }

    // MARK: - Periodic Flush

    private func startFlushTimer() {
        flushTimer?.invalidate()
        flushTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.flushCurrentSession()
            }
        }
    }

    private func stopFlushTimer() {
        flushTimer?.invalidate()
        flushTimer = nil
    }

    /// Flush elapsed time to Keychain without ending the session.
    private func flushCurrentSession() {
        guard let start = currentSessionStart else { return }
        let elapsed = max(0, Date().timeIntervalSince(start))
        storedSeconds += elapsed
        writeDouble(key: keychainKey, value: storedSeconds)

        // Reset session start to now
        let now = Date()
        currentSessionStart = now
        writeDouble(key: sessionStartKey, value: now.timeIntervalSince1970)
        objectWillChange.send()
    }

    // MARK: - Keychain Helpers

    private func writeDouble(key: String, value: Double) {
        let data = withUnsafeBytes(of: value) { Data($0) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        // Try to update first
        let updateAttributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)

        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    private func readDouble(key: String) -> Double {
        readOptionalDouble(key: key) ?? 0
    }

    private func readOptionalDouble(key: String) -> Double? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data, data.count == MemoryLayout<Double>.size else {
            return nil
        }
        return data.withUnsafeBytes { $0.load(as: Double.self) }
    }

    private func deleteItem(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
