import SwiftUI

struct CaptureIndicatorView: View {
    @ObservedObject var engine: GodEngine
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 8) {
            Text(engine.capture.state == .idle ? "○" : "◉")
                .foregroundColor(captureColor)
                .opacity(engine.capture.state == .recording ? (pulse ? 1.0 : 0.5) : 1.0)

            Text("GOD")
                .foregroundColor(captureColor)

            if engine.capture.state == .armed {
                Text("— armed")
                    .foregroundColor(Theme.orange)
            } else if engine.capture.state == .recording {
                Text("— recording")
                    .foregroundColor(Theme.orange)
            }
        }
        .font(Theme.mono)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var captureColor: Color {
        switch engine.capture.state {
        case .idle: return Theme.text
        case .armed: return Theme.orange
        case .recording: return Theme.orange
        }
    }
}
