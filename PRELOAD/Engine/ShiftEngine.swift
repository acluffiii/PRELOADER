import Foundation
import Observation

/// Transient feedback shown on screen for a moment after something happens — a score popup,
/// a strike warning, a discipline bonus.
struct FeedbackEvent: Identifiable {
    enum Kind {
        case success
        case mistake
        case discipline
    }

    let id = UUID()
    let text: String
    let kind: Kind
}

/// Where a shift currently stands.
enum ShiftPhase: Equatable {
    case ready
    case running
    case over
}

/// Why a strike was charged. Kept distinct so results can tell "you misload a lot" apart from
/// "you miss a lot" — different skill problems with different fixes.
enum StrikeReason {
    case wrongShelf
    case forbiddenTouch
    case ranOff

    var message: String {
        switch self {
        case .wrongShelf: return "WRONG SHELF"
        case .forbiddenTouch: return "NOT YOUR TRUCK"
        case .ranOff: return "MISSED IT"
        }
    }
}

/// Drives one shift of loading: spawning packages onto the belt, advancing them, scoring
/// grabs and drops, and deciding when the shift ends. Owns all game state; views only read it
/// and call `grab`/`drop`.
@MainActor
@Observable
final class ShiftEngine {
    private(set) var phase: ShiftPhase = .ready

    /// Packages currently riding the belt (not yet grabbed, loaded, or removed).
    private(set) var beltPackages: [Package] = []

    /// Packages stacked on each shelf, for the shelf-stacking visual.
    private(set) var loadedPackages: [LoadZone: [Package]] = [:]

    private(set) var score = 0
    private(set) var combo = 0
    private(set) var bestCombo = 0
    private(set) var strikes = 0
    private(set) var spawnedCount = 0
    private(set) var loadedCount = 0

    /// Strikes broken down by cause, for the results screen.
    private(set) var misloadCount = 0
    private(set) var forbiddenTouchCount = 0
    private(set) var missedCount = 0

    /// Spawn → grab, and grab → drop, kept separately so results can show whether a player
    /// is slow to read a label or slow to move a box.
    private(set) var decisionTimes: [Duration] = []
    private(set) var moveTimes: [Duration] = []

    /// The most recent thing worth showing the player; views can react to its id changing.
    private(set) var lastEvent: FeedbackEvent?

    /// Monotonically increasing belt travel, in units of "full belt lengths." Purely cosmetic —
    /// it drives the conveyor stripe animation, so the belt visibly speeds up with the ramp.
    private(set) var beltDistance: Double = 0

    /// When the shift started and ended, for the packages-per-hour stat on the results screen.
    private(set) var shiftStartedAt: ContinuousClock.Instant?
    private(set) var shiftEndedAt: ContinuousClock.Instant?

    var comboMultiplier: Int { ScoreRules.multiplier(forCombo: combo) }

    private var factory: PackageFactory
    private let clock = ContinuousClock()
    private var spawnClock: Double = 0

    /// Internal (not private) so tests can confirm the ramp approaches but never passes its
    /// floor multiplier.
    private(set) var beltTravelTime = ScoreRules.baseBeltTravelTime
    private(set) var spawnInterval = ScoreRules.baseSpawnInterval

    init(factory: PackageFactory = PackageFactory()) {
        self.factory = factory
    }

    // MARK: Lifecycle

    func startShift() {
        phase = .running
        beltPackages = []
        loadedPackages = [:]
        score = 0
        combo = 0
        bestCombo = 0
        strikes = 0
        spawnedCount = 0
        loadedCount = 0
        misloadCount = 0
        forbiddenTouchCount = 0
        missedCount = 0
        decisionTimes = []
        moveTimes = []
        lastEvent = nil
        beltDistance = 0
        spawnClock = 0
        beltTravelTime = ScoreRules.baseBeltTravelTime
        spawnInterval = ScoreRules.baseSpawnInterval
        shiftStartedAt = clock.now
        shiftEndedAt = nil
    }

    // MARK: Game loop

    /// Advances the belt, spawns new packages, and resolves any that ran off the end.
    /// Call this roughly 60 times a second from the view's game loop.
    func tick(delta: Double) {
        guard phase == .running else { return }

        advanceBelt(delta: delta)
        resolveRunoff()
        maybeSpawn(delta: delta)
        checkForShiftEnd()
    }

    private func advanceBelt(delta: Double) {
        let step = delta / beltTravelTime
        beltDistance += step
        for index in beltPackages.indices {
            if beltPackages[index].state == .onBelt {
                beltPackages[index].beltProgress += step
            }
        }
    }

    private func resolveRunoff() {
        let ranOff = beltPackages.filter { $0.state == .onBelt && $0.beltProgress >= 1 }
        guard !ranOff.isEmpty else { return }

        for package in ranOff {
            // Only an untouched "do not touch" box earns discipline — once it's been grabbed
            // at and strike-charged, letting it ride off the rest of the way is not a bonus.
            if package.isDoNotTouch && !package.wasTouched {
                score += ScoreRules.disciplinePoints
                lastEvent = FeedbackEvent(text: "DISCIPLINE +\(ScoreRules.disciplinePoints)", kind: .discipline)
            } else if !package.isDoNotTouch {
                registerStrike(.ranOff)
            }
        }
        beltPackages.removeAll { $0.state == .onBelt && $0.beltProgress >= 1 }
    }

    private func maybeSpawn(delta: Double) {
        spawnClock += delta
        while spawnClock >= spawnInterval && spawnedCount < ScoreRules.packagesPerShift {
            spawnClock -= spawnInterval
            spawnedCount += 1
            beltPackages.append(factory.makePackage(now: clock.now))
        }
    }

    private func checkForShiftEnd() {
        if strikes >= ScoreRules.maxStrikes {
            beltPackages.removeAll() // release anything mid-carry; the shift is over
            endShift()
        } else if spawnedCount >= ScoreRules.packagesPerShift && beltPackages.isEmpty {
            endShift()
        }
    }

    private func endShift() {
        phase = .over
        shiftEndedAt = clock.now
    }

    // MARK: Player actions

    /// Attempts to pick up a package. Returns false for a "do not touch" package — the caller
    /// should not let the drag continue. Only the first touch on a given box charges a strike;
    /// repeated `onChanged` events (or repeated taps) on an already-touched box are no-ops.
    @discardableResult
    func grab(id: Package.ID) -> Bool {
        guard phase == .running, let index = beltPackages.firstIndex(where: { $0.id == id }) else {
            return false
        }
        guard beltPackages[index].state == .onBelt else { return false }

        if beltPackages[index].isDoNotTouch {
            if !beltPackages[index].wasTouched {
                beltPackages[index].wasTouched = true
                registerStrike(.forbiddenTouch)
            }
            return false
        }

        beltPackages[index].state = .held
        beltPackages[index].grabbedAt = clock.now
        return true
    }

    /// Releases a held package over `zone`, or back onto the belt if `zone` is nil (released
    /// outside any shelf or the floor).
    func drop(id: Package.ID, in zone: LoadZone?) {
        guard phase == .running else { return }
        guard let index = beltPackages.firstIndex(where: { $0.id == id }) else { return }
        guard beltPackages[index].state == .held else { return }

        guard let zone else {
            // Released over nothing — back on the belt, no penalty, clock keeps running.
            beltPackages[index].state = .onBelt
            beltPackages[index].grabbedAt = nil
            return
        }

        let package = beltPackages[index]
        let now = clock.now

        if zone == package.correctZone {
            recordLoad(package: package, zone: zone, now: now)
            beltPackages.remove(at: index)
        } else {
            registerStrike(.wrongShelf)
            beltPackages.remove(at: index)
        }
    }

    // MARK: Scoring

    private func recordLoad(package: Package, zone: LoadZone, now: ContinuousClock.Instant) {
        guard let grabbedAt = package.grabbedAt else {
            // Invariant violation: a `.held` package is always grabbed through `grab(id:)`,
            // which always sets `grabbedAt`. Surface it loudly in debug rather than silently
            // dropping the package and its score.
            assertionFailure("Loaded a package with no grabbedAt timestamp")
            return
        }

        let totalElapsed = package.spawnedAt.duration(to: now)
        var points = ScoreRules.correctLoadPoints
        var tag = ""
        if totalElapsed <= ScoreRules.snapThreshold {
            points += ScoreRules.snapBonus
            tag = " SNAP"
        } else if totalElapsed <= ScoreRules.cleanThreshold {
            points += ScoreRules.cleanBonus
            tag = " CLEAN"
        }

        combo += 1
        bestCombo = max(bestCombo, combo)
        let multiplier = comboMultiplier
        let awarded = points * multiplier
        score += awarded
        loadedCount += 1

        decisionTimes.append(package.spawnedAt.duration(to: grabbedAt))
        moveTimes.append(grabbedAt.duration(to: now))

        var loaded = package
        loaded.state = .loaded(zone)
        loaded.resolvedAt = now
        loadedPackages[zone, default: []].append(loaded)

        let multiplierTag = multiplier > 1 ? " x\(multiplier)" : ""
        lastEvent = FeedbackEvent(text: "+\(awarded)\(tag)\(multiplierTag)", kind: .success)
        advanceRamp()
    }

    private func registerStrike(_ reason: StrikeReason) {
        strikes += 1
        combo = 0
        switch reason {
        case .wrongShelf: misloadCount += 1
        case .forbiddenTouch: forbiddenTouchCount += 1
        case .ranOff: missedCount += 1
        }
        lastEvent = FeedbackEvent(text: "\(reason.message) — STRIKE \(strikes)/\(ScoreRules.maxStrikes)", kind: .mistake)
    }

    private func advanceRamp() {
        beltTravelTime = max(
            ScoreRules.baseBeltTravelTime * ScoreRules.rampFloorMultiplier,
            beltTravelTime * ScoreRules.rampPerLoad
        )
        spawnInterval = max(
            ScoreRules.baseSpawnInterval * ScoreRules.rampFloorMultiplier,
            spawnInterval * ScoreRules.rampPerLoad
        )
    }
}
