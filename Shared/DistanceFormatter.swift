import Foundation

/// Locale-aware distance formatting shared across all targets.
/// Uses `MeasurementFormatter` so decimal separators, unit names, and
/// abbreviations are automatically adapted for the user's locale.
enum DistanceFormatter {
    private static let formatter: MeasurementFormatter = {
        let f = MeasurementFormatter()
        f.unitOptions = .providedUnit
        f.numberFormatter.maximumFractionDigits = 1
        f.numberFormatter.minimumFractionDigits = 0
        return f
    }()

    private static let wholeNumberFormatter: MeasurementFormatter = {
        let f = MeasurementFormatter()
        f.unitOptions = .providedUnit
        f.numberFormatter.maximumFractionDigits = 0
        return f
    }()

    /// Format a distance in meters using the user's preferred unit system.
    static func format(meters: Double, usesMetric: Bool) -> String {
        if usesMetric {
            if meters >= 1000 {
                let km = Measurement(value: meters / 1000, unit: UnitLength.kilometers)
                return formatter.string(from: km)
            }
            let m = Measurement(value: meters.rounded(), unit: UnitLength.meters)
            return wholeNumberFormatter.string(from: m)
        }

        let miles = meters / 1609.344
        if miles < 0.1 {
            let ft = Measurement(value: (meters * 3.28084).rounded(), unit: UnitLength.feet)
            return wholeNumberFormatter.string(from: ft)
        }
        let mi = Measurement(value: miles, unit: UnitLength.miles)
        return formatter.string(from: mi)
    }
}
