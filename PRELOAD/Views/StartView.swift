import SwiftUI

/// The pre-shift screen: a quick reminder of the rules and a button to start the belt.
struct StartView: View {
    let engine: ShiftEngine

    @AppStorage("preload.bestScore") private var bestScore = 0

    var body: some View {
        GeometryReader { proxy in
            // The source art is a 1080x1920 portrait poster; in this landscape frame we only
            // ever see a thin horizontal slice of it. A plain centered fill crops straight
            // into the character's face, so bias the crop toward the belt and boxes instead.
            let sourceSize = CGSize(width: 1080, height: 1920)
            let scale = proxy.size.width / sourceSize.width
            let verticalOverflow = max(0, sourceSize.height * scale - proxy.size.height)
            let beltFocus = 0.60 // 0 = top of the poster, 1 = bottom

            ZStack {
                Image("HomeScreenBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: proxy.size.width, height: sourceSize.height * scale, alignment: .top)
                    .offset(y: -verticalOverflow * beltFocus)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                // Darken top and bottom so the title and button stay legible over the art.
                LinearGradient(
                    colors: [.black.opacity(0.65), .black.opacity(0.1), .black.opacity(0.65)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(spacing: 20) {
                    Text("PRELOAD")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Read the serial. Load the right shelf. Leave what's not yours alone.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(maxWidth: 420)

                    if bestScore > 0 {
                        Text("Best score: \(bestScore)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.yellow)
                    }

                    Spacer()

                    Button {
                        engine.startShift()
                    } label: {
                        Text("Start Shift")
                            .font(.title3.bold())
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                .padding()
                .padding(.vertical, 24)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
    }
}
