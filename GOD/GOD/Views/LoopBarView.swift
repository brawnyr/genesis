import SwiftUI

struct LoopBarView: View {
    @ObservedObject var engine: GodEngine

    private var progress: Double {
        guard engine.transport.loopLengthFrames > 0 else { return 0 }
        return Double(engine.transport.position) / Double(engine.transport.loopLengthFrames)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Theme.subtle)
                    .frame(height: 3)

                Rectangle()
                    .fill(Theme.blue)
                    .frame(width: geo.size.width * progress, height: 3)
            }
        }
        .frame(height: 3)
    }
}
