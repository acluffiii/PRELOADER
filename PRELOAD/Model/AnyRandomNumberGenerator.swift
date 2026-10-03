import Foundation

/// Type-erases a `RandomNumberGenerator` so it can be stored as a property and still be passed
/// into generic stdlib APIs like `Int.random(in:using:)`, which require a concrete conforming type.
nonisolated final class AnyRandomNumberGenerator: RandomNumberGenerator {
    private var base: RandomNumberGenerator

    init(_ base: RandomNumberGenerator = SystemRandomNumberGenerator()) {
        self.base = base
    }

    func next() -> UInt64 {
        base.next()
    }
}
