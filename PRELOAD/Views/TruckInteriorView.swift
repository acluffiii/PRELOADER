import SwiftUI

/// The static backdrop: the two side walls, the center bulkhead, the floor, the shelf lips and
/// stencils, and the boxes already stacked on each shelf. Everything here is drawn from the
/// same `TruckLayout` geometry used for drop hit-testing.
struct TruckInteriorView: View {
    let layout: TruckLayout
    let loadedPackages: [LoadZone: [Package]]
    let hoveredZone: LoadZone?

    var body: some View {
        ZStack {
            wall(layout.leftWallPath)
            wall(layout.rightWallPath)
            bulkhead
            ForEach(LoadZone.allCases) { zone in
                zoneLayer(for: zone)
            }
        }
    }

    // MARK: Walls and bulkhead

    private func wall(_ path: Path) -> some View {
        path
            .fill(wallGradient)
            .overlay(path.stroke(Color.black.opacity(0.5), lineWidth: 1))
    }

    private var bulkhead: some View {
        layout.bulkheadPath
            .fill(bulkheadGradient)
            .overlay(layout.bulkheadPath.stroke(Color.black.opacity(0.6), lineWidth: 1))
    }

    private var wallGradient: LinearGradient {
        LinearGradient(
            colors: [Color(white: 0.22), Color(white: 0.13)],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    private var bulkheadGradient: LinearGradient {
        LinearGradient(
            colors: [Color(white: 0.17), Color(white: 0.08)],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    // MARK: Zones (shelves and floor)

    @ViewBuilder
    private func zoneLayer(for zone: LoadZone) -> some View {
        let path = layout.path(for: zone)
        let bounds = path.boundingRect

        ZStack {
            path.fill(zone.isShelf ? shelfGradient : floorGradient)

            // A depth shadow, darkest at the near edge, masked to the zone's own shape —
            // reads as a shelf lip for the shelves and as shading under the walls for the floor.
            LinearGradient(colors: [.clear, .black.opacity(0.32)], startPoint: .top, endPoint: .bottom)
                .mask(path)

            if zone == .floor {
                ribs(in: path)
            }

            path.stroke(Color.black.opacity(0.55), lineWidth: 1.5)

            if zone == hoveredZone {
                path.fill(Color.white.opacity(0.18))
                path.stroke(Color.white.opacity(0.8), lineWidth: 2)
            }

            if let label = zone.shelfLabel {
                Text(label)
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.22))
                    .position(x: bounds.midX, y: bounds.minY + (bounds.height * 0.22))
            }

            ForEach(Array((loadedPackages[zone] ?? []).enumerated()), id: \.element.id) { index, package in
                BoxArtwork(package: package)
                    .position(layout.stackPosition(in: zone, index: index))
                    .allowsHitTesting(false)
            }
        }
    }

    /// Thin vertical ribs suggesting ridged metal flooring, clipped to the floor's own shape.
    private func ribs(in path: Path) -> some View {
        let bounds = path.boundingRect
        let spacing: CGFloat = 14
        return Canvas { context, _ in
            var x = bounds.minX
            while x < bounds.maxX {
                var line = Path()
                line.move(to: CGPoint(x: x, y: bounds.minY))
                line.addLine(to: CGPoint(x: x, y: bounds.maxY))
                context.stroke(line, with: .color(.black.opacity(0.15)), lineWidth: 1)
                x += spacing
            }
        }
        .mask(path)
    }

    private var shelfGradient: LinearGradient {
        LinearGradient(colors: [Color(white: 0.24), Color(white: 0.16)], startPoint: .top, endPoint: .bottom)
    }

    private var floorGradient: LinearGradient {
        LinearGradient(colors: [Color(white: 0.20), Color(white: 0.10)], startPoint: .top, endPoint: .bottom)
    }
}
