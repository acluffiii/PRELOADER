import Foundation

/// Builds packages with a weighted mix of shelf-bound, floor-bound, and "do not touch" boxes.
/// Takes an injectable RNG so tests can get deterministic belts.
nonisolated struct PackageFactory {
    /// Serials that deliberately look like they could belong to a shelf but don't — letter
    /// look-alikes, numbers just outside a range, and mixed alphanumerics.
    private static let doNotTouchSerials = [
        "1O42", "5012", "2150", "1Z9-44A", "3150", "40A9", "9999",
        "1250", "2999", "ABC123", "3O87", "4150", "1999", "2O50",
    ]

    private var rng: AnyRandomNumberGenerator

    init(rng: RandomNumberGenerator = SystemRandomNumberGenerator()) {
        self.rng = AnyRandomNumberGenerator(rng)
    }

    /// Produces the next package to spawn on the belt.
    mutating func makePackage(now: ContinuousClock.Instant) -> Package {
        let roll = Double.random(in: 0..<1, using: &rng)
        let size = PackageSize.allCases.randomElement(using: &rng) ?? .medium

        switch roll {
        case 0..<0.70:
            return makeShelfPackage(now: now)
        case 0.70..<0.82:
            return makeFloorPackage(now: now, size: size)
        default:
            return makeDoNotTouchPackage(now: now, size: size)
        }
    }

    private mutating func makeShelfPackage(now: ContinuousClock.Instant) -> Package {
        let entry = SerialRules.shelfRanges.randomElement(using: &rng)!
        let serial = String(Int.random(in: entry.range, using: &rng))
        let size: PackageSize = [.small, .medium, .large].randomElement(using: &rng) ?? .medium
        return makePackage(serial: serial, size: size, now: now)
    }

    private mutating func makeFloorPackage(now: ContinuousClock.Instant, size: PackageSize) -> Package {
        // Floor packages are either plainly oversize, or regular-sized with no label.
        let isOversize = Bool.random(using: &rng)
        let resolvedSize: PackageSize = isOversize ? .oversize : size
        let serial: String? = isOversize ? String(Int.random(in: 1000...4099, using: &rng)) : nil
        return makePackage(serial: serial, size: resolvedSize, now: now)
    }

    private mutating func makeDoNotTouchPackage(now: ContinuousClock.Instant, size: PackageSize) -> Package {
        let serial = Self.doNotTouchSerials.randomElement(using: &rng)!
        let resolvedSize = size == .oversize ? .large : size
        return makePackage(serial: serial, size: resolvedSize, now: now)
    }

    /// Builds a package and derives its `correctZone` from `SerialRules`, the single source of
    /// truth, instead of letting each call site assert its own answer.
    private func makePackage(serial: String?, size: PackageSize, now: ContinuousClock.Instant) -> Package {
        Package(
            id: UUID(),
            serial: serial,
            size: size,
            correctZone: SerialRules.zone(for: serial, size: size),
            beltProgress: 0,
            spawnedAt: now
        )
    }
}
