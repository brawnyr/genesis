import Foundation

struct Pad {
    let index: Int
    let midiNote: Int
    var name: String
    var sample: Sample?
    var samplePath: String?
    var isOneShot: Bool = true
}

struct PadAssignment: Codable {
    let path: String
    let name: String
}

struct PadConfig: Codable {
    var assignments: [String: PadAssignment] = [:]
}

struct PadBank {
    static let baseNote = 36
    static let padCount = 8

    var pads: [Pad] = (0..<8).map { i in
        Pad(index: i, midiNote: baseNote + i, name: "PAD \(i + 1)")
    }

    func padIndex(forNote note: Int) -> Int? {
        let index = note - Self.baseNote
        guard index >= 0, index < Self.padCount else { return nil }
        return index
    }

    mutating func assign(sample: Sample, toPad index: Int) {
        guard index >= 0, index < Self.padCount else { return }
        pads[index].sample = sample
        pads[index].name = sample.name.uppercased()
    }

    var config: PadConfig {
        var cfg = PadConfig()
        for pad in pads {
            if let path = pad.samplePath {
                cfg.assignments[String(pad.index)] = PadAssignment(path: path, name: pad.name)
            }
        }
        return cfg
    }

    static let configURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".god")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("pads.json")
    }()

    func save() throws {
        let data = try JSONEncoder().encode(config)
        try data.write(to: Self.configURL)
    }

    mutating func loadConfig() throws {
        let data = try Data(contentsOf: Self.configURL)
        let cfg = try JSONDecoder().decode(PadConfig.self, from: data)
        for (key, assignment) in cfg.assignments {
            guard let index = Int(key), index >= 0, index < Self.padCount else { continue }
            let url = URL(fileURLWithPath: assignment.path)
            if let sample = try? Sample.load(from: url) {
                pads[index].sample = sample
                pads[index].samplePath = assignment.path
                pads[index].name = assignment.name
            }
        }
    }
}
