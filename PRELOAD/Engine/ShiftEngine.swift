import Foundation
import Observation

/// Transient feedback shown on screen for a moment after something happens — a score popup,
/// a strike warning, a discipline bonus.
struct FeedbackEvent: Identifiable {
    enum Kind {
        case success
        case mistake
        case discipline
        /// A correct load that also happened to be the one that filled a shelf — a bigger
        /// moment than an ordinary success, so it gets its own louder sound/haptic/visual.
        case shelfFull
        /// A power-up box was tapped, or the Helper button swept the belt.
        case powerUp
    }

    let id = UUID()
    let text: String
    let kind: Kind
}

/// Where a shift currently stands.
enum ShiftPhase: Equatable {
    case ready
    /// The shift screen is up and reset, but the belt is stopped — waiting on the player to
    /// tap "Start" before anything moves or scores.
    case paused
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

    /// Seconds left on the current "freeze" / "slow" power-up effect. Freeze takes priority
    /// over slow when both happen to be nonzero — see `beltSpeedFactor`.
    private(set) var freezeRemaining: Double = 0
    private(set) var slowRemaining: Double = 0

    /// Helper-button uses left for the truck currently loading. Refilled every time a new
    /// truck rolls in — see `completeTruck`, `startShift`, `restartTruck`.
    private(set) var helperUsesRemaining = ScoreRules.helperUsesPerTruck

    /// How fast the belt (and spawning) currently runs, as a fraction of normal — 0 while
    /// frozen, `ScoreRules.slowFactor` while slowed, 1 otherwise. Scales the `delta` passed to
    /// `advanceBelt`/`maybeSpawn` each tick, so the ramp's own `beltTravelTime`/`spawnInterval`
    /// are untouched and simply resume where they left off once an effect ends.
    var beltSpeedFactor: Double {
        if freezeRemaining > 0 { return 0 }
        if slowRemaining > 0 { return ScoreRules.slowFactor }
        return 1
    }

    /// Strikes broken down by cause, for the results screen.
    private(set) var misloadCount = 0
    private(set) var forbiddenTouchCount = 0
    private(set) var missedCount = 0

    /// Which truck is currently being loaded. Starts at 1 and increments every time all four
    /// shelves fill up and the next truck rolls in — score, strikes, and combo all carry over.
    private(set) var truckNumber = 1

    /// This truck's four shelf ranges, freshly rolled by `RangeGenerator` at the start of every
    /// truck. `SerialRules` and `PackageFactory` both read this rather than a fixed default once
    /// a shift is actually running.
    private(set) var shelfRanges: [LoadZone: ClosedRange<Int>] = SerialRules.defaultRanges

    /// True while the `.paused` screen is up *because a truck just pulled out* — as opposed to
    /// the very first truck of a run — so the view can show "Truck N is full!" instead of the
    /// plain "ready to start" copy.
    private(set) var truckJustCompleted = false

    /// True for a practice run: strikes still register (and still reset the combo) but never
    /// end the shift, and the belt never ramps up past its base, slowest pace. Everything else
    /// — scoring, combos, trucks, ranges — works exactly the same as a normal run.
    private(set) var isPracticeMode = false

    /// Chosen from the homepage options menu before `startShift()` is called; scales the belt's
    /// base pace and ramp floor for the whole run.
    var difficulty: Difficulty = .normal

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

    /// Whether the current streak has reached fever — a visual celebration, not a separate
    /// scoring mechanism (the multiplier itself already comes from `comboMultiplier`).
    var isFevered: Bool { comboMultiplier >= ScoreRules.feverMultiplier }

    private var factory: PackageFactory
    private let clock = ContinuousClock()
    private var spawnClock: Double = 0
    private var rangeRNG: AnyRandomNumberGenerator
    private var powerUpRNG: AnyRandomNumberGenerator
    private let powerUpChance: Double

    /// Internal (not private) so tests can confirm the ramp approaches but never passes its
    /// floor multiplier.
    private(set) var beltTravelTime = ScoreRules.baseBeltTravelTime
    private(set) var spawnInterval = ScoreRules.baseSpawnInterval

    init(
        factory: PackageFactory = PackageFactory(),
        rangeRNG: RandomNumberGenerator = SystemRandomNumberGenerator(),
        powerUpRNG: RandomNumberGenerator = SystemRandomNumberGenerator(),
        powerUpChance: Double = ScoreRules.powerUpSpawnChance
    ) {
        self.factory = factory
        self.rangeRNG = AnyRandomNumberGenerator(rangeRNG)
        self.powerUpRNG = AnyRandomNumberGenerator(powerUpRNG)
        self.powerUpChance = powerUpChance
    }

    // MARK: Lifecycle

    /// Resets everything for a fresh shift and parks it on the paused "ready to start" screen.
    /// The belt doesn't actually move, and nothing scores, until `beginRunning()`.
    func startShift(practiceMode: Bool = false) {
        phase = .paused
        isPracticeMode = practiceMode
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
        truckNumber = 1
        shelfRanges = RangeGenerator.makeRanges(using: &rangeRNG)
        truckJustCompleted = false
        freezeRemaining = 0
        slowRemaining = 0
        helperUsesRemaining = ScoreRules.helperUsesPerTruck
        decisionTimes = []
        moveTimes = []
        lastEvent = nil
        beltDistance = 0
        spawnClock = 0
        beltTravelTime = ScoreRules.baseBeltTravelTime * difficulty.paceMultiplier
        spawnInterval = ScoreRules.baseSpawnInterval * difficulty.paceMultiplier
        shiftStartedAt = nil
        shiftEndedAt = nil
    }

    /// The player tapped "Start" on the paused shift screen: the belt starts moving and the
    /// packages-per-hour clock starts ticking. On the very first truck this also starts that
    /// clock; on every truck after, `shiftStartedAt` is left alone so packages-per-hour is
    /// measured across the whole run, not reset each truck.
    func beginRunning() {
        guard phase == .paused else { return }
        phase = .running
        truckJustCompleted = false
        if shiftStartedAt == nil {
            shiftStartedAt = clock.now
        }
    }

    /// From the pause menu: re-rolls the current truck's belt, shelves, and ranges without
    /// ending the run — score, strikes, combo, and `truckNumber` all carry over, since this is
    /// the same truck starting over, not a new one pulling in.
    func restartTruck() {
        guard phase == .running || phase == .paused else { return }
        loadedPackages = [:]
        beltPackages = []
        shelfRanges = RangeGenerator.makeRanges(using: &rangeRNG)
        spawnedCount = 0
        spawnClock = 0
        truckJustCompleted = false
        freezeRemaining = 0
        slowRemaining = 0
        helperUsesRemaining = ScoreRules.helperUsesPerTruck
        phase = .paused
    }

    /// From the pause menu: ends the run early, same as a 3-strike game over, so the results
    /// screen reports whatever was earned up to this point.
    func quitRun() {
        guard phase == .running || phase == .paused else { return }
        beltPackages.removeAll()
        endShift()
    }

    /// From the results screen: steps back to the start screen, discarding this run's state
    /// entirely — `ContentView` switches to `StartView` the moment `phase` reaches `.ready`, and
    /// the next `startShift()` begins a completely fresh run.
    func returnToMenu() {
        guard phase == .over else { return }
        phase = .ready
    }

    // MARK: Game loop

    /// Advances the belt, spawns new packages, and resolves any that ran off the end.
    /// Call this roughly 60 times a second from the view's game loop.
    func tick(delta: Double) {
        guard phase == .running else { return }

        // Timers always run on real time, even while frozen/slowed — otherwise a freeze would
        // never count down. The belt and spawn clock get the scaled delta instead.
        freezeRemaining = max(0, freezeRemaining - delta)
        slowRemaining = max(0, slowRemaining - delta)
        let scaledDelta = delta * beltSpeedFactor

        advanceBelt(delta: scaledDelta)
        resolveRunoff()
        maybeSpawn(delta: scaledDelta)
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
            // An ignored power-up just rides off, same as never having spawned — no bonus for
            // leaving it alone, no strike for missing it.
            if package.isPowerUp {
                continue
            }
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
            // A power-up takes this spawn slot instead of an ordinary package — and doesn't
            // count against the truck's package budget, so it's a bonus, not a substitution.
            // Capped at one on the belt at a time so effects don't pile up for free.
            if !beltPackages.contains(where: \.isPowerUp),
               Double.random(in: 0..<1, using: &powerUpRNG) < powerUpChance {
                beltPackages.append(makePowerUpPackage(now: clock.now))
            } else {
                spawnedCount += 1
                beltPackages.append(factory.makePackage(now: clock.now, ranges: shelfRanges))
            }
        }
    }

    private func makePowerUpPackage(now: ContinuousClock.Instant) -> Package {
        Package(id: UUID(), serial: nil, size: .medium, correctZone: nil, isPowerUp: true, beltProgress: 0, spawnedAt: now)
    }

    private func checkForShiftEnd() {
        // In practice mode, strikes still happen (and still reset the combo) but never end the
        // run — the whole point is a shift with no stakes.
        if !isPracticeMode && strikes >= ScoreRules.maxStrikes {
            beltPackages.removeAll() // release anything mid-carry; the run is over
            endShift()
        } else if spawnedCount >= ScoreRules.packagesPerShift && beltPackages.isEmpty {
            // The per-truck safety cap: if a truck somehow spawns out without every shelf
            // filling (a very slow or very unlucky player), pull it out anyway rather than
            // stalling the run entirely. Normal play reaches `completeTruck()` from
            // `recordLoad` well before this.
            completeTruck()
        }
    }

    private func endShift() {
        phase = .over
        shiftEndedAt = clock.now
    }

    /// Whether every shelf has reached the capacity that counts as "full" — the normal way a
    /// truck ends.
    private func allShelvesFull() -> Bool {
        LoadZone.allCases
            .filter(\.isShelf)
            .allSatisfy { (loadedPackages[$0]?.count ?? 0) >= ScoreRules.shelfCapacityForCelebration }
    }

    /// The truck pulls out: everything currently loaded or on the belt goes with it, a new truck
    /// rolls in with freshly rolled shelf ranges, and the screen drops back to the paused
    /// "ready" gate so the view can show a quick tutorial before the next truck's belt moves.
    /// Score, strikes, combo, and the speed ramp all carry over — this is one continuous run.
    private func completeTruck() {
        loadedPackages = [:]
        beltPackages = []
        truckNumber += 1
        shelfRanges = RangeGenerator.makeRanges(using: &rangeRNG)
        spawnedCount = 0
        spawnClock = 0
        truckJustCompleted = true
        freezeRemaining = 0
        slowRemaining = 0
        helperUsesRemaining = ScoreRules.helperUsesPerTruck
        phase = .paused
    }

    // MARK: Player actions

    /// Attempts to pick up a package. Returns false for a "do not touch" package — the caller
    /// should not let the drag continue. Only the first touch on a given do-not-touch box charges
    /// a strike; repeated `onChanged` events (or repeated taps) on an already-touched box are
    /// no-ops.
    @discardableResult
    func grab(id: Package.ID) -> Bool {
        guard phase == .running, let index = beltPackages.firstIndex(where: { $0.id == id }) else {
            return false
        }
        guard beltPackages[index].state == .onBelt else { return false }

        if beltPackages[index].isPowerUp {
            activatePowerUp(removing: id)
            return false
        }

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
            // `recordLoad` can complete the truck (when this load fills the last shelf), which
            // resets `beltPackages` entirely — `index` would then point past the end of the now-
            // empty array, so removal has to go by `id`, not the stale index, to avoid an
            // out-of-range crash.
            recordLoad(package: package, zone: zone, now: now)
            beltPackages.removeAll { $0.id == id }
        } else {
            registerStrike(.wrongShelf)
            beltPackages.removeAll { $0.id == id }
        }
    }

    // MARK: Power-ups

    /// Rolls a random effect and applies it, then removes the tapped box. "Remove a strike"
    /// is re-rolled away from when there's no strike to remove, so a tap is never wasted.
    private func activatePowerUp(removing id: Package.ID) {
        var effect = PowerUpEffect.allCases.randomElement(using: &powerUpRNG) ?? .slow
        if effect == .removeStrike && strikes == 0 {
            effect = [.slow, .freeze].randomElement(using: &powerUpRNG) ?? .slow
        }
        applyPowerUpEffect(effect)
        beltPackages.removeAll { $0.id == id }
        lastEvent = FeedbackEvent(text: effect.message, kind: .powerUp)
    }

    /// Internal (not private) so tests can force a specific effect without fighting the RNG.
    /// Setting (rather than adding to) a timer means re-tapping the same effect refreshes its
    /// duration instead of stacking.
    func applyPowerUpEffect(_ effect: PowerUpEffect) {
        switch effect {
        case .slow: slowRemaining = ScoreRules.slowDuration
        case .freeze: freezeRemaining = ScoreRules.freezeDuration
        case .removeStrike: strikes = max(0, strikes - 1)
        }
    }

    /// The Helper button: every sortable box currently on the belt is marked `.autoSorting` —
    /// frozen in place so it stops advancing and can't run off — and handed back to the view
    /// to animate flying to its shelf. `finishHelper` actually resolves them once that
    /// animation completes. Returns an empty array (and changes nothing) if there's no use
    /// left or nothing sortable to sweep.
    @discardableResult
    func beginHelper() -> [(id: Package.ID, zone: LoadZone)] {
        guard phase == .running, helperUsesRemaining > 0 else { return [] }
        let onBelt = beltPackages.filter { $0.state == .onBelt }
        let sortable = onBelt.filter { $0.correctZone != nil }
        guard !sortable.isEmpty else { return [] }

        helperUsesRemaining -= 1
        combo = 0

        let sortableIDs = Set(sortable.map(\.id))
        for index in beltPackages.indices where sortableIDs.contains(beltPackages[index].id) {
            beltPackages[index].state = .autoSorting
        }
        // A do-not-touch or power-up box left on the belt is swept away for free along with
        // everything else — no discipline bonus (it wasn't left to run off on its own), no
        // strike, no effect.
        beltPackages.removeAll { $0.state == .onBelt }

        return sortable.compactMap { package in package.correctZone.map { (package.id, $0) } }
    }

    /// Resolves the boxes `beginHelper` handed off, once the view's flight animation for each
    /// has finished: loads them onto their shelves with no score (it's a bailout, not a skill
    /// play) and checks whether that happens to complete the truck.
    func finishHelper(ids: [Package.ID]) {
        let now = clock.now
        for id in ids {
            guard let index = beltPackages.firstIndex(where: { $0.id == id }),
                  beltPackages[index].state == .autoSorting,
                  let zone = beltPackages[index].correctZone else { continue }
            var package = beltPackages[index]
            package.state = .loaded(zone)
            package.resolvedAt = now
            loadedPackages[zone, default: []].append(package)
            loadedCount += 1
        }
        beltPackages.removeAll { ids.contains($0.id) }
        lastEvent = FeedbackEvent(text: "HELPER SORTED \(ids.count)", kind: .powerUp)
        if allShelvesFull() {
            completeTruck()
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
        var awarded = points * multiplier
        loadedCount += 1

        decisionTimes.append(package.spawnedAt.duration(to: grabbedAt))
        moveTimes.append(grabbedAt.duration(to: now))

        var loaded = package
        loaded.state = .loaded(zone)
        loaded.resolvedAt = now
        loadedPackages[zone, default: []].append(loaded)

        let multiplierTag = multiplier > 1 ? " x\(multiplier)" : ""

        // A shelf hitting its celebration count is a bigger moment than an ordinary load, so
        // fold its bonus into this same event rather than firing a second one — `lastEvent` can
        // only hold one value, and a second write here would stomp the first before the view
        // ever saw it.
        if zone.isShelf, loadedPackages[zone]?.count == ScoreRules.shelfCapacityForCelebration {
            awarded += ScoreRules.shelfFullBonus
            score += awarded
            lastEvent = FeedbackEvent(text: "+\(awarded)\(tag)\(multiplierTag) SHELF FULL!", kind: .shelfFull)
            // Only a shelf load can be the one that completes the last shelf, so this check only
            // needs to run in this branch.
            if allShelvesFull() {
                completeTruck()
            }
        } else {
            score += awarded
            lastEvent = FeedbackEvent(text: "+\(awarded)\(tag)\(multiplierTag)", kind: .success)
        }
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
        // Practice mode has no 3-strike limit, so counting toward "/3" there would be a lie —
        // just name the mistake instead of framing it as progress toward an ending that can't
        // happen.
        let text = isPracticeMode ? reason.message : "\(reason.message) — STRIKE \(strikes)/\(ScoreRules.maxStrikes)"
        lastEvent = FeedbackEvent(text: text, kind: .mistake)
    }

    /// In practice mode the belt stays at its base, slowest pace forever — no speed-up pressure
    /// while you're just practicing reads.
    private func advanceRamp() {
        guard !isPracticeMode else { return }
        beltTravelTime = max(
            ScoreRules.baseBeltTravelTime * difficulty.paceMultiplier * ScoreRules.rampFloorMultiplier,
            beltTravelTime * ScoreRules.rampPerLoad
        )
        spawnInterval = max(
            ScoreRules.baseSpawnInterval * difficulty.paceMultiplier * ScoreRules.rampFloorMultiplier,
            spawnInterval * ScoreRules.rampPerLoad
        )
    }
}
