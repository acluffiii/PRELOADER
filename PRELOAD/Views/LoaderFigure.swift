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

/// The low-poly warehouse loader from the app icon and home poster — faceted cap, mustache,
/// brown uniform — built from flat polygons so he can crouch, reach, hold a box, and toss it
/// toward a shelf. Joint positions, pose angles, and the figure's frame match the previous rig;
/// only the shapes inside those slots changed. Every measurement is relative to `height`, so the
/// whole figure scales as a single unit. Purely decorative: never hit-tests, so taps still reach
/// the floor and belt behind him.
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
            ear.offset(x: -15 * s, y: 1 * s)
            ear.scaleEffect(x: -1).offset(x: 15 * s, y: 1 * s)

            FacetHead().fill(ArtPalette.skin).frame(width: 32 * s, height: 32 * s)
            FaceShade().fill(ArtPalette.skinShade).frame(width: 32 * s, height: 32 * s)
            ForeheadPlane().fill(ArtPalette.skinLight).frame(width: 32 * s, height: 32 * s)

            HStack(spacing: 10 * s) {
                eye
                eye
            }
            .offset(y: -2 * s)

            HStack(spacing: 8 * s) {
                Brow().fill(ArtPalette.hair).frame(width: 9 * s, height: 3.5 * s)
                Brow().fill(ArtPalette.hair).frame(width: 9 * s, height: 3.5 * s).scaleEffect(x: -1)
            }
            .offset(y: -8 * s)

            FacetNose().fill(ArtPalette.skinShade).frame(width: 5 * s, height: 4 * s).offset(y: 3 * s)

            mouth
            Mustache().fill(ArtPalette.hair).frame(width: 20 * s, height: 6 * s).offset(y: 7 * s)

            cap

            shards

            if isFevered {
                sparks
            } else {
                sweatDrops
            }
        }
        .rotationEffect(.degrees(rig.headTilt))
        .frame(width: 32 * s, height: 32 * s)
    }

    private var ear: some View {
        EarShape().fill(ArtPalette.skinShade).frame(width: 6 * s, height: 9 * s)
    }

    private var eye: some View {
        ZStack {
            EyeWhite().fill(.white).frame(width: 7 * s, height: 5 * s)
            Rectangle().fill(.black).frame(width: 2.6 * s, height: 2.6 * s).offset(y: 0.4 * s)
        }
    }

    /// The icon's open, stressed mouth. Fever swaps in a wider grin so the streak still reads,
    /// without changing the head's slot.
    private var mouth: some View {
        ZStack {
            if isFevered {
                Smile()
                    .stroke(ArtPalette.hair, style: StrokeStyle(lineWidth: 2.2 * s, lineCap: .round))
                    .frame(width: 14 * s, height: 6 * s)
                Rectangle().fill(.white).frame(width: 9 * s, height: 2.4 * s).offset(y: 1.2 * s)
            } else {
                RoundedRectangle(cornerRadius: 1)
                    .fill(ArtPalette.hair)
                    .frame(width: 12 * s, height: 5.5 * s)
                Rectangle().fill(.white).frame(width: 8.5 * s, height: 2.1 * s).offset(y: -0.9 * s)
            }
        }
        .offset(y: 10.5 * s)
    }

    private var cap: some View {
        ZStack(alignment: .top) {
            CapBrim().fill(ArtPalette.capShade).frame(width: 36 * s, height: 7 * s).offset(y: -8 * s)
            CapBrimHighlight().fill(ArtPalette.capLight.opacity(0.85)).frame(width: 36 * s, height: 7 * s).offset(y: -8 * s)

            CapCrown().fill(ArtPalette.cap).frame(width: 30 * s, height: 16 * s).offset(y: -18 * s)
            CapCrownLight().fill(ArtPalette.capLight).frame(width: 30 * s, height: 16 * s).offset(y: -18 * s)
            CapCrownShade().fill(ArtPalette.capShade).frame(width: 30 * s, height: 16 * s).offset(y: -18 * s)

            Diamond().fill(ArtPalette.capLight).frame(width: 4 * s, height: 4 * s).offset(y: -25 * s)
        }
    }

    /// White diamond flecks from the poster, parked around the cap. They ride the head tilt
    /// with him and don't animate on their own.
    private var shards: some View {
        ZStack {
            shard.offset(x: -18 * s, y: -20 * s)
            shard.scaleEffect(0.7).offset(x: 16 * s, y: -22 * s)
            shard.scaleEffect(0.55).offset(x: -8 * s, y: -28 * s)
            shard.scaleEffect(0.8).offset(x: 8 * s, y: -16 * s)
        }
    }

    private var shard: some View {
        Diamond().fill(Color.white.opacity(0.92)).frame(width: 5 * s, height: 5 * s)
    }

    private var sweatDrops: some View {
        ZStack {
            SweatDrop().fill(Color.white.opacity(0.92)).frame(width: 4.5 * s, height: 7 * s).offset(x: -14 * s, y: -2 * s)
            SweatDrop().fill(Color.white.opacity(0.85)).frame(width: 3.5 * s, height: 6 * s).offset(x: 15 * s, y: -6 * s)
        }
    }

    private var sparks: some View {
        ZStack {
            spark.rotationEffect(.degrees(-30)).offset(x: -20 * s, y: -16 * s)
            spark.rotationEffect(.degrees(30)).offset(x: 20 * s, y: -16 * s)
            spark.offset(y: -26 * s)
        }
        .opacity(breathe ? 1 : 0.55)
    }

    private var spark: some View {
        Diamond().fill(ArtPalette.orange).frame(width: 4 * s, height: 11 * s)
    }

    // MARK: Torso

    private var torso: some View {
        ZStack {
            TorsoShape().fill(ArtPalette.shirt).frame(width: 52 * s, height: 50 * s)
            TorsoHighlight().fill(ArtPalette.shirtLight).frame(width: 52 * s, height: 50 * s)
            TorsoShade().fill(ArtPalette.shirtShade).frame(width: 52 * s, height: 50 * s)

            Rectangle()
                .fill(ArtPalette.shirtShade)
                .frame(width: max(1, 1.4 * s), height: 26 * s)
                .offset(y: 6 * s)

            Collar().fill(ArtPalette.collar).frame(width: 16 * s, height: 12 * s).offset(y: -16 * s)

            VStack(spacing: 6 * s) {
                Rectangle().fill(ArtPalette.shirtShade).frame(width: 3.2 * s, height: 3.2 * s)
                Rectangle().fill(ArtPalette.shirtShade).frame(width: 3.2 * s, height: 3.2 * s)
            }
            .offset(y: 4 * s)
        }
        .offset(y: 6 * s)
    }

    // MARK: Arms — a two-bone chain: the whole arm rotates at the shoulder, and the
    // forearm+hand rotates again at the elbow, so each joint animates independently. Both
    // angles are given for the screen-right arm; mirroring the screen-left arm means negating
    // both (negating only the shoulder would leave its elbow bending the wrong way).
    // Slot sizes match the previous capsule rig so the poses land in the same places.
    private func arm(_ angles: ArmAngles, mirrored: Bool) -> some View {
        let shoulder = mirrored ? -angles.shoulder : angles.shoulder
        let elbow = mirrored ? -angles.elbow : angles.elbow
        return VStack(spacing: -2 * s) {
            ShoulderPad()
                .fill(ArtPalette.shirtLight)
                .frame(width: 20 * s, height: 10 * s)
                .scaleEffect(x: mirrored ? -1 : 1)
            Limb(topScale: 1, bottomScale: 0.78).fill(ArtPalette.shirt).frame(width: 15 * s, height: 28 * s)
            VStack(spacing: 0) {
                Limb(topScale: 0.92, bottomScale: 0.7).fill(ArtPalette.shirtShade).frame(width: 13 * s, height: 24 * s)
                hand(mirrored: mirrored)
            }
            .rotationEffect(.degrees(elbow), anchor: .top)
        }
        .rotationEffect(.degrees(shoulder), anchor: .top)
    }

    private func hand(mirrored: Bool) -> some View {
        ZStack {
            HandShape().fill(ArtPalette.skin)
            HandShape().stroke(ArtPalette.skinLight, lineWidth: max(0.8, 1 * s))
            // The poster's bright knuckle edge.
            Rectangle()
                .fill(Color.white.opacity(0.75))
                .frame(width: 9 * s, height: max(1, 1.3 * s))
                .offset(y: 1 * s)
        }
        .frame(width: 15 * s, height: 15 * s)
        .scaleEffect(x: mirrored ? -1 : 1)
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
            ZStack {
                Limb(topScale: 1, bottomScale: 0.82).fill(ArtPalette.pants)
                Limb(topScale: 0.42, bottomScale: 0.32).fill(ArtPalette.pantsShade).offset(x: 3 * s)
            }
            .frame(width: 18 * s, height: 40 * s)
            ShoeShape().fill(ArtPalette.shoe).frame(width: 20 * s, height: 10 * s)
        }
    }
}

// MARK: - Pose rig (unchanged)

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

// MARK: - Facet shapes

private struct FacetHead: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.width * 0.22, y: r.height * 0.08))
        path.addLine(to: CGPoint(x: r.width * 0.78, y: r.height * 0.08))
        path.addLine(to: CGPoint(x: r.width * 0.97, y: r.height * 0.34))
        path.addLine(to: CGPoint(x: r.width * 0.90, y: r.height * 0.68))
        path.addLine(to: CGPoint(x: r.width * 0.64, y: r.height * 0.98))
        path.addLine(to: CGPoint(x: r.width * 0.36, y: r.height * 0.98))
        path.addLine(to: CGPoint(x: r.width * 0.10, y: r.height * 0.68))
        path.addLine(to: CGPoint(x: r.width * 0.03, y: r.height * 0.34))
        path.closeSubpath()
        return path
    }
}

private struct FaceShade: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.width * 0.56, y: r.height * 0.10))
        path.addLine(to: CGPoint(x: r.width * 0.96, y: r.height * 0.34))
        path.addLine(to: CGPoint(x: r.width * 0.88, y: r.height * 0.70))
        path.addLine(to: CGPoint(x: r.width * 0.62, y: r.height * 0.97))
        path.addLine(to: CGPoint(x: r.width * 0.46, y: r.height * 0.58))
        path.closeSubpath()
        return path
    }
}

private struct ForeheadPlane: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.width * 0.26, y: r.height * 0.14))
        path.addLine(to: CGPoint(x: r.width * 0.68, y: r.height * 0.12))
        path.addLine(to: CGPoint(x: r.width * 0.60, y: r.height * 0.34))
        path.addLine(to: CGPoint(x: r.width * 0.30, y: r.height * 0.36))
        path.closeSubpath()
        return path
    }
}

private struct EarShape: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.width * 0.7, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.height * 0.35))
        path.addLine(to: CGPoint(x: r.width * 0.85, y: r.maxY))
        path.addLine(to: CGPoint(x: r.width * 0.15, y: r.height * 0.7))
        path.closeSubpath()
        return path
    }
}

private struct EyeWhite: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.minX, y: r.midY))
        path.addLine(to: CGPoint(x: r.width * 0.32, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.height * 0.28))
        path.addLine(to: CGPoint(x: r.width * 0.68, y: r.maxY))
        path.closeSubpath()
        return path
    }
}

private struct Brow: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.minX, y: r.height * 0.75))
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.height * 0.45))
        path.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        path.closeSubpath()
        return path
    }
}

private struct FacetNose: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.midX, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.height * 0.8))
        path.closeSubpath()
        return path
    }
}

private struct Mustache: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.midX, y: r.height * 0.28))
        path.addLine(to: CGPoint(x: r.minX, y: r.height * 0.05))
        path.addLine(to: CGPoint(x: r.width * 0.06, y: r.height * 0.78))
        path.addLine(to: CGPoint(x: r.midX, y: r.height * 0.48))
        path.addLine(to: CGPoint(x: r.width * 0.94, y: r.height * 0.78))
        path.addLine(to: CGPoint(x: r.maxX, y: r.height * 0.05))
        path.closeSubpath()
        return path
    }
}

private struct CapCrown: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.width * 0.30, y: r.height * 0.06))
        path.addLine(to: CGPoint(x: r.width * 0.70, y: r.height * 0.06))
        path.addLine(to: CGPoint(x: r.width * 0.98, y: r.maxY))
        path.addLine(to: CGPoint(x: r.width * 0.02, y: r.maxY))
        path.closeSubpath()
        return path
    }
}

private struct CapCrownLight: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.width * 0.30, y: r.height * 0.06))
        path.addLine(to: CGPoint(x: r.width * 0.52, y: r.height * 0.06))
        path.addLine(to: CGPoint(x: r.width * 0.46, y: r.maxY))
        path.addLine(to: CGPoint(x: r.width * 0.02, y: r.maxY))
        path.closeSubpath()
        return path
    }
}

private struct CapCrownShade: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.width * 0.62, y: r.height * 0.08))
        path.addLine(to: CGPoint(x: r.width * 0.70, y: r.height * 0.06))
        path.addLine(to: CGPoint(x: r.width * 0.98, y: r.maxY))
        path.addLine(to: CGPoint(x: r.width * 0.58, y: r.maxY))
        path.closeSubpath()
        return path
    }
}

private struct CapBrim: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.width * 0.08, y: r.height * 0.25))
        path.addLine(to: CGPoint(x: r.width * 0.92, y: r.height * 0.25))
        path.addLine(to: CGPoint(x: r.maxX, y: r.height * 0.62))
        path.addLine(to: CGPoint(x: r.width * 0.90, y: r.maxY))
        path.addLine(to: CGPoint(x: r.width * 0.10, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.height * 0.62))
        path.closeSubpath()
        return path
    }
}

/// A thin lighter strip along the brim's top edge.
private struct CapBrimHighlight: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.width * 0.12, y: r.height * 0.25))
        path.addLine(to: CGPoint(x: r.width * 0.88, y: r.height * 0.25))
        path.addLine(to: CGPoint(x: r.width * 0.82, y: r.height * 0.48))
        path.addLine(to: CGPoint(x: r.width * 0.18, y: r.height * 0.48))
        path.closeSubpath()
        return path
    }
}

private struct Diamond: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.midX, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        path.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.midY))
        path.closeSubpath()
        return path
    }
}

private struct SweatDrop: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.midX, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.height * 0.62))
        path.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.height * 0.62))
        path.closeSubpath()
        return path
    }
}

/// A trapezoid with peaked shoulders, wider across the chest than the waist.
private struct TorsoShape: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.width * 0.06, y: r.height * 0.18))
        path.addLine(to: CGPoint(x: r.width * 0.20, y: r.minY))
        path.addLine(to: CGPoint(x: r.width * 0.80, y: r.minY))
        path.addLine(to: CGPoint(x: r.width * 0.94, y: r.height * 0.18))
        path.addLine(to: CGPoint(x: r.width * 0.84, y: r.maxY))
        path.addLine(to: CGPoint(x: r.width * 0.16, y: r.maxY))
        path.closeSubpath()
        return path
    }
}

private struct TorsoHighlight: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.width * 0.20, y: r.minY))
        path.addLine(to: CGPoint(x: r.width * 0.48, y: r.minY))
        path.addLine(to: CGPoint(x: r.width * 0.42, y: r.maxY))
        path.addLine(to: CGPoint(x: r.width * 0.16, y: r.maxY))
        path.addLine(to: CGPoint(x: r.width * 0.06, y: r.height * 0.18))
        path.closeSubpath()
        return path
    }
}

private struct TorsoShade: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.width * 0.58, y: r.minY))
        path.addLine(to: CGPoint(x: r.width * 0.80, y: r.minY))
        path.addLine(to: CGPoint(x: r.width * 0.94, y: r.height * 0.18))
        path.addLine(to: CGPoint(x: r.width * 0.84, y: r.maxY))
        path.addLine(to: CGPoint(x: r.width * 0.52, y: r.maxY))
        path.closeSubpath()
        return path
    }
}

private struct Collar: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.minX, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        path.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        path.closeSubpath()
        return path
    }
}

private struct ShoulderPad: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.width * 0.12, y: r.maxY))
        path.addLine(to: CGPoint(x: r.width * 0.04, y: r.height * 0.35))
        path.addLine(to: CGPoint(x: r.width * 0.38, y: r.minY))
        path.addLine(to: CGPoint(x: r.width * 0.96, y: r.height * 0.18))
        path.addLine(to: CGPoint(x: r.width * 0.88, y: r.maxY))
        path.closeSubpath()
        return path
    }
}

/// A tapered quad. `topScale` / `bottomScale` are fractions of the full width.
private struct Limb: Shape {
    var topScale: CGFloat = 1
    var bottomScale: CGFloat = 0.75

    func path(in r: CGRect) -> Path {
        let topInset = r.width * (1 - topScale) / 2
        let bottomInset = r.width * (1 - bottomScale) / 2
        var path = Path()
        path.move(to: CGPoint(x: topInset, y: r.minY))
        path.addLine(to: CGPoint(x: r.width - topInset, y: r.minY))
        path.addLine(to: CGPoint(x: r.width - bottomInset, y: r.maxY))
        path.addLine(to: CGPoint(x: bottomInset, y: r.maxY))
        path.closeSubpath()
        return path
    }
}

private struct HandShape: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.width * 0.18, y: r.minY))
        path.addLine(to: CGPoint(x: r.width * 0.82, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.height * 0.42))
        path.addLine(to: CGPoint(x: r.width * 0.74, y: r.maxY))
        path.addLine(to: CGPoint(x: r.width * 0.52, y: r.height * 0.72))
        path.addLine(to: CGPoint(x: r.width * 0.36, y: r.maxY))
        path.addLine(to: CGPoint(x: r.width * 0.08, y: r.height * 0.68))
        path.addLine(to: CGPoint(x: r.minX, y: r.height * 0.32))
        path.closeSubpath()
        return path
    }
}

private struct ShoeShape: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.width * 0.08, y: r.minY))
        path.addLine(to: CGPoint(x: r.width * 0.92, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.height * 0.45))
        path.addLine(to: CGPoint(x: r.width * 0.86, y: r.maxY))
        path.addLine(to: CGPoint(x: r.width * 0.06, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.height * 0.45))
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
    .background(ArtPalette.sky)
}

#Preview("Fevered") {
    HStack(spacing: 24) {
        LoaderFigure(pose: .idle, isFevered: true)
        LoaderFigure(pose: .holding, isFevered: true)
        LoaderFigure(pose: .tossing(towardLeft: true, high: false), isFevered: true)
    }
    .padding(40)
    .background(ArtPalette.skyDeep)
}
