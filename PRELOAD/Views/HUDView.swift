import SwiftUI

/// Score, combo, strikes, and progress — pinned to the top of the shift. A thin meter under
/// the row fills toward the next combo tier, and the whole bar glows once the streak reaches
/// fever.
struct HUDView: View {
    let engine: ShiftEngine
    /// Called when the pause button is tapped. Visually covered (and so effectively unreachable)
    /// whenever the pre-truck tutorial overlay is up, since that overlay already blocks taps.
    var onPause: () -> Void = {}
    /// Called when the Helper button is tapped. The button disables itself once
    /// `engine.helperUsesRemaining` hits 0, so this is only ever called when a use is available.
    var onHelper: () -> Void = {}

    @State private var comboPulse = false
    @State private var feverPulse = false

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 16) {
                Text("\(engine.score)")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(.white)

                if engine.comboMultiplier > 1 {
                    HStack(spacing: 5) {
                        Text("x\(engine.comboMultiplier)")
                            .font(.subheadline.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.yellow, in: Capsule())
                            .foregroundStyle(.black)

                        if engine.isFevered {
                            Text("FEVER")
                                .font(.caption2.bold())
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(feverGradient, in: Capsule())
                                .foregroundStyle(.white)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .scaleEffect(comboPulse ? 1.3 : 1.0)
                    .animation(.bouncy(duration: 0.3), value: engine.comboMultiplier)
                    .animation(.bouncy(duration: 0.3), value: engine.isFevered)
                    .onChange(of: engine.comboMultiplier) {
                        comboPulse = true
                        Task {
                            try? await Task.sleep(for: .milliseconds(150))
                            comboPulse = false
                        }
                    }
                }

                Spacer()

                if engine.isPracticeMode {
                    Text("PRACTICE")
                        .font(.caption2.bold())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.2), in: Capsule())
                        .foregroundStyle(.white.opacity(0.85))
                } else {
                    strikesView
                }

                activeEffectChip

                Spacer()

                Text("TRUCK \(engine.truckNumber)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white.opacity(0.85))

                helperButton

                Button(action: onPause) {
                    Image(systemName: "pause.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }

            comboMeter
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            // Purely decorative — but a solid Color fill, unlike the plain Spacers it sits
            // behind, *is* hit-testable across its whole rectangle by default. Left enabled,
            // this bar swallowed every tap in its band clean across the screen width, including
            // the top of the roof/AIR zone drawn underneath it — explicitly disabled so those
            // taps pass through to whatever's actually behind the bar. The pause button above
            // keeps its own tap target regardless, since button hit-testing doesn't depend on
            // a sibling's `allowsHitTesting`.
            ZStack {
                Color.black.opacity(0.55)
                if engine.isFevered {
                    feverGradient.opacity(0.25)
                }
            }
            .allowsHitTesting(false)
        }
        .overlay(alignment: .bottom) {
            if engine.isFevered {
                Rectangle()
                    .fill(feverGradient)
                    .frame(height: 3)
                    .shadow(color: .orange, radius: feverPulse ? 8 : 2)
                    .allowsHitTesting(false)
            }
        }
        .task(id: engine.isFevered) {
            if engine.isFevered {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    feverPulse = true
                }
            } else {
                withAnimation(.easeInOut(duration: 0.2)) { feverPulse = false }
            }
        }
    }

    /// Flies every sortable box on the belt to its shelf — a once-a-truck bailout for falling
    /// behind. Greys out once `helperUsesRemaining` hits 0, and refills when the next truck
    /// rolls in.
    private var helperButton: some View {
        Button(action: onHelper) {
            VStack(spacing: 0) {
                Image(systemName: "hand.raised.fill")
                    .font(.title3)
                Text("\(engine.helperUsesRemaining)")
                    .font(.caption2.bold())
            }
            .foregroundStyle(.white.opacity(isHelperEnabled ? 0.9 : 0.3))
        }
        .disabled(!isHelperEnabled)
    }

    private var isHelperEnabled: Bool {
        engine.phase == .running && engine.helperUsesRemaining > 0
    }

    /// A countdown chip for whichever power-up effect is currently active — freeze takes
    /// priority since `engine.beltSpeedFactor` treats it the same way. Renders nothing when
    /// neither is active.
    @ViewBuilder
    private var activeEffectChip: some View {
        if engine.freezeRemaining > 0 {
            effectChip(systemImage: "snowflake", seconds: engine.freezeRemaining, color: .cyan)
        } else if engine.slowRemaining > 0 {
            effectChip(systemImage: "tortoise.fill", seconds: engine.slowRemaining, color: .purple)
        }
    }

    private func effectChip(systemImage: String, seconds: Double, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
            Text("\(Int(seconds.rounded(.up)))s")
        }
        .font(.caption.bold())
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(color.opacity(0.4), in: Capsule())
        .foregroundStyle(.white)
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

    /// Fills toward the next combo tier; climbs within a tier, resets at each boundary, and
    /// caps full once the top tier is reached.
    private var comboMeter: some View {
        GeometryReader { proxy in
            let progress = ScoreRules.comboProgress(forCombo: engine.combo)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.15))
                Capsule()
                    .fill(engine.isFevered ? AnyShapeStyle(feverGradient) : AnyShapeStyle(Color.yellow.opacity(0.85)))
                    .frame(width: proxy.size.width * progress)
            }
            .allowsHitTesting(false)
        }
        .frame(height: 4)
        .animation(.easeOut(duration: 0.2), value: engine.combo)
    }

    private var feverGradient: LinearGradient {
        LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
    }
}

/// A transient "+150 SNAP" / "STRIKE" / "DISCIPLINE" popup that fades in and back out.
struct FeedbackToastView: View {
    let event: FeedbackEvent?

    var body: some View {
        Group {
            if let event {
                let isShelfFull = event.kind == .shelfFull
                Text(event.text)
                    .font(isShelfFull ? .title2.bold() : .headline.bold())
                    .padding(.horizontal, isShelfFull ? 20 : 14)
                    .padding(.vertical, isShelfFull ? 12 : 8)
                    .background(background(for: event.kind), in: Capsule())
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(isShelfFull ? 0.4 : 0), radius: 8, y: 4)
                    .id(event.id)
                    .transition(.scale(scale: isShelfFull ? 1.4 : 0.7).combined(with: .opacity))
            }
        }
        .animation(.bouncy(duration: 0.35), value: event?.id)
    }

    private func background(for kind: FeedbackEvent.Kind) -> AnyShapeStyle {
        switch kind {
        case .success: AnyShapeStyle(Color.green)
        case .mistake: AnyShapeStyle(Color.red)
        case .discipline: AnyShapeStyle(Color.blue)
        case .shelfFull: AnyShapeStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing))
        case .powerUp: AnyShapeStyle(LinearGradient(colors: [.purple, .cyan], startPoint: .leading, endPoint: .trailing))
        }
    }
}
