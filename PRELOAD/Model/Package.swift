import Foundation

/// The physical size of a package, which affects how it is drawn and whether it belongs on the floor.
nonisolated enum PackageSize: CaseIterable, Equatable, Sendable {
    case small
    case medium
    case large

    /// The box's footprint on the belt, in points, at the game's reference scale.
    var footprint: CGSize {
        switch self {
        case .small: return CGSize(width: 46, height: 38)
        case .medium: return CGSize(width: 62, height: 50)
        case .large: return CGSize(width: 80, height: 64)
        }
    }
}

/// Where a package currently is in its lifecycle.
nonisolated enum PackageState: Equatable, Sendable {
    case onBelt
    case held
    case loaded(LoadZone)
    case rejected
    case ranOff
    /// Flying to its shelf as part of a Helper-button sweep — frozen in place (not advancing,
    /// not run-off-able) until the view's flight animation finishes and resolves it.
    case autoSorting
}

/// A single package riding the belt.
nonisolated struct Package: Identifiable, Sendable {
    let id: UUID
    /// The serial printed on the label, or nil for an unlabeled package.
    let serial: String?
    let size: PackageSize
    /// The zone this package should be loaded into, or nil if it's a "do not touch" package.
    let correctZone: LoadZone?
    /// True for a special air package — shows an airplane icon instead of a serial, and always
    /// belongs on the roof. Never actually mutates after creation, but needs `var` (matching
    /// `state`/`beltProgress` below) so the synthesized memberwise init exposes it as an
    /// overridable parameter — a `let` with a default is excluded from that init entirely, which
    /// would force every existing call site to start passing it.
    var isAirPackage: Bool = false

    /// True for a power-up box: tapping it fires a random `PowerUpEffect` instead of being
    /// picked up and carried to a shelf. Never has a `correctZone`.
    var isPowerUp: Bool = false

    /// Position along the belt, in the belt's own coordinate space (0 = spawn point).
    var beltProgress: Double
    var state: PackageState = .onBelt

    /// Timestamps used to compute the decision-time / move-time split on the results screen.
    let spawnedAt: ContinuousClock.Instant
    var grabbedAt: ContinuousClock.Instant?
    var resolvedAt: ContinuousClock.Instant?

    /// True once a "do not touch" package has already drawn its one strike, so a second grab
    /// attempt on the same box in the same shift can't charge another.
    var wasTouched: Bool = false

    /// True for packages the player must leave alone. A power-up box also has no
    /// `correctZone`, but isn't a "do not touch" box — tapping it is exactly how it's used.
    var isDoNotTouch: Bool { correctZone == nil && !isPowerUp }

    var labelText: String {
        isAirPackage ? "AIR" : (serial ?? "NO LABEL")
    }
}
