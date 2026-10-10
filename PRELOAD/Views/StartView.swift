import SwiftUI

/// The pre-shift screen: a quick reminder of the rules and a button to start the belt.
struct StartView: View {
    let engine: ShiftEngine

    @AppStorage("preload.bestScore") private var bestScore = 0
    @AppStorage("preload.difficulty") private var difficultyRaw = Difficulty.normal.rawValue

    @State private var showingOptions = false
    @State private var showingQuitConfirm = false

    var body: some View {
        GeometryReader { proxy in
            // The source art is a 2160x1074 landscape two-panel poster (worker/boxes/belt on
            // top, a truck-interior snapshot on the bottom), built with generous sky/dark
            // margins around both panels. Scaled by whichever axis needs the larger factor
            // (classic "aspect fill") so it covers the frame edge to edge with no pillarboxing
            // — any crop this causes on real device aspect ratios lands in those margins, not
            // on the worker, boxes, belt, or truck content.
            let sourceSize = CGSize(width: 2160, height: 1074)
            let isLandscape = proxy.size.width > proxy.size.height
            let widthScale = proxy.size.width / sourceSize.width
            let heightScale = proxy.size.height / sourceSize.height
            let scale = max(widthScale, heightScale)

            ZStack {
                Color(red: 96 / 255, green: 158 / 255, blue: 200 / 255)

                Image("HomeScreenBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: sourceSize.width * scale, height: sourceSize.height * scale)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                // Darken top and bottom so the title and button stay legible over the art.
                LinearGradient(
                    colors: [.black.opacity(0.65), .black.opacity(0.1), .black.opacity(0.65)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // A quick preview of where things go, floated over the art — only in landscape,
                // where there's enough width beside the centered title/buttons for it not to
                // crowd them. Inset from the leading edge by a fifth of the screen's own width,
                // on top of the real safe-area insets, so it clears a Dynamic Island or notch
                // rotated onto this edge in landscape, even where the safe-area inset alone
                // doesn't cover it.
                if isLandscape {
                    HStack {
                        zonesPreview
                            .padding(.leading, proxy.size.width * 0.2)
                        Spacer()
                    }
                    .padding(proxy.safeAreaInsets)
                }

                VStack {
                    HStack {
                        Spacer()
                        Button {
                            showingOptions = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(Color.black.opacity(0.4), in: Circle())
                        }
                    }
                    Spacer()
                }
                .padding(proxy.safeAreaInsets)
                .padding(12)

                // A plain VStack here previously let the "Practice Mode" button (added below
                // "Start Shift") get pushed below the bottom edge on real landscape phone
                // heights — present in the hierarchy's underlying view tree, but clipped out of
                // the visible/tappable screen entirely. Wrapping in a ScrollView with a
                // height-matching minimum costs nothing when content fits (the common case: the
                // Spacer below still absorbs the slack and nothing visibly scrolls) but
                // guarantees every control stays reachable if it doesn't.
                ScrollView {
                    VStack(spacing: 14) {
                        Text("Preloader")
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Read the serial. Load the right shelf. Leave what's not yours alone.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(maxWidth: 420)

                        if bestScore > 0 {
                            Text("Best score: \(bestScore)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.yellow)
                        }

                        Spacer(minLength: 12)

                        VStack(spacing: 8) {
                            Button {
                                engine.difficulty = Difficulty(rawValue: difficultyRaw) ?? .normal
                                engine.startShift()
                            } label: {
                                Text("Start Shift")
                                    .font(.headline.bold())
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)

                            Button {
                                engine.difficulty = Difficulty(rawValue: difficultyRaw) ?? .normal
                                engine.startShift(practiceMode: true)
                            } label: {
                                Text("Practice Mode")
                                    .font(.subheadline.bold())
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.bordered)
                            .tint(.white)

                            Text("No strikes, slow belt — just read and load.")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.6))

                            Button(role: .destructive) {
                                showingQuitConfirm = true
                            } label: {
                                Text("Quit App")
                                    .font(.footnote.bold())
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 4)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                            .padding(.top, 6)
                        }
                    }
                    .padding()
                    .frame(minHeight: proxy.size.height - 32)
                }
                .scrollIndicators(.hidden)
                .padding(proxy.safeAreaInsets)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showingOptions) {
            OptionsView()
        }
        .confirmationDialog("Quit Preloader?", isPresented: $showingQuitConfirm, titleVisibility: .visible) {
            Button("Quit", role: .destructive) { exit(0) }
            Button("Cancel", role: .cancel) {}
        }
    }

    /// A compact legend of the truck's zones — the same four-shelf-grid-plus-reminders shape as
    /// the shift-ready tutorial card in `ShiftView`, just without live serial ranges (none have
    /// been rolled yet; a truck hasn't started).
    private var zonesPreview: some View {
        VStack(spacing: 8) {
            Text("TRUCK ZONES")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                zoneChip("1000s")
                zoneChip("3000s")
                zoneChip("2000s")
                zoneChip("4000s")
            }

            Divider().background(Color.white.opacity(0.2))

            VStack(alignment: .leading, spacing: 4) {
                Label("No label → RERUN", systemImage: "arrow.down.square")
                Label("Airplane → AIR", systemImage: "airplane")
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.85))
        }
        .padding(12)
        .frame(width: 148)
        .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.15)))
    }

    private func zoneChip(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
    }
}
