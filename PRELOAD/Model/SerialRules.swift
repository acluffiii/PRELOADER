import Foundation

/// The single source of truth for where a package belongs. Every other system — scoring,
/// the package factory, tests — routes through this function instead of re-deriving the rule.
nonisolated enum SerialRules {
    /// The shelf ranges used whenever a call site doesn't care about a specific truck's
    /// rotation — most tests, and any call that predates per-truck ranges. `ShiftEngine` passes
    /// its own current `shelfRanges` (from `RangeGenerator`) everywhere that matters in play.
    static let defaultRanges: [LoadZone: ClosedRange<Int>] = [
        .shelf1000: 1000...1999,
        .shelf2000: 2000...2999,
        .shelf3000: 3000...3999,
        .shelf4000: 4000...4999,
    ]

    /// Returns the zone a package belongs in, or nil if it's a "do not touch" package.
    ///
    /// Checked in order:
    /// - An air package always belongs on the roof, regardless of label.
    /// - An unlabeled (non-air) package belongs in rerun.
    /// - A serial that is purely digits and falls inside a shelf's range belongs on that shelf.
    /// - Anything else (letters mixed in, digits outside every range) is "do not touch".
    static func zone(
        for serial: String?,
        size: PackageSize,
        isAirPackage: Bool = false,
        ranges: [LoadZone: ClosedRange<Int>] = defaultRanges
    ) -> LoadZone? {
        if isAirPackage {
            return .roof
        }
        guard let serial else {
            return .rerun
        }
        guard let number = Int(serial), serial == String(number) else {
            // Contains letters, punctuation, leading zeros that don't round-trip, etc.
            return nil
        }
        for (zone, range) in ranges where range.contains(number) {
            return zone
        }
        return nil
    }

    /// The exact serial range stenciled on `zone`'s shelf, or nil for a zone with no range
    /// (rerun, roof).
    static func range(for zone: LoadZone, ranges: [LoadZone: ClosedRange<Int>] = defaultRanges) -> ClosedRange<Int>? {
        ranges[zone]
    }
}
