import SwiftUI

/// What the loader is doing right now. `towardLeft`/`high` describe which shelf he's tossing a
/// box toward, in the same left/right and upper/lower sense as `LoadZone` (1000/2000 are the
/// left-side shelves, 1000/3000 are the upper shelves).
nonisolated enum LoaderPose: Equatable {
    case idle
    case reaching
    case holding
    case tossing(towardLeft: Bool, high: Bool)
}

/// The low-poly warehouse loader from the app icon and home poster — cap, mustache, brown
/// uniform — rebuilt from flat SwiftUI shapes so he can crouch, reach, hold a box, and toss it
/// toward a shelf. Every measurement is relative to `height`, so the whole figure scales as a
/// single unit. Purely decorative: never hit-tests, so taps still reach the floor and belt
/// behind him.
struct LoaderFigure: View {
    var pose: LoaderPose
    var isFevered: Bool = false
    var height: CGFloat = 150

    @State private var breathe = false

    private var s: CGFloat { height / 150 }
    private var rig: PoseRig { PoseRig(pose: pose) }

    var body: some View {
        let rig = rig
        ZStack(alignment: .top) {
            legs
            upperBody(rig: rig)
        }
        .frame(width: 70 * s, height: height)
        .offset(y: breathe ? -1.5 * s : 1.5 * s)
        .animation(.spring(duration: 0.35), value: pose)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: Upper body (torso, head, arms) — the part that leans and crouches as a unit

    private func upperBody(rig: PoseRig) -> some View {
        ZStack(alignment: .top) {
            arm(rig.leftArm, mirrored: true).offset(x: -24 * s, y: 18 * s)
            arm(rig.rightArm, mirrored: false).offset(x: 24 * s, y: 18 * s)

            torso

            head(rig: rig)
                .offset(y: -16 * s)
        }
        .rotationEffect(.degrees(rig.lean), anchor: .bottom)
        .offset(y: rig.crouch * 16 * s)
    }

    // MARK: Head

    private func head(rig: PoseRig) -> some View {
        ZStack {
            Circle().fill(skin).frame(width: 32 * s, height: 32 * s)

            Capsule().fill(hairColor).frame(width: 18 * s, height: 6 * s).offset(y: 6 * s)

            HStack(spacing: 10 * s) {
                eye
                eye
            }
            .offset(y: -2 * s)

            HStack(spacing: 8 * s) {
                Capsule().fill(hairColor).frame(width: 9 * s, height: 3 * s).rotationEffect(.degrees(-10))
                Capsule().fill(hairColor).frame(width: 9 * s, height: 3 * s).rotationEffect(.degrees(10))
            }
            .offset(y: -9 * s)

            mouth

            cap

            if isFevered {
                sparks
            } else {
                sweatDrops
            }
        }
        .rotationEffect(.degrees(rig.headTilt))
        .frame(width: 32 * s, height: 32 * s)
    }

    private var eye: some View {
        ZStack {
            Ellipse().fill(.white).frame(width: 7 * s, height: 5 * s)
            Circle().fill(.black).frame(width: 3 * s, height: 3 * s)
        }
    }

    private var mouth: some View {
        Group {
            if isFevered {
                Smile()
                    .stroke(Color.black.opacity(0.85), style: StrokeStyle(lineWidth: 2.5 * s, lineCap: .round))
                    .frame(width: 15 * s, height: 7 * s)
                    .offset(y: 9 * s)
            } else {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.black.opacity(0.85))
                    .frame(width: 13 * s, height: 3.5 * s)
                    .offset(y: 11.5 * s)
            }
        }
    }

    private var cap: some View {
        ZStack(alignment: .top) {
            Capsule().fill(capShade).frame(width: 34 * s, height: 7 * s).offset(y: -9 * s)
            RoundedRectangle(cornerRadius: 6 * s).fill(capColor).frame(width: 30 * s, height: 16 * s).offset(y: -18 * s)
            Circle().fill(capShade).frame(width: 4 * s, height: 4 * s).offset(y: -25 * s)
        }
    }

    private var sweatDrops: some View {
        ZStack {
            dropShape.offset(x: -20 * s, y: -14 * s)
            dropShape.offset(x: 18 * s, y: -10 * s).scaleEffect(0.8)
        }
    }

    private var dropShape: some View {
        Ellipse().fill(Color.white.opacity(0.85)).frame(width: 5 * s, height: 8 * s)
    }

    private var sparks: some View {
        ZStack {
            sparkLine.rotationEffect(.degrees(-30)).offset(x: -20 * s, y: -16 * s)
            sparkLine.rotationEffect(.degrees(30)).offset(x: 20 * s, y: -16 * s)
            sparkLine.rotationEffect(.degrees(0)).offset(x: 0, y: -26 * s)
        }
        .opacity(breathe ? 1 : 0.55)
    }

    private var sparkLine: some View {
        Capsule().fill(Color.orange).frame(width: 2.5 * s, height: 10 * s)
    }

    // MARK: Torso

    private var torso: some View {
        ZStack {
            TorsoShape().fill(shirtColor).frame(width: 52 * s, height: 50 * s)
            TorsoShape().stroke(shirtShadow, lineWidth: 1).frame(width: 52 * s, height: 50 * s)

            Triangle().fill(.white.opacity(0.9)).frame(width: 14 * s, height: 16 * s).offset(y: -14 * s)

            VStack(spacing: 6 * s) {
                Circle().fill(shirtShadow).frame(width: 3 * s, height: 3 * s)
                Circle().fill(shirtShadow).frame(width: 3 * s, height: 3 * s)
            }
            .offset(y: 2 * s)
        }
        .offset(y: 6 * s)
    }

    // MARK: Arms — a two-bone chain: the whole arm rotates at the shoulder, and the
    // forearm+hand rotates again at the elbow, so each joint animates independently. Both
    // angles are given for the screen-right arm; mirroring the screen-left arm means negating
    // both (negating only the shoulder would leave its elbow bending the wrong way).
    private func arm(_ angles: ArmAngles, mirrored: Bool) -> some View {
        let shoulder = mirrored ? -angles.shoulder : angles.shoulder
        let elbow = mirrored ? -angles.elbow : angles.elbow
        return VStack(spacing: -2 * s) {
            Capsule().fill(shirtColor).frame(width: 20 * s, height: 10 * s)
            Capsule().fill(skin).frame(width: 15 * s, height: 28 * s)
            VStack(spacing: 0) {
                Capsule().fill(skin).frame(width: 13 * s, height: 24 * s)
                Circle().fill(skin).frame(width: 15 * s, height: 15 * s)
            }
            .rotationEffect(.degrees(elbow), anchor: .top)
        }
        .rotationEffect(.degrees(shoulder), anchor: .top)
    }

    // MARK: Legs

    private var legs: some View {
        HStack(spacing: 6 * s) {
            leg
            leg
        }
        .offset(y: 54 * s)
    }

    private var leg: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 4 * s).fill(pantsColor).frame(width: 18 * s, height: 40 * s)
            RoundedRectangle(cornerRadius: 3 * s).fill(shoeColor).frame(width: 20 * s, height: 10 * s)
        }
    }

    // MARK: Palette — matches the poster

    private var skin: Color { Color(red: 0.62, green: 0.45, blue: 0.32) }
    private var hairColor: Color { Color(red: 0.18, green: 0.13, blue: 0.10) }
    private var capColor: Color { Color(red: 0.42, green: 0.30, blue: 0.18) }
    private var capShade: Color { Color(red: 0.33, green: 0.23, blue: 0.14) }
    private var shirtColor: Color { Color(red: 0.47, green: 0.36, blue: 0.24) }
    private var shirtShadow: Color { Color(red: 0.33, green: 0.25, blue: 0.16) }
    private var pantsColor: Color { Color(red: 0.30, green: 0.27, blue: 0.24) }
    private var shoeColor: Color { Color(red: 0.16, green: 0.14, blue: 0.13) }
}

/// One arm's joint angles, in degrees, measured for the screen-right arm with 0° hanging
/// straight down; `LoaderFigure.arm` mirrors the shoulder angle for the screen-left side.
private struct ArmAngles {
    var shoulder: Double
    var elbow: Double
}

/// Translates a `LoaderPose` into concrete joint angles, body lean, crouch, and head tilt.
private struct PoseRig {
    var leftArm: ArmAngles
    var rightArm: ArmAngles
    var lean: Double
    var crouch: Double
    var headTilt: Double

    init(pose: LoaderPose) {
        switch pose {
        case .idle:
            // Between boxes, but alert: a slight athletic crouch, elbows bent with hands raised
            // a little in front rather than fully slack — reads as "ready to grab the next one,"
            // not off-duty. This is the pose he spends the most time in, so it matters most.
            leftArm = ArmAngles(shoulder: -20, elbow: 30)
            rightArm = ArmAngles(shoulder: -20, elbow: 30)
            lean = 0
            crouch = 0.2
            headTilt = 4

        case .reaching:
            // Both arms swing down and slightly apart toward the belt; the whole body dips.
            leftArm = ArmAngles(shoulder: -25, elbow: 10)
            rightArm = ArmAngles(shoulder: -25, elbow: 10)
            lean = 0
            crouch = 1
            headTilt = 12

        case .holding:
            // Forearms swing up in front of the chest, cradling a box.
            leftArm = ArmAngles(shoulder: -45, elbow: 95)
            rightArm = ArmAngles(shoulder: -45, elbow: 95)
            lean = 0
            crouch = 0.3
            headTilt = 6

        case let .tossing(towardLeft, high):
            let lead = ArmAngles(shoulder: high ? -165 : -100, elbow: high ? -15 : -35)
            let trail = ArmAngles(shoulder: -25, elbow: 45)
            leftArm = towardLeft ? lead : trail
            rightArm = towardLeft ? trail : lead
            lean = towardLeft ? -16 : 16
            crouch = high ? 0 : 0.45
            headTilt = (towardLeft ? -10 : 10) + (high ? -8 : 6)
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

/// A trapezoid, wider at the shoulders than the waist.
private struct TorsoShape: Shape {
    func path(in rect: CGRect) -> Path {
        let shoulderInset = rect.width * 0.02
        let waistInset = rect.width * 0.12
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + shoulderInset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - shoulderInset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - waistInset, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + waistInset, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct Smile: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

#Preview("Poses") {
    HStack(alignment: .bottom, spacing: 24) {
        VStack { LoaderFigure(pose: .idle); Text("idle").foregroundStyle(.white) }
        VStack { LoaderFigure(pose: .reaching); Text("reaching").foregroundStyle(.white) }
        VStack { LoaderFigure(pose: .holding); Text("holding").foregroundStyle(.white) }
        VStack { LoaderFigure(pose: .tossing(towardLeft: true, high: true)); Text("toss L hi").foregroundStyle(.white) }
        VStack { LoaderFigure(pose: .tossing(towardLeft: false, high: false)); Text("toss R lo").foregroundStyle(.white) }
    }
    .padding(40)
    .background(Color(white: 0.15))
}

#Preview("Fevered") {
    HStack(spacing: 24) {
        LoaderFigure(pose: .idle, isFevered: true)
        LoaderFigure(pose: .holding, isFevered: true)
        LoaderFigure(pose: .tossing(towardLeft: true, high: false), isFevered: true)
    }
    .padding(40)
    .background(Color(white: 0.15))
}
