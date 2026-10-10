import SwiftUI

/// Pure geometry for the truck interior: a one-point-perspective view straight into the back of
/// an open delivery van, converging toward a small far wall centered in the opening. Drawing and
/// drop hit-testing both read from this same geometry, so a box dropped "on" a shelf visually is
/// also "on" it logically.
///
/// The room is built from flat quads: a ceiling strip, a floor strip, a left wall (split into
/// the 1000 and 2000 shelves), a right wall (split into the 3000 and 4000 shelves), and the small
/// far wall at the back — which doubles as the roof zone, where air packages go. A rerun tray
/// sits below the floating belt, outside the truck itself. Every internal split (the two shelves
/// on a wall) leaves a small gap that belongs to neither neighbor, so a tap near a boundary can't
/// land on the wrong zone by accident.
nonisolated struct TruckLayout {
    let size: CGSize

    /// Horizontal margin outside the open doors, as a fraction of the canvas width.
    private let openingXInsetFraction: CGFloat = 0.09
    /// Where the door opening starts and ends vertically, as fractions of the canvas height.
    private let openingTopFraction: CGFloat = 0.06
    private let openingBottomFraction: CGFloat = 0.68
    /// The far wall's size, as a fraction of the opening's own width/height — small and
    /// centered, so the interior reads deep.
    private let farWallWidthFraction: CGFloat = 0.30
    private let farWallHeightFraction: CGFloat = 0.42
    /// Where each wall splits into its upper and lower shelf, as a fraction down the wall.
    private let shelfSplitFraction: CGFloat = 0.45
    /// Half the gap left at that split, as a fraction of the wall's own height — each shelf
    /// insets its divider-facing edge by this much, so the two shelves never share an edge.
    private let shelfGapHalfFraction: CGFloat = 0.025
    /// The floating belt band, as fractions of the canvas height.
    private let beltTopFraction: CGFloat = 0.70
    private let beltBottomFraction: CGFloat = 0.84
    /// Roughly where the loader's head reaches, as a fraction of the canvas height — he stands
    /// at the threshold, in front of the truck, not deep inside it.
    private let workerTopFraction: CGFloat = 0.30

    init(size: CGSize) {
        self.size = size
    }

    // MARK: Opening and far-wall geometry

    private var openingLeft: CGFloat { size.width * openingXInsetFraction }
    private var openingRight: CGFloat { size.width * (1 - openingXInsetFraction) }
    private var openingTop: CGFloat { size.height * openingTopFraction }
    private var openingBottom: CGFloat { size.height * openingBottomFraction }

    /// The rectangle the open doors frame — everything drawable inside the truck lives here.
    var truckOpening: CGRect {
        CGRect(x: openingLeft, y: openingTop, width: openingRight - openingLeft, height: openingBottom - openingTop)
    }

    /// The bottom of the interior — where the floor meets the sill and bumper outside.
    var truckBottom: CGFloat { openingBottom }

    /// The small back wall the whole interior converges toward.
    private var farWallRect: CGRect {
        let width = truckOpening.width * farWallWidthFraction
        let height = truckOpening.height * farWallHeightFraction
        let centerX = truckOpening.midX
        let centerY = truckOpening.minY + truckOpening.height * 0.5
        return CGRect(x: centerX - width / 2, y: centerY - height / 2, width: width, height: height)
    }

    /// Where the upper/lower shelf split falls on each side of its gap, at the near edge
    /// (on the opening) and the far edge (on the far wall), interpolated by the same fraction so
    /// both the divider and its gap recede correctly in perspective.
    private var shelfSplitNearYUpper: CGFloat { lerp(openingTop, openingBottom, shelfSplitFraction - shelfGapHalfFraction) }
    private var shelfSplitNearYLower: CGFloat { lerp(openingTop, openingBottom, shelfSplitFraction + shelfGapHalfFraction) }
    private var shelfSplitFarYUpper: CGFloat { lerp(farWallRect.minY, farWallRect.maxY, shelfSplitFraction - shelfGapHalfFraction) }
    private var shelfSplitFarYLower: CGFloat { lerp(farWallRect.minY, farWallRect.maxY, shelfSplitFraction + shelfGapHalfFraction) }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }

    // MARK: Zone polygons

    /// The four corners of `zone`'s quad, as `(s: 0, t: 0)`, `(s: 1, t: 0)`, `(s: 1, t: 1)`,
    /// `(s: 0, t: 1)` — the same corner order `bilinear(_:_:_:_:s:t:)` assumes. For every shelf,
    /// `s` runs across the shelf's own band (0 = toward the ceiling/divider, 1 = the shelf lip
    /// boxes rest on) and `t` runs from the opening (0) back to the far wall (1). For the floor,
    /// `s` runs left-to-right and `t` runs from the opening (0) back to the far wall (1). Roof is
    /// the far wall's own rect; rerun is a plain rect below the belt.
    private func corners(for zone: LoadZone) -> [CGPoint] {
        let o = truckOpening
        let f = farWallRect

        switch zone {
        case .shelf1000:
            return [
                CGPoint(x: o.minX, y: o.minY), CGPoint(x: o.minX, y: shelfSplitNearYUpper),
                CGPoint(x: f.minX, y: shelfSplitFarYUpper), CGPoint(x: f.minX, y: f.minY),
            ]
        case .shelf2000:
            return [
                CGPoint(x: o.minX, y: shelfSplitNearYLower), CGPoint(x: o.minX, y: o.maxY),
                CGPoint(x: f.minX, y: f.maxY), CGPoint(x: f.minX, y: shelfSplitFarYLower),
            ]
        case .shelf3000:
            return [
                CGPoint(x: o.maxX, y: o.minY), CGPoint(x: o.maxX, y: shelfSplitNearYUpper),
                CGPoint(x: f.maxX, y: shelfSplitFarYUpper), CGPoint(x: f.maxX, y: f.minY),
            ]
        case .shelf4000:
            return [
                CGPoint(x: o.maxX, y: shelfSplitNearYLower), CGPoint(x: o.maxX, y: o.maxY),
                CGPoint(x: f.maxX, y: f.maxY), CGPoint(x: f.maxX, y: shelfSplitFarYLower),
            ]
        case .roof:
            return [
                CGPoint(x: f.minX, y: f.minY), CGPoint(x: f.maxX, y: f.minY),
                CGPoint(x: f.maxX, y: f.maxY), CGPoint(x: f.minX, y: f.maxY),
            ]
        case .rerun:
            let r = dockFloorRect
            return [
                CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY),
                CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.minX, y: r.maxY),
            ]
        }
    }

    /// The truck's actual floor plane — decorative only (oversize packages and the floor as a
    /// drop zone are gone), but still drawn so the room doesn't look bottomless.
    var floorPath: Path {
        let o = truckOpening
        let f = farWallRect
        return quad(
            CGPoint(x: o.minX, y: o.maxY), CGPoint(x: o.maxX, y: o.maxY),
            CGPoint(x: f.maxX, y: f.maxY), CGPoint(x: f.minX, y: f.maxY)
        )
    }

    /// Returns the drop-zone polygon for `zone`.
    func path(for zone: LoadZone) -> Path {
        let points = corners(for: zone)
        return quad(points[0], points[1], points[2], points[3])
    }

    /// Maps `(s, t)` in `[0, 1] × [0, 1]` onto the quad defined by `c00, c10, c11, c01` (in
    /// perimeter order) by bilinear interpolation. Because that's a convex combination of the
    /// corners, and every quad here is convex, the result is always strictly inside the shape for
    /// `s`/`t` strictly between 0 and 1 — regardless of how skewed the quad is in perspective.
    private func bilinear(_ c00: CGPoint, _ c10: CGPoint, _ c11: CGPoint, _ c01: CGPoint, s: CGFloat, t: CGFloat) -> CGPoint {
        let x = (1 - s) * (1 - t) * c00.x + s * (1 - t) * c10.x + s * t * c11.x + (1 - s) * t * c01.x
        let y = (1 - s) * (1 - t) * c00.y + s * (1 - t) * c10.y + s * t * c11.y + (1 - s) * t * c01.y
        return CGPoint(x: x, y: y)
    }

    /// `bilinear(_:_:_:_:s:t:)` applied to `zone`'s own corners — this is what makes
    /// `zoneAnchor(for:)` and `stackPosition(in:index:)` safe to reason about independent of the
    /// zone's exact shape.
    private func bilinearPoint(in zone: LoadZone, s: CGFloat, t: CGFloat) -> CGPoint {
        let c = corners(for: zone)
        return bilinear(c[0], c[1], c[2], c[3], s: s, t: t)
    }

    /// The dead-center of `zone`'s quad — unlike a bounding-rect center, this is guaranteed to
    /// fall inside the (convex) zone itself, so it's safe to use for stencil placement and tests.
    func zoneAnchor(for zone: LoadZone) -> CGPoint {
        bilinearPoint(in: zone, s: 0.5, t: 0.5)
    }

    /// The ceiling's own corners, in the same `[c00, c10, c11, c01]` convention as `corners(for:)`
    /// — `s` runs left-to-right, `t` runs from the opening (0) back to the far wall (1).
    private var ceilingCorners: [CGPoint] {
        let o = truckOpening
        let f = farWallRect
        return [
            CGPoint(x: o.minX, y: o.minY), CGPoint(x: o.maxX, y: o.minY),
            CGPoint(x: f.maxX, y: f.minY), CGPoint(x: f.minX, y: f.minY),
        ]
    }

    /// The ceiling strip — the horizontal plane from the top of the opening back to the top of
    /// the far wall. Decorative only.
    var ceilingPath: Path {
        let c = ceilingCorners
        return quad(c[0], c[1], c[2], c[3])
    }

    /// The full left wall (1000 and 2000 together, gap included), used as a backdrop for seams
    /// and rivets before the two shelves are drawn on top of it.
    var leftWallPath: Path {
        let o = truckOpening
        let f = farWallRect
        return quad(
            CGPoint(x: o.minX, y: o.minY), CGPoint(x: f.minX, y: f.minY),
            CGPoint(x: f.minX, y: f.maxY), CGPoint(x: o.minX, y: o.maxY)
        )
    }

    /// The full right wall (3000 and 4000 together); see `leftWallPath`.
    var rightWallPath: Path {
        let o = truckOpening
        let f = farWallRect
        return quad(
            CGPoint(x: o.maxX, y: o.minY), CGPoint(x: o.maxX, y: o.maxY),
            CGPoint(x: f.maxX, y: f.maxY), CGPoint(x: f.maxX, y: f.minY)
        )
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

    /// All six drop zones, tested in a fixed order. Returns nil outside all of them (the belt,
    /// the HUD, the ceiling/far wall margins, the gaps between zones, or any outer margin).
    func zone(at point: CGPoint) -> LoadZone? {
        LoadZone.allCases.first { path(for: $0).contains(point) }
    }

    // MARK: Belt positioning

    /// The floating conveyor band — raised off the dock floor, below the truck's open doors.
    var beltRect: CGRect {
        let top = size.height * beltTopFraction
        let bottom = size.height * beltBottomFraction
        return CGRect(x: 0, y: top, width: size.width, height: bottom - top)
    }

    /// The concrete dock floor beneath the belt, where its support legs plant — and, re-themed in
    /// the view layer, the rerun tray's own footprint (`path(for: .rerun)`).
    var dockFloorRect: CGRect {
        CGRect(x: 0, y: beltRect.maxY, width: size.width, height: size.height - beltRect.maxY)
    }

    /// Maps belt progress (0 = just spawned, 1 = falls off the end) to a point in the belt band.
    func beltPosition(progress: Double) -> CGPoint {
        let inset = size.width * 0.06
        let travel = size.width - inset * 2
        let x = inset + travel * CGFloat(progress.clamped(to: 0...1))
        return CGPoint(x: x, y: beltRect.midY)
    }

    // MARK: Worker and hands

    /// Where the loader stands: at the threshold in front of the truck, his head roughly level
    /// with the lower shelves and his feet overlapping the near edge of the belt band (drawn
    /// over afterward, so they read as tucked behind it rather than floating in front).
    var workerFrame: CGRect {
        let top = size.height * workerTopFraction
        let bottom = beltRect.minY + beltRect.height * 0.55
        let height = max(0, bottom - top)
        let width = height * (70.0 / 150.0)
        return CGRect(x: size.width / 2 - width / 2, y: top, width: width, height: height)
    }

    /// Where a held or carried box sits: at the loader's chest, just above the belt, and
    /// comfortably inside the floor's own footprint.
    var handsPosition: CGPoint {
        CGPoint(x: workerFrame.midX, y: beltRect.minY - size.height * 0.03)
    }

    // MARK: Stacking

    /// Where the nth box stacked in `zone` should sit, so loaded boxes visibly pile up. On a
    /// shelf, boxes rest toward `s = 1` and spread back toward the far wall across columns, with
    /// each row stacking toward `s = 0`. On the roof, boxes split into a left and right half so
    /// they never stack directly behind the loader, who stands right in front of the far wall.
    /// The rerun tray is a plain rect, so it uses a simple axis-aligned grid instead of the
    /// bilinear approach.
    func stackPosition(in zone: LoadZone, index: Int) -> CGPoint {
        gridResult(in: zone, index: index).point
    }

    /// A gentle shrink for boxes in higher rows, so a tall stack still reads as receding rather
    /// than floating in a flat tower.
    func stackScale(in zone: LoadZone, index: Int) -> CGFloat {
        max(0.6, 1.0 - CGFloat(gridResult(in: zone, index: index).row) * 0.15)
    }

    private func gridResult(in zone: LoadZone, index: Int) -> (point: CGPoint, row: Int) {
        switch zone {
        case .roof:
            // Split into a left and right band — the roof's centroid sits on the far wall,
            // right where the loader stands, so boxes stack away from him rather than piling up
            // straight behind his back.
            let columnsPerSide = 2
            let side = index % 2
            let slot = index / 2
            let column = slot % columnsPerSide
            let row = slot / columnsPerSide

            let sRange: ClosedRange<CGFloat> = side == 0 ? 0.06...0.36 : 0.64...0.94
            let s = lerp(sRange.lowerBound, sRange.upperBound, (CGFloat(column) + 0.5) / CGFloat(columnsPerSide))
            let t = min(0.75, 0.12 + CGFloat(row) * 0.22)
            return (bilinearPoint(in: .roof, s: s, t: t), row)

        case .rerun:
            // Wide and shallow, unlike every other zone — row spacing has to come from the
            // tray's own (small) height, not a share of its (much larger) width.
            let bounds = path(for: .rerun).boundingRect
            let columns = 6
            let column = index % columns
            let row = index / columns
            let cellWidth = bounds.width / CGFloat(columns)
            let rowHeight = bounds.height * 0.4
            let x = bounds.minX + cellWidth * (CGFloat(column) + 0.5)
            let y = bounds.maxY - bounds.height * 0.25 - CGFloat(row) * rowHeight
            return (CGPoint(x: x, y: max(bounds.minY, y)), row)

        case .shelf1000, .shelf2000, .shelf3000, .shelf4000:
            let columns = 4
            let column = index % columns
            let row = index / columns
            // Spread across depth (t) near→far, capped short of the far wall.
            let t = ((CGFloat(column) + 0.5) / CGFloat(columns)) * 0.80
            // Stack each row up off the shelf lip (s = 1) toward the ceiling/divider (s = 0).
            let s = max(0.08, 1.0 - CGFloat(row) * 0.22)
            return (bilinearPoint(in: zone, s: s, t: t), row)
        }
    }
}

nonisolated private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
