import Foundation

/// A place inside the truck where a package can be loaded.
nonisolated enum LoadZone: String, CaseIterable, Identifiable, Equatable, Sendable {
    case shelf1000
    case shelf2000
    case shelf3000
    case shelf4000
    /// Below the belt: where unlabeled packages go until their serial can be read on a later
    /// pass. Stacks like a shelf, but isn't one — it never triggers the "shelf full" celebration.
    case rerun
    /// The small back wall the truck converges toward: where air packages (airplane icon, no
    /// serial) go. Also not a "shelf" for celebration purposes.
    case roof

    var id: String { rawValue }

    /// Whether this zone is one of the four wall shelves — the only zones that trigger the
    /// "shelf full" celebration bonus. `rerun` and `roof` both accept drops and stack boxes, but
    /// neither counts toward completing a truck.
    var isShelf: Bool {
        switch self {
        case .shelf1000, .shelf2000, .shelf3000, .shelf4000: return true
        case .rerun, .roof: return false
        }
    }
}
