import Testing
@testable import Genesis

@Test func layerHitsInRangeBoundaryPrecision() {
    var layer = Layer(index: 0, name: "KICK")
    layer.addHit(at: 100, velocity: 100)
    layer.addHit(at: 500, velocity: 80)
    layer.addHit(at: 1000, velocity: 90)

    // Hit exactly at lowerBound should be included
    let hitsAtLower = layer.hits(inRange: 100..<500)
    #expect(hitsAtLower.count == 1)
    #expect(hitsAtLower[0].position == 100)

    // Hit exactly at upperBound should be excluded (Range is half-open)
    let hitsAtUpper = layer.hits(inRange: 100..<1000)
    #expect(hitsAtUpper.count == 2)

    // Empty range
    let empty = layer.hits(inRange: 200..<200)
    #expect(empty.count == 0)
}

@Test func layerOutOfOrderInsertionMaintainsSortedOrder() {
    var layer = Layer(index: 0, name: "KICK")
    layer.addHit(at: 500, velocity: 80)
    layer.addHit(at: 100, velocity: 100)
    layer.addHit(at: 300, velocity: 90)

    #expect(layer.hits[0].position == 100)
    #expect(layer.hits[1].position == 300)
    #expect(layer.hits[2].position == 500)
}

@Test func layerDoubleClearThenUndo() {
    var layer = Layer(index: 0, name: "KICK")
    layer.addHit(at: 100, velocity: 100)
    layer.addHit(at: 200, velocity: 80)
    layer.clear()  // previousHits = [hit100, hit200]
    layer.undo()   // should restore [hit100, hit200]
    #expect(layer.hits.count == 2, "Undo after single clear should restore both hits")
    #expect(layer.hits[0].position == 100)
    #expect(layer.hits[1].position == 200)

    // Second clear + undo should also round-trip
    layer.clear()  // previousHits = [hit100, hit200]
    layer.clear()  // previousHits = [] (empty)
    layer.undo()   // should restore [] (the state after first clear)
    #expect(layer.hits.count == 0, "Undo after double clear restores the empty state")
}

@Test func layerSwingDefaultValue() {
    let layer = Layer(index: 0, name: "KICK")
    #expect(layer.swing == 0.5)
}

@Test func layerSwingClamped() {
    var layer = Layer(index: 0, name: "KICK")
    layer.swing = 0.3
    #expect(layer.swing == 0.5)  // clamped to min 0.5
    layer.swing = 1.5
    #expect(layer.swing == 1.0)  // clamped to max 1.0
    layer.swing = 0.9
    #expect(layer.swing == 0.9)  // within range, unchanged
    layer.swing = 0.65
    #expect(layer.swing == 0.65)
}
