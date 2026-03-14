// Genesis/Genesis/Views/PadSelect.swift
// Compact horizontal pad strip — lives at the bottom of the layout
import SwiftUI

struct PadSelect: View {
    @ObservedObject var engine: GenesisEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PAD_SELECT")
                .font(.system(size: 11, design: .monospaced).bold())
                .foregroundColor(Theme.orange)
                .shadow(color: Theme.orange.opacity(0.5), radius: 6)
                .padding(.horizontal, 6)
                .padding(.top, 4)
                .padding(.bottom, 2)

            TimelineView(.periodic(from: .now, by: 0.5)) { timeline in
            let blink = Int(timeline.date.timeIntervalSinceReferenceDate / 0.5) % 2 == 0

            HStack(spacing: 2) {
                ForEach(0..<PadBank.padCount, id: \.self) { padIdx in
                    let layer = engine.layers[padIdx]
                    let isActive = engine.activePadIndex == padIdx
                    let name = PadBank.spliceFolderNames[padIdx].uppercased()
                    let padColor = Theme.padColor(padIdx)

                    VStack(alignment: .leading, spacing: 3) {
                        // Pad name
                        HStack(spacing: 3) {
                            Text(name)
                                .font(.system(size: isActive ? 14 : 11, design: .monospaced).bold())
                                .foregroundColor(padColor)
                                .shadow(color: padColor.opacity(isActive ? 0.6 : 0.2), radius: 6)
                            if isActive && blink {
                                Text("_")
                                    .font(.system(size: 11, weight: .light, design: .monospaced))
                                    .foregroundColor(padColor)
                                    .shadow(color: padColor.opacity(0.5), radius: 4)
                            }
                        }

                        // Volume
                        Text("\(Int(layer.volume * 100))%")
                            .font(.system(size: 12, design: .monospaced).bold())
                            .foregroundColor(layer.isMuted ? Theme.blue : .white)
                            .shadow(color: (layer.isMuted ? Theme.blue : .white).opacity(isActive ? 0.4 : 0.1), radius: 5)

                        // Status
                        if !layer.statusLine.isEmpty {
                            Text(layer.statusLine)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.white.opacity(0.4))
                                .lineLimit(2)
                        }

                        // Hit count
                        if !layer.hits.isEmpty {
                            Text("\(layer.hits.count) hits")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(padColor.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isActive ? padColor.opacity(0.08) : Color.clear)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(isActive ? padColor.opacity(0.3) : Color.white.opacity(0.04), lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        engine.activePadIndex = padIdx
                    }
                }
            }
            .padding(4)
        }
        }
    }
}
