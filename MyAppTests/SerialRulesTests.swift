import Testing
@testable import MyApp

struct SerialRulesTests {
    @Test("Shelf range boundaries", arguments: [
        ("999", LoadZone?.none),
        ("1000", .shelf1000),
        ("1099", .shelf1000),
        ("1100", .none),
        ("2000", .shelf2000),
        ("2099", .shelf2000),
        ("3000", .shelf3000),
        ("3099", .shelf3000),
        ("4000", .shelf4000),
        ("4099", .shelf4000),
        ("5000", .none),
    ])
    func boundaries(serial: String, expected: LoadZone?) {
        #expect(SerialRules.zone(for: serial, size: .medium) == expected)
    }

    @Test("Letter look-alikes are do-not-touch", arguments: ["1O42", "ABC123", "1Z9-44A", "3O87"])
    func letterLookAlikes(serial: String) {
        #expect(SerialRules.zone(for: serial, size: .medium) == nil)
    }

    @Test("No label goes to the floor")
    func noLabel() {
        #expect(SerialRules.zone(for: nil, size: .medium) == .floor)
    }

    @Test("Oversize always goes to the floor, even with a valid shelf serial")
    func oversizeOverridesValidSerial() {
        #expect(SerialRules.zone(for: "1042", size: .oversize) == .floor)
    }

    @Test("A serial that doesn't round-trip through Int is do-not-touch")
    func nonRoundTrippingSerial() {
        // "01042" parses as 1042, but re-stringifying 1042 gives "1042", not "01042" —
        // the leading zero means this isn't actually a clean numeric serial.
        #expect(SerialRules.zone(for: "01042", size: .medium) == nil)
    }
}
