import Foundation
@testable import IsoMe

final class FakeUserDefaults: UserDefaultsStoring, @unchecked Sendable {
    private var storage: [String: Any] = [:]
    private let queue = DispatchQueue(label: "com.bontecou.isome.tests.fake-user-defaults")

    func data(forKey defaultName: String) -> Data? {
        queue.sync { storage[defaultName] as? Data }
    }

    func string(forKey defaultName: String) -> String? {
        queue.sync { storage[defaultName] as? String }
    }

    func set(_ value: Any?, forKey defaultName: String) {
        queue.sync {
            if let value {
                storage[defaultName] = value
            } else {
                storage.removeValue(forKey: defaultName)
            }
        }
    }

    func removeObject(forKey defaultName: String) {
        queue.sync {
            storage.removeValue(forKey: defaultName)
        }
    }
}
