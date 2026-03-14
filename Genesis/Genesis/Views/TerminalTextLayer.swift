// Genesis/Genesis/Views/TerminalTextLayer.swift
import SwiftUI

struct TerminalTextLayer: View {
    @ObservedObject var interpreter: EngineEventInterpreter
    @ObservedObject var engine: GenesisEngine

    @State private var cursorVisible = true

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(interpreter.lines.enumerated()), id: \.element.id) { index, line in
                        TerminalLineView(
                            line: line,
                            opacity: lineOpacity(index: index, total: interpreter.lines.count)
                        )
                    }

                    // Blinking cursor
                    Text("_")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(Theme.terracotta)
                        .shadow(color: Theme.terracotta.opacity(0.4), radius: 4)
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

struct TerminalLineView: View {
    let line: TerminalLine
    let opacity: Double

    private var color: Color {
        if let padIdx = line.padIndex, line.kind == .hit {
            return Theme.padColor(padIdx)
        }
        switch line.kind {
        case .system:    return Theme.moss
        case .transport: return Theme.moss
        case .hit:       return Theme.terracotta
        case .state:     return Theme.text
        case .capture:   return Theme.terracotta
        case .browse:    return Theme.moss
        case .oracle:    return Theme.forest
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(line.timeString)
                .foregroundColor(Theme.subtle.opacity(0.8))
            Text(" > ")
                .foregroundColor(color.opacity(0.4))
            Text(line.text)
                .foregroundColor(color)
                .shadow(color: color.opacity(0.3), radius: 3)
        }
        .font(.system(size: 14, design: .monospaced))
        .opacity(opacity)
    }
}
