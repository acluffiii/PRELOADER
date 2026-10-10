import Testing
@testable import MyApp

struct SerialRulesTests {
    @Test("Shelf range boundaries", arguments: [
        ("999", LoadZone?.none),
        ("1000", .shelf1000),
        ("1999", .shelf1000),
        ("2000", .shelf2000),
        ("2999", .shelf2000),
        ("3000", .shelf3000),
        ("3999", .shelf3000),
        ("4000", .shelf4000),
        ("4999", .shelf4000),
        ("5000", .none),
    ])
    func boundaries(serial: String, expected: LoadZone?) {
        #expect(SerialRules.zone(for: serial, size: .medium) == expected)
    }

    @Test("Letter look-alikes are do-not-touch", arguments: ["1O42", "ABC123", "1Z9-44A", "3O87"])
    func letterLookAlikes(serial: String) {
        #expect(SerialRules.zone(for: serial, size: .medium) == nil)
    }

    @Test("No label goes to rerun")
    func noLabel() {
        #expect(SerialRules.zone(for: nil, size: .medium) == .rerun)
    }

    @Test("An air package always goes to the roof, regardless of label or a valid serial")
    func airPackageOverridesEverything() {
        #expect(SerialRules.zone(for: nil, size: .medium, isAirPackage: true) == .roof)
        #expect(SerialRules.zone(for: "1042", size: .medium, isAirPackage: true) == .roof)
    }

    @Test("Ranges rotate: the same serial resolves differently against a different truck's ranges")
    func rangesRotatePerTruck() {
        let truckOneRanges: [LoadZone: ClosedRange<Int>] = [
            .shelf1000: 1200...1299, .shelf2000: 2700...2799,
            .shelf3000: 3100...3199, .shelf4000: 4500...4599,
        ]
        #expect(SerialRules.zone(for: "1042", size: .medium, ranges: truckOneRanges) == nil)
        #expect(SerialRules.zone(for: "1250", size: .medium, ranges: truckOneRanges) == .shelf1000)
        #expect(SerialRules.zone(for: "1250", size: .medium) == nil) // not in the default ranges
    }

    @Test("A serial that doesn't round-trip through Int is do-not-touch")
    func nonRoundTrippingSerial() {
        // "01042" parses as 1042, but re-stringifying 1042 gives "1042", not "01042" —
        // the leading zero means this isn't actually a clean numeric serial.
        #expect(SerialRules.zone(for: "01042", size: .medium) == nil)
    }

    @Test("Each shelf stencils its own exact range")
    func shelfRanges() {
        #expect(SerialRules.range(for: .shelf1000) == 1000...1999)
        #expect(SerialRules.range(for: .shelf2000) == 2000...2999)
        #expect(SerialRules.range(for: .shelf3000) == 3000...3999)
        #expect(SerialRules.range(for: .shelf4000) == 4000...4999)
    }

    @Test("The roof has no shelf range")
    func roofHasNoRange() {
        #expect(SerialRules.range(for: .roof) == nil)
    }
}
