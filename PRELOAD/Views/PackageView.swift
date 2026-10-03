import SwiftUI

/// The cardboard-box look shared by every package, whether it's riding the belt, being
/// dragged, or already stacked on a shelf. Critically, a "do not touch" package must look
/// identical to every other package — the only tell is the serial — so this never branches
/// on `package.isDoNotTouch`.
struct BoxArtwork: View {
    let package: Package
    var isLifted: Bool = false

    var body: some View {
        let footprint = package.size.footprint
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(cardboardGradient)
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color(red: 0.42, green: 0.30, blue: 0.18).opacity(0.6), lineWidth: 1)
            Rectangle()
                .fill(Color(white: 0.88).opacity(0.85))
                .frame(height: footprint.height * 0.22)

            if let serial = package.serial {
                Text(serial)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 2))
                    .frame(maxWidth: footprint.width * 0.82)
            }
        }
        .frame(width: footprint.width, height: footprint.height)
        .shadow(
            color: .black.opacity(isLifted ? 0.45 : 0.25),
            radius: isLifted ? 10 : 3,
            y: isLifted ? 8 : 2
        )
        .scaleEffect(isLifted ? 1.08 : 1.0)
    }

    private var cardboardGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.76, green: 0.60, blue: 0.42), Color(red: 0.66, green: 0.50, blue: 0.34)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// A draggable package riding the belt. Owns its own grab/carry/blocked state locally — only
/// one `PackageView` can ever be the one actually receiving touch input at a time, so there's
/// no need to share drag state at a higher level, except for which zone is currently glowing.
struct PackageView: View {
    let package: Package
    let layout: TruckLayout
    let engine: ShiftEngine
    @Binding var hoveredZone: LoadZone?

    private enum Phase: Equatable {
        case idle
        case dragging
        case blocked
    }

    @State private var phase: Phase = .idle
    @State private var grabOrigin: CGPoint = .zero
    @State private var currentPosition: CGPoint = .zero

    private var restingPosition: CGPoint {
        layout.beltPosition(progress: package.beltProgress)
    }

    var body: some View {
        BoxArtwork(package: package, isLifted: phase == .dragging)
            .overlay {
                if phase == .blocked {
                    RoundedRectangle(cornerRadius: 4).fill(Color.red.opacity(0.35))
                }
            }
            .animation(.easeInOut(duration: 0.15), value: phase)
            .position(phase == .dragging ? currentPosition : restingPosition)
            .zIndex(phase == .dragging ? 1000 : 0)
            .gesture(dragGesture)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("truck"))
            .onChanged { value in
                switch phase {
                case .idle:
                    grabOrigin = restingPosition
                    if engine.grab(id: package.id) {
                        phase = .dragging
                        currentPosition = grabOrigin
                        hoveredZone = layout.zone(at: currentPosition)
                    } else {
                        phase = .blocked
                    }
                case .dragging:
                    currentPosition = CGPoint(
                        x: grabOrigin.x + value.translation.width,
                        y: grabOrigin.y + value.translation.height
                    )
                    hoveredZone = layout.zone(at: currentPosition)
                case .blocked:
                    break
                }
            }
            .onEnded { value in
                if phase == .dragging {
                    let dropPoint = CGPoint(
                        x: grabOrigin.x + value.translation.width,
                        y: grabOrigin.y + value.translation.height
                    )
                    engine.drop(id: package.id, in: layout.zone(at: dropPoint))
                }
                phase = .idle
                hoveredZone = nil
            }
    }
}

#Preview("Boxes") {
    HStack(alignment: .bottom, spacing: 20) {
        BoxArtwork(package: Package(id: UUID(), serial: "1042", size: .small, correctZone: .shelf1000, beltProgress: 0, spawnedAt: ContinuousClock.now))
        BoxArtwork(package: Package(id: UUID(), serial: nil, size: .oversize, correctZone: .floor, beltProgress: 0, spawnedAt: ContinuousClock.now))
        BoxArtwork(package: Package(id: UUID(), serial: "5012", size: .medium, correctZone: nil, beltProgress: 0, spawnedAt: ContinuousClock.now))
        BoxArtwork(package: Package(id: UUID(), serial: "3087", size: .large, correctZone: .shelf3000, beltProgress: 0, spawnedAt: ContinuousClock.now), isLifted: true)
    }
    .padding(40)
    .background(Color(white: 0.2))
}
