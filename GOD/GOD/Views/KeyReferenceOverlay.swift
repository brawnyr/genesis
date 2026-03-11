import SwiftUI

enum KeyAction: CaseIterable {
    case play, capture, padLeft, padRight, padJump
    case killAll, cool, hot, browse, browseNav, closeBrowser
    case metronome, bpmMode, fewerBars, moreBars
    case volume, velocityMode, undoClear, cutMode
    case toggleMode, clearPad, stop, help

    var key: String {
        switch self {
        case .play:         return "SPC"
        case .capture:      return "G"
        case .padLeft:      return "A"
        case .padRight:     return "D"
        case .padJump:      return "⇧1-8"
        case .killAll:      return "F"
        case .cool:         return "Q"
        case .hot:          return "E"
        case .browse:       return "T"
        case .browseNav:    return "W/S"
        case .closeBrowser: return "⏎/T/ESC"
        case .metronome:    return "M"
        case .bpmMode:      return "B"
        case .fewerBars:    return "["
        case .moreBars:     return "]"
        case .volume:       return "0-9"
        case .velocityMode: return "P"
        case .undoClear:    return "Z"
        case .cutMode:      return "X"  // retrig toggle
        case .toggleMode:   return "N"
        case .clearPad:     return "C"
        case .stop:         return "ESC"
        case .help:         return "?"
        }
    }

    var action: String {
        switch self {
        case .play:         return "play / stop"
        case .capture:      return "god capture"
        case .padLeft:      return "select pad left"
        case .padRight:     return "select pad right"
        case .padJump:      return "jump to pad 1-8"
        case .killAll:      return "kill all sound"
        case .cool:         return "cool (mute) active pad"
        case .hot:          return "hot (unmute) active pad"
        case .browse:       return "browse samples for pad"
        case .browseNav:    return "browse + auto-load sample"
        case .closeBrowser: return "close browser"
        case .metronome:    return "metronome"
        case .bpmMode:      return "bpm mode (W/S presets or type)"
        case .fewerBars:    return "fewer bars"
        case .moreBars:     return "more bars"
        case .volume:       return "pad volume"
        case .velocityMode: return "pressure / full velocity"
        case .undoClear:    return "undo clear"
        case .cutMode:      return "retrig (kills previous)"
        case .toggleMode:   return "toggle instant / next loop"
        case .clearPad:     return "clear active pad"
        case .stop:         return "stop"
        case .help:         return "this help"
        }
    }
}

struct KeyReferenceOverlay: View {
    @Binding var isVisible: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text("KEYS")
                .font(Theme.monoLarge)
                .foregroundColor(Theme.text)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(KeyAction.allCases, id: \.self) { action in
                    HStack(spacing: 20) {
                        Text(action.key)
                            .foregroundColor(Theme.blue)
                            .frame(width: 60, alignment: .trailing)
                        Text(action.action)
                            .foregroundColor(Theme.text)
                    }
                }
            }

            Text("press ? to close")
                .font(Theme.monoSmall)
                .foregroundColor(Theme.subtle)
                .padding(.top, 12)
        }
        .font(Theme.mono)
        .padding(40)
        .background(Theme.bg.opacity(0.95))
    }
}
