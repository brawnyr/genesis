import SwiftUI

struct TerminalLine: Identifiable {
    let id = UUID()
    let text: String
    let isHighlight: Bool
}

class TerminalState: ObservableObject {
    @Published var lines: [TerminalLine] = []
    private let maxLines = 50

    func append(_ text: String, highlight: Bool = false) {
        let line = TerminalLine(text: text, isHighlight: highlight)
        lines.append(line)
        if lines.count > maxLines {
            lines.removeFirst(lines.count - maxLines)
        }
    }

    func setStatus(_ text: String) {
        lines = [TerminalLine(text: text, isHighlight: false)]
    }
}

struct GenesisTerminalView: View {
    @ObservedObject var state: TerminalState

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(state.lines.enumerated()), id: \.element.id) { index, line in
                        Text(line.text)
                            .font(Theme.monoSmall)
                            .foregroundColor(line.isHighlight ? Theme.blue : Theme.terminalText)
                            .opacity(lineOpacity(index: index, total: state.lines.count))
                            .id(line.id)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
            }
            .onChange(of: state.lines.count) { _, _ in
                if let last = state.lines.last {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .background(Theme.bg)
    }

    private func lineOpacity(index: Int, total: Int) -> Double {
        guard total > 1 else { return 1.0 }
        let position = Double(index) / Double(total - 1)
        // Linear: 0.3 for oldest, 1.0 for newest
        return 0.3 + 0.7 * position
    }
}
