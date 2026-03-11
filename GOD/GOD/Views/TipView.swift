import SwiftUI

struct TipView: View {
    @State private var tipDeck = TipDeck()
    @State private var currentTip = ""
    @State private var tipStartTime = Date()
    @State private var elapsed: Double = 0

    private let charInterval = 0.08
    private let cycleInterval = 12.0

    // Static timer avoids accumulating duplicates if view is recreated
    private static let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            let typewriter = TypewriterState(text: currentTip, charInterval: charInterval)
            let visible = typewriter.visibleText(elapsed: elapsed)

            Text("\"\(visible)\"")
                .font(Theme.monoSmall)
                .foregroundColor(Theme.text)

            if elapsed >= typewriter.totalDuration {
                Text("— claude")
                    .font(Theme.monoTiny)
                    .foregroundColor(Theme.blue)
            }
        }
        .onAppear { nextTip() }
        .onReceive(Self.timer) { _ in
            elapsed = Date().timeIntervalSince(tipStartTime)
            let typewriter = TypewriterState(text: currentTip, charInterval: charInterval)
            if elapsed > typewriter.totalDuration + cycleInterval {
                nextTip()
            }
        }
    }

    private func nextTip() {
        currentTip = tipDeck.next()
        tipStartTime = Date()
        elapsed = 0
    }
}
