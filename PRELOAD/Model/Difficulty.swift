import Foundation

/// Player-chosen difficulty, set from the homepage options menu before a shift starts. Scales
/// the belt's base pace and how far the speed ramp can push it — everything else (scoring,
/// combos, strikes) stays identical across difficulties.
enum Difficulty: String, CaseIterable, Identifiable {
    case easy, normal, hard

    var id: String { rawValue }

    var label: String {
        switch self {
        case .easy: return "Easy"
        case .normal: return "Normal"
        case .hard: return "Hard"
        }
    }

    /// Scales `ScoreRules.baseBeltTravelTime` and `.baseSpawnInterval` — above 1 slows the belt
    /// and spawns down (easier), below 1 speeds them up (harder).
    var paceMultiplier: Double {
        switch self {
        case .easy: return 1.3
        case .normal: return 1.0
        case .hard: return 0.75
        }
    }
}
