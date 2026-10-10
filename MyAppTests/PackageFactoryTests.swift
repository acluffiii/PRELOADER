import Testing
@testable import MyApp

struct PackageFactoryTests {
    @Test("Every spawned package's correctZone matches SerialRules independently")
    func correctZoneMatchesSerialRules() {
        var factory = PackageFactory(rng: SeededRandomNumberGenerator(seed: 42))
        let clock = ContinuousClock()

        for _ in 0..<500 {
            let package = factory.makePackage(now: clock.now, ranges: SerialRules.defaultRanges)
            let expected = SerialRules.zone(
                for: package.serial,
                size: package.size,
                isAirPackage: package.isAirPackage,
                ranges: SerialRules.defaultRanges
            )
            #expect(package.correctZone == expected)
        }
    }

    @Test("The belt mix is roughly 72% shelf, 10% rerun, 8% air, 10% do-not-touch")
    func mixRatios() {
        var factory = PackageFactory(rng: SeededRandomNumberGenerator(seed: 7))
        let clock = ContinuousClock()

        var shelfCount = 0
        var rerunCount = 0
        var roofCount = 0
        var doNotTouchCount = 0
        let total = 4000

        for _ in 0..<total {
            let package = factory.makePackage(now: clock.now, ranges: SerialRules.defaultRanges)
            switch package.correctZone {
            case .rerun: rerunCount += 1
            case .roof: roofCount += 1
            case .shelf1000, .shelf2000, .shelf3000, .shelf4000: shelfCount += 1
            case nil: doNotTouchCount += 1
            }
        }

        #expect(abs(Double(shelfCount) / Double(total) - 0.72) < 0.05)
        #expect(abs(Double(rerunCount) / Double(total) - 0.10) < 0.05)
        #expect(abs(Double(roofCount) / Double(total) - 0.08) < 0.05)
        #expect(abs(Double(doNotTouchCount) / Double(total) - 0.10) < 0.05)
    }

    @Test("Every roof-bound package is an air package with no serial")
    func airPackagesAreConsistent() {
        var factory = PackageFactory(rng: SeededRandomNumberGenerator(seed: 11))
        let clock = ContinuousClock()

        for _ in 0..<2000 {
            let package = factory.makePackage(now: clock.now, ranges: SerialRules.defaultRanges)
            if package.correctZone == .roof {
                #expect(package.isAirPackage)
                #expect(package.serial == nil)
            }
            if package.isAirPackage {
                #expect(package.correctZone == .roof)
            }
        }
    }

    @Test("The same seed produces the same belt")
    func deterministicWithSeed() {
        let clock = ContinuousClock()
        var factoryA = PackageFactory(rng: SeededRandomNumberGenerator(seed: 99))
        var factoryB = PackageFactory(rng: SeededRandomNumberGenerator(seed: 99))

        let serialsA = (0..<20).map { _ in factoryA.makePackage(now: clock.now, ranges: SerialRules.defaultRanges).serial }
        let serialsB = (0..<20).map { _ in factoryB.makePackage(now: clock.now, ranges: SerialRules.defaultRanges).serial }

        #expect(serialsA == serialsB)
    }
}
