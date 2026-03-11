import SwiftUI

struct TipDeck {
    private var queue: [Int] = []

    static let allTips: [String] = [
        "sidechain compression is basically the kick telling everything else to duck",
        "most hip-hop drums sit between 80-100 BPM in half-time feel",
        "layering a clap with a snare adds body without losing the crack",
        "high-passing your kicks around 30hz removes sub-rumble you can't hear anyway",
        "a loop that sounds boring solo might be exactly what the mix needs",
        "the MPC was designed so you could play drums like a keyboard player",
        "J Dilla's secret was making quantized beats feel drunk",
        "vinyl crackle is just noise but it makes everything feel warmer",
        "the 808 kick is actually a sine wave with a pitch envelope",
        "reverb on a snare: a little adds space, a lot adds vibe",
        "swing is just delaying every other note by a few milliseconds",
        "four-on-the-floor kick + offbeat hi-hat = instant house music",
        "the TR-808 was a commercial failure before hip-hop saved it",
        "sampling a sound and pitching it down makes everything sound heavier",
        "sometimes the best production move is deleting something",
    ]

    mutating func next() -> String {
        if queue.isEmpty {
            queue = Array(0..<Self.allTips.count)
            queue.shuffle()
        }
        return Self.allTips[queue.removeLast()]
    }
}

struct TypewriterState {
    let text: String
    let charInterval: Double

    func visibleText(elapsed: Double) -> String {
        let charCount = min(Int(elapsed / charInterval), text.count)
        return String(text.prefix(charCount))
    }

    var totalDuration: Double {
        Double(text.count) * charInterval
    }
}

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
