import SwiftUI

enum Theme {
    // ═══════════════════════════════════════════════════════════════
    //  GENESIS — First Light design system
    // ═══════════════════════════════════════════════════════════════

    // Backgrounds — midnight studio
    static let bg       = Color(red: 0.043, green: 0.067, blue: 0.125)     // #0B1120
    static let canvasBg = Color(red: 0.067, green: 0.094, blue: 0.153)     // #111827
    static let elevated = Color(red: 0.102, green: 0.137, blue: 0.196)     // #1A2332

    // Text — true bright white
    static let text   = Color(red: 0.796, green: 0.835, blue: 0.882)       // #CBD5E1
    static let chrome = Color(red: 0.973, green: 0.980, blue: 0.988)       // #F8FAFC

    // Signature blues
    static let electric = Color(red: 0.231, green: 0.510, blue: 0.965)     // #3B82F6
    static let sky      = Color(red: 0.490, green: 0.827, blue: 0.988)     // #7DD3FC
    static let ice      = Color(red: 0.729, green: 0.902, blue: 0.992)     // #BAE6FD

    // Semantic — vivid, not muted
    static let sage       = Color(red: 0.290, green: 0.871, blue: 0.502)   // #4ADE80
    static let mint       = Color(red: 0.204, green: 0.827, blue: 0.600)   // #34D399
    static let ember      = Color(red: 0.976, green: 0.451, blue: 0.086)   // #F97316
    static let terracotta = Color(red: 0.918, green: 0.345, blue: 0.047)   // #EA580C
    static let gold       = Color(red: 0.984, green: 0.749, blue: 0.141)   // #FBBF24
    static let clay       = Color(red: 0.937, green: 0.267, blue: 0.267)   // #EF4444
    static let rose       = Color(red: 0.984, green: 0.443, blue: 0.522)   // #FB7185

    // Structural
    static let subtle    = Color(red: 0.118, green: 0.161, blue: 0.231)    // #1E293B
    static let muted     = Color(red: 0.392, green: 0.455, blue: 0.545)    // #64748B
    static let separator = Color(red: 0.231, green: 0.510, blue: 0.965)
                            .opacity(0.12)                                  // electric @ 12%

    // Pad colors — full spectrum
    static let padColors: [Color] = [
        Color(red: 0.976, green: 0.451, blue: 0.086),  // kicks  — bright orange  #F97316
        Color(red: 0.984, green: 0.749, blue: 0.141),  // snares — electric gold  #FBBF24
        Color(red: 0.490, green: 0.827, blue: 0.988),  // hats   — sky blue       #7DD3FC
        Color(red: 0.290, green: 0.871, blue: 0.502),  // perc   — vivid green    #4ADE80
        Color(red: 0.231, green: 0.510, blue: 0.965),  // bass   — electric blue  #3B82F6
        Color(red: 0.655, green: 0.545, blue: 0.984),  // keys   — soft violet    #A78BFA
        Color(red: 0.984, green: 0.443, blue: 0.522),  // vox    — warm rose      #FB7185
        Color(red: 0.204, green: 0.827, blue: 0.600),  // fx     — mint           #34D399
    ]

    static func padColor(_ index: Int) -> Color {
        padColors[index % padColors.count]
    }

    // ═══════════════════════════════════════════════════════════════
    //  TYPOGRAPHY — 17pt HARD FLOOR. Nothing smaller. Ever.
    // ═══════════════════════════════════════════════════════════════

    static let hero         = Font.system(size: 52, design: .monospaced).weight(.bold)
    static let title        = Font.system(size: 36, design: .monospaced).weight(.bold)
    static let monoLarge    = Font.system(size: 22, design: .monospaced).weight(.bold)
    static let sectionLabel = Font.system(size: 20, design: .monospaced).weight(.semibold)
    static let mono         = Font.system(size: 17, design: .monospaced)

    // REMOVED: monoSmall (was 14pt), monoTiny (was 11pt)
    static let monoSmall    = mono    // ← was 14pt, now 17pt
    static let monoTiny     = mono    // ← was 11pt, now 17pt

    // Legacy aliases
    static let blue   = electric
    static let ice_   = sky
    static let orange = ember
    static let green  = sage
    static let red    = clay
    static let amber  = gold
    static let moss   = mint
    static let forest = sage
    static let wheat  = gold
}
