import Testing
@testable import GOD

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
    layer.clear()  // previousHits = [] (empty, since hits was already empty)
    layer.undo()   // should restore [] (the state after first clear)
    #expect(layer.hits.count == 0)
}

@Test func layerSwingDefaultValue() {
    let layer = Layer(index: 0, name: "KICK")
    #expect(layer.swing == 0.5)
}

@Test func layerSwingClamped() {
    var layer = Layer(index: 0, name: "KICK")
    layer.swing = 0.3
    #expect(layer.swing == 0.5)
    layer.swing = 0.9
    #expect(layer.swing == 0.75)
    layer.swing = 0.65
    #expect(layer.swing == 0.65)
}
