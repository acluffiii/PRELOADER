import AVFoundation

/// Procedurally synthesizes the game's feedback tones at runtime — a chime for a correct load,
/// a buzz for a strike, and so on. There are no bundled audio assets: each sound is a short
/// envelope-shaped sine/noise buffer built on the fly and played through its own node, so two
/// sounds firing back-to-back (a strike right after a combo chime) don't cut each other off.
@MainActor
final class SoundEngine {
    static let shared = SoundEngine()

    private let engine = AVAudioEngine()
    private let sampleRate: Double = 44_100

    /// The persistent ambient loop's node, kept around (unlike the one-shot nodes in `schedule`)
    /// so `setAmbientMuted` can fade it without tearing down and re-scheduling the loop.
    private var ambientNode: AVAudioPlayerNode?

    /// Master volume (0...1) applied to the ambient loop and every one-shot SFX node, independent
    /// of `setAmbientMuted` — muting and volume are tracked separately so restoring sound after a
    /// mute doesn't need to remember what the slider was last set to.
    private var volume: Float = 1.0
    private var isAmbientMuted = false

    private init() {
        // Just the category here — `setActive(true)` is flagged by the system as a main-thread
        // hang risk (it can block on the audio daemon), and it's redundant anyway: starting the
        // engine below implicitly activates the session on iOS.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        // Touching mainMixerNode forces the engine to lazily wire up its mixer -> output
        // connection. Without this, the graph has no I/O nodes at all and `start()` throws an
        // Objective-C exception that `try?` can't catch, killing the process outright.
        _ = engine.mainMixerNode
        try? engine.start()
    }

    /// An ordinary correct load.
    func playSuccess() { play(notes: [(880, 0.07), (1318.5, 0.09)]) }

    /// A wrong shelf, a forbidden touch — anything that costs a strike.
    func playStrike() { play(buzz: true) }

    /// Leaving a "do not touch" package alone to run off the belt.
    func playDiscipline() { play(notes: [(659.25, 0.08), (987.77, 0.10)]) }

    /// The big one: a load that also happened to fill a shelf.
    func playShelfFull() { play(notes: [(659.25, 0.07), (880, 0.07), (1108.73, 0.07), (1318.5, 0.14)]) }

    /// A strike, layered on top of `playStrike()` — loud and alarm-like, so a miss is never
    /// quiet enough to go unnoticed.
    func playSiren() { play(siren: true) }

    /// A power-up box tapped, or the Helper button sweeping the belt.
    func playPowerUp() { play(notes: [(523.25, 0.06), (659.25, 0.06), (783.99, 0.06), (1046.5, 0.12)]) }

    // MARK: Ambient loop

    /// Starts a soft, breathing ambient drone — a warehouse hum rather than music — looping
    /// under the whole app for as long as it's running. Safe to call repeatedly; a second call
    /// while already playing is a no-op rather than stacking a second loop on top.
    func startAmbientLoop() {
        guard ambientNode == nil, let buffer = makeAmbientLoopBuffer(), ensureEngineRunning() else { return }
        let node = AVAudioPlayerNode()
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: buffer.format)
        node.scheduleBuffer(buffer, at: nil, options: .loops)
        node.play()
        ambientNode = node
    }

    /// Mutes or restores the ambient loop in place, so toggling the sound setting doesn't
    /// re-trigger the loop's attack (and can't drift out of its own seamless loop point).
    func setAmbientMuted(_ muted: Bool) {
        isAmbientMuted = muted
        ambientNode?.volume = muted ? 0 : volume
    }

    /// Sets the master volume (0...1) for the ambient loop and every SFX node played from here
    /// on — existing one-shot nodes already scheduled keep whatever volume they started with.
    func setVolume(_ value: Double) {
        volume = Float(max(0, min(1, value)))
        ambientNode?.volume = isAmbientMuted ? 0 : volume
    }

    /// A handful of low tones, each tuned so it completes a whole number of cycles over
    /// `duration` — the only way a sine wave's start and end frames line up with zero
    /// discontinuity, which is what lets `.loops` repeat this buffer forever without a click at
    /// the seam. One slow amplitude swell per loop (same whole-cycle trick) keeps it breathing
    /// rather than droning perfectly flat.
    private func makeAmbientLoopBuffer() -> AVAudioPCMBuffer? {
        let duration = 8.0
        guard let buffer = makeBuffer(totalDuration: duration) else { return nil }
        let data = buffer.floatChannelData![0]
        let frameCount = Int(sampleRate * duration)
        let tones: [(frequency: Double, amplitude: Double)] = [(110, 0.5), (110.5, 0.3), (165, 0.2)]

        for frame in 0..<frameCount {
            let t = Double(frame) / sampleRate
            let tone = tones.reduce(0.0) { $0 + sin(2 * .pi * $1.frequency * t) * $1.amplitude }
            let swell = 0.6 + 0.4 * sin(2 * .pi * t / duration)
            data[frame] = Float(tone * swell * 0.1)
        }
        return buffer
    }

    // MARK: Synthesis

    private func play(notes: [(frequency: Double, duration: Double)]) {
        guard let buffer = makeBuffer(totalDuration: notes.reduce(0) { $0 + $1.duration }) else { return }
        var cursor = 0
        let data = buffer.floatChannelData![0]
        for note in notes {
            let frameCount = Int(sampleRate * note.duration)
            for frame in 0..<frameCount {
                let t = Double(frame) / sampleRate
                let envelope = exp(-t * 9)
                data[cursor] = Float(sin(2 * .pi * note.frequency * t) * envelope * 0.3)
                cursor += 1
            }
        }
        schedule(buffer)
    }

    private func play(buzz: Bool) {
        let duration = 0.18
        guard let buffer = makeBuffer(totalDuration: duration) else { return }
        let data = buffer.floatChannelData![0]
        let frameCount = Int(sampleRate * duration)
        for frame in 0..<frameCount {
            let t = Double(frame) / sampleRate
            let envelope = exp(-t * 6)
            let wave = sin(2 * .pi * 150 * t) + sin(2 * .pi * 161 * t)
            data[frame] = Float(wave * 0.5 * envelope * 0.3)
        }
        schedule(buffer)
    }

    /// A two-sweep wail between 600Hz and 1200Hz — deliberately longer and louder than the
    /// ordinary strike buzz, played alongside it rather than instead of it, so a miss gets a
    /// distinct "you missed" alarm on top of the routine mistake sound.
    private func play(siren: Bool) {
        let duration = 0.9
        guard let buffer = makeBuffer(totalDuration: duration) else { return }
        let data = buffer.floatChannelData![0]
        let frameCount = Int(sampleRate * duration)
        let sweepHz = 2.0 / duration // two full up-down sweeps over the whole sound
        for frame in 0..<frameCount {
            let t = Double(frame) / sampleRate
            let sweep = 0.5 - 0.5 * cos(2 * .pi * sweepHz * t) // 0...1, smooth up and down
            let frequency = 600 + sweep * 600
            data[frame] = Float(sin(2 * .pi * frequency * t) * 0.5)
        }
        schedule(buffer)
    }

    private func makeBuffer(totalDuration: Double) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return nil }
        let frameCount = AVAudioFrameCount(sampleRate * totalDuration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        return buffer
    }

    /// Plays `buffer` on a fresh node, then tears the node down once playback finishes so
    /// overlapping sounds each get their own voice instead of fighting over one player.
    private func schedule(_ buffer: AVAudioPCMBuffer) {
        guard ensureEngineRunning() else { return }

        let node = AVAudioPlayerNode()
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: buffer.format)
        node.volume = volume
        node.scheduleBuffer(buffer)
        node.play()

        let lifetime = Double(buffer.frameLength) / sampleRate + 0.1
        Task {
            try? await Task.sleep(for: .seconds(lifetime))
            engine.disconnectNodeOutput(node)
            engine.detach(node)
        }
    }

    /// `AVAudioPlayerNode.play()` raises an uncatchable Objective-C exception if the engine
    /// isn't running — and the engine can stop itself at any time (a phone call, Siri, Control
    /// Center audio takeover, a route change) without this process doing anything wrong. Every
    /// call site that's about to call `play()` goes through here first, so a sound that can't
    /// play is silently skipped instead of crashing the app outright.
    private func ensureEngineRunning() -> Bool {
        if engine.isRunning { return true }
        return (try? engine.start()) != nil
    }
}
