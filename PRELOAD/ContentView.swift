import SwiftUI

/// Switches between the pre-shift screen, the running shift, and the results screen based on
/// the engine's phase.
struct ContentView: View {
    @State private var engine = ShiftEngine()

    /// Shared with the pause menu's "Sound" toggle — the ambient loop (started once below) mutes
    /// and unmutes in place whenever this changes, the same setting gating the one-shot SFX.
    @AppStorage("preload.soundEnabled") private var soundEnabled = true

    /// Shared with the homepage options menu's volume slider — applies to the ambient loop and
    /// every SFX node, independent of the mute toggle above.
    @AppStorage("preload.volume") private var volume = 1.0

    var body: some View {
        Group {
            switch engine.phase {
            case .ready:
                StartView(engine: engine)
            case .paused, .running:
                ShiftView(engine: engine)
            case .over:
                ResultsView(engine: engine)
            }
        }
        .onAppear {
            // Deferred to the next run loop turn rather than called inline: `SoundEngine.shared`
            // starts an AVAudioEngine on first access, which makes blocking IPC calls to the audio
            // daemon. Doing that synchronously inside `onAppear` nests it inside SwiftUI's live
            // render/commit pass — if the daemon is slow to respond (seen under simulator/CI load),
            // the audio stack's own RPC-timeout watchdog calls abort() directly, which no amount of
            // `try?` can catch. Running it a tick later keeps that risk off the render path.
            DispatchQueue.main.async {
                SoundEngine.shared.startAmbientLoop()
                SoundEngine.shared.setAmbientMuted(!soundEnabled)
                SoundEngine.shared.setVolume(volume)
            }
        }
        .onChange(of: soundEnabled) { _, enabled in
            SoundEngine.shared.setAmbientMuted(!enabled)
        }
        .onChange(of: volume) { _, newVolume in
            SoundEngine.shared.setVolume(newVolume)
        }
    }
}

#Preview {
    ContentView()
}
