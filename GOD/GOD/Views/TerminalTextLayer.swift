// GOD/GOD/Views/TerminalTextLayer.swift
import SwiftUI

struct TerminalTextLayer: View {
    @ObservedObject var interpreter: EngineEventInterpreter
    @State private var cursorVisible = true

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 1) {
                    Spacer(minLength: 100)

                    ForEach(Array(interpreter.lines.enumerated()), id: \.element.id) { index, line in
                        HStack(alignment: .top, spacing: 0) {
                            Text(line.timeString)
                                .foregroundColor(Color(white: 0.3))
                            Text(" > ")
                                .foregroundColor(lineColor(line.kind).opacity(0.5))
                            Text(line.text)
                                .foregroundColor(lineColor(line.kind))
                        }
                        .font(.system(size: 11, design: .monospaced))
                        .opacity(lineOpacity(index: index, total: interpreter.lines.count))
                        .id(line.id)
                    }

                    // Blinking cursor
                    Text("_")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Theme.orange)
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

    private func lineColor(_ kind: LineKind) -> Color {
        switch kind {
        case .system:    return Theme.ice
        case .transport: return Theme.ice
        case .hit:       return Theme.orange
        case .state:     return Color.white
        case .capture:   return Theme.orange
        case .browse:    return Theme.ice
        }
    }

    private func lineOpacity(index: Int, total: Int) -> Double {
        guard total > 1 else { return 1.0 }
        let position = Double(index) / Double(total - 1)
        return 0.35 + 0.65 * position
    }
}
