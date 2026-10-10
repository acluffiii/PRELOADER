import SwiftUI

/// The cardboard-box look shared by every package, whether it's riding the belt, being
/// dragged, or already stacked on a shelf. Every box looks like plain cardboard — a "do not
/// touch" box has no visible tell beyond its serial, so reading the label is the only way to
/// know.
struct BoxArtwork: View {
    let package: Package
    var isLifted: Bool = false

    /// Drives the power-up glow's pulse — irrelevant (and never animated) for an ordinary box.
    @State private var powerUpPulse = false

    var body: some View {
        let baseFootprint = package.size.footprint
        let footprint = CGSize(width: baseFootprint.width * DeviceScale.text, height: baseFootprint.height * DeviceScale.text)
        ZStack {
            if package.isPowerUp {
                RoundedRectangle(cornerRadius: 4)
                    .fill(powerUpGradient)
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5)
                Image(systemName: "bolt.fill")
                    .font(.system(size: max(14, footprint.height * 0.45), weight: .heavy))
                    .foregroundStyle(.white)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(cardboardGradient)
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color(red: 0.42, green: 0.30, blue: 0.18).opacity(0.6), lineWidth: 1)
                Rectangle()
                    .fill(Color(white: 0.88).opacity(0.85))
                    .frame(height: footprint.height * 0.22)

                if package.isAirPackage {
                    // No serial to read at all — the airplane glyph is the entire label, and the
                    // only thing that tells the player this one goes to the roof.
                    Image(systemName: "airplane")
                        .font(.system(size: max(14, footprint.height * 0.4), weight: .heavy))
                        .foregroundStyle(.black)
                        .padding(6)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 3))
                } else if let serial = package.serial {
                    // Scales with the box instead of a fixed size — on a large package a flat
                    // 11pt label reads as an afterthought from arm's length.
                    let serialFontSize = max(12, footprint.height * 0.34)
                    Text(serial)
                        .font(.system(size: serialFontSize, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 3))
                        .frame(maxWidth: footprint.width * 0.88)
                }
            }
        }
        .frame(width: footprint.width, height: footprint.height)
        .shadow(
            color: package.isPowerUp ? Color.cyan.opacity(powerUpPulse ? 0.9 : 0.5) : .black.opacity(isLifted ? 0.45 : 0.25),
            radius: package.isPowerUp ? (powerUpPulse ? 14 : 6) : (isLifted ? 10 : 3),
            y: isLifted ? 8 : 2
        )
        .scaleEffect(isLifted ? 1.08 : 1.0)
        .task(id: package.isPowerUp) {
            guard package.isPowerUp else { return }
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                powerUpPulse = true
            }
        }
    }

    private var cardboardGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.76, green: 0.60, blue: 0.42), Color(red: 0.66, green: 0.50, blue: 0.34)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var powerUpGradient: LinearGradient {
        LinearGradient(colors: [.purple, .cyan], startPoint: .top, endPoint: .bottom)
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

    @State private var isBlockedFlash = false

    private var isSelected: Bool { selectedPackageID == package.id }

    var body: some View {
        BoxArtwork(package: package, isLifted: isSelected)
            .overlay {
                if isSelected {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4).fill(Color.green.opacity(0.35))
                        RoundedRectangle(cornerRadius: 4).strokeBorder(Color.green, lineWidth: 2)
                    }
                } else if isBlockedFlash {
                    RoundedRectangle(cornerRadius: 4).fill(Color.red.opacity(0.35))
                }
            }
            .animation(.easeInOut(duration: 0.15), value: isSelected)
            .position(position)
            .zIndex(isSelected ? 1000 : 0)
            .onTapGesture(perform: handleTap)
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
        BoxArtwork(package: Package(id: UUID(), serial: "2150", size: .medium, correctZone: nil, beltProgress: 0, spawnedAt: ContinuousClock.now))
        BoxArtwork(package: Package(id: UUID(), serial: "3087", size: .large, correctZone: .shelf3000, beltProgress: 0, spawnedAt: ContinuousClock.now), isLifted: true)
        BoxArtwork(package: Package(id: UUID(), serial: nil, size: .medium, correctZone: nil, isPowerUp: true, beltProgress: 0, spawnedAt: ContinuousClock.now))
    }
    .padding(40)
    .background(Color(white: 0.2))
}
