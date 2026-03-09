"""MIDI input handling for MiniLab 3."""
from __future__ import annotations
from dataclasses import dataclass
from typing import Callable


@dataclass
class MidiEvent:
    type: str
    note: int = 0
    velocity: int = 0
    cc: int = 0
    value: int = 0
    channel: int = 0

    @classmethod
    def from_raw(cls, data: list[int]) -> MidiEvent:
        status = data[0] & 0xF0
        channel = data[0] & 0x0F
        if status == 0x90 and data[2] > 0:
            return cls(type="note_on", note=data[1], velocity=data[2], channel=channel)
        elif status == 0x90 and data[2] == 0:
            return cls(type="note_off", note=data[1], channel=channel)
        elif status == 0x80:
            return cls(type="note_off", note=data[1], channel=channel)
        elif status == 0xB0:
            return cls(type="cc", cc=data[1], value=data[2], channel=channel)
        return cls(type="unknown", channel=channel)


class MidiInput:
    def __init__(self):
        self.connected: bool = False
        self.port_name: str = ""
        self.on_event: Callable[[MidiEvent], None] | None = None
        self._midi_in = None

    def list_ports(self) -> list[str]:
        import mido
        return mido.get_input_names()

    def connect(self, port_name: str | None = None) -> bool:
        import mido
        ports = mido.get_input_names()
        if not ports:
            return False
        if port_name is None:
            for p in ports:
                if "minilab" in p.lower():
                    port_name = p
                    break
            if port_name is None:
                port_name = ports[0]
        try:
            self._midi_in = mido.open_input(port_name, callback=self._mido_callback)
            self.connected = True
            self.port_name = port_name
            return True
        except Exception:
            return False

    def _mido_callback(self, message) -> None:
        self._handle_message(message.bytes(), None)

    def _handle_message(self, data: list[int], _timestamp) -> None:
        if len(data) >= 3 and self.on_event:
            event = MidiEvent.from_raw(data)
            self.on_event(event)

    def disconnect(self) -> None:
        if self._midi_in:
            self._midi_in.close()
        self.connected = False
        self.port_name = ""
