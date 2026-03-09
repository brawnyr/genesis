import SwiftUI

struct PadGridView: View {
    @ObservedObject var engine: GodEngine

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                ForEach(0..<8, id: \.self) { i in
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.muted.opacity(0.4))
                            .frame(width: 50, height: 40)
                            .overlay(
                                Text("\(i + 1)")
                                    .font(Theme.monoSmall)
                                    .foregroundColor(Theme.dim)
                            )
                        Text(engine.padBank.pads[i].name)
                            .font(Theme.monoTiny)
                            .foregroundColor(Theme.dim)
                            .lineLimit(1)
                            .frame(width: 50)
                    }
                }
            }
        }
    }
}
