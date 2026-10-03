import SwiftUI

/// The belt the boxes ride in on, along the bottom edge nearest the player. Its stripes scroll
/// at a rate tied to `beltDistance`, so the belt visibly speeds up as the shift's ramp kicks in.
struct ConveyorBeltView: View {
    let layout: TruckLayout
    let beltDistance: Double

    private let stripeSpacing: CGFloat = 34
    private let rollerDiameter: CGFloat = 14

    var body: some View {
        let rect = layout.beltRect
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(beltBaseColor))

            let offset = CGFloat(beltDistance.truncatingRemainder(dividingBy: 1)) * stripeSpacing
            var x = -stripeSpacing + offset
            while x < size.width {
                let stripe = Path(CGRect(x: x, y: 0, width: stripeSpacing * 0.45, height: size.height))
                context.fill(stripe, with: .color(.black.opacity(0.22)))
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
            Rectangle().fill(Color.black.opacity(0.4)).frame(height: 2)
        }
    }

    private var beltBaseColor: Color {
        Color(red: 0.14, green: 0.14, blue: 0.16)
    }
}
