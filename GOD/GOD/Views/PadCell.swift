// GOD/GOD/Views/PadCell.swift
import SwiftUI

struct PadCell: View {
    let index: Int
    let pad: Pad
    let layer: Layer
    let isActive: Bool
    let triggered: Bool
    let signalLevel: Float
    let intensity: Float
    let folderName: String
    let pendingMute: Bool?  // nil = no pending change

    @State private var breathe: Double = 0
    @State private var pendingBlink: Bool = false

    private var hasPending: Bool { pendingMute != nil }
    private var isHot: Bool { !layer.isMuted }
    private var isCold: Bool { layer.isMuted }

    private var padColor: Color {
        if hasPending {
            // Show the target state color, pulsing
            return pendingMute == true ? Theme.ice : Theme.orange
        }
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
        .modifier(PadCellOverlay(
            isHot: isHot,
            isCold: isCold,
            isActive: isActive,
            triggered: triggered,
            hasPending: hasPending,
            pendingMute: pendingMute,
            breathe: breathe,
            pendingBlink: pendingBlink
        ))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                breathe = 1.0
            }
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                pendingBlink = true
            }
        }
    }
}
