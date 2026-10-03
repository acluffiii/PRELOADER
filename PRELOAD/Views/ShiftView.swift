import SwiftUI

/// One running shift: the truck interior, the belt, every package currently in play, and the
/// HUD. Owns the drag-shared "which zone is glowing" state and drives the game loop.
struct ShiftView: View {
    let engine: ShiftEngine

    @State private var hoveredZone: LoadZone?
    @State private var visibleEvent: FeedbackEvent?

    var body: some View {
        GeometryReader { proxy in
            let layout = TruckLayout(size: proxy.size)

            ZStack {
                TruckInteriorView(layout: layout, loadedPackages: engine.loadedPackages, hoveredZone: hoveredZone)
                ConveyorBeltView(layout: layout, beltDistance: engine.beltDistance)

                ForEach(engine.beltPackages) { package in
                    PackageView(package: package, layout: layout, engine: engine, hoveredZone: $hoveredZone)
                }

                VStack {
                    HUDView(engine: engine)
                    Spacer()
                    FeedbackToastView(event: visibleEvent)
                        .padding(.bottom, layout.beltRect.height + 12)
                        .allowsHitTesting(false)
                }
            }
            .coordinateSpace(.named("truck"))
        }
        .background(Color.black)
        .ignoresSafeArea()
        .task { await runGameLoop() }
        .onChange(of: engine.lastEvent?.id) { _, _ in
            showToast(for: engine.lastEvent)
        }
        .sensoryFeedback(trigger: engine.lastEvent?.id) { _, _ in
            switch engine.lastEvent?.kind {
            case .success: .success
            case .mistake: .error
            case .discipline: .impact(weight: .light)
            case nil: nil
            }
        }
    }

    /// A stall — a dropped frame, the app backgrounding, a debugger pause, UI-automation
    /// overhead during testing — must not let the belt "catch up" by fast-forwarding however
    /// much real time actually passed. Capping the delta turns a multi-second stall into a
    /// brief visible hitch instead of an instant, unwinnable pile of runoff strikes.
    private static let maxTickDelta: Double = 0.1

    /// Advances the belt roughly 60 times a second until the shift ends. No `TimelineView` —
    /// that would mean mutating observable state from inside a view's `body`.
    private func runGameLoop() async {
        let clock = ContinuousClock()
        var last = clock.now
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(16))
            guard engine.phase == .running else { break }
            let now = clock.now
            let delta = min(last.duration(to: now).seconds, Self.maxTickDelta)
            engine.tick(delta: delta)
            last = now
        }
    }

    private func showToast(for event: FeedbackEvent?) {
        visibleEvent = event
        guard let event else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(1100))
            if visibleEvent?.id == event.id {
                withAnimation { visibleEvent = nil }
            }
        }
    }
}

#Preview("Shift in progress", traits: .fixedLayout(width: 844, height: 390)) {
    let engine = ShiftEngine()
    engine.startShift()
    return ShiftView(engine: engine)
}

