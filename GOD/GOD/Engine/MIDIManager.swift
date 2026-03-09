import CoreMIDI
import Foundation

class MIDIManager: ObservableObject {
    private var midiClient: MIDIClientRef = 0
    private var inputPort: MIDIPortRef = 0
    private weak var engine: GodEngine?

    @Published var connectedDevice: String = "None"

    init(engine: GodEngine) {
        self.engine = engine
    }

    func start() {
        MIDIClientCreateWithBlock("GOD" as CFString, &midiClient) { [weak self] notification in
            self?.handleMIDINotification(notification)
        }

        MIDIInputPortCreateWithProtocol(
            midiClient,
            "GOD Input" as CFString,
            ._1_0,
            &inputPort
        ) { [weak self] eventList, _ in
            self?.handleMIDIEvents(eventList)
        }

        connectToMiniLab()
    }

    private func connectToMiniLab() {
        let sourceCount = MIDIGetNumberOfSources()
        for i in 0..<sourceCount {
            let source = MIDIGetSource(i)
            var name: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(source, kMIDIPropertyDisplayName, &name)

            if let deviceName = name?.takeRetainedValue() as String? {
                let lower = deviceName.lowercased()
                if lower.contains("minilab") {
                    MIDIPortConnectSource(inputPort, source, nil)
                    DispatchQueue.main.async {
                        self.connectedDevice = deviceName
                    }
                    return
                }
            }
        }

        // Fallback: connect first available source
        if sourceCount > 0 {
            let source = MIDIGetSource(0)
            MIDIPortConnectSource(inputPort, source, nil)
            var name: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(source, kMIDIPropertyDisplayName, &name)
            let deviceName = (name?.takeRetainedValue() as String?) ?? "Unknown"
            DispatchQueue.main.async {
                self.connectedDevice = deviceName
            }
        }
    }

    private func handleMIDIEvents(_ eventList: UnsafePointer<MIDIEventList>) {
        let list = eventList.pointee
        var packet = list.packet

        for _ in 0..<list.numPackets {
            let word = packet.words.0

            let status = (word >> 16) & 0xF0
            let note = Int((word >> 8) & 0x7F)
            let velocity = Int(word & 0x7F)

            if status == 0x90 && velocity > 0 { // note on
                DispatchQueue.main.async { [weak self] in
                    self?.engine?.onPadHit(note: note, velocity: velocity)
                }
            }

            var current = packet
            packet = MIDIEventPacketNext(&current).pointee
        }
    }

    private func handleMIDINotification(_ notification: UnsafePointer<MIDINotification>) {
        if notification.pointee.messageID == .msgObjectAdded {
            connectToMiniLab()
        }
    }

    func stop() {
        MIDIPortDispose(inputPort)
        MIDIClientDispose(midiClient)
    }
}
