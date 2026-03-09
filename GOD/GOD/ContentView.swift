import SwiftUI

struct ContentView: View {
    @ObservedObject var engine: GodEngine
    @State private var showSetup = false
    @State private var showCommandInput = false
    @State private var showKeyReference = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 16) {
                TitleView()
                    .padding(.top, 8)

                TransportView(engine: engine)

                LoopBarView(engine: engine)

                ChannelListView(engine: engine)
                    .padding(.vertical, 8)

                Spacer()

                CaptureIndicatorView(engine: engine)

                TipView()
                    .padding(.vertical, 4)

                Text("SPC play · G god · M metro · ↑↓ bpm · / cmd · ? keys")
                    .font(Theme.monoTiny)
                    .foregroundColor(Theme.subtle)

                CommandInputView(engine: engine, isVisible: $showCommandInput)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 20)

            if showKeyReference {
                KeyReferenceOverlay(isVisible: $showKeyReference)
            }
        }
        .sheet(isPresented: $showSetup) {
            SetupView(engine: engine, isPresented: $showSetup)
                .frame(width: 500, height: 500)
        }
        .onKeyPress(.space) {
            guard !showCommandInput else { return .ignored }
            engine.togglePlay()
            return .handled
        }
        .onKeyPress("g") {
            guard !showCommandInput else { return .ignored }
            engine.toggleCapture()
            return .handled
        }
        .onKeyPress("m") {
            guard !showCommandInput else { return .ignored }
            engine.toggleMetronome()
            return .handled
        }
        .onKeyPress(.upArrow) {
            guard !showCommandInput else { return .ignored }
            engine.setBPM(engine.transport.bpm + 1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            guard !showCommandInput else { return .ignored }
            engine.setBPM(engine.transport.bpm - 1)
            return .handled
        }
        .onKeyPress(.escape) {
            if showCommandInput {
                showCommandInput = false
            } else if showKeyReference {
                showKeyReference = false
            } else {
                engine.stop()
            }
            return .handled
        }
        .onKeyPress("/") {
            guard !showCommandInput else { return .ignored }
            showCommandInput = true
            return .handled
        }
        .onKeyPress("?") {
            guard !showCommandInput else { return .ignored }
            showKeyReference.toggle()
            return .handled
        }
        .onKeyPress("1") { guard !showCommandInput else { return .ignored }; engine.toggleMute(layer: 0); return .handled }
        .onKeyPress("2") { guard !showCommandInput else { return .ignored }; engine.toggleMute(layer: 1); return .handled }
        .onKeyPress("3") { guard !showCommandInput else { return .ignored }; engine.toggleMute(layer: 2); return .handled }
        .onKeyPress("4") { guard !showCommandInput else { return .ignored }; engine.toggleMute(layer: 3); return .handled }
        .onKeyPress("5") { guard !showCommandInput else { return .ignored }; engine.toggleMute(layer: 4); return .handled }
        .onKeyPress("6") { guard !showCommandInput else { return .ignored }; engine.toggleMute(layer: 5); return .handled }
        .onKeyPress("7") { guard !showCommandInput else { return .ignored }; engine.toggleMute(layer: 6); return .handled }
        .onKeyPress("8") { guard !showCommandInput else { return .ignored }; engine.toggleMute(layer: 7); return .handled }
    }
}
