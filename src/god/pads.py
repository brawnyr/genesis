"""Pad bank — maps MIDI notes to samples."""
from __future__ import annotations
from god.audio import Sample

PAD_NOTE_START = 36
PAD_COUNT = 16


class PadBank:
    def __init__(self, note_start: int = PAD_NOTE_START):
        self.note_start = note_start
        self.pads: list[Sample | None] = [None] * PAD_COUNT

    def assign(self, pad_index: int, sample: Sample) -> None:
        if 0 <= pad_index < PAD_COUNT:
            self.pads[pad_index] = sample

    def get_sample(self, pad_index: int) -> Sample | None:
        if 0 <= pad_index < PAD_COUNT:
            return self.pads[pad_index]
        return None

    def note_to_pad(self, note: int) -> int | None:
        idx = note - self.note_start
        if 0 <= idx < PAD_COUNT:
            return idx
        return None

    def get_sample_by_note(self, note: int) -> Sample | None:
        idx = self.note_to_pad(note)
        if idx is not None:
            return self.pads[idx]
        return None

    def clear(self, pad_index: int) -> None:
        if 0 <= pad_index < PAD_COUNT:
            self.pads[pad_index] = None

    def clear_all(self) -> None:
        self.pads = [None] * PAD_COUNT
