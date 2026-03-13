import CoreMIDI
import Foundation
import os

private let logger = Logger(subsystem: "genesis", category: "MIDI")

class MIDIManager {
    private var midiClient: MIDIClientRef = 0
    private var inputPort: MIDIPortRef = 0
    private let ringBuffer: MIDIRingBuffer
    private var connectedSources: Set<MIDIEndpointRef> = []

    var interpreter: EngineEventInterpreter?
    var connectedDevice: String = "None"

    init(ringBuffer: MIDIRingBuffer) {
        self.ringBuffer = ringBuffer
    }

    func start() {
        let clientStatus = MIDIClientCreateWithBlock("Genesis" as CFString, &midiClient) { [weak self] notification in
            self?.handleMIDINotification(notification)
        }
        guard clientStatus == noErr else {
            logger.error("MIDIClientCreate failed: \(clientStatus)")
            log("midi → client creation failed (error \(clientStatus))")
            return
        }

        let portStatus = MIDIInputPortCreateWithProtocol(
            midiClient,
            "Genesis Input" as CFString,
            ._1_0,
            &inputPort
        ) { [weak self] eventList, _ in
            self?.handleMIDIEvents(eventList)
        }
        guard portStatus == noErr else {
            logger.error("MIDIInputPortCreate failed: \(portStatus)")
            log("midi → port creation failed (error \(portStatus))")
            return
        }

        connectAllSources()
    }

    private func connectAllSources() {
        let sourceCount = MIDIGetNumberOfSources()

        if sourceCount == 0 {
            log("midi → no devices found")
            DispatchQueue.main.async {
                self.connectedDevice = "None"
            }
            return
        }

        // Prioritize MiniLab, but connect to all sources
        var deviceNames: [String] = []
        var primaryName: String?

        for i in 0..<sourceCount {
            let source = MIDIGetSource(i)
            guard !connectedSources.contains(source) else { continue }

            let deviceName = self.sourceName(source)
            let connectStatus = MIDIPortConnectSource(inputPort, source, nil)

            if connectStatus == noErr {
                connectedSources.insert(source)
                deviceNames.append(deviceName)
                log("midi → \(deviceName.lowercased()) connected")

                if deviceName.lowercased().contains("minilab") {
                    primaryName = deviceName
                }
            } else {
                logger.error("MIDIPortConnectSource failed for \(deviceName): \(connectStatus)")
                log("midi → failed to connect \(deviceName.lowercased()) (error \(connectStatus))")
            }
        }

        let displayName = primaryName ?? deviceNames.first ?? "Unknown"
        DispatchQueue.main.async {
            self.connectedDevice = displayName
        }
    }

    private func disconnectRemovedSources() {
        // Check which connected sources are still valid
        let currentSources = Set((0..<MIDIGetNumberOfSources()).map { MIDIGetSource($0) })
        let removed = connectedSources.subtracting(currentSources)

        for source in removed {
            let name = sourceName(source)
            MIDIPortDisconnectSource(inputPort, source)
            connectedSources.remove(source)
            log("midi → \(name.lowercased()) disconnected")
        }

        if connectedSources.isEmpty {
            DispatchQueue.main.async {
                self.connectedDevice = "None"
            }
        }
    }

    private func sourceName(_ source: MIDIEndpointRef) -> String {
        var name: Unmanaged<CFString>?
        let status = MIDIObjectGetStringProperty(source, kMIDIPropertyDisplayName, &name)
        if status == noErr, let cfName = name?.takeRetainedValue() {
            return cfName as String
        }
        return "Unknown"
    }

    private func handleMIDIEvents(_ eventList: UnsafePointer<MIDIEventList>) {
        let list = eventList.pointee
        var packet = list.packet

        for _ in 0..<list.numPackets {
            let word = packet.words.0
            let messageType = (word >> 28) & 0xF

            // Only process MIDI 1.0 Channel Voice messages (type 0x2)
            guard messageType == 0x2 else {
                var current = packet
                packet = MIDIEventPacketNext(&current).pointee
                continue
            }

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
        switch notification.pointee.messageID {
        case .msgObjectAdded, .msgSetupChanged:
            connectAllSources()
        case .msgObjectRemoved:
            disconnectRemovedSources()
        default:
            break
        }
    }

    private func log(_ message: String) {
        let interp = interpreter
        DispatchQueue.main.async {
            interp?.appendLine(message, kind: .system)
        }
    }

    func stop() {
        for source in connectedSources {
            MIDIPortDisconnectSource(inputPort, source)
        }
        connectedSources.removeAll()
        MIDIPortDispose(inputPort)
        MIDIClientDispose(midiClient)
    }
}
