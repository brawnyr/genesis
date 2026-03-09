import Foundation

struct TipDeck {
    private var queue: [Int] = []

    static let allTips: [String] = [
        // Aseprite
        "in aseprite, hold shift while drawing to make a straight line",
        "aseprite's onion skin lets you see previous frames while animating",
        "ctrl+shift+h in aseprite toggles the grid overlay",
        "in aseprite, press b for brush tool, e for eraser, g for paint bucket",
        "aseprite can export sprite sheets — file > export sprite sheet",

        // macOS
        "cmd+shift+4 then space lets you screenshot a specific window",
        "cmd+option+esc opens force quit on mac",
        "option+click the green button to maximize without full screen",
        "cmd+shift+. shows hidden files in Finder",
        "three-finger drag on trackpad moves windows without clicking",

        // Terminal
        "ctrl+r in terminal lets you reverse-search through your command history",
        "!! repeats the last command — sudo !! is your friend",
        "cmd+k clears your terminal buffer completely, not just the screen",
        "you can pipe anything to pbcopy to copy to clipboard on mac",
        "ctrl+a jumps to the start of the line, ctrl+e to the end",

        // Zed
        "cmd+p in zed opens the file finder",
        "cmd+shift+p opens the command palette in zed",
        "option+up/down moves the current line in zed",
        "cmd+d selects the next occurrence in zed for multi-cursor editing",
        "cmd+shift+l selects all occurrences in zed",

        // Claude Code
        "/init creates a CLAUDE.md file for your project",
        "claude code remembers context from your CLAUDE.md across sessions",
        "you can pipe files into claude code with cat file.py | claude",
        "use /compact to compress conversation context when it gets long",
        "claude code can read images — just pass the file path",

        // CS trivia
        "the term 'bug' came from an actual moth found at Harvard in 1947",
        "a hash map is just an array wearing a trench coat pretending to be smart",
        "the internet runs on BGP and it's basically held together by trust and hope",
        "in floating point, 0.1 + 0.2 != 0.3 because binary can't represent those decimals exactly",
        "git was written by Linus Torvalds in about 10 days because he was annoyed",
        "TCP's three-way handshake is basically two computers saying 'hey' 'hey' 'ok cool'",
        "the first computer mouse was made of wood",
        "there are more possible chess games than atoms in the observable universe",
        "the @ symbol in email was chosen because it was the least-used key on the keyboard",
        "a kilobyte is 1024 bytes because computers think in powers of 2, not 10",

        // Music production
        "sidechain compression is basically the kick telling everything else to duck",
        "most hip-hop drums sit between 80-100 BPM in half-time feel",
        "layering a clap with a snare adds body without losing the crack",
        "high-passing your kicks around 30hz removes sub-rumble you can't hear anyway",
        "a loop that sounds boring solo might be exactly what the mix needs",
        "the MPC was designed so you could play drums like a keyboard player",
        "J Dilla's secret was making quantized beats feel drunk",
        "vinyl crackle is just noise but it makes everything feel warmer",
        "the 808 kick is actually a sine wave with a pitch envelope",
        "reverb on a snare: a little adds space, a lot adds vibe",
        "swing is just delaying every other note by a few milliseconds",
        "four-on-the-floor kick + offbeat hi-hat = instant house music",
        "the TR-808 was a commercial failure before hip-hop saved it",
        "sampling a sound and pitching it down makes everything sound heavier",
        "sometimes the best production move is deleting something",
    ]

    mutating func next() -> String {
        if queue.isEmpty {
            queue = Array(0..<Self.allTips.count)
            queue.shuffle()
        }
        return Self.allTips[queue.removeLast()]
    }
}

struct TypewriterState {
    let text: String
    let charInterval: Double

    func visibleText(elapsed: Double) -> String {
        let charCount = min(Int(elapsed / charInterval), text.count)
        return String(text.prefix(charCount))
    }

    var totalDuration: Double {
        Double(text.count) * charInterval
    }
}
