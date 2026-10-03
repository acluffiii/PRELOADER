import SwiftUI

/// Score, combo, strikes, and progress — pinned to the top of the shift.
struct HUDView: View {
    let engine: ShiftEngine

    var body: some View {
        HStack(spacing: 16) {
            Text("\(engine.score)")
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(.white)

            if engine.comboMultiplier > 1 {
                Text("x\(engine.comboMultiplier)")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.yellow, in: Capsule())
                    .foregroundStyle(.black)
            }

            Spacer()

            strikesView

            Spacer()

            Text("\(engine.loadedCount)/\(ScoreRules.packagesPerShift)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.55))
    }

    private var strikesView: some View {
        HStack(spacing: 5) {
            ForEach(0..<ScoreRules.maxStrikes, id: \.self) { index in
                Circle()
                    .fill(index < engine.strikes ? Color.red : Color.white.opacity(0.25))
                    .frame(width: 11, height: 11)
            }
        }
    }
}

/// A transient "+150 SNAP" / "STRIKE" / "DISCIPLINE" popup that fades in and back out.
struct FeedbackToastView: View {
    let event: FeedbackEvent?

    var body: some View {
        Group {
            if let event {
                Text(event.text)
                    .font(.headline.bold())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(color(for: event.kind), in: Capsule())
                    .foregroundStyle(.white)
                    .id(event.id)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: event?.id)
    }

    private func color(for kind: FeedbackEvent.Kind) -> Color {
        switch kind {
        case .success: .green
        case .mistake: .red
        case .discipline: .blue
        }
    }
}
