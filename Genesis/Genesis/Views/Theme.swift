import SwiftUI

enum Theme {
    // Background
    static let bg = Color(red: 0.102, green: 0.098, blue: 0.090)       // #1a1917

    // Text — bright white, always pops
    static let text = Color.white

    // Claude blue — active state, playing, channels
    static let blue = Color(red: 0.384, green: 0.514, blue: 0.886)     // #6283e2

    // Ice blue — frozen, not faded
    static let ice = Color(red: 0.39, green: 0.75, blue: 1.0)          // #64beff

    // Orange — hot state, recording, triggers, alive
    static let orange = Color(red: 0.855, green: 0.482, blue: 0.290)   // #da7b4a

    // Crystal clear — warm white with orange warmth, like sunlight through glass
    static let crystalClear = Color(red: 0.95, green: 0.85, blue: 0.70) // warm amber-white

    // Status colors
    static let green = Color(red: 0.373, green: 0.667, blue: 0.431)    // #5faa6e
    static let red = Color(red: 0.831, green: 0.337, blue: 0.306)      // #d4564e
    static let amber = Color(red: 0.831, green: 0.635, blue: 0.306)    // #d4a24e

    // Pad channel colors — bright, solid, clean
    static let padColors: [Color] = [
        Color(red: 0.95, green: 0.30, blue: 0.30),  // kicks — red
        Color(red: 0.95, green: 0.60, blue: 0.20),  // snares — orange
        Color(red: 0.95, green: 0.85, blue: 0.25),  // hats — yellow
        Color(red: 0.30, green: 0.85, blue: 0.45),  // perc — green
        Color(red: 0.25, green: 0.75, blue: 0.95),  // bass — cyan
        Color(red: 0.45, green: 0.45, blue: 0.95),  // keys — blue
        Color(red: 0.75, green: 0.40, blue: 0.95),  // vox — purple
        Color(red: 0.95, green: 0.45, blue: 0.70),  // fx — pink
    ]

    static func padColor(_ index: Int) -> Color {
        padColors[index % padColors.count]
    }

    // Subtle — only for empty slots and track background
    static let subtle = Color(white: 0.25)

    // Terminal text — same white but for dimming
    static let terminalText = Color.white
    static let terminalDim = Color(white: 0.4)

    // Fonts — bumped sizes for readability
    static let mono = Font.system(size: 16, design: .monospaced)
    static let monoSmall = Font.system(size: 14, design: .monospaced)
    static let monoTiny = Font.system(size: 12, design: .monospaced)
    static let monoLarge = Font.system(size: 22, design: .monospaced)
    static let monoTitle = Font.system(size: 28, design: .monospaced).weight(.bold)

    // Canvas
    static let canvasBg = Color(red: 0.075, green: 0.071, blue: 0.063)  // #131210

    static let genesisSubtitle = "GENESIS ON DISK"

    // Charcoal for idle title
    static let charcoal = Color(red: 0.165, green: 0.157, blue: 0.145)  // #2a2825

}
