// GOD/GOD/Views/PadVisualsLayer.swift
import SwiftUI

struct PadVisualsLayer: View {
    @ObservedObject var interpreter: EngineEventInterpreter
    let isMuted: [Bool]
    let isSustained: [Bool]

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(0..<PadBank.padCount, id: \.self) { i in
                    ZStack(alignment: .bottom) {
                        if !isMuted[i] && interpreter.padIntensities[i] > 0.01 {
                            let intensity = CGFloat(interpreter.padIntensities[i])
                            let height = geo.size.height * intensity
                            // Hot pads = orange columns
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Theme.orange.opacity(Double(intensity) * 0.25),
                                    Theme.orange.opacity(0.03),
                                    .clear
                                ]),
                                startPoint: .bottom,
                                endPoint: .top
                            )
                            .frame(height: height)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
    }
}
