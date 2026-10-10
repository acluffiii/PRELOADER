import SwiftUI

/// One running shift: the truck interior, the belt, every package currently in play, and the
/// HUD. Owns which package is currently selected (tapped off the belt, awaiting a shelf tap)
/// and drives the game loop.
struct ShiftView: View {
    let engine: ShiftEngine

    @State private var selectedPackageID: Package.ID?
    @State private var visibleEvent: FeedbackEvent?
    @State private var celebrationFlash = false
    @State private var strikeFlash = false

    /// Boxes currently mid-flight to a shelf as part of a Helper-button sweep, keyed by
    /// package id. While a box's id is a key here, `position(for:)` overrides its normal belt
    /// position with the shelf-stack target it's animating toward.
    @State private var helperFlights: [Package.ID: CGPoint] = [:]

    /// True while the pause menu is up — a view-only gate, separate from `engine.phase`, so the
    /// engine's own state (score, strikes, the belt) just freezes in place rather than needing
    /// its own "paused mid-run" phase.
    @State private var isPaused = false
    @State private var showingResetConfirm = false

    @AppStorage("preload.soundEnabled") private var soundEnabled = true
    @AppStorage("preload.hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("preload.bestScore") private var bestScore = 0

    /// A box currently airborne between the loader's hands and a shelf, rerun, or the roof.
    /// While this is set, further box/zone taps are ignored — see `handleZoneTap`.
    @State private var flight: BoxFlight?
    @State private var loaderPose: LoaderPose = .idle

    private struct BoxFlight {
        let packageID: Package.ID
        let target: CGPoint
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = TruckLayout(size: proxy.size)

            ZStack {
                TruckExteriorView(layout: layout)

                TruckInteriorView(
                    layout: layout,
                    loadedPackages: engine.loadedPackages,
                    shelfRanges: engine.shelfRanges,
                    isSelecting: selectedPackageID != nil && flight == nil,
                    onZoneTap: { zone in handleZoneTap(zone, layout: layout) }
                )

                LoaderFigure(pose: loaderPose, isFevered: engine.isFevered, height: layout.workerFrame.height)
                    .frame(width: layout.workerFrame.width, height: layout.workerFrame.height)
                    .position(x: layout.workerFrame.midX, y: layout.workerFrame.midY)

                ConveyorBeltView(
                    layout: layout,
                    beltDistance: engine.beltDistance,
                    isFevered: engine.isFevered,
                    isFrozen: engine.freezeRemaining > 0,
                    isSlowed: engine.slowRemaining > 0
                )

                ForEach(engine.beltPackages) { package in
                    PackageView(
                        package: package,
                        position: position(for: package, layout: layout),
                        engine: engine,
                        selectedPackageID: $selectedPackageID
                    )
                    .allowsHitTesting(flight?.packageID != package.id && helperFlights[package.id] == nil)
                }

                VStack {
                    HUDView(engine: engine, onPause: { isPaused = true }, onHelper: { triggerHelper(layout: layout) })
                    Spacer()
                    FeedbackToastView(event: visibleEvent)
                        .padding(.bottom, proxy.size.height - layout.beltRect.minY + 12)
                        .allowsHitTesting(false)
                }

                // A big, quick flash of gold across the whole screen for the one moment that's
                // bigger than an ordinary success — filling a shelf. Everything else (the
                // toast, the haptic, the chime) already covers the routine case.
                Color.yellow
                    .opacity(celebrationFlash ? 0.35 : 0)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()

                // An unmissable red pulse the instant a strike lands, on top of the toast and
                // the siren — the user wants a strike to be impossible to miss.
                Color.red
                    .opacity(strikeFlash ? 0.4 : 0)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()

                // The belt, the loader, and the HUD are all already in their resting state at
                // this point — this is just a scrim on top holding the player at the threshold
                // until they're ready, and it blocks taps on the zones behind it.
                if engine.phase == .paused {
                    pausedOverlay
                }

                if isPaused {
                    pauseMenuOverlay
                }
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .task { await runGameLoop() }
        .onChange(of: engine.lastEvent?.id) { _, _ in
            showToast(for: engine.lastEvent)
            playSound(for: engine.lastEvent)
        }
        .onChange(of: selectedPackageID) { oldValue, newValue in
            if newValue != nil && oldValue == nil {
                beginGrab()
            } else if newValue == nil && flight == nil {
                withAnimation(.spring(duration: 0.2)) { loaderPose = .idle }
            }
        }
        .sensoryFeedback(trigger: engine.lastEvent?.id) { _, _ in
            guard hapticsEnabled else { return nil }
            switch engine.lastEvent?.kind {
            case .success: return .success
            case .mistake: return .impact(weight: .heavy, intensity: 1.0)
            case .discipline: return .impact(weight: .light)
            case .shelfFull: return .impact(weight: .heavy, intensity: 1.0)
            case .powerUp: return .success
            case nil: return nil
            }
        }
    }

    /// Held over the truck before a truck's belt starts moving: a quick tutorial covering this
    /// truck's four shelf ranges plus reminders about rerun and roof packages, with a Start
    /// button. Shown both for the very first truck and every truck after one pulls out —
    /// `engine.truckJustCompleted` picks which copy to use.
    private var pausedOverlay: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()

            // Kept deliberately compact top-to-bottom — this has to fit comfortably in a
            // landscape phone's ~390pt height alongside everything else on screen.
            VStack(spacing: 8) {
                Text(engine.truckJustCompleted ? "TRUCK \(engine.truckNumber - 1) FULL!" : "SHIFT READY")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(
                    engine.truckJustCompleted
                        ? "Truck \(engine.truckNumber) rolled in with new ranges:"
                        : "Read the serial, load the right shelf:"
                )
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.85))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                    ForEach([LoadZone.shelf1000, .shelf3000, .shelf2000, .shelf4000], id: \.self) { zone in
                        if let range = SerialRules.range(for: zone, ranges: engine.shelfRanges) {
                            VStack(spacing: 0) {
                                Text(positionLabel(for: zone))
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.65))
                                // Plain `String(Int)` rather than Text's locale-formatted
                                // interpolation — a shelf range should read "9400–9499", not
                                // "9,400–9,499".
                                Text("\(String(range.lowerBound))–\(String(range.upperBound))")
                                    .font(.system(.callout, design: .monospaced).bold())
                            }
                        }
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: 300)
                .padding(8)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

                HStack(spacing: 14) {
                    Label("No label → RERUN", systemImage: "arrow.down.square")
                    Label("Airplane → ROOF", systemImage: "airplane")
                }
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))

                Button {
                    engine.beginRunning()
                } label: {
                    Text("Start")
                        .font(.headline.bold())
                        .padding(.horizontal, 26)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .padding(12)
        }
    }

    /// "Upper Left" / "Lower Right" etc. — the shelf's fixed screen position, since the enum
    /// case name (`shelf1000`) no longer matches the actual range stenciled there once ranges
    /// rotate every truck.
    private func positionLabel(for zone: LoadZone) -> String {
        switch zone {
        case .shelf1000: return "Upper Left"
        case .shelf2000: return "Lower Left"
        case .shelf3000: return "Upper Right"
        case .shelf4000: return "Lower Right"
        case .rerun, .roof: return ""
        }
    }

    /// The in-run pause menu: resume, restart this truck, or quit to the results screen, plus
    /// sound/haptics toggles and a reset for the saved best score.
    private var pauseMenuOverlay: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()

            VStack(spacing: 16) {
                Text("PAUSED")
                    .font(.system(size: 28, weight: .black, design: .rounded))

                Button {
                    isPaused = false
                } label: {
                    Text("Resume").font(.title3.bold()).frame(maxWidth: 220)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

                Button {
                    engine.restartTruck()
                    selectedPackageID = nil
                    flight = nil
                    loaderPose = .idle
                    isPaused = false
                } label: {
                    Text("Restart Truck").frame(maxWidth: 220)
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    engine.quitRun()
                    isPaused = false
                } label: {
                    Text("Quit").frame(maxWidth: 220)
                }
                .buttonStyle(.bordered)

                Divider().frame(maxWidth: 240)

                Toggle("Sound", isOn: $soundEnabled).frame(maxWidth: 240)
                Toggle("Haptics", isOn: $hapticsEnabled).frame(maxWidth: 240)

                Button("Reset Best Score") {
                    showingResetConfirm = true
                }
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
            }
            .padding(24)
            .foregroundStyle(.white)
            .tint(.white)
        }
        .confirmationDialog("Reset your best score?", isPresented: $showingResetConfirm, titleVisibility: .visible) {
            Button("Reset Best Score", role: .destructive) { bestScore = 0 }
            Button("Cancel", role: .cancel) {}
        }
    }

    /// Where to draw a belt package: wherever it's flying to, the loader's hands if it's held,
    /// or its ordinary belt position otherwise.
    private func position(for package: Package, layout: TruckLayout) -> CGPoint {
        if let target = helperFlights[package.id] {
            return target
        }
        if let flight, flight.packageID == package.id {
            return flight.target
        }
        if selectedPackageID == package.id {
            return layout.handsPosition
        }
        return layout.beltPosition(progress: package.beltProgress)
    }

    /// A quick crouch-and-reach the instant a box is grabbed, settling into a hold once the
    /// box has had time to arrive in his hands. Guarded by the pose check so a zone tap (or a
    /// cancel) that lands before the reach finishes isn't stomped by this delayed step.
    private func beginGrab() {
        withAnimation(.spring(duration: 0.18)) { loaderPose = .reaching }
        Task {
            try? await Task.sleep(for: .milliseconds(120))
            if loaderPose == .reaching {
                withAnimation(.spring(duration: 0.2)) { loaderPose = .holding }
            }
        }
    }

    /// A stall — a dropped frame, the app backgrounding, a debugger pause, UI-automation
    /// overhead during testing — must not let the belt "catch up" by fast-forwarding however
    /// much real time actually passed. Capping the delta turns a multi-second stall into a
    /// brief visible hitch instead of an instant, unwinnable pile of runoff strikes.
    private static let maxTickDelta: Double = 0.1

    /// Advances the belt roughly 60 times a second for as long as this view is on screen —
    /// which includes the paused "ready to start" moment, so `last` doesn't fall behind and
    /// produce a runoff-spawning delta spike the instant the player taps Start. `engine.tick`
    /// itself is a no-op while paused, so there's nothing to gate here beyond the view-only
    /// `isPaused` pause-menu gate, which stops calling `tick` entirely while it's up.
    ///
    /// Skipped entirely under Xcode's live Preview canvas: a Preview only ever needs one static
    /// snapshot, and this loop's sustained 60fps ticking (plus the flurry of short-lived Tasks
    /// it drives — grabs, tosses, toasts) has reproducibly crashed Previews' own JIT execution
    /// runtime (`PreviewsInjection`/`XOJITExecutor`) when a gameplay preview is left running live
    /// for a while. A real Run is unaffected — `XCODE_RUNNING_FOR_PREVIEWS` is never set there.
    private func runGameLoop() async {
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }

        let clock = ContinuousClock()
        var last = clock.now
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(16))
            let now = clock.now
            let delta = min(last.duration(to: now).seconds, Self.maxTickDelta)
            if !isPaused {
                engine.tick(delta: delta)
            }
            last = now
        }
    }

    /// A shelf, rerun, or the roof was tapped. If nothing is held, or a box is already mid-toss,
    /// this is a no-op. Otherwise the held box flies from the loader's hands to wherever it
    /// would land on that zone, he leans and reaches toward it, and only once it arrives does
    /// this actually resolve the drop with the engine — right or wrong zone alike.
    private func handleZoneTap(_ zone: LoadZone, layout: TruckLayout) {
        guard flight == nil, let id = selectedPackageID else { return }

        let target = layout.stackPosition(in: zone, index: engine.loadedPackages[zone]?.count ?? 0)
        let isHigh = zone == .shelf1000 || zone == .shelf3000 || zone == .roof
        let towardLeft = target.x < layout.size.width / 2

        withAnimation(.spring(duration: 0.3)) {
            flight = BoxFlight(packageID: id, target: target)
            loaderPose = .tossing(towardLeft: towardLeft, high: isHigh)
        }

        Task {
            try? await Task.sleep(for: .milliseconds(300))
            engine.drop(id: id, in: zone)
            flight = nil
            selectedPackageID = nil
            withAnimation(.spring(duration: 0.2)) { loaderPose = .idle }
        }
    }

    /// The Helper button: any currently-held box is dropped back onto the belt first so it
    /// gets swept up too, then every sortable box on the belt flies to its shelf together.
    /// `engine.beginHelper()` does the bookkeeping and hands back where each box is headed;
    /// this just animates them there before telling the engine to actually resolve the loads.
    private func triggerHelper(layout: TruckLayout) {
        guard helperFlights.isEmpty else { return }
        if let id = selectedPackageID {
            engine.drop(id: id, in: nil)
            selectedPackageID = nil
            flight = nil
            loaderPose = .idle
        }

        let assignments = engine.beginHelper()
        guard !assignments.isEmpty else { return }

        var targets: [Package.ID: CGPoint] = [:]
        var addedPerZone: [LoadZone: Int] = [:]
        for assignment in assignments {
            let index = (engine.loadedPackages[assignment.zone]?.count ?? 0) + (addedPerZone[assignment.zone] ?? 0)
            addedPerZone[assignment.zone, default: 0] += 1
            targets[assignment.id] = layout.stackPosition(in: assignment.zone, index: index)
        }

        withAnimation(.spring(duration: 0.4)) {
            helperFlights = targets
        }

        Task {
            try? await Task.sleep(for: .milliseconds(400))
            engine.finishHelper(ids: assignments.map(\.id))
            helperFlights = [:]
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

        if event.kind == .shelfFull {
            withAnimation(.easeOut(duration: 0.1)) { celebrationFlash = true }
            Task {
                try? await Task.sleep(for: .milliseconds(220))
                withAnimation(.easeIn(duration: 0.3)) { celebrationFlash = false }
            }
        } else if event.kind == .mistake {
            Task { await pulseStrikeFlash() }
        }
    }

    /// Two quick red pulses rather than one steady flash — reads as an alarm instead of a
    /// screen tint, matching the siren it plays alongside.
    private func pulseStrikeFlash() async {
        for _ in 0..<2 {
            withAnimation(.easeOut(duration: 0.08)) { strikeFlash = true }
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.easeIn(duration: 0.15)) { strikeFlash = false }
            try? await Task.sleep(for: .milliseconds(150))
        }
    }

    private func playSound(for event: FeedbackEvent?) {
        guard soundEnabled, let event else { return }
        switch event.kind {
        case .success: SoundEngine.shared.playSuccess()
        case .mistake:
            SoundEngine.shared.playStrike()
            SoundEngine.shared.playSiren()
        case .discipline: SoundEngine.shared.playDiscipline()
        case .shelfFull: SoundEngine.shared.playShelfFull()
        case .powerUp: SoundEngine.shared.playPowerUp()
        }
    }
}

#Preview("Shift in progress", traits: .fixedLayout(width: 844, height: 390)) {
    let engine = ShiftEngine()
    engine.startShift()
    engine.beginRunning()
    return ShiftView(engine: engine)
}

#Preview("Shift paused", traits: .fixedLayout(width: 844, height: 390)) {
    let engine = ShiftEngine()
    engine.startShift()
    return ShiftView(engine: engine)
}
