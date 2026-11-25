import SwiftUI

/// The cardboard-box look shared by every package, whether it's riding the belt, held,
/// in flight, or already stacked on a shelf. Drawn as a flat 3/4 box (top, front, side) inside
/// the same footprint the belt and shelves already use, so hit targets don't move.
///
/// Special types stay readable at a glance:
/// - a shelf box and a "do not touch" box both wear a large monospaced serial — telling them
///   apart is the read (near-miss digits and look-alike letters), so the sticker itself is
///   the same on purpose
/// - an unlabeled box has an empty dashed slot instead of a sticker
/// - an air box has a sky-blue tape band and an airplane, and no serial
/// - a power-up keeps its bolt and a pulsing edge, without a blurred glow
struct BoxArtwork: View {
    let package: Package
    var isLifted: Bool = false

    /// Drives the power-up edge pulse — irrelevant (and never animated) for an ordinary box.
    @State private var powerUpPulse = false

    var body: some View {
        let baseFootprint = package.size.footprint
        let footprint = CGSize(width: baseFootprint.width * DeviceScale.text, height: baseFootprint.height * DeviceScale.text)
        let metrics = BoxMetrics(size: footprint)

        ZStack {
            Canvas { context, size in
                let metrics = BoxMetrics(size: size)
                let paint = BoxPaint(package: package)
                drawBox(in: &context, metrics: metrics, paint: paint)
            }

            label(in: metrics, footprint: footprint)

            if package.isPowerUp {
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(Color.white.opacity(powerUpPulse ? 0.95 : 0.4), lineWidth: 2)
                    .frame(width: metrics.front.width, height: metrics.front.height)
                    .position(x: metrics.front.midX, y: metrics.front.midY)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: footprint.width, height: footprint.height)
        .scaleEffect(isLifted ? 1.08 : 1.0)
        .task(id: package.isPowerUp) {
            guard package.isPowerUp else { return }
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                powerUpPulse = true
            }
        }
    }

    @ViewBuilder
    private func label(in metrics: BoxMetrics, footprint: CGSize) -> some View {
        let labelY = metrics.front.minY + metrics.front.height * 0.66
        if package.isPowerUp {
            Image(systemName: "bolt.fill")
                .font(.system(size: max(14, metrics.front.height * 0.5), weight: .heavy))
                .foregroundStyle(.white)
                .position(x: metrics.front.midX, y: metrics.front.midY)
        } else if package.isAirPackage {
            Image(systemName: "airplane")
                .font(.system(size: max(14, metrics.front.height * 0.48), weight: .heavy))
                .foregroundStyle(.black)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 2))
                .position(x: metrics.front.midX, y: labelY)
        } else if let serial = package.serial {
            // Same size rule as before — keyed off the full footprint, not the smaller front
            // face, so the serial stays the largest thing on the box.
            let serialFontSize = max(12, footprint.height * 0.34)
            Text(serial)
                .font(.system(size: serialFontSize, weight: .heavy, design: .monospaced))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 2))
                .frame(maxWidth: metrics.front.width * 0.92)
                .position(x: metrics.front.midX, y: labelY)
        } else {
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.white.opacity(0.7), style: StrokeStyle(lineWidth: 1.25, dash: [3, 2]))
                .frame(width: metrics.front.width * 0.72, height: max(12, metrics.front.height * 0.42))
                .position(x: metrics.front.midX, y: labelY)
        }
    }

    private func drawBox(in context: inout GraphicsContext, metrics: BoxMetrics, paint: BoxPaint) {
        let front = metrics.front
        let side = metrics.side
        let rise = metrics.rise

        var sidePath = Path()
        sidePath.move(to: CGPoint(x: front.maxX, y: front.minY))
        sidePath.addLine(to: CGPoint(x: front.maxX + side, y: front.minY - rise))
        sidePath.addLine(to: CGPoint(x: front.maxX + side, y: front.maxY - rise))
        sidePath.addLine(to: CGPoint(x: front.maxX, y: front.maxY))
        sidePath.closeSubpath()

        var topPath = Path()
        topPath.move(to: CGPoint(x: front.minX, y: front.minY))
        topPath.addLine(to: CGPoint(x: front.maxX, y: front.minY))
        topPath.addLine(to: CGPoint(x: front.maxX + side, y: front.minY - rise))
        topPath.addLine(to: CGPoint(x: front.minX + side, y: front.minY - rise))
        topPath.closeSubpath()

        let frontPath = Path(front)
        context.fill(sidePath, with: .color(paint.side))
        context.fill(topPath, with: .color(paint.top))
        context.fill(frontPath, with: .color(paint.front))

        // A darker lip along the bottom of the front face, in place of a per-box shadow.
        let lip = CGRect(x: front.minX, y: front.maxY - front.height * 0.14, width: front.width, height: front.height * 0.14)
        context.fill(Path(lip), with: .color(paint.frontShade))

        if !paint.hidesTape {
            let tapeW = max(3, front.width * 0.16)
            let tape = CGRect(x: front.midX - tapeW / 2, y: front.minY, width: tapeW, height: front.height * 0.32)
            context.fill(Path(tape), with: .color(paint.tape))

            let t0 = (tape.minX - front.minX) / front.width
            let t1 = (tape.maxX - front.minX) / front.width
            func topPoint(_ t: CGFloat, back: CGFloat) -> CGPoint {
                let xFront = front.minX + front.width * t
                let xBack = front.minX + side + (front.width) * t
                let yFront = front.minY
                let yBack = front.minY - rise
                return CGPoint(
                    x: xFront + (xBack - xFront) * back,
                    y: yFront + (yBack - yFront) * back
                )
            }
            var topTape = Path()
            topTape.move(to: topPoint(t0, back: 0))
            topTape.addLine(to: topPoint(t1, back: 0))
            topTape.addLine(to: topPoint(t1, back: 0.92))
            topTape.addLine(to: topPoint(t0, back: 0.92))
            topTape.closeSubpath()
            context.fill(topTape, with: .color(paint.tape))
        }

        let edge = GraphicsContext.Shading.color(.black.opacity(0.28))
        context.stroke(frontPath, with: edge, lineWidth: 1)
        context.stroke(topPath, with: edge, lineWidth: 1)
        context.stroke(sidePath, with: edge, lineWidth: 1)
    }
}

/// Cabinet-projection inset that keeps the whole box inside `size`.
private struct BoxMetrics {
    var side: CGFloat
    var rise: CGFloat
    var front: CGRect

    init(size: CGSize) {
        let depth = min(size.width, size.height)
        side = depth * 0.15
        rise = depth * 0.18
        front = CGRect(x: 0, y: rise, width: max(1, size.width - side), height: max(1, size.height - rise))
    }
}

private struct BoxPaint {
    var top: Color
    var front: Color
    var frontShade: Color
    var side: Color
    var tape: Color
    var hidesTape: Bool

    init(package: Package) {
        if package.isPowerUp {
            top = Color(red: 0.55, green: 0.85, blue: 0.95)
            front = Color(red: 0.42, green: 0.22, blue: 0.72)
            frontShade = Color(red: 0.28, green: 0.12, blue: 0.48)
            side = Color(red: 0.24, green: 0.10, blue: 0.42)
            tape = .clear
            hidesTape = true
        } else if package.isAirPackage {
            top = ArtPalette.boxTop
            front = ArtPalette.boxFront
            frontShade = ArtPalette.boxFrontShade
            side = ArtPalette.boxSide
            tape = ArtPalette.airTape
            hidesTape = false
        } else {
            top = ArtPalette.boxTop
            front = ArtPalette.boxFront
            frontShade = ArtPalette.boxFrontShade
            side = ArtPalette.boxSide
            tape = ArtPalette.tape
            hidesTape = false
        }
    }
}

/// A tappable package riding the belt: tap it to pick it up, then tap a shelf or the floor to
/// send it there. Deliberately tap-only (no drag) — a drag gesture here fights with the
/// system's edge-swipe gestures in landscape (the app-switcher swipe-up), so picking up and
/// placing a box is always two discrete taps.
struct PackageView: View {
    let package: Package
    /// Where to draw this box, decided by the parent: the belt, the loader's hands, or
    /// (while being tossed) wherever it's currently flying to.
    let position: CGPoint
    let engine: ShiftEngine
    @Binding var selectedPackageID: Package.ID?
    /// True while this box is animating from the hands (or the belt, for a Helper sweep) to a
    /// shelf. Visual only — the drop still resolves at `position`'s target.
    var isAirborne: Bool = false
    var airborneDuration: Double = 0.3

    @State private var isBlockedFlash = false
    @State private var arcProgress: CGFloat = 0

    private var isSelected: Bool { selectedPackageID == package.id }

    var body: some View {
        let lift = CGFloat(sin(Double(arcProgress) * Double.pi))
        BoxArtwork(package: package, isLifted: isSelected)
            .overlay {
                if isSelected {
                    ZStack {
                        RoundedRectangle(cornerRadius: 2).fill(Color.green.opacity(0.28))
                        RoundedRectangle(cornerRadius: 2).strokeBorder(Color.green, lineWidth: 2)
                    }
                } else if isBlockedFlash {
                    RoundedRectangle(cornerRadius: 2).fill(Color.red.opacity(0.35))
                }
            }
            .animation(.easeInOut(duration: 0.15), value: isSelected)
            .offset(y: -lift * 26)
            .scaleEffect(x: 1 - lift * 0.04, y: 1 + lift * 0.07)
            .position(position)
            .zIndex(isSelected ? 1000 : 0)
            .onTapGesture(perform: handleTap)
            .onChange(of: isAirborne) { _, flying in
                guard flying else {
                    var reset = Transaction()
                    reset.disablesAnimations = true
                    withTransaction(reset) { arcProgress = 0 }
                    return
                }
                arcProgress = 0
                withAnimation(.easeInOut(duration: airborneDuration)) {
                    arcProgress = 1
                }
            }
    }

    /// Tapping the selected box again drops it back on the belt (no penalty); tapping an
    /// unselected box picks it up, unless something else is already held, in which case the
    /// tap is ignored — the player must finish or cancel the current pick-up first. Both the
    /// pick-up and the drop-back-to-belt are animated, so the box visibly hops to and from the
    /// loader's hands rather than snapping.
    private func handleTap() {
        if isSelected {
            withAnimation(.spring(duration: 0.25)) {
                engine.drop(id: package.id, in: nil)
                selectedPackageID = nil
            }
            return
        }
        guard selectedPackageID == nil else { return }
        if engine.grab(id: package.id) {
            withAnimation(.spring(duration: 0.25)) {
                selectedPackageID = package.id
            }
        } else if !package.isPowerUp {
            // A power-up tap also makes `grab` return false, but it already did its job
            // (the engine applied the effect and removed the box) — not a blocked attempt.
            flashBlocked()
        }
    }

    private func flashBlocked() {
        isBlockedFlash = true
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            isBlockedFlash = false
        }
    }
}

#Preview("Boxes") {
    HStack(alignment: .bottom, spacing: 20) {
        BoxArtwork(package: Package(id: UUID(), serial: "1042", size: .small, correctZone: .shelf1000, beltProgress: 0, spawnedAt: ContinuousClock.now))
        BoxArtwork(package: Package(id: UUID(), serial: nil, size: .medium, correctZone: .rerun, beltProgress: 0, spawnedAt: ContinuousClock.now))
        BoxArtwork(package: Package(id: UUID(), serial: nil, size: .small, correctZone: .roof, isAirPackage: true, beltProgress: 0, spawnedAt: ContinuousClock.now))
        BoxArtwork(package: Package(id: UUID(), serial: "5012", size: .medium, correctZone: nil, beltProgress: 0, spawnedAt: ContinuousClock.now))
        BoxArtwork(package: Package(id: UUID(), serial: "2I50", size: .medium, correctZone: nil, beltProgress: 0, spawnedAt: ContinuousClock.now))
        BoxArtwork(package: Package(id: UUID(), serial: "3087", size: .large, correctZone: .shelf3000, beltProgress: 0, spawnedAt: ContinuousClock.now), isLifted: true)
        BoxArtwork(package: Package(id: UUID(), serial: nil, size: .medium, correctZone: nil, isPowerUp: true, beltProgress: 0, spawnedAt: ContinuousClock.now))
    }
    .padding(40)
    .background(ArtPalette.skyDeep)
}
