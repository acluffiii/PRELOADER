import Foundation

nonisolated extension Duration {
    /// This duration expressed as a plain `Double` number of seconds, for display and for
    /// feeding into the game loop's frame delta.
    var seconds: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
