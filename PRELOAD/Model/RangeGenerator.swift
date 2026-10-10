import Foundation

/// Picks a fresh set of shelf ranges for a new truck: four 1000-wide blocks, scattered across the
/// four-digit space so no two sit next to each other (a block ending at *1999 right next to one
/// starting at *2000 would read as one continuous range at a glance). Reused every time a truck
/// pulls out and the next one rolls in.
nonisolated enum RangeGenerator {
    /// The pool of thousands-blocks to choose from: `1...9` keeps every range's lower bound at
    /// `block * 1000` four digits (1000...9000), with `+999` for the upper bound staying in range.
    private static let blockPool = Array(1...9)

    /// The four shelf zones, in a fixed order so range assignment is deterministic for a given
    /// shuffle — only the shuffle itself (seeded by `rng`) varies.
    private static let shelfZones: [LoadZone] = [.shelf1000, .shelf2000, .shelf3000, .shelf4000]

    static func makeRanges(using rng: inout AnyRandomNumberGenerator) -> [LoadZone: ClosedRange<Int>] {
        let blocks = pickBlocks(using: &rng)
        return Dictionary(uniqueKeysWithValues: zip(shelfZones, blocks.map { $0 * 1000...($0 * 1000 + 999) }))
    }

    /// Repeatedly shuffles the pool and takes the first four until none of them are adjacent to
    /// one another. The pool is large relative to four picks, so this converges in a handful of
    /// tries in practice.
    private static func pickBlocks(using rng: inout AnyRandomNumberGenerator) -> [Int] {
        while true {
            let candidate = Array(blockPool.shuffled(using: &rng).prefix(4))
            if isWellSeparated(candidate) {
                return candidate
            }
        }
    }

    private static func isWellSeparated(_ blocks: [Int]) -> Bool {
        for i in blocks.indices {
            for j in blocks.indices where j > i {
                if abs(blocks[i] - blocks[j]) < 2 {
                    return false
                }
            }
        }
        return true
    }
}
