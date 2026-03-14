// Genesis/Genesis/Views/SampleBrowserView.swift
import SwiftUI
import UniformTypeIdentifiers
import os

private let logger = Logger(subsystem: "genesis", category: "SampleBrowser")

struct SampleBrowserView: View {
    @ObservedObject var engine: GenesisEngine
    let padIndex: Int
    @Binding var isOpen: Bool
    @Binding var selectedIndex: Int

    @State private var files: [URL] = []

    private var folderName: String { PadBank.spliceFolderNames[padIndex] }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("BROWSER")
                    .font(.system(size: 12, design: .monospaced).bold())
                    .foregroundColor(Theme.terracotta)
                    .shadow(color: Theme.terracotta.opacity(0.3), radius: 4)
                Spacer()
                Text("[T] close")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Theme.subtle)
            }

            Rectangle()
                .fill(Theme.text.opacity(0.06))
                .frame(height: 1)
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
                        .foregroundColor(Theme.sage)
                        .shadow(color: Theme.sage.opacity(0.3), radius: 4)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 1) {
                            ForEach(Array(files.enumerated()), id: \.offset) { idx, file in
                                let name = file.deletingPathExtension().lastPathComponent
                                let isSelected = idx == selectedIndex
                                Text(name.lowercased().prefix(18))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(isSelected ? Theme.terracotta : Theme.text.opacity(0.4))
                                    .shadow(color: isSelected ? Theme.terracotta.opacity(0.3) : .clear, radius: 3)
                                    .padding(.vertical, 2)
                                    .padding(.horizontal, 4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        isSelected
                                            ? Theme.terracotta.opacity(0.08)
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
                Rectangle()
                    .fill(Theme.text.opacity(0.06))
                    .frame(height: 1)

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
        do {
            try engine.loadSample(from: files[selectedIndex], forPad: padIndex)
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
                try engine.loadSample(from: url, forPad: padIndex)
            } catch {
                logger.error("Failed to load sample: \(error.localizedDescription)")
            }
        }
    }
}
