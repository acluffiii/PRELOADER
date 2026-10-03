import Foundation

/// All of the game's tuning knobs in one place, so difficulty can be adjusted later without
/// hunting through the engine or view code.
nonisolated enum ScoreRules {
    // MARK: Scoring

    /// Points for any correctly loaded package.
    static let correctLoadPoints = 100

    /// Drop the package on its shelf within this long of it spawning to earn the "SNAP" bonus.
    static let snapThreshold: Duration = .milliseconds(1500)
    static let snapBonus = 100

    /// Drop the package on its shelf within this long of it spawning to earn the "CLEAN" bonus.
    static let cleanThreshold: Duration = .seconds(3)
    static let cleanBonus = 50

    /// Reward for leaving a "do not touch" package alone as it rides off the belt.
    static let disciplinePoints = 25

    /// Combo streak lengths at which the score multiplier increases.
    static let comboMultiplierSteps: [(streak: Int, multiplier: Int)] = [
        (20, 4), (10, 3), (5, 2),
    ]

    static func multiplier(forCombo combo: Int) -> Int {
        for step in comboMultiplierSteps where combo >= step.streak {
            return step.multiplier
        }
        return 1
    }

    // MARK: Shift pacing

    /// Strikes that end a shift: wrong shelf, touching a "do not touch" box, or a good box
    /// running off the belt untouched.
    static let maxStrikes = 3

    /// Total packages spawned before the shift winds down.
    static let packagesPerShift = 40

    /// Seconds of belt travel from spawn to the end of the belt, before any speed-up.
    static let baseBeltTravelTime: Double = 7.0

    /// Seconds between spawns, before any speed-up.
    static let baseSpawnInterval: Double = 1.8

    /// Belt travel time and spawn interval both shrink by this fraction per correct load,
    /// down to the floor multiplier below.
    static let rampPerLoad: Double = 0.985
    static let rampFloorMultiplier: Double = 0.55

    // MARK: Ranks

    /// Score thresholds for the results-screen rank title, checked highest first.
    private static let rankThresholds: [(score: Int, title: String)] = [
        (6000, "Hub Legend"),
        (3000, "Lead Loader"),
        (1000, "Preloader"),
    ]

    static func rank(forScore score: Int) -> String {
        for threshold in rankThresholds where score >= threshold.score {
            return threshold.title
        }
        return "Seasonal Helper"
    }
}
