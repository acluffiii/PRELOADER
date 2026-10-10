import Testing
import SwiftUI
@testable import MyApp

struct TruckLayoutTests {
    private let layout = TruckLayout(size: CGSize(width: 800, height: 400))

    @Test("Each zone's own centroid falls inside that zone", arguments: LoadZone.allCases)
    func zoneAnchorsResolveToThemselves(zone: LoadZone) {
        let anchor = layout.zoneAnchor(for: zone)
        #expect(layout.zone(at: anchor) == zone)
    }

    @Test("Zones don't overlap")
    func zonesDoNotOverlap() {
        for zone in LoadZone.allCases {
            let anchor = layout.zoneAnchor(for: zone)
            let hits = LoadZone.allCases.filter { layout.path(for: $0).contains(anchor) }
            #expect(hits == [zone])
        }
    }

    @Test("Every interior zone (shelves, roof) lies inside the truck's door opening")
    func interiorZonesLieInsideOpening() {
        for zone in LoadZone.allCases where zone != .rerun {
            #expect(layout.truckOpening.contains(layout.zoneAnchor(for: zone)))
        }
    }

    @Test("Rerun sits outside the truck entirely, in the dock floor strip below the belt")
    func rerunSitsInDockFloor() {
        #expect(layout.path(for: .rerun).boundingRect == layout.dockFloorRect)
        #expect(!layout.truckOpening.contains(layout.zoneAnchor(for: .rerun)))
    }

    @Test("A thin gap between shelf1000 and shelf2000 belongs to neither")
    func shelfGapIsUnclaimed() {
        #expect(hasGap(between: .shelf1000, and: .shelf2000))
    }

    @Test("A thin gap between shelf3000 and shelf4000 belongs to neither")
    func otherShelfGapIsUnclaimed() {
        #expect(hasGap(between: .shelf3000, and: .shelf4000))
    }

    /// Scans a vertical line near the opening's edge between two (vertically stacked) zones'
    /// centroids, looking for any point that belongs to neither — proving a real gap exists
    /// without needing to know the layout's private gap-fraction constant.
    private func hasGap(between upper: LoadZone, and lower: LoadZone) -> Bool {
        let x = upper == .shelf1000 || lower == .shelf1000 ? layout.truckOpening.minX + 1 : layout.truckOpening.maxX - 1
        var y = layout.zoneAnchor(for: upper).y
        let endY = layout.zoneAnchor(for: lower).y
        while y < endY {
            if layout.zone(at: CGPoint(x: x, y: y)) == nil {
                return true
            }
            y += 0.5
        }
        return false
    }

    @Test("1000 sits above 2000 on the left; 3000 sits above 4000 on the right")
    func shelvesAreStackedOnTheCorrectSide() {
        let shelf1000 = layout.zoneAnchor(for: .shelf1000)
        let shelf2000 = layout.zoneAnchor(for: .shelf2000)
        let shelf3000 = layout.zoneAnchor(for: .shelf3000)
        let shelf4000 = layout.zoneAnchor(for: .shelf4000)
        let centerX = layout.size.width / 2

        #expect(shelf1000.y < shelf2000.y)
        #expect(shelf3000.y < shelf4000.y)
        #expect(shelf1000.x < centerX)
        #expect(shelf2000.x < centerX)
        #expect(shelf3000.x > centerX)
        #expect(shelf4000.x > centerX)
    }

    @Test("The roof sits on the far wall, centered between the shelf columns")
    func roofSitsTopMiddle() {
        let roof = layout.zoneAnchor(for: .roof)
        let shelf1000 = layout.zoneAnchor(for: .shelf1000)
        let shelf3000 = layout.zoneAnchor(for: .shelf3000)
        let centerX = layout.size.width / 2

        #expect(abs(roof.x - centerX) < layout.truckOpening.width * 0.2)
        #expect(roof.x > shelf1000.x)
        #expect(roof.x < shelf3000.x)
        #expect(abs(roof.y - layout.truckOpening.midY) < layout.truckOpening.height * 0.3)
    }

    @Test("The belt floats above the truck's floor and short of the bottom edge")
    func beltFloats() {
        #expect(layout.beltRect.minY >= layout.truckBottom)
        #expect(layout.beltRect.maxY < layout.size.height)
    }

    @Test("The belt, the rerun tray, and the open doors each resolve correctly")
    func beltAndOutsideResolveCorrectly() {
        let beltPoint = CGPoint(x: layout.beltRect.midX, y: layout.beltRect.midY)
        #expect(layout.zone(at: beltPoint) == nil)

        // The dock floor beneath the belt is the rerun tray's own footprint now, not empty space.
        let dockPoint = CGPoint(x: layout.dockFloorRect.midX, y: layout.dockFloorRect.midY)
        #expect(layout.zone(at: dockPoint) == .rerun)

        let aboveTruck = CGPoint(x: 400, y: -20)
        #expect(layout.zone(at: aboveTruck) == nil)

        let farOffToTheSide = CGPoint(x: -500, y: 100)
        #expect(layout.zone(at: farOffToTheSide) == nil)
    }

    @Test("Belt progress maps monotonically from the start to the end of the belt")
    func beltPositionMonotonic() {
        let start = layout.beltPosition(progress: 0)
        let middle = layout.beltPosition(progress: 0.5)
        let end = layout.beltPosition(progress: 1)

        #expect(start.x < middle.x)
        #expect(middle.x < end.x)
    }

    @Test("The worker stands centered")
    func workerFrameIsCentered() {
        #expect(abs(layout.workerFrame.midX - layout.size.width / 2) < 0.001)
    }

    @Test("The loader's hands sit within the floor's footprint, just above the belt")
    func handsPositionIsOnFloorAboveBelt() {
        let hands = layout.handsPosition
        #expect(layout.floorPath.contains(hands))
        #expect(hands.y < layout.beltRect.minY)
    }

    @Test("The first several boxes stacked in each zone land back inside that zone", arguments: LoadZone.allCases)
    func stackPositionsResolveToTheirOwnZone(zone: LoadZone) {
        for index in 0..<8 {
            let point = layout.stackPosition(in: zone, index: index)
            #expect(layout.zone(at: point) == zone)
        }
    }
}
