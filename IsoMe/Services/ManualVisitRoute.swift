import Foundation
import Observation

/// Deep links only open forms/details. Saving always goes through the normal UI validation.
enum ManualVisitRoute: Equatable {
    case checkIn(name: String?, latitude: Double?, longitude: Double?, arrival: Date?)
    case pastVisit(name: String?, latitude: Double?, longitude: Double?, arrival: Date?, departure: Date?)
    case visit(UUID)

    static func parse(_ url: URL, now: Date = Date()) throws -> ManualVisitRoute {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme == "isome", parts.user == nil, parts.password == nil,
              parts.port == nil, parts.fragment == nil else { throw RouteError.invalid }
        if parts.host == "visit" {
            guard parts.query == nil, let id = UUID(uuidString: String(parts.path.dropFirst())),
                  parts.path == "/\(id.uuidString)" || parts.path.lowercased() == "/\(id.uuidString.lowercased())" else {
                throw RouteError.invalid
            }
            return .visit(id)
        }
        guard parts.host == "check-in" || parts.host == "log-visit", parts.path.isEmpty || parts.path == "/" else {
            throw RouteError.invalid
        }
        let items = parts.queryItems ?? []
        let allowed: Set<String> = parts.host == "check-in" ? ["name", "latitude", "longitude", "arrival"] : ["name", "latitude", "longitude", "arrival", "departure"]
        guard items.allSatisfy({ allowed.contains($0.name) && $0.value != nil }),
              Set(items.map(\.name)).count == items.count else { throw RouteError.invalid }
        let values = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        let name = values["name"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name == nil || name?.isEmpty == false else { throw RouteError.invalid }
        func number(_ key: String) throws -> Double? {
            guard let raw = values[key] else { return nil }
            guard let value = Double(raw), value.isFinite else { throw RouteError.invalid }
            return value
        }
        let latitude = try number("latitude"), longitude = try number("longitude")
        guard (latitude == nil) == (longitude == nil),
              latitude.map({ (-90...90).contains($0) }) ?? true,
              longitude.map({ (-180...180).contains($0) }) ?? true else { throw RouteError.invalid }
        func date(_ key: String) throws -> Date? {
            guard let raw = values[key] else { return nil }
            guard let date = ISO8601DateFormatter().date(from: raw), date <= now else { throw RouteError.invalid }
            return date
        }
        let arrival = try date("arrival"), departure = try date("departure")
        if parts.host == "check-in" { return .checkIn(name: name, latitude: latitude, longitude: longitude, arrival: arrival) }
        guard (arrival == nil) == (departure == nil) else { throw RouteError.invalid }
        if let arrival, let departure, departure < arrival { throw RouteError.invalid }
        return .pastVisit(name: name, latitude: latitude, longitude: longitude, arrival: arrival, departure: departure)
    }

    enum RouteError: LocalizedError {
        case invalid
        var errorDescription: String? { String(localized: "This visit link is invalid. Check the place, coordinates, and times.") }
    }
}

@MainActor @Observable
final class ManualVisitRouter {
    struct Request: Identifiable {
        let id = UUID()
        let route: ManualVisitRoute
    }
    var request: Request?
    var errorMessage: String?

    func open(_ url: URL) {
        do { request = Request(route: try ManualVisitRoute.parse(url)) }
        catch { request = nil; errorMessage = error.localizedDescription }
    }
}
