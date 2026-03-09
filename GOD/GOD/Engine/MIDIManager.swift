import CoreMIDI
import Foundation

class MIDIManager: ObservableObject {
    private var midiClient: MIDIClientRef = 0
    private var inputPort: MIDIPortRef = 0
    private let ringBuffer: MIDIRingBuffer

    @Published var connectedDevice: String = "None"

    init(ringBuffer: MIDIRingBuffer) {
        self.ringBuffer = ringBuffer
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
            let data1 = Int((word >> 8) & 0x7F)
            let data2 = Int(word & 0x7F)

            switch status {
            case 0x90 where data2 > 0:
                ringBuffer.write(.noteOn(note: data1, velocity: data2))
            case 0x80, 0x90:
                ringBuffer.write(.noteOff(note: data1))
            case 0xB0:
                ringBuffer.write(.cc(number: data1, value: data2))
            default:
                break
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
