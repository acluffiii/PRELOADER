import Testing
@testable import MyApp

/// The `rangeSeed` every helper defaults to, so a package pre-screened by `findSeed` against
/// these ranges always matches what an engine built with the same `rangeSeed` actually spawns.
private let defaultRangeSeed: UInt64 = 0

private func makeRanges(seed: UInt64 = defaultRangeSeed) -> [LoadZone: ClosedRange<Int>] {
    var rng = AnyRandomNumberGenerator(SeededRandomNumberGenerator(seed: seed))
    return RangeGenerator.makeRanges(using: &rng)
}

/// Finds a seed whose first `count` spawned packages (in order) all satisfy `predicate`, so an
/// engine test can get an exactly-known belt without any chance interference from other
/// packages spawning, running off, or needing to be touched. Screens against the ranges a
/// same-`rangeSeed` engine will actually use, so the prediction holds once that engine spawns.
@MainActor
private func findSeed(
    count: Int = 1,
    rangeSeed: UInt64 = defaultRangeSeed,
    searching maxSeed: UInt64 = 50_000,
    matching predicate: ([Package]) -> Bool
) -> UInt64 {
    let clock = ContinuousClock()
    let ranges = makeRanges(seed: rangeSeed)
    for seed in UInt64(0)..<maxSeed {
        var factory = PackageFactory(rng: SeededRandomNumberGenerator(seed: seed))
        let packages = (0..<count).map { _ in factory.makePackage(now: clock.now, ranges: ranges) }
        if predicate(packages) {
            return seed
        }
    }
    fatalError("No seed found matching the predicate within range")
}

/// Starts a shift and spawns exactly one package by ticking forward by one spawn interval.
@MainActor
private func startAndSpawnOne(
    seed: UInt64,
    rangeSeed: UInt64 = defaultRangeSeed,
    practiceMode: Bool = false
) -> (ShiftEngine, Package) {
    let engine = ShiftEngine(
        factory: PackageFactory(rng: SeededRandomNumberGenerator(seed: seed)),
        rangeRNG: SeededRandomNumberGenerator(seed: rangeSeed),
        powerUpChance: 0
    )
    engine.startShift(practiceMode: practiceMode)
    engine.beginRunning()
    engine.tick(delta: ScoreRules.baseSpawnInterval + 0.01)
    return (engine, engine.beltPackages[0])
}

@MainActor
struct ShiftEngineTests {
    @Test("A correct load adds score and extends the combo")
    func correctLoadScoresAndCombos() {
        let seed = findSeed { $0[0].correctZone == .shelf1000 }
        let (engine, package) = startAndSpawnOne(seed: seed)

        #expect(engine.grab(id: package.id))
        engine.drop(id: package.id, in: .shelf1000)

        #expect(engine.score > 0)
        #expect(engine.combo == 1)
        #expect(engine.loadedCount == 1)
        #expect(engine.strikes == 0)
        #expect(engine.beltPackages.isEmpty)
    }

    @Test("A misload strikes and resets the combo")
    func misloadStrikesAndResetsCombo() {
        let seed = findSeed { $0[0].correctZone == .shelf1000 }
        let (engine, package) = startAndSpawnOne(seed: seed)

        #expect(engine.grab(id: package.id))
        engine.drop(id: package.id, in: .shelf2000) // deliberately wrong

        #expect(engine.strikes == 1)
        #expect(engine.misloadCount == 1)
        #expect(engine.combo == 0)
        #expect(engine.score == 0)
    }

    @Test("Grabbing a do-not-touch package fails and strikes exactly once")
    func doNotTouchStrikesOnce() {
        let seed = findSeed { $0[0].correctZone == nil }
        let (engine, package) = startAndSpawnOne(seed: seed)

        #expect(engine.grab(id: package.id) == false)
        #expect(engine.strikes == 1)
        #expect(engine.forbiddenTouchCount == 1)

        // A second touch on the same box must not charge a second strike.
        #expect(engine.grab(id: package.id) == false)
        #expect(engine.strikes == 1)
        #expect(engine.forbiddenTouchCount == 1)
    }

    @Test("A valid package left to run off the belt strikes")
    func validRunoffStrikes() {
        let seed = findSeed { $0[0].correctZone == .shelf1000 }
        let (engine, package) = startAndSpawnOne(seed: seed)

        // A delta this big both runs the original package off the end AND spawns the next
        // one or two (B4's spawn-remainder fix is working as intended) — so check that this
        // specific package is gone, not that the belt is empty.
        engine.tick(delta: engine.beltTravelTime + 0.1)

        #expect(engine.strikes == 1)
        #expect(engine.missedCount == 1)
        #expect(!engine.beltPackages.contains { $0.id == package.id })
    }

    @Test("A do-not-touch package left alone to run off earns discipline, not a strike")
    func doNotTouchRunoffEarnsDiscipline() {
        let seed = findSeed { $0[0].correctZone == nil }
        let (engine, package) = startAndSpawnOne(seed: seed)

        engine.tick(delta: engine.beltTravelTime + 0.1)

        #expect(engine.score == ScoreRules.disciplinePoints)
        #expect(engine.strikes == 0)
        #expect(!engine.beltPackages.contains { $0.id == package.id })
    }

    @Test("Releasing over nothing returns the package to the belt with no penalty")
    func releaseOverNothingReturnsToBelt() {
        let seed = findSeed { $0[0].correctZone == .shelf1000 }
        let (engine, package) = startAndSpawnOne(seed: seed)

        #expect(engine.grab(id: package.id))
        engine.drop(id: package.id, in: nil)

        #expect(engine.score == 0)
        #expect(engine.strikes == 0)
        #expect(engine.combo == 0)
        #expect(engine.beltPackages.count == 1)
        #expect(engine.beltPackages[0].state == .onBelt)
    }

    @Test("A no-label package loaded into rerun scores like any other correct load")
    func rerunLoadScores() {
        let seed = findSeed { $0[0].correctZone == .rerun }
        let (engine, package) = startAndSpawnOne(seed: seed)

        #expect(engine.grab(id: package.id))
        engine.drop(id: package.id, in: .rerun)

        #expect(engine.score > 0)
        #expect(engine.loadedCount == 1)
        #expect(engine.strikes == 0)
    }

    @Test("An air package loaded onto the roof scores like any other correct load")
    func roofLoadScores() {
        let seed = findSeed { $0[0].correctZone == .roof }
        let (engine, package) = startAndSpawnOne(seed: seed)

        #expect(engine.grab(id: package.id))
        engine.drop(id: package.id, in: .roof)

        #expect(engine.score > 0)
        #expect(engine.loadedCount == 1)
        #expect(engine.strikes == 0)
    }

    @Test("Three strikes ends the shift")
    func threeStrikesEndsShift() {
        let seed = findSeed(count: 3) { $0.allSatisfy { $0.correctZone != nil } }
        let engine = ShiftEngine(
            factory: PackageFactory(rng: SeededRandomNumberGenerator(seed: seed)),
            rangeRNG: SeededRandomNumberGenerator(seed: defaultRangeSeed),
            powerUpChance: 0
        )
        engine.startShift()
        engine.beginRunning()

        for expectedStrikes in 1...3 {
            engine.tick(delta: ScoreRules.baseSpawnInterval + 0.01)
            let package = engine.beltPackages[0]
            #expect(engine.grab(id: package.id))
            let wrongZone = LoadZone.allCases.first { $0 != package.correctZone }!
            engine.drop(id: package.id, in: wrongZone)
            #expect(engine.strikes == expectedStrikes)
        }

        // `checkForShiftEnd` only runs inside `tick`, so the 3rd strike (registered inside
        // `drop`) doesn't flip the phase until the next tick.
        engine.tick(delta: 0.001)

        #expect(engine.phase == .over)
        #expect(engine.beltPackages.isEmpty)
    }

    @Test("In practice mode, strikes still register but never end the shift")
    func practiceModeStrikesNeverEndTheShift() {
        let seed = findSeed(count: 5) { $0.allSatisfy { $0.correctZone != nil } }
        let engine = ShiftEngine(
            factory: PackageFactory(rng: SeededRandomNumberGenerator(seed: seed)),
            rangeRNG: SeededRandomNumberGenerator(seed: defaultRangeSeed),
            powerUpChance: 0
        )
        engine.startShift(practiceMode: true)
        engine.beginRunning()

        for expectedStrikes in 1...5 {
            engine.tick(delta: ScoreRules.baseSpawnInterval + 0.01)
            let package = engine.beltPackages[0]
            #expect(engine.grab(id: package.id))
            let wrongZone = LoadZone.allCases.first { $0 != package.correctZone }!
            engine.drop(id: package.id, in: wrongZone)
            #expect(engine.strikes == expectedStrikes)
            engine.tick(delta: 0.001)
            #expect(engine.phase == .running)
        }
    }

    @Test("In practice mode, the belt never ramps past its base pace")
    func practiceModeBeltStaysAtBasePace() {
        let seed = findSeed(count: 10) { $0.allSatisfy { $0.correctZone != nil } }
        let engine = ShiftEngine(
            factory: PackageFactory(rng: SeededRandomNumberGenerator(seed: seed)),
            rangeRNG: SeededRandomNumberGenerator(seed: defaultRangeSeed),
            powerUpChance: 0
        )
        engine.startShift(practiceMode: true)
        engine.beginRunning()

        for _ in 0..<10 {
            engine.tick(delta: engine.spawnInterval + 0.01)
            guard let package = engine.beltPackages.first else { continue }
            #expect(engine.grab(id: package.id))
            engine.drop(id: package.id, in: package.correctZone)
        }

        #expect(engine.beltTravelTime == ScoreRules.baseBeltTravelTime)
        #expect(engine.spawnInterval == ScoreRules.baseSpawnInterval)
    }

    @Test("Filling every shelf completes the truck: ranges rotate, shelves clear, score carries over")
    func fillingAllShelvesCompletesTheTruck() {
        let engine = ShiftEngine(
            factory: PackageFactory(rng: SeededRandomNumberGenerator(seed: 5)),
            rangeRNG: SeededRandomNumberGenerator(seed: defaultRangeSeed),
            powerUpChance: 0
        )
        engine.startShift()
        let rangesBefore = engine.shelfRanges
        engine.beginRunning()

        // Ticks in small steps and, every iteration, grabs and correctly drops every loadable
        // package currently on the belt — leaving do-not-touch packages alone to ride off for
        // discipline instead of a strike — until the truck completes or the safety cap trips.
        var iterations = 0
        while engine.truckNumber == 1 && iterations < 3000 {
            iterations += 1
            engine.tick(delta: 0.2)
            for package in engine.beltPackages where package.state == .onBelt {
                if let zone = package.correctZone, engine.grab(id: package.id) {
                    engine.drop(id: package.id, in: zone)
                }
            }
        }

        #expect(engine.truckNumber == 2)
        #expect(engine.phase == .paused)
        #expect(engine.truckJustCompleted)
        #expect(engine.shelfRanges != rangesBefore)
        #expect(engine.loadedPackages.values.allSatisfy(\.isEmpty))
        #expect(engine.beltPackages.isEmpty)
        #expect(engine.strikes == 0)
        #expect(engine.score > 0)
    }

    @Test("The belt and spawn ramp decay toward their floor and never pass it")
    func rampNeverPassesItsFloor() {
        // A shift only spawns `packagesPerShift` packages per truck, so to actually reach the
        // ramp's floor (it takes ~40 consecutive loads given `rampPerLoad`), find a seed where
        // none of this run's packages are "do not touch" — every spawn is loadable. Filling every
        // shelf along the way would otherwise complete the truck and reset the spawn cap, so the
        // loop below resumes play on the next truck if that happens.
        let seed = findSeed(count: ScoreRules.packagesPerShift) { $0.allSatisfy { $0.correctZone != nil } }
        let engine = ShiftEngine(
            factory: PackageFactory(rng: SeededRandomNumberGenerator(seed: seed)),
            rangeRNG: SeededRandomNumberGenerator(seed: defaultRangeSeed),
            powerUpChance: 0
        )
        engine.startShift()
        engine.beginRunning()

        var iterations = 0
        while engine.loadedCount < ScoreRules.packagesPerShift && iterations < 100 {
            iterations += 1
            if engine.phase == .paused {
                engine.beginRunning()
            }
            engine.tick(delta: engine.spawnInterval + 0.01)
            guard let package = engine.beltPackages.first else { continue }
            #expect(engine.grab(id: package.id))
            engine.drop(id: package.id, in: package.correctZone)
        }

        #expect(engine.loadedCount == ScoreRules.packagesPerShift)
        #expect(engine.strikes == 0)

        let floorBeltTravelTime = ScoreRules.baseBeltTravelTime * ScoreRules.rampFloorMultiplier
        let floorSpawnInterval = ScoreRules.baseSpawnInterval * ScoreRules.rampFloorMultiplier

        // 40 straight loads is just past the point where the geometric decay crosses the
        // floor, so both values should have actually clamped to the floor by now.
        #expect(abs(engine.beltTravelTime - floorBeltTravelTime) < 0.01)
        #expect(abs(engine.spawnInterval - floorSpawnInterval) < 0.01)
        #expect(engine.beltTravelTime >= floorBeltTravelTime - 0.001)
        #expect(engine.spawnInterval >= floorSpawnInterval - 0.001)
    }
}

@MainActor
struct PowerUpTests {
    /// Starts a shift, forces exactly one power-up to spawn (via `powerUpChance: 1`, which
    /// guarantees the very first spawn slot is a power-up rather than an ordinary package),
    /// and returns it.
    private func startAndSpawnPowerUp() -> (ShiftEngine, Package) {
        let engine = ShiftEngine(
            factory: PackageFactory(rng: SeededRandomNumberGenerator(seed: 0)),
            rangeRNG: SeededRandomNumberGenerator(seed: defaultRangeSeed),
            powerUpChance: 1
        )
        engine.startShift()
        engine.beginRunning()
        engine.tick(delta: ScoreRules.baseSpawnInterval + 0.01)
        let powerUp = engine.beltPackages.first { $0.isPowerUp }
        return (engine, powerUp!)
    }

    @Test("A power-up box spawns instead of an ordinary package, without using the spawn budget")
    func powerUpSpawnsWithoutCountingAgainstBudget() {
        let (engine, powerUp) = startAndSpawnPowerUp()
        #expect(powerUp.correctZone == nil)
        #expect(powerUp.isDoNotTouch == false)
        #expect(engine.spawnedCount == 0)
    }

    @Test("Tapping a power-up never grabs it, and removes it from the belt")
    func tappingPowerUpDoesNotGrabIt() {
        let (engine, powerUp) = startAndSpawnPowerUp()
        #expect(engine.grab(id: powerUp.id) == false)
        #expect(!engine.beltPackages.contains { $0.id == powerUp.id })
    }

    @Test("A power-up riding off the belt untouched earns no bonus and no strike")
    func powerUpRunoffIsPenaltyFree() {
        let (engine, powerUp) = startAndSpawnPowerUp()
        engine.tick(delta: engine.beltTravelTime + 0.1)
        #expect(!engine.beltPackages.contains { $0.id == powerUp.id })
        #expect(engine.strikes == 0)
        #expect(engine.score == 0)
    }

    @Test("Freeze stops the belt and spawning entirely, then resumes once it expires")
    func freezeStopsBeltAndSpawning() {
        let engine = ShiftEngine(
            factory: PackageFactory(rng: SeededRandomNumberGenerator(seed: 0)),
            rangeRNG: SeededRandomNumberGenerator(seed: defaultRangeSeed),
            powerUpChance: 0
        )
        engine.startShift()
        engine.beginRunning()
        engine.applyPowerUpEffect(.freeze)

        let distanceBefore = engine.beltDistance
        let countBefore = engine.beltPackages.count

        engine.tick(delta: ScoreRules.freezeDuration - 0.5)
        #expect(engine.beltDistance == distanceBefore)
        #expect(engine.beltPackages.count == countBefore)

        engine.tick(delta: 1) // crosses past the freeze's expiry
        #expect(engine.beltDistance > distanceBefore)
    }

    @Test("Slow halves belt and spawn progress while active")
    func slowHalvesProgress() {
        let engine = ShiftEngine(
            factory: PackageFactory(rng: SeededRandomNumberGenerator(seed: 0)),
            rangeRNG: SeededRandomNumberGenerator(seed: defaultRangeSeed),
            powerUpChance: 0
        )
        engine.startShift()
        engine.beginRunning()
        engine.applyPowerUpEffect(.slow)

        engine.tick(delta: 1)
        let slowedDistance = engine.beltDistance
        #expect(abs(slowedDistance - (1 / engine.beltTravelTime) * ScoreRules.slowFactor) < 0.0001)

        engine.tick(delta: ScoreRules.slowDuration) // runs well past the slow's expiry
        let afterExpiry = engine.beltDistance - slowedDistance
        #expect(afterExpiry > (1 / engine.beltTravelTime) * ScoreRules.slowFactor)
    }

    @Test("Remove-a-strike lowers strikes by one and never goes below zero")
    func removeStrikeNeverGoesNegative() {
        let engine = ShiftEngine(
            factory: PackageFactory(rng: SeededRandomNumberGenerator(seed: 0)),
            rangeRNG: SeededRandomNumberGenerator(seed: defaultRangeSeed),
            powerUpChance: 0
        )
        engine.startShift()
        engine.beginRunning()

        engine.applyPowerUpEffect(.removeStrike)
        #expect(engine.strikes == 0)
    }
}

@MainActor
struct HelperButtonTests {
    @Test("Helper sorts every sortable box with no score and resets the combo")
    func helperSortsBeltForFree() {
        let seed = findSeed(count: 3) { $0.allSatisfy { $0.correctZone != nil } }
        let engine = ShiftEngine(
            factory: PackageFactory(rng: SeededRandomNumberGenerator(seed: seed)),
            rangeRNG: SeededRandomNumberGenerator(seed: defaultRangeSeed),
            powerUpChance: 0
        )
        engine.startShift()
        engine.beginRunning()
        engine.tick(delta: ScoreRules.baseSpawnInterval * 3 + 0.01)

        let onBeltCount = engine.beltPackages.count
        #expect(onBeltCount > 0)

        let assignments = engine.beginHelper()
        #expect(assignments.count == onBeltCount)
        #expect(engine.combo == 0)
        #expect(engine.helperUsesRemaining == 0)

        engine.finishHelper(ids: assignments.map(\.id))
        #expect(engine.score == 0)
        #expect(engine.loadedCount == onBeltCount)
        #expect(engine.beltPackages.isEmpty)
    }

    @Test("Helper has no uses left until the next truck rolls in")
    func helperIsLimitedToOnceATruck() {
        let seed = findSeed(count: 2) { $0.allSatisfy { $0.correctZone != nil } }
        let engine = ShiftEngine(
            factory: PackageFactory(rng: SeededRandomNumberGenerator(seed: seed)),
            rangeRNG: SeededRandomNumberGenerator(seed: defaultRangeSeed),
            powerUpChance: 0
        )
        engine.startShift()
        engine.beginRunning()
        engine.tick(delta: ScoreRules.baseSpawnInterval + 0.01)

        let first = engine.beginHelper()
        #expect(!first.isEmpty)
        engine.finishHelper(ids: first.map(\.id))

        engine.tick(delta: ScoreRules.baseSpawnInterval + 0.01)
        let second = engine.beginHelper()
        #expect(second.isEmpty)

        engine.restartTruck()
        #expect(engine.helperUsesRemaining == ScoreRules.helperUsesPerTruck)
    }
}

struct ScoreRulesComboProgressTests {
    @Test(
        "Progress climbs within a tier and resets at each boundary",
        arguments: [
            (combo: 0, expected: 0.0),
            (combo: 4, expected: 0.8),
            (combo: 5, expected: 0.0),
            (combo: 9, expected: 0.8),
            (combo: 10, expected: 0.0),
        ]
    )
    func progressWithinTiers(combo: Int, expected: Double) {
        #expect(abs(ScoreRules.comboProgress(forCombo: combo) - expected) < 0.001)
    }

    @Test("Progress caps at 1 once the top tier is reached, with nothing higher to climb toward")
    func progressCapsAtTopTier() {
        #expect(ScoreRules.comboProgress(forCombo: 20) == 1)
        #expect(ScoreRules.comboProgress(forCombo: 35) == 1)
    }
}
