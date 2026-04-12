import Foundation
import HealthKit

final class HealthKitWorkoutObserver {
    static let shared = HealthKitWorkoutObserver()

    private let healthStore = HKHealthStore()
    private var observerQuery: HKObserverQuery?

    /// Called on an arbitrary queue when a workout sample is added to HealthKit
    var onWorkoutDetected: (() -> Void)?

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        let workoutType = HKWorkoutType.workoutType()
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [workoutType])
            return true
        } catch {
            return false
        }
    }

    func startObserving() {
        guard isAvailable, observerQuery == nil else { return }
        let workoutType = HKWorkoutType.workoutType()

        healthStore.enableBackgroundDelivery(for: workoutType, frequency: .immediate) { _, _ in }

        let query = HKObserverQuery(sampleType: workoutType, predicate: nil) { [weak self] _, completionHandler, error in
            guard error == nil else {
                completionHandler()
                return
            }
            self?.onWorkoutDetected?()
            completionHandler()
        }

        observerQuery = query
        healthStore.execute(query)
    }

    func stopObserving() {
        if let query = observerQuery {
            healthStore.stop(query)
            observerQuery = nil
        }
        guard isAvailable else { return }
        let workoutType = HKWorkoutType.workoutType()
        healthStore.disableBackgroundDelivery(for: workoutType) { _, _ in }
    }
}
