import Testing
@testable import MyApp

/// Finds a seed whose first `count` spawned packages (in order) all satisfy `predicate`, so an
/// engine test can get an exactly-known belt without any chance interference from other
/// packages spawning, running off, or needing to be touched.
@MainActor
private func findSeed(count: Int = 1, searching maxSeed: UInt64 = 50_000, matching predicate: ([Package]) -> Bool) -> UInt64 {
    let clock = ContinuousClock()
    for seed in UInt64(0)..<maxSeed {
        var factory = PackageFactory(rng: SeededRandomNumberGenerator(seed: seed))
        let packages = (0..<count).map { _ in factory.makePackage(now: clock.now) }
        if predicate(packages) {
            return seed
        }
    }
    fatalError("No seed found matching the predicate within range")
}

/// Starts a shift and spawns exactly one package by ticking forward by one spawn interval.
@MainActor
private func startAndSpawnOne(seed: UInt64) -> (ShiftEngine, Package) {
    let engine = ShiftEngine(factory: PackageFactory(rng: SeededRandomNumberGenerator(seed: seed)))
    engine.startShift()
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

    @Test("Three strikes ends the shift")
    func threeStrikesEndsShift() {
        let seed = findSeed(count: 3) { $0.allSatisfy { $0.correctZone != nil } }
        let engine = ShiftEngine(factory: PackageFactory(rng: SeededRandomNumberGenerator(seed: seed)))
        engine.startShift()

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

    @Test("The belt and spawn ramp decay toward their floor and never pass it")
    func rampNeverPassesItsFloor() {
        // A shift only spawns `packagesPerShift` packages, so to actually reach the ramp's
        // floor within one shift (it takes ~40 consecutive loads given `rampPerLoad`), find a
        // seed where none of this shift's packages are "do not touch" — every spawn is loadable.
        let seed = findSeed(count: ScoreRules.packagesPerShift) { $0.allSatisfy { $0.correctZone != nil } }
        let engine = ShiftEngine(factory: PackageFactory(rng: SeededRandomNumberGenerator(seed: seed)))
        engine.startShift()

        var iterations = 0
        while engine.loadedCount < ScoreRules.packagesPerShift && iterations < 100 {
            iterations += 1
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
