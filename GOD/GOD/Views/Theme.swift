// GOD/GOD/Views/Theme.swift
import SwiftUI

enum Theme {
    static let bg = Color(red: 0.102, green: 0.098, blue: 0.090)       // #1a1917
    static let text = Color(red: 0.831, green: 0.812, blue: 0.776)     // #d4cfc6
    static let dim = Color(red: 0.478, green: 0.459, blue: 0.420)      // #7a756b
    static let muted = Color(red: 0.290, green: 0.275, blue: 0.251)    // #4a4640
    static let accent = Color(red: 0.855, green: 0.482, blue: 0.290)   // #da7b4a
    static let green = Color(red: 0.373, green: 0.667, blue: 0.431)    // #5faa6e
    static let red = Color(red: 0.831, green: 0.337, blue: 0.306)      // #d4564e
    static let amber = Color(red: 0.831, green: 0.635, blue: 0.306)    // #d4a24e

    static let mono = Font.custom("JetBrains Mono", size: 13)
    static let monoSmall = Font.custom("JetBrains Mono", size: 11)
    static let monoTiny = Font.custom("JetBrains Mono", size: 10)
    static let monoLarge = Font.custom("JetBrains Mono", size: 18)
    static let monoTitle = Font.custom("JetBrains Mono", size: 24)
}
