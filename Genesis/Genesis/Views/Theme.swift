import SwiftUI

enum Theme {
    // Background — warm brown, never cold black
    static let bg = Color(red: 0.165, green: 0.145, blue: 0.125)            // #2a2520

    // Canvas — deep brown, slightly deeper than bg
    static let canvasBg = Color(red: 0.133, green: 0.118, blue: 0.102)      // #221e1a

    // Text — cream, warm not sterile white
    static let text = Color(red: 0.941, green: 0.922, blue: 0.890)          // #f0ebe3

    // Sage — active state, playing, channels (was "blue")
    static let sage = Color(red: 0.478, green: 0.549, blue: 0.314)          // #7a8c50

    // Moss — system messages, muted/frozen state (was "ice")
    static let moss = Color(red: 0.604, green: 0.667, blue: 0.471)          // #9aaa78

    // Terracotta — hot state, recording, triggers, alive (was "orange")
    static let terracotta = Color(red: 0.769, green: 0.451, blue: 0.290)    // #c4734a

    // Forest — oracle, success, positive feedback (was "green")
    static let forest = Color(red: 0.420, green: 0.502, blue: 0.251)        // #6b8040

    // Clay — warnings, pad labels, stop (was "red")
    static let clay = Color(red: 0.710, green: 0.380, blue: 0.306)          // #b5614e

    // Wheat — edit mode, secondary warnings (was "amber")
    static let wheat = Color(red: 0.769, green: 0.604, blue: 0.322)         // #c49a52

    // Subtle — warm gray for empty slots, hints, disabled
    static let subtle = Color(red: 0.227, green: 0.208, blue: 0.188)        // #3a3530

    // Pad channel colors — earth spectrum
    static let padColors: [Color] = [
        Color(red: 0.659, green: 0.353, blue: 0.259),  // kicks — sienna    #a85a42
        Color(red: 0.769, green: 0.502, blue: 0.314),  // snares — clay     #c48050
        Color(red: 0.769, green: 0.627, blue: 0.333),  // hats — wheat      #c4a055
        Color(red: 0.478, green: 0.549, blue: 0.271),  // perc — olive      #7a8c45
        Color(red: 0.353, green: 0.478, blue: 0.290),  // bass — forest     #5a7a4a
        Color(red: 0.545, green: 0.431, blue: 0.306),  // keys — umber      #8b6e4e
        Color(red: 0.627, green: 0.439, blue: 0.408),  // vox — dusty rose  #a07068
        Color(red: 0.722, green: 0.627, blue: 0.439),  // fx — sand         #b8a070
    ]

    static func padColor(_ index: Int) -> Color {
        padColors[index % padColors.count]
    }

    // Fonts
    static let mono = Font.system(size: 16, design: .monospaced)
    static let monoSmall = Font.system(size: 14, design: .monospaced)
    static let monoLarge = Font.system(size: 22, design: .monospaced)

    // Legacy aliases — use new names in new code
    static let blue = sage
    static let ice = moss
    static let orange = terracotta
    static let green = forest
    static let red = clay
    static let amber = wheat
}
