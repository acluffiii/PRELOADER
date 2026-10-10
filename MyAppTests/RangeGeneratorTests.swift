import Testing
@testable import MyApp

struct RangeGeneratorTests {
    @Test("Every generated range is exactly 1000 wide")
    func rangesAreThousandWide() {
        var rng = AnyRandomNumberGenerator(SeededRandomNumberGenerator(seed: 1))
        let ranges = RangeGenerator.makeRanges(using: &rng)
        for range in ranges.values {
            #expect(range.upperBound - range.lowerBound == 999)
        }
    }

    @Test("All four shelves get a distinct range")
    func allFourShelvesAreAssigned() {
        var rng = AnyRandomNumberGenerator(SeededRandomNumberGenerator(seed: 2))
        let ranges = RangeGenerator.makeRanges(using: &rng)
        #expect(Set(ranges.keys) == Set([.shelf1000, .shelf2000, .shelf3000, .shelf4000]))
        #expect(Set(ranges.values.map(\.lowerBound)).count == 4)
    }

    @Test("No two ranges sit adjacent to each other", arguments: UInt64(0)..<30)
    func rangesAreNeverAdjacent(seed: UInt64) {
        var rng = AnyRandomNumberGenerator(SeededRandomNumberGenerator(seed: seed))
        let ranges = Array(RangeGenerator.makeRanges(using: &rng).values)
        for i in ranges.indices {
            for j in ranges.indices where j > i {
                let gap = ranges[i].lowerBound < ranges[j].lowerBound
                    ? ranges[j].lowerBound - ranges[i].upperBound
                    : ranges[i].lowerBound - ranges[j].upperBound
                #expect(gap >= 1000)
            }
        }
    }

    @Test("The same seed produces the same ranges")
    func deterministicWithSeed() {
        var rngA = AnyRandomNumberGenerator(SeededRandomNumberGenerator(seed: 42))
        var rngB = AnyRandomNumberGenerator(SeededRandomNumberGenerator(seed: 42))
        #expect(RangeGenerator.makeRanges(using: &rngA) == RangeGenerator.makeRanges(using: &rngB))
    }
}
