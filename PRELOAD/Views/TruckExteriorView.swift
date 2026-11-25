import SwiftUI

/// Everything outside the open doors: the dock backdrop and floor, the van's painted rear body
/// wrapped around the doorway, its roof marker lights and taillights, the open barn doors swung
/// out to the screen edges, and the bumper/wheels below. Drawn first, behind
/// `TruckInteriorView`, so the interior reads as a deep opening cut into a real vehicle rather
/// than a flat room filling the whole screen. Purely decorative: never hit-tests.
///
/// The body, doors, and bumper wear the poster's white panel and orange stripe. Opening, door,
/// and bumper frames are the same rects as before — only the paint changed.
struct TruckExteriorView: View {
    let layout: TruckLayout

    var body: some View {
        let opening = layout.truckOpening

        ZStack {
            dockBackdrop
            vanBody(around: opening)
            roofMarkerLights(around: opening)
            taillights(around: opening)
            openDoor(mirrored: false, opening: opening)
            openDoor(mirrored: true, opening: opening)
            sillAndBumper(below: opening)
        }
        .allowsHitTesting(false)
    }

    // MARK: Dock backdrop

    private var dockBackdrop: some View {
        ZStack(alignment: .bottom) {
            sky
                .frame(width: layout.size.width, height: layout.size.height)
            dockFloor.frame(width: layout.size.width, height: layout.dockFloorRect.height)
        }
    }

    /// Poster sky: a flat blue field, a pale disc, and a triangle. No blur — the grain lives
    /// in the home-screen bitmap, and a noise fill here would be per-frame work for nothing.
    private var sky: some View {
        ZStack {
            LinearGradient(
                colors: [ArtPalette.skyTop, ArtPalette.sky, ArtPalette.skyDeep],
                startPoint: .top,
                endPoint: .bottom
            )
            Circle()
                .fill(Color.white.opacity(0.16))
                .frame(width: layout.size.width * 0.16, height: layout.size.width * 0.16)
                .position(x: layout.size.width * 0.12, y: layout.size.height * 0.16)
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: layout.size.width * 0.07, height: layout.size.width * 0.07)
                .position(x: layout.size.width * 0.22, y: layout.size.height * 0.08)
            SkyTriangle()
                .fill(Color.white.opacity(0.14))
                .frame(width: layout.size.height * 0.09, height: layout.size.height * 0.08)
                .position(x: layout.size.width * 0.90, y: layout.size.height * 0.10)
        }
    }

    private var dockFloor: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.16, green: 0.20, blue: 0.24)))
            var y: CGFloat = 0
            while y < size.height {
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(line, with: .color(.black.opacity(0.18)), lineWidth: 1)
                y += 14
            }
        }
    }

    // MARK: Van body

    /// The painted rear panel wrapping the doorway and the roof edge — the part of the van
    /// you'd see if the doors weren't there. Filled as a plain rect rather than punching a hole
    /// for the opening: `TruckInteriorView` draws on top of this in `ShiftView` and already
    /// covers the opening completely, so there's nothing to subtract. The orange band therefore
    /// shows on the two rear pillars once the interior is composited on top.
    private func vanBody(around opening: CGRect) -> some View {
        let bodyInset = layout.size.width * 0.03
        let bodyTop = layout.size.height * 0.01
        let bodyBottom = layout.size.height * 0.82
        let bodyRect = CGRect(x: bodyInset, y: bodyTop, width: layout.size.width - bodyInset * 2, height: bodyBottom - bodyTop)
        let stripeHeight = max(6, bodyRect.height * 0.055)
        let stripeY = bodyRect.minY + bodyRect.height * 0.62

        return ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(vanBodyGradient)
                .frame(width: bodyRect.width, height: bodyRect.height)
                .position(x: bodyRect.midX, y: bodyRect.midY)

            Rectangle()
                .fill(ArtPalette.orange)
                .frame(width: bodyRect.width, height: stripeHeight)
                .position(x: bodyRect.midX, y: stripeY)

            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.black.opacity(0.45), lineWidth: 1.5)
                .frame(width: bodyRect.width, height: bodyRect.height)
                .position(x: bodyRect.midX, y: bodyRect.midY)

            Rectangle()
                .strokeBorder(Color.black.opacity(0.6), lineWidth: 2)
                .frame(width: opening.width, height: opening.height)
                .position(x: opening.midX, y: opening.midY)

            // The rolled-up door drum tucked just above the opening.
            VStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle().fill(ArtPalette.steelLight.opacity(0.85))
                }
            }
            .frame(width: opening.width, height: 10)
            .background(ArtPalette.steel)
            .position(x: opening.midX, y: opening.minY - 7)
        }
    }

    private var vanBodyGradient: LinearGradient {
        LinearGradient(colors: [ArtPalette.vanWhite, ArtPalette.vanShade], startPoint: .top, endPoint: .bottom)
    }

    /// Small amber marker lights along the roofline, standard on a box van.
    private func roofMarkerLights(around opening: CGRect) -> some View {
        HStack(spacing: layout.size.width * 0.06) {
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(ArtPalette.orange)
                    .frame(width: 7, height: 7)
                    .overlay(Circle().fill(Color.white.opacity(0.4)).frame(width: 3, height: 3))
            }
        }
        .position(x: opening.midX, y: layout.size.height * 0.025)
    }

    /// Vertical red taillight strips flanking the opening, just outside the door posts.
    private func taillights(around opening: CGRect) -> some View {
        let width: CGFloat = 8
        let height = opening.height * 0.22
        return ZStack {
            taillight.frame(width: width, height: height).position(x: opening.minX - 12, y: opening.maxY - height * 0.4)
            taillight.frame(width: width, height: height).position(x: opening.maxX + 12, y: opening.maxY - height * 0.4)
        }
    }

    private var taillight: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(LinearGradient(colors: [Color.red, Color.red.opacity(0.55)], startPoint: .top, endPoint: .bottom))
            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Color.black.opacity(0.5), lineWidth: 1))
    }

    // MARK: Open doors

    /// One barn door, swung fully open so it reads edge-on in the margin beside the opening —
    /// white panels, a window, and the same orange band as the body.
    private func openDoor(mirrored: Bool, opening: CGRect) -> some View {
        let margin = opening.minX
        let doorWidth = margin * 0.55
        let x = mirrored ? layout.size.width - margin * 0.65 : margin * 0.65
        let doorHeight = opening.height * 0.92

        return VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(ArtPalette.vanWhite)
                .frame(width: doorWidth, height: doorHeight * 0.22)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ArtPalette.sky.opacity(0.85))
                        .padding(4)
                )
            Rectangle()
                .fill(ArtPalette.vanWhite)
                .frame(width: doorWidth, height: doorHeight * 0.34)
            Rectangle()
                .fill(ArtPalette.orange)
                .frame(width: doorWidth, height: doorHeight * 0.07)
            Rectangle()
                .fill(ArtPalette.vanShade)
                .frame(width: doorWidth, height: doorHeight * 0.33)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(Color.black.opacity(0.4), lineWidth: 1)
        )
        .position(x: x, y: opening.minY + doorHeight / 2 + opening.height * 0.02)
    }

    // MARK: Sill, bumper, wheels

    /// The step plate, bumper, and tires below the opening — mostly hidden behind the floating
    /// belt, but visible at its edges so the truck still reads as sitting on the ground.
    private func sillAndBumper(below opening: CGRect) -> some View {
        let sillTop = opening.maxY
        let bumperBottom = layout.size.height * 0.80
        let height = bumperBottom - sillTop

        return ZStack(alignment: .top) {
            Rectangle()
                .fill(sillGradient)
                .frame(width: opening.width + layout.size.width * 0.02, height: height)
                .position(x: opening.midX, y: sillTop + height / 2)

            Rectangle()
                .fill(ArtPalette.orange)
                .frame(width: opening.width * 0.7, height: 3)
                .position(x: opening.midX, y: sillTop + 4)

            HStack(spacing: opening.width * 0.5) {
                wheel
                wheel
            }
            .position(x: opening.midX, y: bumperBottom - 4)
        }
    }

    private var wheel: some View {
        ZStack {
            Circle().fill(Color.black.opacity(0.92))
            Circle().fill(Color(white: 0.28)).frame(width: 12, height: 12)
            Circle().fill(ArtPalette.vanShade).frame(width: 5, height: 5)
        }
        .frame(width: 22, height: 22)
    }

    private var sillGradient: LinearGradient {
        LinearGradient(colors: [ArtPalette.vanShade, Color(white: 0.16)], startPoint: .top, endPoint: .bottom)
    }
}

private struct SkyTriangle: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.midX, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview("Exterior only", traits: .fixedLayout(width: 844, height: 390)) {
    GeometryReader { proxy in
        TruckExteriorView(layout: TruckLayout(size: proxy.size))
    }
    .background(Color.black)
}
