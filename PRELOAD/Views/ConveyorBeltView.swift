import SwiftUI

/// The belt the boxes ride in on, floating on legs above the dock floor just outside the open
/// truck doors. Its stripes scroll at a rate tied to `beltDistance`, so the belt visibly speeds
/// up as the shift's ramp kicks in.
struct ConveyorBeltView: View {
    let layout: TruckLayout
    let beltDistance: Double
    /// Whether the player's combo has reached fever — the belt's edge and stripes glow to
    /// match the HUD and the loader.
    var isFevered: Bool = false
    /// Power-up effects currently in play. Frozen takes visual priority over slowed, matching
    /// `ShiftEngine.beltSpeedFactor`'s own priority between the two.
    var isFrozen: Bool = false
    var isSlowed: Bool = false

    private let stripeSpacing: CGFloat = 34
    private let rollerDiameter: CGFloat = 14
    private let legWidth: CGFloat = 8

    @State private var feverPulse = false

    var body: some View {
        ZStack {
            dockShadow
            legs
            belt
        }
    }

    // MARK: Floating support

    /// A soft, blurred ellipse on the dock floor below the belt — the thing that actually sells
    /// "floating" rather than "resting directly on the ground."
    private var dockShadow: some View {
        let rect = layout.beltRect
        let dock = layout.dockFloorRect
        return Ellipse()
            .fill(Color.black.opacity(0.35))
            .frame(width: rect.width * 0.7, height: dock.height * 0.4)
            .blur(radius: 6)
            .position(x: rect.midX, y: dock.minY + dock.height * 0.3)
    }

    /// A few steel posts planting the belt onto the dock floor.
    private var legs: some View {
        let rect = layout.beltRect
        let dock = layout.dockFloorRect
        let legHeight = dock.minY + dock.height * 0.6 - rect.maxY
        // Flanking the center rather than a leg dead in the middle, so none of them cross
        // through the "RERUN" stencil centered on the tray below.
        let positions: [CGFloat] = [rect.width * 0.12, rect.width * 0.32, rect.width * 0.68, rect.width * 0.88]

        return ZStack {
            ForEach(Array(positions.enumerated()), id: \.offset) { _, x in
                VStack(spacing: 0) {
                    Rectangle().fill(legGradient).frame(width: legWidth, height: legHeight)
                    RoundedRectangle(cornerRadius: 2).fill(Color(white: 0.2)).frame(width: legWidth * 2.2, height: 5)
                }
                .position(x: x, y: rect.maxY + legHeight / 2)
            }
        }
    }

    private var legGradient: LinearGradient {
        LinearGradient(colors: [Color(white: 0.5), Color(white: 0.25)], startPoint: .leading, endPoint: .trailing)
    }

    // MARK: Belt body

    private var belt: some View {
        let rect = layout.beltRect
        return Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(beltBaseColor))

            let offset = CGFloat(beltDistance.truncatingRemainder(dividingBy: 1)) * stripeSpacing
            var x = -stripeSpacing + offset
            while x < size.width {
                let stripe = Path(CGRect(x: x, y: 0, width: stripeSpacing * 0.45, height: size.height))
                context.fill(stripe, with: .color(isFevered ? Color.orange.opacity(0.4) : Color.black.opacity(0.22)))
                x += stripeSpacing
            }

            let rollerY = size.height / 2
            var rollerX = rollerDiameter
            while rollerX < size.width {
                let roller = Path(ellipseIn: CGRect(
                    x: rollerX - rollerDiameter / 2,
                    y: rollerY - rollerDiameter / 2,
                    width: rollerDiameter,
                    height: rollerDiameter
                ))
                context.fill(roller, with: .color(.black.opacity(0.12)))
                rollerX += rollerDiameter * 3
            }
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(isFevered ? AnyShapeStyle(feverGradient) : AnyShapeStyle(Color.black.opacity(0.4)))
                .frame(height: isFevered ? 3 : 2)
                .shadow(color: .orange, radius: isFevered && feverPulse ? 10 : 2)
        }
        .overlay(alignment: .bottom) {
            // A darker rail along the belt's underside, showing its thickness so it reads as a
            // solid object floating on its legs rather than a flat stripe painted on the floor.
            Rectangle()
                .fill(Color(white: 0.08))
                .frame(height: 6)
                .offset(y: 6)
        }
        .overlay {
            // A cheap full-rect tint so a freeze or slow is readable at a glance, not just
            // something you infer from the stripes crawling slower.
            if isFrozen {
                Color.cyan.opacity(0.3).allowsHitTesting(false)
            } else if isSlowed {
                Color.purple.opacity(0.2).allowsHitTesting(false)
            }
        }
        .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
        .task(id: isFevered) {
            if isFevered {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    feverPulse = true
                }
            } else {
                withAnimation(.easeInOut(duration: 0.2)) { feverPulse = false }
            }
        }
    }

    private var beltBaseColor: Color {
        Color(red: 0.14, green: 0.14, blue: 0.16)
    }

    private var feverGradient: LinearGradient {
        LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
    }
}
