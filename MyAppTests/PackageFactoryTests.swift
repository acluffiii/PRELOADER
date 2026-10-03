import Testing
@testable import MyApp

struct PackageFactoryTests {
    @Test("Every spawned package's correctZone matches SerialRules independently")
    func correctZoneMatchesSerialRules() {
        var factory = PackageFactory(rng: SeededRandomNumberGenerator(seed: 42))
        let clock = ContinuousClock()

        for _ in 0..<500 {
            let package = factory.makePackage(now: clock.now)
            #expect(package.correctZone == SerialRules.zone(for: package.serial, size: package.size))
        }
    }

    @Test("The belt mix is roughly 70% shelf, 12% floor, 18% do-not-touch")
    func mixRatios() {
        var factory = PackageFactory(rng: SeededRandomNumberGenerator(seed: 7))
        let clock = ContinuousClock()

        var shelfCount = 0
        var floorCount = 0
        var doNotTouchCount = 0
        let total = 2000

        for _ in 0..<total {
            let package = factory.makePackage(now: clock.now)
            switch package.correctZone {
            case .floor: floorCount += 1
            case .some: shelfCount += 1
            case nil: doNotTouchCount += 1
            }
        }

        #expect(abs(Double(shelfCount) / Double(total) - 0.70) < 0.05)
        #expect(abs(Double(floorCount) / Double(total) - 0.12) < 0.05)
        #expect(abs(Double(doNotTouchCount) / Double(total) - 0.18) < 0.05)
    }

    @Test("The same seed produces the same belt")
    func deterministicWithSeed() {
        let clock = ContinuousClock()
        var factoryA = PackageFactory(rng: SeededRandomNumberGenerator(seed: 99))
        var factoryB = PackageFactory(rng: SeededRandomNumberGenerator(seed: 99))

        let serialsA = (0..<20).map { _ in factoryA.makePackage(now: clock.now).serial }
        let serialsB = (0..<20).map { _ in factoryB.makePackage(now: clock.now).serial }

        #expect(serialsA == serialsB)
    }
}
