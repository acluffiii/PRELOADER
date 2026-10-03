import SwiftUI

/// The post-shift report: final score and rank, the loaded/misloaded/missed/touched breakdown,
/// and the decision-time vs. move-time split that tells a player whether they're slow to read
/// or slow to move.
struct ResultsView: View {
    let engine: ShiftEngine

    @AppStorage("preload.bestScore") private var bestScore = 0

    private var totalResolved: Int {
        engine.loadedCount + engine.misloadCount + engine.forbiddenTouchCount + engine.missedCount
    }

    private var accuracy: Double {
        totalResolved > 0 ? Double(engine.loadedCount) / Double(totalResolved) : 0
    }

    private var packagesPerHour: Double {
        guard let start = engine.shiftStartedAt, let end = engine.shiftEndedAt else { return 0 }
        let hours = start.duration(to: end).seconds / 3600
        return hours > 0 ? Double(engine.loadedCount) / hours : 0
    }

    private var averageDecisionSeconds: Double { average(of: engine.decisionTimes) }
    private var averageMoveSeconds: Double { average(of: engine.moveTimes) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("SHIFT COMPLETE")
                    .font(.system(size: 32, weight: .black, design: .rounded))

                Text(ScoreRules.rank(forScore: engine.score))
                    .font(.title3.bold())
                    .foregroundStyle(.yellow)

                statGrid
                    .frame(maxWidth: 420)

                Button {
                    engine.startShift()
                } label: {
                    Text("Run It Again")
                        .font(.title3.bold())
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .ignoresSafeArea()
        .onAppear {
            bestScore = max(bestScore, engine.score)
        }
    }

    private var statGrid: some View {
        VStack(spacing: 10) {
            statRow("Score", "\(engine.score)")
            statRow("Best Score", "\(max(bestScore, engine.score))")
            statRow("Packages / Hour", String(format: "%.0f", packagesPerHour))
            Divider().background(Color.white.opacity(0.2))
            statRow("Loaded", "\(engine.loadedCount)")
            statRow("Misloaded", "\(engine.misloadCount)")
            statRow("Missed", "\(engine.missedCount)")
            statRow("Wrong-Truck Touches", "\(engine.forbiddenTouchCount)")
            statRow("Accuracy", String(format: "%.0f%%", accuracy * 100))
            statRow("Best Streak", "\(engine.bestCombo)")
            Divider().background(Color.white.opacity(0.2))
            statRow("Avg. Decision Time (reading)", String(format: "%.2fs", averageDecisionSeconds))
            statRow("Avg. Move Time (hands)", String(format: "%.2fs", averageMoveSeconds))
        }
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.white.opacity(0.65))
            Spacer()
            Text(value).fontWeight(.semibold).monospacedDigit()
        }
    }

    private func average(of durations: [Duration]) -> Double {
        guard !durations.isEmpty else { return 0 }
        return durations.reduce(0.0) { $0 + $1.seconds } / Double(durations.count)
    }
}
