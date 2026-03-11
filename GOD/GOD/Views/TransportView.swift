import SwiftUI

struct TransportView: View {
    @ObservedObject var engine: GodEngine

    private var currentBeat: Int {
        let beatLength = engine.metronome.beatLengthFrames(
            bpm: engine.transport.bpm,
            sampleRate: Transport.sampleRate
        )
        guard beatLength > 0 else { return 1 }
        return (engine.transport.position / beatLength) % (engine.transport.barCount * 4) + 1
    }

    private var loopProgress: Double {
        let loopLen = engine.transport.loopLengthFrames
        guard loopLen > 0 else { return 0 }
        return Double(engine.transport.position) / Double(loopLen)
    }

    private var captureText: String {
        switch engine.capture.state {
        case .idle: return "○ GOD"
        case .armed: return "◉ GOD — armed"
        case .recording: return "◉ GOD — recording"
        }
    }

    private var captureColor: Color {
        switch engine.capture.state {
        case .idle: return Theme.text
        case .armed, .recording: return Theme.orange
        }
    }

    @State private var captureOpacity: Double = 1.0

    var body: some View {
        HStack(spacing: 16) {
            // Play state
            Text(engine.transport.isPlaying ? "▶" : "■")
                .foregroundColor(engine.transport.isPlaying ? Theme.blue : Theme.subtle)
                .font(Theme.monoLarge)

            // BPM
            Text("\(engine.transport.bpm)")
                .foregroundColor(engine.transport.isPlaying ? Theme.text : Theme.subtle)
                .font(.system(size: 18, design: .monospaced).bold())
            Text("bpm")
                .foregroundColor(Theme.subtle)
                .font(Theme.monoSmall)

            // Bar count
            HStack(spacing: 2) {
                Text("[").foregroundColor(Theme.blue)
                Text("\(engine.transport.barCount)").foregroundColor(Theme.text)
                Text("]").foregroundColor(Theme.blue)
                Text("bars").foregroundColor(Theme.subtle)
            }
            .font(Theme.monoSmall)

            // Metronome
            Text("♩ \(engine.metronome.isOn ? "on" : "off")")
                .foregroundColor(engine.metronome.isOn ? Theme.blue : Theme.subtle)
                .font(Theme.monoSmall)

            // Beat counter
            if engine.transport.isPlaying {
                Text("beat \(currentBeat)")
                    .foregroundColor(Theme.blue)
                    .font(Theme.monoSmall)
            }

            Spacer()

            // Capture status
            Text(captureText)
                .foregroundColor(captureColor)
                .font(Theme.monoSmall)
                .opacity(engine.capture.state == .recording ? captureOpacity : 1.0)
                .animation(
                    engine.capture.state == .recording
                        ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true)
                        : .default,
                    value: engine.capture.state == .recording
                )
                .onChange(of: engine.capture.state == .recording) { _, isRecording in
                    captureOpacity = isRecording ? 0.5 : 1.0
                }

            // Master volume + level
            HStack(spacing: 4) {
                Text("master \(Int(engine.masterVolume * 100))%")
                    .foregroundColor(Theme.subtle)
                Text(formatDb(engine.masterLevelDb))
                    .foregroundColor(engine.masterLevelDb > 0 ? Theme.orange : Theme.subtle)
            }
            .font(Theme.monoSmall)

            // Inline loop progress bar
            GeometryReader { _ in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.subtle.opacity(0.3))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.blue)
                        .frame(width: 80 * loopProgress)
                }
            }
            .frame(width: 80, height: 3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(red: 0.122, green: 0.118, blue: 0.106))  // #1f1e1b
    }
}
