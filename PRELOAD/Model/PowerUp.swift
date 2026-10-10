import Foundation

/// What happens when a power-up box on the belt is tapped.
nonisolated enum PowerUpEffect: CaseIterable, Sendable {
    case slow
    case freeze
    case removeStrike

    var message: String {
        switch self {
        case .slow: return "BELT SLOWED"
        case .freeze: return "BELT FROZEN"
        case .removeStrike: return "STRIKE REMOVED"
        }
    }
}
