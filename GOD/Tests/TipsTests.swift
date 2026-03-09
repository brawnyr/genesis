import Testing
@testable import GOD

@Test func tipsDeckShuffles() {
    var deck = TipDeck()
    let first = deck.next()
    #expect(!first.isEmpty)
}

@Test func tipsDeckNoRepeatsUntilExhausted() {
    var deck = TipDeck()
    var seen: Set<String> = []
    let total = TipDeck.allTips.count
    for _ in 0..<total {
        let tip = deck.next()
        #expect(!seen.contains(tip), "Duplicate tip before deck exhausted")
        seen.insert(tip)
    }
    // After exhaustion, reshuffles — should still return a tip
    let afterReshuffle = deck.next()
    #expect(!afterReshuffle.isEmpty)
}

@Test func typewriterProgress() {
    let tw = TypewriterState(text: "hello", charInterval: 0.1)
    #expect(tw.visibleText(elapsed: 0) == "")
    #expect(tw.visibleText(elapsed: 0.25) == "he")
    #expect(tw.visibleText(elapsed: 1.0) == "hello")
}
