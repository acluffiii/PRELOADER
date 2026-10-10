import Testing
@testable import MyApp

struct DoNotTouchSerialGeneratorTests {
    private static let sampleRanges: [LoadZone: ClosedRange<Int>] = [
        .shelf1000: 1200...1299, .shelf2000: 2700...2799,
        .shelf3000: 3100...3199, .shelf4000: 4500...4599,
    ]

    @Test(
        "Every generated serial resolves to nil against the ranges it was generated from",
        arguments: UInt64(0)..<100
    )
    func generatedSerialsAreAlwaysDoNotTouch(seed: UInt64) {
        var rng = AnyRandomNumberGenerator(SeededRandomNumberGenerator(seed: seed))
        let serial = DoNotTouchSerialGenerator.makeSerial(ranges: Self.sampleRanges, using: &rng)
        #expect(SerialRules.zone(for: serial, size: .medium, ranges: Self.sampleRanges) == nil)
    }

    @Test("Still do-not-touch against the default ranges too", arguments: UInt64(0)..<30)
    func generatedSerialsAreDoNotTouchAgainstDefaultRanges(seed: UInt64) {
        var rng = AnyRandomNumberGenerator(SeededRandomNumberGenerator(seed: seed))
        let serial = DoNotTouchSerialGenerator.makeSerial(ranges: SerialRules.defaultRanges, using: &rng)
        #expect(SerialRules.zone(for: serial, size: .medium) == nil)
    }
}
