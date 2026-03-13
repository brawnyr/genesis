import SwiftUI

enum KeyAction: CaseIterable {
    case play, capture, padLeft, padRight
    case recPad, queuePad, mutePad, muteMaster, muteAll
    case browse, browseNav, closeBrowser
    case bpmMode, fewerBars, moreBars
    case volume, velocityMode, undoClear, chokeMode
    case toggleMode, clearPad, oracle, stop, help

    var key: String {
        switch self {
        case .play:         return "SPC"
        case .capture:      return "G"
        case .padLeft:      return "A"
        case .padRight:     return "D"
        case .recPad:       return "F"
        case .queuePad:     return "⇧F"
        case .mutePad:      return "Q"
        case .muteMaster:   return "⇧Q"
        case .muteAll:      return "⌘⇧Q"
        case .browse:       return "T"
        case .browseNav:    return "W/S"
        case .closeBrowser: return "⏎/T/ESC"
        case .bpmMode:      return "B"
        case .fewerBars:    return "["
        case .moreBars:     return "]"
        case .volume:       return "0-9"
        case .velocityMode: return "P"
        case .undoClear:    return "Z"
        case .chokeMode:     return "X"
        case .toggleMode:   return "N"
        case .clearPad:     return "C"
        case .oracle:       return "O"
        case .stop:         return "ESC"
        case .help:         return "?"
        }
    }

    var action: String {
        switch self {
        case .play:         return "play / stop"
        case .capture:      return "looper on / off"
        case .padLeft:      return "select pad left"
        case .padRight:     return "select pad right"
        case .recPad:       return "pad recording on / off"
        case .queuePad:     return "queue pad at loop start"
        case .mutePad:      return "mute / unmute active pad"
        case .muteMaster:   return "mute / unmute master"
        case .muteAll:      return "mute all pads + master"
        case .browse:       return "browse samples for pad"
        case .browseNav:    return "browse + auto-load sample"
        case .closeBrowser: return "close browser"
        case .bpmMode:      return "bpm mode (W/S presets or type)"
        case .fewerBars:    return "fewer bars"
        case .moreBars:     return "more bars"
        case .volume:       return "pad volume"
        case .velocityMode: return "pressure / full velocity"
        case .undoClear:    return "undo clear"
        case .chokeMode:     return "choke (cuts previous sound)"
        case .toggleMode:   return "queued mutes on / off"
        case .clearPad:     return "clear active pad"
        case .oracle:       return "oracle on / off"
        case .stop:         return "stop"
        case .help:         return "this help"
        }
    }
}

struct KeyboardShortcutHelpOverlay: View {
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
