import Foundation
import CoreLocation
import SwiftData
import Combine

/// Resolves history in bounded batches. Each completed lookup is saved, so cancellation is resumable.
@MainActor
final class CountryDayResolver: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var completed = 0
    @Published private(set) var resolved = 0
    @Published private(set) var message: String?
    private var cancelled = false
    private let geocoder = GeocodingService()
    private let reverseGeocode: ((CLLocation) async throws -> GeocodingResult)?

    init(reverseGeocode: ((CLLocation) async throws -> GeocodingResult)? = nil) {
        self.reverseGeocode = reverseGeocode
    }

    func cancel() {
        guard isRunning else { return }
        cancelled = true
        message = String(localized: "Stopping analysis…")
    }

    func resolveHistory(in context: ModelContext) async {
        guard !isRunning else { return }
        guard networkAllowed else {
            message = String(localized: "Enable network geocoding in Settings to identify countries, or add a manual stay.")
            return
        }
        isRunning = true
        cancelled = false
        completed = 0
        resolved = 0
        message = nil
        defer { isRunning = false }
        // Unresolved locations retry after an hour; unavailable geocodes never create invented days.
        let retryBefore = Date().addingTimeInterval(-3600)
        let neverAttempted = Date.distantPast
        do {
            while !shouldStop {
                var descriptor = FetchDescriptor<Visit>(predicate: #Predicate {
                    $0.countryCode == nil && ($0.countryResolutionAttemptedAt ?? neverAttempted) < retryBefore
                }, sortBy: [SortDescriptor(\.arrivedAt)])
                descriptor.fetchLimit = 100
                let visits = try context.fetch(descriptor)
                guard !visits.isEmpty else { break }
                for visit in visits {
                    guard !shouldStop else { break }
                    let latitude = visit.latitude
                    let longitude = visit.longitude
                    let result = try await lookup(latitude: latitude, longitude: longitude)
                    guard !shouldStop else { break }
                    // An edit or deletion while awaiting the network invalidates this result.
                    guard !visit.isDeleted, visit.modelContext != nil,
                          visit.latitude == latitude, visit.longitude == longitude else { continue }
                    visit.countryCode = result?.countryCode
                    visit.countryTimeZoneIdentifier = result?.timeZoneIdentifier
                    visit.countryResolutionAttemptedAt = Date()
                    try context.save()
                    record(result)
                }
            }
            while !shouldStop {
                var descriptor = FetchDescriptor<LocationPoint>(predicate: #Predicate {
                    !$0.isOutlier && $0.countryCode == nil && ($0.countryResolutionAttemptedAt ?? neverAttempted) < retryBefore
                }, sortBy: [SortDescriptor(\.timestamp)])
                descriptor.fetchLimit = 100
                let points = try context.fetch(descriptor)
                guard !points.isEmpty else { break }
                for point in points {
                    guard !shouldStop else { break }
                    let result = try await lookup(latitude: point.latitude, longitude: point.longitude)
                    guard !shouldStop else { break }
                    guard !point.isDeleted, point.modelContext != nil else { continue }
                    point.countryCode = result?.countryCode
                    point.countryTimeZoneIdentifier = result?.timeZoneIdentifier
                    point.countryResolutionAttemptedAt = Date()
                    try context.save()
                    record(result)
                }
            }
            if cancelled || Task.isCancelled {
                message = String(localized: "Analysis stopped. Completed results are saved; analyze again to continue.")
            } else if !networkAllowed {
                message = String(localized: "Analysis stopped because network geocoding is disabled.")
            } else if completed == 0 {
                message = String(localized: "No saved locations need analysis right now. Unavailable lookups can be retried after an hour.")
            } else {
                message = String(localized: "Identified \(resolved) of \(completed) locations. Unavailable lookups can be retried after an hour.")
            }
        } catch {
            message = error.localizedDescription
        }
    }

    private var networkAllowed: Bool {
        UserDefaults.standard.object(forKey: "allowNetworkGeocoding") == nil || UserDefaults.standard.bool(forKey: "allowNetworkGeocoding")
    }
    private var shouldStop: Bool { cancelled || Task.isCancelled || !networkAllowed }

    private func lookup(latitude: Double, longitude: Double) async throws -> GeocodingResult? {
        do {
            let location = CLLocation(latitude: latitude, longitude: longitude)
            let result: GeocodingResult
            if let reverseGeocode {
                result = try await reverseGeocode(location)
            } else {
                result = try await geocoder.reverseGeocode(location: location)
            }
            // A country without a local time zone cannot be assigned a reliable civil date.
            guard result.countryCode != nil, result.timeZoneIdentifier != nil else { return nil }
            return result
        } catch {
            // Stop on network/rate-limit errors rather than hammering a failing service.
            throw error
        }
    }

    private func record(_ result: GeocodingResult?) {
        completed += 1
        if result?.countryCode != nil { resolved += 1 }
    }
}
