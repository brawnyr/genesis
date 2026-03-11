import Testing
@testable import GOD

@Test func layerRecordsHits() {
    var layer = Layer(index: 0, name: "KICK")
    layer.addHit(at: 1000, velocity: 100)
    layer.addHit(at: 5000, velocity: 80)
    #expect(layer.hits.count == 2)
}

@Test func layerHitsInRange() {
    var layer = Layer(index: 0, name: "KICK")
    layer.addHit(at: 100, velocity: 100)
    layer.addHit(at: 500, velocity: 80)
    layer.addHit(at: 1000, velocity: 90)

    let hits = layer.hits(inRange: 50..<600)
    #expect(hits.count == 2)
    #expect(hits[0].position == 100)
    #expect(hits[1].position == 500)
}

@Test func layerClear() {
    var layer = Layer(index: 0, name: "KICK")
    layer.addHit(at: 100, velocity: 100)
    layer.addHit(at: 200, velocity: 80)
    layer.clear()
    #expect(layer.hits.count == 0)
}

@Test func layerMuteToggle() {
    var layer = Layer(index: 0, name: "KICK")
    #expect(layer.isMuted == false)
    layer.isMuted.toggle()
    #expect(layer.isMuted == true)
}

@Test func layerUndo() {
    var layer = Layer(index: 0, name: "KICK")
    layer.addHit(at: 100, velocity: 100)
    layer.addHit(at: 200, velocity: 80)
    #expect(layer.hits.count == 2)

    layer.clear()
    #expect(layer.hits.count == 0)
    #expect(layer.canUndo == true)

    layer.undo()
    #expect(layer.hits.count == 2)
    #expect(layer.canUndo == false)
}

@Test func layerUndoWhenNothingCleared() {
    var layer = Layer(index: 0, name: "KICK")
    layer.addHit(at: 100, velocity: 100)
    #expect(layer.canUndo == false)
    layer.undo() // should be a no-op
    #expect(layer.hits.count == 1)
}

@Test func layerEffectDefaults() {
    let layer = Layer(index: 0, name: "KICK")
    #expect(layer.pan == 0.5)
    #expect(layer.hpCutoff == 20.0)
    #expect(layer.lpCutoff == 20000.0)
}

@Test func layerEffectParamsSettable() {
    var layer = Layer(index: 0, name: "KICK")
    layer.pan = 0.0
    layer.hpCutoff = 500.0
    layer.lpCutoff = 8000.0
    #expect(layer.pan == 0.0)
    #expect(layer.hpCutoff == 500.0)
    #expect(layer.lpCutoff == 8000.0)
}

@Test func layerCutDefaultsFalse() {
    let layer = Layer(index: 0, name: "KICK")
    #expect(layer.cut == false)
}
