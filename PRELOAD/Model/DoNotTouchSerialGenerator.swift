import Foundation

/// Produces a serial for a "do not touch" package, built relative to *this truck's* current
/// shelf ranges rather than a fixed list — so a near-miss always actually looks like a near-miss,
/// no matter how the ranges have rotated. Every serial this produces is guaranteed to resolve to
/// `nil` via `SerialRules.zone(for:size:ranges:)` against those same ranges; that invariant is
/// covered by `DoNotTouchSerialGeneratorTests`.
nonisolated enum DoNotTouchSerialGenerator {
    /// Look-alike letters for digits, used to turn a genuinely in-range number into something
    /// that reads as that number at a glance but fails to parse as one.
    private static let lookAlikes: [Character: Character] = ["0": "O", "1": "I", "2": "Z", "5": "S", "8": "B"]

    static func makeSerial(ranges: [LoadZone: ClosedRange<Int>], using rng: inout AnyRandomNumberGenerator) -> String {
        switch Double.random(in: 0..<1, using: &rng) {
        case 0..<0.4:
            return nearMiss(ranges: ranges, using: &rng)
        case 0.4..<0.8:
            return lookAlike(ranges: ranges, using: &rng)
        default:
            return junk(using: &rng)
        }
    }

    /// A number just outside a random range's bounds. Every pair of ranges `RangeGenerator`
    /// produces is at least 1000 apart, so an offset capped well under that can never accidentally
    /// land inside a neighboring range — checked defensively anyway, with a look-alike fallback.
    private static func nearMiss(ranges: [LoadZone: ClosedRange<Int>], using rng: inout AnyRandomNumberGenerator) -> String {
        guard let range = ranges.values.randomElement(using: &rng) else {
            return junk(using: &rng)
        }
        let offset = Int.random(in: 1...50, using: &rng)
        let number = Bool.random(using: &rng) ? range.upperBound + offset : max(0, range.lowerBound - offset)

        guard !ranges.values.contains(where: { $0.contains(number) }) else {
            return lookAlike(ranges: ranges, using: &rng)
        }
        return String(number)
    }

    /// A genuinely in-range number with one digit swapped for its look-alike letter — reads as
    /// "maybe mine" until you actually check it, but never parses as a plain number.
    private static func lookAlike(ranges: [LoadZone: ClosedRange<Int>], using rng: inout AnyRandomNumberGenerator) -> String {
        guard let range = ranges.values.randomElement(using: &rng) else {
            return junk(using: &rng)
        }
        var digits = Array(String(Int.random(in: range, using: &rng)))
        let swappableIndices = digits.indices.filter { lookAlikes[digits[$0]] != nil }
        guard let index = swappableIndices.randomElement(using: &rng), let swapped = lookAlikes[digits[index]] else {
            // No swappable digit in this particular number — fall back to definitely-junk.
            return junk(using: &rng)
        }
        digits[index] = swapped
        return String(digits)
    }

    /// A short alphanumeric with no pretense of being a real serial.
    private static func junk(using rng: inout AnyRandomNumberGenerator) -> String {
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ"
        let digits = "0123456789"
        var result = ""
        for _ in 0..<2 { result.append(letters.randomElement(using: &rng)!) }
        for _ in 0..<3 { result.append(digits.randomElement(using: &rng)!) }
        return result
    }
}
