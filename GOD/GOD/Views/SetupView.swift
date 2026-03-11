import SwiftUI
import UniformTypeIdentifiers
import os

private let logger = Logger(subsystem: "com.god.ui", category: "SetupView")

struct SetupView: View {
    @ObservedObject var engine: GodEngine
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 16) {
                Text("SET UP PADS")
                    .font(Theme.monoLarge)
                    .foregroundColor(Theme.text)
                    .padding(.top)

                ForEach(0..<8, id: \.self) { i in
                    HStack {
                        Text("PAD \(i + 1)")
                            .font(Theme.mono)
                            .foregroundColor(Theme.subtle)
                            .frame(width: 60, alignment: .leading)

                        Text(engine.padBank.pads[i].sample?.name ?? "—")
                            .font(Theme.mono)
                            .foregroundColor(Theme.text)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button("LOAD") {
                            loadSample(forPad: i)
                        }
                        .font(Theme.monoSmall)
                        .foregroundColor(Theme.blue)
                        .buttonStyle(.plain)

                        if engine.padBank.pads[i].sample != nil {
                            Button("×") {
                                engine.padBank.pads[i].sample = nil
                                engine.padBank.pads[i].samplePath = nil
                                engine.padBank.pads[i].name = "PAD \(i + 1)"
                            }
                            .font(Theme.mono)
                            .foregroundColor(Theme.red)
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()

                Button("DONE") {
                    do {
                        try engine.padBank.save()
                    } catch {
                        logger.error("Failed to save pad config: \(error.localizedDescription)")
                    }
                    isPresented = false
                }
                .font(Theme.mono)
                .foregroundColor(Theme.blue)
                .buttonStyle(.plain)
                .padding()
            }
            .padding()
        }
    }

    private func loadSample(forPad index: Int) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.audio]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try engine.loadSample(from: url, forPad: index)
            } catch {
                logger.error("Failed to load sample from \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }
}
