import Foundation

/// A place inside the truck where a package can be loaded.
nonisolated enum LoadZone: String, CaseIterable, Identifiable, Equatable, Sendable {
    case shelf1000
    case shelf2000
    case shelf3000
    case shelf4000
    case floor

    var id: String { rawValue }

    /// The number stenciled on the shelf, or nil for the floor.
    var shelfLabel: String? {
        switch self {
        case .shelf1000: return "1000"
        case .shelf2000: return "2000"
        case .shelf3000: return "3000"
        case .shelf4000: return "4000"
        case .floor: return nil
        }
    }

    /// Whether this zone is one of the four wall shelves (as opposed to the floor).
    var isShelf: Bool { self != .floor }
}
