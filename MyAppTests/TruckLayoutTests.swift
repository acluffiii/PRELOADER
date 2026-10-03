import Testing
import SwiftUI
@testable import MyApp

struct TruckLayoutTests {
    private let layout = TruckLayout(size: CGSize(width: 800, height: 400))

    @Test("The center of each zone's own bounding rect falls inside that zone", arguments: LoadZone.allCases)
    func zoneCentersResolveToThemselves(zone: LoadZone) {
        let bounds = layout.path(for: zone).boundingRect
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        #expect(layout.zone(at: center) == zone)
    }

    @Test("Zones don't overlap")
    func zonesDoNotOverlap() {
        for zone in LoadZone.allCases {
            let bounds = layout.path(for: zone).boundingRect
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            let hits = LoadZone.allCases.filter { layout.path(for: $0).contains(center) }
            #expect(hits == [zone])
        }
    }

    @Test("The belt and areas outside the truck return no zone")
    func beltAndOutsideAreNotZones() {
        let beltPoint = CGPoint(x: layout.beltRect.midX, y: layout.beltRect.midY)
        #expect(layout.zone(at: beltPoint) == nil)

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
}
