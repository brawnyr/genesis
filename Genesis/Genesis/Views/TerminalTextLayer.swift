// Genesis/Genesis/Views/TerminalTextLayer.swift
import SwiftUI

struct TerminalTextLayer: View {
    @ObservedObject var interpreter: EngineEventInterpreter
    @ObservedObject var engine: GenesisEngine

    @State private var cursorVisible = true

    var body: some View {
        let looping = engine.isLooping
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(interpreter.lines.enumerated()), id: \.element.id) { index, line in
                        TerminalLineView(
                            line: line,
                            isLooping: looping,
                            opacity: lineOpacity(index: index, total: interpreter.lines.count)
                        )
                    }

                    // Blinking cursor
                    Text("_")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(looping ? Theme.red : Theme.orange)
                        .shadow(color: (looping ? Theme.red : Theme.orange).opacity(0.6), radius: 6)
                        .opacity(cursorVisible ? 0.7 : 0)
                        .id("cursor")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
            .onChange(of: interpreter.lines.count) { _, _ in
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("cursor", anchor: .bottom)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: looping)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                cursorVisible.toggle()
            }
        }
    }

    private func lineOpacity(index: Int, total: Int) -> Double {
        guard total > 1 else { return 1.0 }
        let position = Double(index) / Double(total - 1)
        return 0.35 + 0.65 * position
    }
}

// Separate view so SwiftUI re-renders each line when isLooping changes
struct TerminalLineView: View {
    let line: TerminalLine
    let isLooping: Bool
    let opacity: Double

    private var color: Color {
        if isLooping { return Theme.red }
        switch line.kind {
        case .system:    return Theme.ice
        case .transport: return Theme.ice
        case .hit:       return Theme.orange
        case .state:     return Color.white
        case .capture:   return Theme.orange
        case .browse:    return Theme.ice
        case .oracle:    return Theme.green
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(line.timeString)
                .foregroundColor(isLooping ? Theme.red.opacity(0.4) : Color(white: 0.4))
                .shadow(color: (isLooping ? Theme.red : Color(white: 0.3)).opacity(0.4), radius: 3)
            Text(" > ")
                .foregroundColor(color.opacity(0.5))
                .shadow(color: color.opacity(0.3), radius: 3)
            Text(line.text)
                .foregroundColor(color)
                .shadow(color: color.opacity(0.5), radius: 6)
        }
        .font(.system(size: 14, design: .monospaced))
        .opacity(opacity)
        .id("\(line.id)-\(isLooping)")
    }
}
