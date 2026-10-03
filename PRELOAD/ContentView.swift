import SwiftUI

/// Switches between the pre-shift screen, the running shift, and the results screen based on
/// the engine's phase.
struct ContentView: View {
    @State private var engine = ShiftEngine()

    var body: some View {
        switch engine.phase {
        case .ready:
            StartView(engine: engine)
        case .running:
            ShiftView(engine: engine)
        case .over:
            ResultsView(engine: engine)
        }
    }
}

#Preview {
    ContentView()
}
