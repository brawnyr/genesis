import SwiftUI

struct ContentView: View {
    @ObservedObject var engine: GodEngine
    @State private var showSetup = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 20) {
                HStack {
                    TitleView()
                    Spacer()
                    Button("SETUP") { showSetup = true }
                        .font(Theme.monoSmall)
                        .foregroundColor(Theme.dim)
                        .buttonStyle(.plain)
                }

                TransportView(engine: engine)

                LoopBarView(engine: engine)

                PadGridView(engine: engine)

                LayerListView(engine: engine)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                CaptureIndicatorView(engine: engine)

                TipView()

                CommandInputView(engine: engine)
                    .padding(.bottom, 8)
            }
            .padding()
        }
        .sheet(isPresented: $showSetup) {
            SetupPlaceholder(isPresented: $showSetup)
                .frame(width: 500, height: 500)
        }
        .onKeyPress(.space) {
            engine.togglePlay()
            return .handled
        }
        .onKeyPress("g") {
            engine.toggleCapture()
            return .handled
        }
        .onKeyPress("m") {
            engine.toggleMetronome()
            return .handled
        }
        .onKeyPress(.upArrow) {
            engine.setBPM(engine.transport.bpm + 1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            engine.setBPM(engine.transport.bpm - 1)
            return .handled
        }
        .onKeyPress(.escape) {
            engine.stop()
            return .handled
        }
    }
}

// Placeholder until Task 15 creates the real SetupView
struct SetupPlaceholder: View {
    @Binding var isPresented: Bool
    var body: some View {
        ZStack {
            Theme.bg
            VStack {
                Text("SETUP")
                    .font(Theme.monoLarge)
                    .foregroundColor(Theme.text)
                Button("CLOSE") { isPresented = false }
                    .font(Theme.mono)
                    .foregroundColor(Theme.accent)
                    .buttonStyle(.plain)
            }
        }
    }
}
