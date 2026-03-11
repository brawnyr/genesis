import Foundation
import os

private let logger = Logger(subsystem: "com.god.pads", category: "PadBank")

struct Pad {
    let index: Int
    let midiNote: Int
    var name: String
    var sample: Sample?
    var samplePath: String?
    var isOneShot: Bool = true
    var cut: Bool = true
}

struct PadAssignment: Codable {
    let path: String
    let name: String
    var cut: Bool?
}


struct PadConfig: Codable {
    var assignments: [String: PadAssignment] = [:]
}

struct PadBank {
    static let baseNote = 36
    static let padCount = 8

    static let spliceFolderNames = ["kicks", "snares", "hats", "perc", "bass", "keys", "vox", "fx"]

    static let spliceBasePath: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Splice")
            .appendingPathComponent("sounds")
    }()

    static let audioExtensions: Set<String> = ["wav", "aif", "aiff", "mp3", "m4a", "flac", "ogg"]

    var pads: [Pad] = (0..<padCount).map { i in
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
                cfg.assignments[String(pad.index)] = PadAssignment(path: path, name: pad.name, cut: pad.cut)
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
            do {
                let sample = try Sample.load(from: url)
                pads[index].sample = sample
                pads[index].samplePath = assignment.path
                pads[index].name = assignment.name
                pads[index].cut = assignment.cut ?? true
            } catch {
                logger.warning("Failed to load saved sample \(assignment.path): \(error.localizedDescription)")
            }
        }
    }

    mutating func loadFromSpliceFolders() {
        let fm = FileManager.default
        for (index, folderName) in Self.spliceFolderNames.enumerated() {
            // Skip pads that already have a sample loaded (pads.json took priority)
            guard pads[index].sample == nil else { continue }

            let folderURL = Self.spliceBasePath.appendingPathComponent(folderName)
            guard let contents = try? fm.contentsOfDirectory(at: folderURL,
                                                              includingPropertiesForKeys: nil)
                    .filter({ Self.audioExtensions.contains($0.pathExtension.lowercased()) })
                    .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
            else { continue }

            guard let firstFile = contents.first else { continue }
            do {
                let sample = try Sample.load(from: firstFile)
                pads[index].sample = sample
                pads[index].samplePath = firstFile.path
                pads[index].name = sample.name.uppercased()
            } catch {
                logger.warning("Failed to load Splice sample \(firstFile.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }
}
