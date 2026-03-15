import SwiftUI

enum Theme {
    // ═══════════════════════════════════════════════════════════════
    //  GENESIS — Deep Forest / Chrome design system
    // ═══════════════════════════════════════════════════════════════

    // Background — deep forest at night
    static let bg = Color(red: 0.051, green: 0.102, blue: 0.071)            // #0d1a12

    // Canvas — the darkest layer, near-black green
    static let canvasBg = Color(red: 0.035, green: 0.071, blue: 0.047)      // #091208

    // Text — bright silver, clean and readable
    static let text = Color(red: 0.847, green: 0.878, blue: 0.855)          // #d8e0da

    // Chrome — pure highlight, white-silver flash for active states
    static let chrome = Color(red: 0.941, green: 0.957, blue: 0.945)        // #f0f4f1

    // Sage — active state, playing, channels
    static let sage = Color(red: 0.400, green: 0.690, blue: 0.420)          // #66b06b

    // Moss — system messages, muted/frozen state
    static let moss = Color(red: 0.500, green: 0.680, blue: 0.530)          // #80ad87

    // Terracotta — hot state, recording, triggers, alive
    static let terracotta = Color(red: 0.878, green: 0.400, blue: 0.220)    // #e06638

    // Forest — oracle, success, positive feedback
    static let forest = Color(red: 0.310, green: 0.620, blue: 0.340)        // #4f9e57

    // Clay — warnings, pad labels, stop
    static let clay = Color(red: 0.820, green: 0.310, blue: 0.250)          // #d14f40

    // Wheat — edit mode, secondary warnings
    static let wheat = Color(red: 0.878, green: 0.690, blue: 0.290)         // #e0b04a

    // Subtle — muted forest for empty slots, hints, disabled
    static let subtle = Color(red: 0.145, green: 0.200, blue: 0.165)        // #25332a

    // Zone separator — subtle thin lines between UI zones
    static let separator = Color(red: 0.200, green: 0.310, blue: 0.230).opacity(0.4)

    // Pad channel colors — bold earth spectrum (MUCH more saturated than before)
    static let padColors: [Color] = [
        Color(red: 0.831, green: 0.345, blue: 0.188),  // kicks — bold rust       #d4582f
        Color(red: 0.831, green: 0.541, blue: 0.188),  // snares — rich amber      #d48a30
        Color(red: 0.831, green: 0.659, blue: 0.157),  // hats — bright gold       #d4a828
        Color(red: 0.435, green: 0.627, blue: 0.188),  // perc — vivid olive       #6fa030
        Color(red: 0.220, green: 0.565, blue: 0.227),  // bass — deep emerald      #38903a
        Color(red: 0.722, green: 0.439, blue: 0.251),  // keys — warm sienna       #b87040
        Color(red: 0.753, green: 0.376, blue: 0.439),  // vox — dusty mauve        #c06070
        Color(red: 0.784, green: 0.659, blue: 0.314),  // fx — sandy gold          #c8a850
    ]

    static func padColor(_ index: Int) -> Color {
        padColors[index % padColors.count]
    }

    // ═══════════════════════════════════════════════════════════════
    //  TYPOGRAPHY — big, bold, retro-digital
    // ═══════════════════════════════════════════════════════════════
    //
    //  OPTIONAL: For true pixel/bitmap feel, bundle one of these OFL fonts:
    //    • "Silkscreen" by Jason Kottke
    //    • "Press Start 2P" from Google Fonts
    //    • "Cozette" by slavfox (MIT)
    //  Add the .ttf to Xcode target + Info.plist "Fonts provided by application"
    //  Then swap .monospaced → .custom("FontName", size: N)

    // Hero numbers — BPM, master volume, dB (SCOREBOARD SIZE)
    static let hero = Font.system(size: 52, design: .monospaced).weight(.bold)

    // Channel name in inspect panel
    static let title = Font.system(size: 36, design: .monospaced).weight(.bold)

    // Standard mono text — terminal lines, inspector rows
    static let mono = Font.system(size: 17, design: .monospaced)

    // Small mono — labels, status indicators
    static let monoSmall = Font.system(size: 14, design: .monospaced)

    // Large mono — hotkey keys, section headers
    static let monoLarge = Font.system(size: 20, design: .monospaced).weight(.bold)

    // Tiny — effect dots, hit counts
    static let monoTiny = Font.system(size: 11, design: .monospaced)

    // Section header label
    static let sectionLabel = Font.system(size: 15, design: .monospaced).weight(.semibold)

    // Legacy aliases — use new names in new code
    static let blue = sage
    static let ice = moss
    static let orange = terracotta
    static let green = forest
    static let red = clay
    static let amber = wheat
}
