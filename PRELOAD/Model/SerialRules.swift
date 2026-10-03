import Foundation

/// The single source of truth for where a package belongs. Every other system — scoring,
/// the package factory, tests — routes through this function instead of re-deriving the rule.
nonisolated enum SerialRules {
    /// The four wall shelves, in ascending order, paired with the serial range they accept.
    static let shelfRanges: [(zone: LoadZone, range: ClosedRange<Int>)] = [
        (.shelf1000, 1000...1099),
        (.shelf2000, 2000...2099),
        (.shelf3000, 3000...3099),
        (.shelf4000, 4000...4099),
    ]

    /// Returns the zone a package belongs in, or nil if it's a "do not touch" package.
    ///
    /// - Oversize packages always belong on the floor, regardless of label.
    /// - An unlabeled package belongs on the floor.
    /// - A serial that is purely digits and falls inside a shelf's range belongs on that shelf.
    /// - Anything else (letters mixed in, digits outside every range) is "do not touch".
    static func zone(for serial: String?, size: PackageSize) -> LoadZone? {
        if size == .oversize {
            return .floor
        }
        guard let serial else {
            return .floor
        }
        guard let number = Int(serial), serial == String(number) else {
            // Contains letters, punctuation, leading zeros that don't round-trip, etc.
            return nil
        }
        for entry in shelfRanges where entry.range.contains(number) {
            return entry.zone
        }
        return nil
    }
}
