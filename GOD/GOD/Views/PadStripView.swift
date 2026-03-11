// GOD/GOD/Views/PadStripView.swift
import SwiftUI
import UniformTypeIdentifiers
import os

private let logger = Logger(subsystem: "com.god.ui", category: "PadStrip")

struct PadStripView: View {
    @ObservedObject var engine: GodEngine
    @ObservedObject var interpreter: EngineEventInterpreter

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<8, id: \.self) { index in
                PadCell(
                    index: index,
                    pad: engine.padBank.pads[index],
                    layer: engine.layers[index],
                    isActive: engine.activePadIndex == index,
                    triggered: engine.channelTriggered[index],
                    signalLevel: engine.channelSignalLevels[index],
                    intensity: interpreter.padIntensities[index],
                    folderName: PadBank.spliceFolderNames[index]
                )
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
    }
}

// MARK: - Marquee scrolling text

struct MarqueeText: View {
    let text: String
    let font: Font
    let color: Color
    let shadow: Color

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0

    private var overflows: Bool { textWidth > containerWidth && containerWidth > 0 }
    private let gap: CGFloat = 40
    private let speed: CGFloat = 30 // points per second

    var body: some View {
        GeometryReader { geo in
            let _ = updateContainerWidth(geo.size.width)
            ZStack(alignment: .leading) {
                if overflows {
                    HStack(spacing: gap) {
                        Text(text)
                            .font(font)
                            .foregroundColor(color)
                            .shadow(color: shadow, radius: 6)
                            .fixedSize()
                        Text(text)
                            .font(font)
                            .foregroundColor(color)
                            .shadow(color: shadow, radius: 6)
                            .fixedSize()
                    }
                    .offset(x: offset)
                    .onAppear { startAnimation() }
                    .onChange(of: text) { _, _ in resetAnimation() }
                } else {
                    Text(text)
                        .font(font)
                        .foregroundColor(color)
                        .shadow(color: shadow, radius: 6)
                        .fixedSize()
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .clipped()
        }
        .background(
            Text(text)
                .font(font)
                .fixedSize()
                .background(GeometryReader { geo in
                    Color.clear.onAppear { textWidth = geo.size.width }
                        .onChange(of: text) { _, _ in textWidth = geo.size.width }
                })
                .hidden()
        )
        .frame(height: 18)
    }

    private func updateContainerWidth(_ width: CGFloat) {
        if containerWidth != width {
            DispatchQueue.main.async { containerWidth = width }
        }
    }

    private func startAnimation() {
        guard overflows else { return }
        let totalWidth = textWidth + gap
        let duration = Double(totalWidth) / Double(speed)
        offset = 0
        withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
            offset = -totalWidth
        }
    }

    private func resetAnimation() {
        offset = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            startAnimation()
        }
    }
}

// MARK: - Individual pad (cold → hot)

struct PadCell: View {
    let index: Int
    let pad: Pad
    let layer: Layer
    let isActive: Bool
    let triggered: Bool
    let signalLevel: Float
    let intensity: Float
    let folderName: String

    @State private var breathe: Double = 0

    private var isHot: Bool { !layer.isMuted }
    private var isCold: Bool { layer.isMuted }

    private var padColor: Color {
        if isCold { return Theme.ice }
        if isHot { return Theme.orange }
        return Theme.subtle
    }

    private var sampleLabel: String {
        if let sample = pad.sample {
            return sample.name.lowercased()
        }
        return "[no sample]"
    }

    var body: some View {
        VStack(spacing: 4) {
            // Sample name (or empty indicator)
            MarqueeText(
                text: sampleLabel,
                font: .system(size: 14, design: .monospaced).bold(),
                color: isHot && isActive ? .white :
                       isHot ? Theme.orange :
                       isCold ? Theme.ice :
                       Color(white: 0.15),
                shadow: isHot ? Theme.orange.opacity(isActive ? 0.6 : 0.3) :
                        isCold ? Theme.ice.opacity(0.4) :
                        .clear
            )

            // Folder name
            Text(folderName.uppercased())
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(
                    isHot ? Theme.orange.opacity(isActive ? 0.9 : 0.7) :
                    isCold ? Theme.ice.opacity(0.7) :
                    Color(white: 0.15)
                )
                .lineLimit(1)

            // Signal meter
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(isCold ? Theme.ice.opacity(0.25) : (isHot ? Theme.orange.opacity(0.2) : Theme.subtle.opacity(0.3)))
                    RoundedRectangle(cornerRadius: 1)
                        .fill(isHot && isActive ? .white : padColor)
                        .frame(width: geo.size.width * CGFloat(signalLevel))
                }
            }
            .frame(height: 3)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    isHot && isActive ? Theme.orange.opacity(0.2) :
                    isHot ? Theme.orange.opacity(0.08) :
                    isCold ? Theme.ice.opacity(0.1) :
                    Color(white: 0.02)
                )
        )
        // Hot glow
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isHot && isActive ? Theme.orange.opacity(0.3 + 0.2 * breathe) : .clear, lineWidth: 1)
        )
        .shadow(color: isHot && isActive ? Theme.orange.opacity(0.3 + 0.15 * breathe) : .clear, radius: 10)
        // Ice frost — full presence, not dimmed
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .fill(isCold ? Theme.ice.opacity(0.05) : .clear)
        )
        .shadow(color: isCold ? Theme.ice.opacity(0.2) : .clear, radius: 8)
        // Trigger flash
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .fill(triggered ? Theme.orange.opacity(0.15) : .clear)
        )
        // Top border
        .overlay(alignment: .top) {
            Rectangle()
                .fill(
                    isHot && isActive ? Theme.orange :
                    isCold ? Theme.ice.opacity(0.6) :
                    .clear
                )
                .frame(height: 2)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                breathe = 1.0
            }
        }
    }
}

// MARK: - Loop progress bar (above pads)

struct LoopProgressBar: View {
    @ObservedObject var engine: GodEngine

    private var progress: Double {
        let loopLen = engine.transport.loopLengthFrames
        guard loopLen > 0 else { return 0 }
        return Double(engine.transport.position) / Double(loopLen)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Theme.subtle.opacity(0.15))
                Rectangle()
                    .fill(engine.transport.isPlaying ? Theme.blue : Theme.subtle.opacity(0.3))
                    .frame(width: geo.size.width * progress)
            }
        }
        .frame(height: 6)
        .padding(.horizontal, 6)
    }
}

// MARK: - Right-side panel (CC readout + sample browser)

struct CCPanelView: View {
    @ObservedObject var engine: GodEngine
    let masterVolumeMode: Bool
    @Binding var browsingPad: Bool
    @Binding var browserIndex: Int

    private var activeIndex: Int { engine.activePadIndex }
    private var layer: Layer { engine.layers[activeIndex] }
    private var pad: Pad { engine.padBank.pads[activeIndex] }
    private var folderName: String { PadBank.spliceFolderNames[activeIndex] }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Master section — log style
            HStack(spacing: 4) {
                Text("~")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Theme.orange.opacity(0.4))
                Text("MASTER")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.35))
                    .tracking(1)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(Int(engine.masterVolume * 100))")
                    .font(.system(size: 36, design: .monospaced).bold())
                    .foregroundColor(masterVolumeMode ? Theme.orange : Color(white: 0.7))
                Text("%")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(masterVolumeMode ? Theme.orange.opacity(0.6) : Color(white: 0.3))
            }
            .shadow(color: Theme.orange.opacity(masterVolumeMode ? 0.3 : 0.15), radius: 20)
            .padding(.top, 6)

            if masterVolumeMode {
                Text("[V] to exit")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Theme.orange.opacity(0.5))
                    .padding(.top, 2)
            }

            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(height: 1)
                .padding(.vertical, 8)

            if browsingPad {
                SampleBrowserView(engine: engine, padIndex: activeIndex, isOpen: $browsingPad, selectedIndex: $browserIndex)
            } else {
                padReadoutView
            }
        }
        .padding(14)
        .frame(width: 190, alignment: .topLeading)
        .background(Color(red: 0.071, green: 0.067, blue: 0.059))
    }

    private var padReadoutView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Pad number + folder
            HStack(spacing: 6) {
                Text("\(activeIndex + 1)")
                    .font(.system(size: 28, design: .monospaced).bold())
                    .foregroundColor(layer.isMuted ? Theme.ice : Theme.orange)
                Text(folderName.uppercased())
                    .font(.system(size: 16, design: .monospaced).bold())
                    .foregroundColor(layer.isMuted ? Theme.ice.opacity(0.7) : Theme.orange.opacity(0.7))
            }
            .shadow(color: (layer.isMuted ? Theme.ice : Theme.orange).opacity(0.2), radius: 6)
            .padding(.bottom, 4)

            if let sample = pad.sample {
                Text(sample.name.lowercased())
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Color(white: 0.55))
                    .lineLimit(1)
            } else {
                Text("[no sample]")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Theme.subtle)
            }

            Divider()
                .background(Theme.subtle.opacity(0.3))
                .padding(.vertical, 8)

            CCRow(label: "vol", value: "\(Int(layer.volume * 100))%", highlight: !masterVolumeMode)
            CCRow(label: "pan", value: EngineEventInterpreter.formatPan(layer.pan), highlight: false)
            CCRow(label: "HP", value: EngineEventInterpreter.formatFrequency(layer.hpCutoff),
                  highlight: layer.hpCutoff > 21)
            CCRow(label: "LP", value: EngineEventInterpreter.formatFrequency(layer.lpCutoff),
                  highlight: layer.lpCutoff < 19999)

            Spacer()
}
    }
}

// MARK: - Sample browser in right panel

struct SampleBrowserView: View {
    @ObservedObject var engine: GodEngine
    let padIndex: Int
    @Binding var isOpen: Bool
    @Binding var selectedIndex: Int

    @State private var files: [URL] = []

    private var folderName: String { PadBank.spliceFolderNames[padIndex] }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(folderName.uppercased())
                    .font(.system(size: 12, design: .monospaced).bold())
                    .foregroundColor(Theme.orange)
                Spacer()
                Text("[T] close")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Theme.subtle)
            }

            Divider()
                .background(Theme.subtle.opacity(0.3))
                .padding(.vertical, 2)

            if files.isEmpty {
                Text("empty folder")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Theme.subtle)
                    .padding(.top, 4)

                Button {
                    loadFromFilePicker()
                } label: {
                    Text("OPEN FILE...")
                        .font(.system(size: 11, design: .monospaced).bold())
                        .foregroundColor(Theme.blue)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 1) {
                            ForEach(Array(files.enumerated()), id: \.offset) { idx, file in
                                let name = file.deletingPathExtension().lastPathComponent
                                Text(name.lowercased().prefix(18))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(idx == selectedIndex ? Theme.orange : Color(white: 0.5))
                                    .padding(.vertical, 2)
                                    .padding(.horizontal, 4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        idx == selectedIndex
                                            ? Theme.orange.opacity(0.1)
                                            : Color.clear
                                    )
                                    .cornerRadius(2)
                                    .id(idx)
                                    .onTapGesture {
                                        selectedIndex = idx
                                        loadSelectedSample()
                                    }
                            }
                        }
                    }
                    .onChange(of: selectedIndex) { _, newVal in
                        proxy.scrollTo(newVal, anchor: .center)
                    }
                }
            }

            Spacer()

            if !files.isEmpty {
                Divider()
                    .background(Theme.subtle.opacity(0.3))

                HStack(spacing: 8) {
                    Text("W↑ S↓")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(Theme.subtle)
                    Text("⏎ close")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(Theme.subtle)
                }
                .padding(.top, 4)
            }
        }
        .onAppear { scanFolder() }
        .onChange(of: padIndex) { _, _ in scanFolder() }
        .onChange(of: selectedIndex) { _, newVal in
            if !files.isEmpty {
                selectedIndex = min(max(0, newVal), files.count - 1)
            }
        }
    }

    private func scanFolder() {
        let folderURL = PadBank.spliceBasePath.appendingPathComponent(folderName)
        let fm = FileManager.default
        files = (try? fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
            .filter { PadBank.audioExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }) ?? []
        selectedIndex = 0
    }

    func loadSelectedSample() {
        guard selectedIndex < files.count else { return }
        let url = files[selectedIndex]
        do {
            let sample = try Sample.load(from: url)
            engine.padBank.assign(sample: sample, toPad: padIndex)
            engine.padBank.pads[padIndex].samplePath = url.path
            engine.layers[padIndex].name = sample.name.uppercased()
            engine.syncCutToPadBank()
            try? engine.padBank.save()
            engine.detectBPM(forPad: padIndex)
        } catch {
            logger.error("Failed to load sample: \(error.localizedDescription)")
        }
    }

    private func loadFromFilePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.audio]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let sample = try Sample.load(from: url)
                engine.padBank.assign(sample: sample, toPad: padIndex)
                engine.padBank.pads[padIndex].samplePath = url.path
                engine.layers[padIndex].name = sample.name.uppercased()
                engine.syncCutToPadBank()
                try? engine.padBank.save()
                engine.detectBPM(forPad: padIndex)
            } catch {
                logger.error("Failed to load sample: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - CC Row

struct CCRow: View {
    let label: String
    let value: String
    let highlight: Bool

    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .foregroundColor(Color(white: 0.4))
                .frame(width: 40, alignment: .leading)
            Text(value)
                .foregroundColor(highlight ? Theme.orange : Color(white: 0.75))
                .shadow(color: highlight ? Theme.orange.opacity(0.2) : .clear, radius: 4)
        }
        .font(.system(size: 14, design: .monospaced))
        .padding(.vertical, 3)
    }
}
