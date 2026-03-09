import SwiftUI

struct CaptureIndicatorView: View {
    @ObservedObject var engine: GodEngine
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(captureColor)
                .frame(width: 8, height: 8)
                .opacity(engine.capture.state == .recording ? (pulse ? 1.0 : 0.4) : 1.0)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                }

            Text("GOD")
                .font(Theme.mono)
                .foregroundColor(captureColor)

            if engine.capture.state == .armed {
                Text("ARMED")
                    .font(Theme.monoSmall)
                    .foregroundColor(Theme.amber)
            } else if engine.capture.state == .recording {
                Text("REC")
                    .font(Theme.monoSmall)
                    .foregroundColor(Theme.red)
            }
        }
    }

    private var captureColor: Color {
        switch engine.capture.state {
        case .idle: return Theme.dim
        case .armed: return Theme.amber
        case .recording: return Theme.red
        }
    }
}
