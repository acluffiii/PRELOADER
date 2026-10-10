import SwiftUI

/// The homepage's options menu: difficulty, master volume, and a way to close the app entirely
/// from inside it (confirmed first) rather than having to swipe it away from the app switcher.
/// Styled to match the rest of the app (dark background, bold rounded headings, orange accent)
/// rather than a plain system `Form`, since this sheet is the one screen that didn't before.
struct OptionsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("preload.difficulty") private var difficultyRaw = Difficulty.normal.rawValue
    @AppStorage("preload.volume") private var volume = 1.0

    @State private var showingQuitConfirm = false

    private var difficulty: Binding<Difficulty> {
        Binding(
            get: { Difficulty(rawValue: difficultyRaw) ?? .normal },
            set: { difficultyRaw = $0.rawValue }
        )
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Text("OPTIONS")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("DIFFICULTY")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.6))
                    Picker("Difficulty", selection: difficulty) {
                        ForEach(Difficulty.allCases) { level in
                            Text(level.label).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("VOLUME")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.6))
                    HStack {
                        Image(systemName: "speaker.fill")
                            .foregroundStyle(.white.opacity(0.8))
                        Slider(value: $volume, in: 0...1)
                            .tint(.orange)
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }

                Spacer()

                Button(role: .destructive) {
                    showingQuitConfirm = true
                } label: {
                    Text("Quit App").frame(maxWidth: 220)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
            .padding(24)
            .foregroundStyle(.white)
            .tint(.white)
        }
        .confirmationDialog("Quit Preloader?", isPresented: $showingQuitConfirm, titleVisibility: .visible) {
            Button("Quit", role: .destructive) { exit(0) }
            Button("Cancel", role: .cancel) {}
        }
    }
}

#Preview {
    OptionsView()
}
