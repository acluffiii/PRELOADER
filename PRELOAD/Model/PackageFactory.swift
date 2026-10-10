import Foundation

/// Builds packages with a weighted mix of shelf-bound, rerun-bound, air, and "do not touch"
/// boxes. Takes an injectable RNG so tests can get deterministic belts.
nonisolated struct PackageFactory {
    private var rng: AnyRandomNumberGenerator

    init(rng: RandomNumberGenerator = SystemRandomNumberGenerator()) {
        self.rng = AnyRandomNumberGenerator(rng)
    }

    /// Produces the next package to spawn on the belt, against `ranges` — the current truck's
    /// shelf ranges, since what counts as "shelf-bound" vs. "do not touch" rotates every truck.
    mutating func makePackage(now: ContinuousClock.Instant, ranges: [LoadZone: ClosedRange<Int>]) -> Package {
        let roll = Double.random(in: 0..<1, using: &rng)
        let size = PackageSize.allCases.randomElement(using: &rng) ?? .medium

        switch roll {
        case 0..<0.72:
            return makeShelfPackage(now: now, ranges: ranges)
        case 0.72..<0.82:
            return makeRerunPackage(now: now, size: size, ranges: ranges)
        case 0.82..<0.90:
            return makeAirPackage(now: now, ranges: ranges)
        default:
            return makeDoNotTouchPackage(now: now, size: size, ranges: ranges)
        }
    }

    private mutating func makeShelfPackage(now: ContinuousClock.Instant, ranges: [LoadZone: ClosedRange<Int>]) -> Package {
        let range = ranges.values.randomElement(using: &rng) ?? SerialRules.defaultRanges.values.first!
        let serial = String(Int.random(in: range, using: &rng))
        let size: PackageSize = [.small, .medium, .large].randomElement(using: &rng) ?? .medium
        return makePackage(serial: serial, size: size, now: now, ranges: ranges)
    }

    /// A no-label package, bound for rerun.
    private mutating func makeRerunPackage(
        now: ContinuousClock.Instant,
        size: PackageSize,
        ranges: [LoadZone: ClosedRange<Int>]
    ) -> Package {
        return makePackage(serial: nil, size: size, now: now, ranges: ranges)
    }

    /// A special air package: no serial, an airplane icon instead, always bound for the roof.
    /// Always small or medium, and this is the one bucket that doesn't reuse the shared size roll
    /// from `makePackage(now:ranges:)`.
    private mutating func makeAirPackage(now: ContinuousClock.Instant, ranges: [LoadZone: ClosedRange<Int>]) -> Package {
        let size: PackageSize = [.small, .medium].randomElement(using: &rng) ?? .small
        return makePackage(serial: nil, size: size, isAirPackage: true, now: now, ranges: ranges)
    }

    private mutating func makeDoNotTouchPackage(
        now: ContinuousClock.Instant,
        size: PackageSize,
        ranges: [LoadZone: ClosedRange<Int>]
    ) -> Package {
        let serial = DoNotTouchSerialGenerator.makeSerial(ranges: ranges, using: &rng)
        return makePackage(serial: serial, size: size, now: now, ranges: ranges)
    }

    /// Builds a package and derives its `correctZone` from `SerialRules`, the single source of
    /// truth, instead of letting each call site assert its own answer.
    private func makePackage(
        serial: String?,
        size: PackageSize,
        isAirPackage: Bool = false,
        now: ContinuousClock.Instant,
        ranges: [LoadZone: ClosedRange<Int>]
    ) -> Package {
        Package(
            id: UUID(),
            serial: serial,
            size: size,
            correctZone: SerialRules.zone(for: serial, size: size, isAirPackage: isAirPackage, ranges: ranges),
            isAirPackage: isAirPackage,
            beltProgress: 0,
            spawnedAt: now
        )
    }
}
