import SwiftUI

/// The static backdrop inside the open van: the ceiling, the two side walls (each split into its
/// upper and lower shelf), the floor, the small far wall the room converges toward (which
/// doubles as the roof zone, where air packages go), and the boxes already stacked on each
/// shelf. Everything here is drawn from the same `TruckLayout` geometry used for drop
/// hit-testing. The exterior (`TruckExteriorView`) draws everything outside the open doors — this
/// view only fills the doorway itself.
struct TruckInteriorView: View {
    let layout: TruckLayout
    let loadedPackages: [LoadZone: [Package]]
    /// This truck's current shelf ranges, so the stenciled numbers rotate with every truck.
    let shelfRanges: [LoadZone: ClosedRange<Int>]
    /// Whether a package is currently held, so every zone can invite a tap.
    let isSelecting: Bool
    let onZoneTap: (LoadZone) -> Void

    var body: some View {
        ZStack {
            ceiling
            floor
            wallRivets(layout.leftWallPath)
            wallRivets(layout.rightWallPath)
            ForEach(LoadZone.allCases) { zone in
                zoneLayer(for: zone)
            }
        }
    }

    // MARK: Wall texture

    /// A faint rivet row along each wall's near and far edges, drawn once behind both of that
    /// wall's shelves — a riveted-aluminum texture the shelf fills alone wouldn't carry.
    private func wallRivets(_ path: Path) -> some View {
        let bounds = path.boundingRect
        return Canvas { context, _ in
            var y = bounds.minY + 6
            while y < bounds.maxY {
                for x in [bounds.minX + 5, bounds.maxX - 5] {
                    let rivet = Path(ellipseIn: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3))
                    context.fill(rivet, with: .color(.white.opacity(0.3)))
                    context.stroke(rivet, with: .color(.black.opacity(0.4)), lineWidth: 0.5)
                }
                y += 18
            }
        }
        .mask(path)
    }

    // MARK: Ceiling and floor

    private var ceiling: some View {
        let path = layout.ceilingPath
        return ZStack {
            path.fill(ceilingGradient)
            ribs(in: path, count: 5, color: .black.opacity(0.18))
            path.stroke(Color.black.opacity(0.4), lineWidth: 1)
        }
    }

    /// The truck's floor — decorative only, so the room doesn't look bottomless. Not a drop
    /// zone: packages never go here.
    private var floor: some View {
        let path = layout.floorPath
        return ZStack {
            path.fill(floorGradient)
            LinearGradient(colors: [.black.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom)
                .mask(path)
            planks(in: path)
            path.stroke(Color.black.opacity(0.55), lineWidth: 1.5)
        }
    }

    private var ceilingGradient: LinearGradient {
        LinearGradient(colors: [Color(white: 0.30), Color(white: 0.20)], startPoint: .bottom, endPoint: .top)
    }

    // MARK: Zones (shelves, rerun, and roof)

    @ViewBuilder
    private func zoneLayer(for zone: LoadZone) -> some View {
        let path = layout.path(for: zone)
        // The roof's centroid sits on the far wall, right where the loader stands, so its
        // stencil would be hidden behind him — nudged aside instead, purely for label placement.
        let anchor = zone == .roof
            ? CGPoint(x: layout.zoneAnchor(for: zone).x - path.boundingRect.width * 0.28, y: layout.zoneAnchor(for: zone).y)
            : layout.zoneAnchor(for: zone)

        ZStack {
            path.fill(fillGradient(for: zone))

            // A depth shadow, darkest toward the far wall, masked to the zone's own shape.
            LinearGradient(colors: [.black.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom)
                .mask(path)

            switch zone {
            case .rerun:
                slats(in: path)
            case .shelf1000, .shelf2000, .shelf3000, .shelf4000, .roof:
                // A bright metal lip along the near-facing edge, with a rivet row.
                shelfLipGradient.mask(path)
            }

            path.stroke(Color.black.opacity(0.55), lineWidth: 1.5)

            if isSelecting {
                path.fill(Color.white.opacity(0.12))
                path.stroke(Color.white.opacity(0.6), lineWidth: 2)
            }

            zoneStencil(for: zone, at: anchor)

            ForEach(Array((loadedPackages[zone] ?? []).enumerated()), id: \.element.id) { index, package in
                BoxArtwork(package: package)
                    .scaleEffect(layout.stackScale(in: zone, index: index))
                    .position(layout.stackPosition(in: zone, index: index))
                    .allowsHitTesting(false)
                    .transition(.scale(scale: 1.4).combined(with: .opacity))
            }
            .animation(.bouncy(duration: 0.3), value: loadedPackages[zone]?.count)
        }
        .contentShape(path)
        .onTapGesture { onZoneTap(zone) }
    }

    /// The label stenciled on each zone: a shelf's exact range ("1000–1099", which rotates every
    /// truck), the rerun tray's no-label reminder, or the roof's airplane icon — all centered on
    /// the zone's own centroid so they always land inside the (narrow, perspective-skewed) shape
    /// rather than a bounding-rect corner.
    @ViewBuilder
    private func zoneStencil(for zone: LoadZone, at anchor: CGPoint) -> some View {
        switch zone {
        case .shelf1000, .shelf2000, .shelf3000, .shelf4000:
            if let range = SerialRules.range(for: zone, ranges: shelfRanges) {
                // `Text("\(Int)")` string interpolation applies locale number formatting
                // (thousands separators), which reads as "9,400" instead of a plain serial-style
                // "9400" — so the digits are built as plain, unformatted strings first.
                Text("\(String(range.lowerBound))–\(String(range.upperBound))")
                    .font(.system(size: 17 * DeviceScale.text, weight: .black, design: .monospaced))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(.white.opacity(0.55))
                    .position(anchor)
            }
        case .rerun:
            VStack(spacing: 1) {
                Text("RERUN").font(.system(size: 16 * DeviceScale.text, weight: .black, design: .rounded))
                Text("NO LABEL").font(.system(size: 9 * DeviceScale.text, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.5))
            .position(anchor)
        case .roof:
            VStack(spacing: 1) {
                Image(systemName: "airplane")
                    .font(.system(size: 16 * DeviceScale.text, weight: .black))
                Text("AIR").font(.system(size: 9 * DeviceScale.text, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.6))
            .position(anchor)
        }
    }

    /// Thin horizontal ribs suggesting the ceiling's structural slats, converging toward the far
    /// wall. Drawn across the full bounding box and masked rather than following the shape's
    /// true converging edges — simpler, and the mask already hides the difference.
    private func ribs(in path: Path, count: Int, color: Color) -> some View {
        let bounds = path.boundingRect
        return Canvas { context, _ in
            for i in 0...count {
                let y = bounds.minY + bounds.height * (CGFloat(i) / CGFloat(count))
                var line = Path()
                line.move(to: CGPoint(x: bounds.minX, y: y))
                line.addLine(to: CGPoint(x: bounds.maxX, y: y))
                context.stroke(line, with: .color(color), lineWidth: 1)
            }
        }
        .mask(path)
    }

    /// Wood-slat floorboards receding toward the far wall, clipped to the floor's own shape.
    private func planks(in path: Path) -> some View {
        let bounds = path.boundingRect
        let spacing: CGFloat = 22
        return Canvas { context, _ in
            var x = bounds.minX
            while x < bounds.maxX {
                var line = Path()
                line.move(to: CGPoint(x: x, y: bounds.minY))
                line.addLine(to: CGPoint(x: x, y: bounds.maxY))
                context.stroke(line, with: .color(.black.opacity(0.3)), lineWidth: 1.5)
                x += spacing
            }
        }
        .mask(path)
    }

    /// Horizontal roller slats across the rerun tray, clipped to its own shape — reads as a bin
    /// on rollers rather than a flat painted rectangle.
    private func slats(in path: Path) -> some View {
        let bounds = path.boundingRect
        let spacing: CGFloat = 10
        return Canvas { context, _ in
            var y = bounds.minY
            while y < bounds.maxY {
                var line = Path()
                line.move(to: CGPoint(x: bounds.minX, y: y))
                line.addLine(to: CGPoint(x: bounds.maxX, y: y))
                context.stroke(line, with: .color(.black.opacity(0.25)), lineWidth: 1)
                y += spacing
            }
        }
        .mask(path)
    }

    /// A bright metal band along a shelf's (or the roof's) near-facing edge — the lip boxes
    /// actually rest on. Every shelf's own quad is built so its bottom edge is that lip, so the
    /// same fixed stop pattern works for all of them, and for the roof besides.
    private var shelfLipGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .clear, location: 0.82),
                .init(color: Color(white: 0.8), location: 0.90),
                .init(color: Color(white: 0.3), location: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Picks each zone's base fill: the shelves and roof get the riveted-metal look, rerun gets
    /// its own distinct look so it reads as a different kind of surface.
    private func fillGradient(for zone: LoadZone) -> LinearGradient {
        switch zone {
        case .shelf1000, .shelf2000, .shelf3000, .shelf4000: return shelfGradient(for: zone)
        case .roof: return roofGradient
        case .rerun: return rerunGradient
        }
    }

    /// The upper shelves (1000/3000) sit closer to the ceiling light, so they read a touch
    /// brighter than the lower pair.
    private func shelfGradient(for zone: LoadZone) -> LinearGradient {
        let isUpper = zone == .shelf1000 || zone == .shelf3000
        let top = Color(white: isUpper ? 0.32 : 0.25)
        let bottom = Color(white: isUpper ? 0.21 : 0.15)
        return LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }

    /// A cool blue-gray, distinct from the warm metal shelves — a small hatch in the back wall
    /// for air packages.
    private var roofGradient: LinearGradient {
        LinearGradient(colors: [Color(red: 0.30, green: 0.40, blue: 0.52), Color(red: 0.18, green: 0.25, blue: 0.34)], startPoint: .top, endPoint: .bottom)
    }

    private var floorGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.40, green: 0.29, blue: 0.18), Color(red: 0.25, green: 0.18, blue: 0.11)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// A dull galvanized-bin look for the rerun tray, distinct from both the wood-toned floor and
    /// the warmer shelf metal.
    private var rerunGradient: LinearGradient {
        LinearGradient(colors: [Color(white: 0.38), Color(white: 0.24)], startPoint: .top, endPoint: .bottom)
    }
}
