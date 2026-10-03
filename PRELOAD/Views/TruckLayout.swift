import SwiftUI

/// Pure geometry for the truck interior: the two side walls, the center bulkhead, the floor,
/// and the belt, all drawn in one-point perspective so the walls and bulkhead converge toward
/// a vanishing point at the top-center. Drawing and drop hit-testing both read from this same
/// geometry, so a box dropped "on" a shelf visually is also "on" it logically.
nonisolated struct TruckLayout {
    let size: CGSize

    /// Fraction of the canvas height given to the belt band at the bottom.
    private let beltHeightFraction: CGFloat = 0.22
    /// Fraction of the truck band's height where the shelf/bulkhead divider sits.
    private let horizonFraction: CGFloat = 0.40
    /// Bulkhead width at the very top (far, narrow), as a fraction of the canvas width.
    private let bulkheadWidthFraction: CGFloat = 0.24
    /// Floor width at the very bottom (near, wide), as a fraction of the canvas width.
    private let floorWidthFraction: CGFloat = 0.56

    init(size: CGSize) {
        self.size = size
    }

    var truckTop: CGFloat { 0 }
    var truckBottom: CGFloat { size.height * (1 - beltHeightFraction) }
    var horizonY: CGFloat { lerp(truckTop, truckBottom, horizonFraction) }

    private var bulkheadLeft: CGFloat { size.width * (0.5 - bulkheadWidthFraction / 2) }
    private var bulkheadRight: CGFloat { size.width * (0.5 + bulkheadWidthFraction / 2) }
    private var floorBottomLeft: CGFloat { size.width * (0.5 - floorWidthFraction / 2) }
    private var floorBottomRight: CGFloat { size.width * (0.5 + floorWidthFraction / 2) }

    /// The left wall's converging inner edge at the horizon, interpolated between its narrow
    /// top (`bulkheadLeft`) and wide bottom (`floorBottomLeft`).
    private var leftEdgeAtHorizon: CGFloat { lerp(bulkheadLeft, floorBottomLeft, horizonFraction) }
    private var rightEdgeAtHorizon: CGFloat { lerp(bulkheadRight, floorBottomRight, horizonFraction) }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }

    // MARK: Zone polygons

    /// Returns the drop-zone polygon for `zone`. Adjacent zones share exact edges (both are
    /// built from the same wall/floor convergence points), so there are no gaps or overlaps.
    func path(for zone: LoadZone) -> Path {
        switch zone {
        case .shelf1000:
            return quad(
                CGPoint(x: 0, y: truckTop), CGPoint(x: bulkheadLeft, y: truckTop),
                CGPoint(x: leftEdgeAtHorizon, y: horizonY), CGPoint(x: 0, y: horizonY)
            )
        case .shelf2000:
            return quad(
                CGPoint(x: 0, y: horizonY), CGPoint(x: leftEdgeAtHorizon, y: horizonY),
                CGPoint(x: floorBottomLeft, y: truckBottom), CGPoint(x: 0, y: truckBottom)
            )
        case .shelf3000:
            return quad(
                CGPoint(x: size.width, y: truckTop), CGPoint(x: bulkheadRight, y: truckTop),
                CGPoint(x: rightEdgeAtHorizon, y: horizonY), CGPoint(x: size.width, y: horizonY)
            )
        case .shelf4000:
            return quad(
                CGPoint(x: size.width, y: horizonY), CGPoint(x: rightEdgeAtHorizon, y: horizonY),
                CGPoint(x: floorBottomRight, y: truckBottom), CGPoint(x: size.width, y: truckBottom)
            )
        case .floor:
            return quad(
                CGPoint(x: leftEdgeAtHorizon, y: horizonY), CGPoint(x: rightEdgeAtHorizon, y: horizonY),
                CGPoint(x: floorBottomRight, y: truckBottom), CGPoint(x: floorBottomLeft, y: truckBottom)
            )
        }
    }

    /// The bulkhead panel. Not a drop zone — it's the far wall, always empty.
    var bulkheadPath: Path {
        quad(
            CGPoint(x: bulkheadLeft, y: truckTop), CGPoint(x: bulkheadRight, y: truckTop),
            CGPoint(x: rightEdgeAtHorizon, y: horizonY), CGPoint(x: leftEdgeAtHorizon, y: horizonY)
        )
    }

    var leftWallPath: Path {
        quad(
            CGPoint(x: 0, y: truckTop), CGPoint(x: bulkheadLeft, y: truckTop),
            CGPoint(x: floorBottomLeft, y: truckBottom), CGPoint(x: 0, y: truckBottom)
        )
    }

    var rightWallPath: Path {
        quad(
            CGPoint(x: size.width, y: truckTop), CGPoint(x: bulkheadRight, y: truckTop),
            CGPoint(x: floorBottomRight, y: truckBottom), CGPoint(x: size.width, y: truckBottom)
        )
    }

    var beltRect: CGRect {
        CGRect(x: 0, y: truckBottom, width: size.width, height: size.height - truckBottom)
    }

    private func quad(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint) -> Path {
        var path = Path()
        path.move(to: a)
        path.addLine(to: b)
        path.addLine(to: c)
        path.addLine(to: d)
        path.closeSubpath()
        return path
    }

    // MARK: Hit testing

    /// All five drop zones, tested in a fixed order. Returns nil outside all of them (the
    /// belt, the HUD, or any margin).
    func zone(at point: CGPoint) -> LoadZone? {
        LoadZone.allCases.first { path(for: $0).contains(point) }
    }

    // MARK: Belt positioning

    /// Maps belt progress (0 = just spawned, 1 = falls off the end) to a point in the belt band.
    func beltPosition(progress: Double) -> CGPoint {
        let inset = size.width * 0.06
        let travel = size.width - inset * 2
        let x = inset + travel * CGFloat(progress.clamped(to: 0...1))
        return CGPoint(x: x, y: beltRect.midY)
    }

    /// A simple grid position for the nth box stacked on a shelf, so loaded boxes visibly pile up.
    func stackPosition(in zone: LoadZone, index: Int) -> CGPoint {
        let bounds = path(for: zone).boundingRect
        let columns = 4
        let column = index % columns
        let row = index / columns
        let cellWidth = bounds.width / CGFloat(columns)
        let x = bounds.minX + cellWidth * (CGFloat(column) + 0.5)
        let y = bounds.maxY - cellWidth * 0.5 - CGFloat(row) * (cellWidth * 0.85)
        return CGPoint(x: x, y: max(bounds.minY, y))
    }
}

nonisolated private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
