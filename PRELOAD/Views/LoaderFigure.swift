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

/// The loader: a muscular Black man in a fitted work tee and a low cap, drawn with the same
/// flat facets as the rest of the dock. He stays calm — steady eyes, a small closed smile, no
/// sweat or panic — including while a combo is fevered. Joint positions, pose angles, and the
/// figure's frame are unchanged; only the shapes inside those slots, and a slower breathe,
/// differ. Every measurement is relative to `height`. Purely decorative: never hit-tests, so
/// taps still reach the floor and belt behind him.
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
        .offset(y: breathe ? -0.5 * s : 0.5 * s)
        .animation(.spring(duration: 0.48, bounce: 0.08), value: pose)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
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
            ear.offset(x: -15 * s, y: 2 * s)
            ear.scaleEffect(x: -1).offset(x: 15 * s, y: 2 * s)

            FacetHead().fill(ArtPalette.skin).frame(width: 32 * s, height: 32 * s)
            FaceShade().fill(ArtPalette.skinShade).frame(width: 32 * s, height: 32 * s)
            ForeheadPlane().fill(ArtPalette.skinLight).frame(width: 32 * s, height: 32 * s)
            FadeHair().fill(ArtPalette.hair).frame(width: 32 * s, height: 32 * s)

            HStack(spacing: 9 * s) {
                eye
                eye
            }
            .offset(y: -0.5 * s)

            HStack(spacing: 8 * s) {
                Brow().fill(ArtPalette.hair).frame(width: 8 * s, height: 2.2 * s)
                Brow().fill(ArtPalette.hair).frame(width: 8 * s, height: 2.2 * s).scaleEffect(x: -1)
            }
            .offset(y: -4.4 * s)

            FacetNose().fill(ArtPalette.skinShade).frame(width: 4 * s, height: 3.5 * s).offset(y: 3 * s)

            mouth

            cap
        }
        .rotationEffect(.degrees(rig.headTilt))
        .frame(width: 32 * s, height: 32 * s)
    }

    private var ear: some View {
        EarShape().fill(ArtPalette.skinShade).frame(width: 6 * s, height: 9 * s)
    }

    /// Half-lidded and level. The same eyes in fever — the streak shows on the shoulders, not
    /// on his face. A strike is the screen flash; he doesn't flinch.
    private var eye: some View {
        ZStack {
            EyeWhite().fill(.white).frame(width: 7 * s, height: 3.6 * s)
            Rectangle().fill(.black).frame(width: 2.1 * s, height: 2.1 * s).offset(y: 0.5 * s)
            Lid().fill(ArtPalette.skin).frame(width: 8 * s, height: 2.2 * s).offset(y: -1.15 * s)
        }
    }

    /// A short closed smile. Fever doesn't open it or show teeth.
    private var mouth: some View {
        Smile()
            .stroke(ArtPalette.hair, style: StrokeStyle(lineWidth: 1.3 * s, lineCap: .round))
            .frame(width: 7 * s, height: 2.6 * s)
            .offset(y: 9 * s)
    }

    /// A low fitted cap over the fade. Shorter than the old crown so it sits on the head
    /// instead of stacking above it.
    private var cap: some View {
        ZStack {
            CapBrim().fill(ArtPalette.capShade).frame(width: 30 * s, height: 4 * s).offset(y: -7.5 * s)
            CapBrimHighlight().fill(ArtPalette.capLight.opacity(0.8)).frame(width: 30 * s, height: 4 * s).offset(y: -7.5 * s)
            CapCrown().fill(ArtPalette.cap).frame(width: 26 * s, height: 9 * s).offset(y: -12 * s)
            CapCrownLight().fill(ArtPalette.capLight).frame(width: 26 * s, height: 9 * s).offset(y: -12 * s)
            CapCrownShade().fill(ArtPalette.capShade).frame(width: 26 * s, height: 9 * s).offset(y: -12 * s)
        }
    }

    // MARK: Torso

    private var torso: some View {
        ZStack {
            TorsoShape().fill(ArtPalette.shirt).frame(width: 52 * s, height: 50 * s)
            PecLight().fill(ArtPalette.shirtLight).frame(width: 52 * s, height: 50 * s)
            PecShade().fill(ArtPalette.shirtShade).frame(width: 52 * s, height: 50 * s)

            Collar().fill(ArtPalette.collar).frame(width: 12 * s, height: 6 * s).offset(y: -19 * s)
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
            shoulderPad.scaleEffect(x: mirrored ? -1 : 1)
            upperArm
            VStack(spacing: 0) {
                forearm
                hand(mirrored: mirrored)
            }
            .rotationEffect(.degrees(elbow), anchor: .top)
        }
        .rotationEffect(.degrees(shoulder), anchor: .top)
    }

    /// Same 20×10 slot. Fever adds a thin orange edge on the pad — composed, not sparks.
    private var shoulderPad: some View {
        ShoulderPad()
            .fill(ArtPalette.shirtLight)
            .overlay {
                if isFevered {
                    ShoulderPad().stroke(ArtPalette.orange, lineWidth: max(1, 1.2 * s))
                }
            }
            .frame(width: 20 * s, height: 10 * s)
    }

    /// Same 15×28 slot: a short sleeve over a faceted bicep.
    private var upperArm: some View {
        ZStack(alignment: .top) {
            Bicep().fill(ArtPalette.skin)
            BicepHighlight().fill(ArtPalette.skinLight)
            Sleeve().fill(ArtPalette.shirt).frame(width: 15 * s, height: 9 * s)
            Sleeve().fill(ArtPalette.shirtShade).frame(width: 15 * s, height: 2.2 * s).offset(y: 7 * s)
        }
        .frame(width: 15 * s, height: 28 * s)
    }

    /// Same 13×24 slot, skin rather than a sleeve, with one highlight plane.
    private var forearm: some View {
        ZStack {
            Limb(topScale: 0.95, bottomScale: 0.7).fill(ArtPalette.skin)
            Limb(topScale: 0.38, bottomScale: 0.26).fill(ArtPalette.skinLight).offset(x: 1.5 * s)
        }
        .frame(width: 13 * s, height: 24 * s)
    }

    private func hand(mirrored: Bool) -> some View {
        ZStack {
            HandShape().fill(ArtPalette.skin)
            HandShape().stroke(ArtPalette.skinLight, lineWidth: max(0.8, 1 * s))
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

/// Nearly level. A worried angle reads as strain; this one sits flat over the eye.
private struct Brow: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.minX, y: r.height * 0.45))
        path.addLine(to: CGPoint(x: r.maxX, y: r.height * 0.28))
        path.addLine(to: CGPoint(x: r.maxX, y: r.height * 0.62))
        path.addLine(to: CGPoint(x: r.minX, y: r.height * 0.82))
        path.closeSubpath()
        return path
    }
}

/// The upper lid, sitting across the top of the eye white.
private struct Lid: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.minX, y: r.height * 0.35))
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.height * 0.7))
        path.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        path.closeSubpath()
        return path
    }
}

/// Close crop: hair along the crown and temples, forehead left clear.
private struct FadeHair: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.width * 0.14, y: r.height * 0.30))
        path.addLine(to: CGPoint(x: r.width * 0.08, y: r.height * 0.14))
        path.addLine(to: CGPoint(x: r.width * 0.24, y: r.height * 0.02))
        path.addLine(to: CGPoint(x: r.width * 0.76, y: r.height * 0.02))
        path.addLine(to: CGPoint(x: r.width * 0.92, y: r.height * 0.14))
        path.addLine(to: CGPoint(x: r.width * 0.86, y: r.height * 0.30))
        path.addLine(to: CGPoint(x: r.width * 0.70, y: r.height * 0.18))
        path.addLine(to: CGPoint(x: r.width * 0.30, y: r.height * 0.18))
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

/// Broad through the chest, only a little narrower at the waist. Drawn inside the same 52×50 slot.
private struct TorsoShape: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.width * 0.02, y: r.height * 0.18))
        path.addLine(to: CGPoint(x: r.width * 0.12, y: r.minY))
        path.addLine(to: CGPoint(x: r.width * 0.88, y: r.minY))
        path.addLine(to: CGPoint(x: r.width * 0.98, y: r.height * 0.18))
        path.addLine(to: CGPoint(x: r.width * 0.90, y: r.maxY))
        path.addLine(to: CGPoint(x: r.width * 0.10, y: r.maxY))
        path.closeSubpath()
        return path
    }
}

private struct PecLight: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.width * 0.16, y: r.height * 0.18))
        path.addLine(to: CGPoint(x: r.width * 0.46, y: r.height * 0.16))
        path.addLine(to: CGPoint(x: r.width * 0.44, y: r.height * 0.50))
        path.addLine(to: CGPoint(x: r.width * 0.18, y: r.height * 0.54))
        path.closeSubpath()
        return path
    }
}

private struct PecShade: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.width * 0.54, y: r.height * 0.16))
        path.addLine(to: CGPoint(x: r.width * 0.84, y: r.height * 0.18))
        path.addLine(to: CGPoint(x: r.width * 0.82, y: r.height * 0.54))
        path.addLine(to: CGPoint(x: r.width * 0.56, y: r.height * 0.50))
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
        path.move(to: CGPoint(x: r.width * 0.04, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.height * 0.22))
        path.addLine(to: CGPoint(x: r.width * 0.32, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.height * 0.08))
        path.addLine(to: CGPoint(x: r.width * 0.96, y: r.maxY))
        path.closeSubpath()
        return path
    }
}

/// Wider through the middle of the upper-arm slot.
private struct Bicep: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.width * 0.22, y: r.minY))
        path.addLine(to: CGPoint(x: r.width * 0.78, y: r.minY))
        path.addLine(to: CGPoint(x: r.width * 0.98, y: r.height * 0.46))
        path.addLine(to: CGPoint(x: r.width * 0.80, y: r.maxY))
        path.addLine(to: CGPoint(x: r.width * 0.20, y: r.maxY))
        path.addLine(to: CGPoint(x: r.width * 0.04, y: r.height * 0.46))
        path.closeSubpath()
        return path
    }
}

private struct BicepHighlight: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.width * 0.50, y: r.height * 0.22))
        path.addLine(to: CGPoint(x: r.width * 0.76, y: r.height * 0.16))
        path.addLine(to: CGPoint(x: r.width * 0.94, y: r.height * 0.46))
        path.addLine(to: CGPoint(x: r.width * 0.74, y: r.height * 0.74))
        path.addLine(to: CGPoint(x: r.width * 0.52, y: r.height * 0.58))
        path.closeSubpath()
        return path
    }
}

/// The short sleeve, drawn in a short frame at the top of the upper-arm slot.
private struct Sleeve: Shape {
    func path(in r: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: r.width * 0.06, y: r.minY))
        path.addLine(to: CGPoint(x: r.width * 0.94, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.maxY))
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
