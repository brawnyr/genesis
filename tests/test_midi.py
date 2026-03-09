from unittest.mock import MagicMock
from god.midi import MidiInput, MidiEvent


def test_midi_event_from_note_on():
    event = MidiEvent.from_raw([0x90, 36, 100])
    assert event.type == "note_on"
    assert event.note == 36
    assert event.velocity == 100


def test_midi_event_from_note_off():
    event = MidiEvent.from_raw([0x80, 36, 0])
    assert event.type == "note_off"
    assert event.note == 36


def test_midi_event_from_cc():
    event = MidiEvent.from_raw([0xB0, 1, 64])
    assert event.type == "cc"
    assert event.cc == 1
    assert event.value == 64


def test_midi_event_velocity_zero_is_note_off():
    event = MidiEvent.from_raw([0x90, 36, 0])
    assert event.type == "note_off"


def test_midi_input_creates():
    midi = MidiInput()
    assert midi.connected is False


def test_midi_input_callback():
    midi = MidiInput()
    callback = MagicMock()
    midi.on_event = callback
    midi._handle_message([0x90, 36, 100], None)
    callback.assert_called_once()
    event = callback.call_args[0][0]
    assert event.note == 36
