"""Core engine — wires all components together."""
from __future__ import annotations
import numpy as np
from god.audio import AudioEngine, Sample
from god.capture import GodCapture
from god.metronome import Metronome
from god.midi import MidiEvent, MidiInput
from god.pads import PadBank
from god.patterns import PatternStack
from god.transport import Transport


class GodEngine:
    def __init__(self, sample_rate: int = 44100, buffer_size: int = 512):
        self.sample_rate = sample_rate
        self.buffer_size = buffer_size
        self.transport = Transport(sample_rate=sample_rate)
        self.audio = AudioEngine(sample_rate=sample_rate)
        self.metronome = Metronome(sample_rate=sample_rate)
        self.midi = MidiInput()
        self.pad_bank = PadBank()
        self.pattern_stack = PatternStack()
        self.capture = GodCapture(sample_rate=sample_rate)
        self._recording = False
        self._current_pattern = None
        self.midi.on_event = self._on_midi_event

    def play(self) -> None:
        self.transport.play()
        self._recording = True
        self._current_pattern = self.pattern_stack.add_pattern(
            loop_length_frames=self.transport.loop_length_frames
        )

    def stop(self) -> None:
        self.transport.stop()
        self._recording = False
        self._current_pattern = None

    def stop_all(self) -> None:
        self.transport.stop_all()
        self._recording = False
        self._current_pattern = None
        self.audio._voices.clear()

    def set_bpm(self, bpm: int) -> None:
        self.transport.set_bpm(bpm)

    def set_bar_count(self, count: int) -> None:
        self.transport.set_bar_count(count)

    def god_toggle(self) -> None:
        self.capture.toggle()

    def undo_last_pass(self) -> None:
        self.pattern_stack.undo_last_pass()

    def redo(self) -> None:
        self.pattern_stack.redo()

    def _on_midi_event(self, event: MidiEvent) -> None:
        if event.type == "note_on":
            sample = self.pad_bank.get_sample_by_note(event.note)
            if sample:
                volume = event.velocity / 127.0
                self.audio.trigger_sample(sample, volume=volume)
                if self._recording and self._current_pattern:
                    self._current_pattern.record_event(
                        frame=self.transport.position,
                        note=event.note,
                        velocity=event.velocity,
                    )

    def process_block(self, frames: int) -> np.ndarray:
        buf = np.zeros(frames, dtype=np.float32)
        if not self.transport.playing:
            return buf

        old_position = self.transport.position
        boundaries = self.transport.advance(frames)

        if boundaries:
            self.capture.on_loop_boundary()
            if self._recording:
                self._current_pattern = self.pattern_stack.add_pattern(
                    loop_length_frames=self.transport.loop_length_frames
                )

        # Trigger samples from existing patterns
        for pattern, event in self.pattern_stack.get_all_events_in_range(old_position, old_position + frames):
            sample = self.pad_bank.get_sample_by_note(event.note)
            if sample:
                self.audio.trigger_sample(sample, volume=(event.velocity / 127.0) * pattern.volume)

        # Metronome
        if self.metronome.enabled:
            beat_frames = int(60.0 / self.transport.bpm * self.sample_rate)
            beat_in_loop = old_position % beat_frames
            if beat_in_loop + frames >= beat_frames or old_position == 0:
                bar_frames = beat_frames * 4
                is_downbeat = (old_position % bar_frames) < frames
                click = self.metronome.generate_click(downbeat=is_downbeat)
                click_len = min(len(click), frames)
                buf[:click_len] += click[:click_len]

        buf += self.audio.fill_buffer(frames)
        self.capture.write(buf)
        buf *= self.audio.master_volume
        return buf
