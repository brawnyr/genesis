"""Transport engine — tempo, bars, loop timing."""
from __future__ import annotations

VALID_BAR_COUNTS = {1, 2, 4}


class Transport:
    def __init__(self, sample_rate: int = 44100):
        self.sample_rate = sample_rate
        self.bpm: int = 120
        self.bar_count: int = 1
        self.playing: bool = False
        self.position: int = 0
        self.pass_number: int = 0

    def set_bpm(self, bpm: int | float) -> None:
        if isinstance(bpm, float) and bpm != int(bpm):
            return
        self.bpm = int(bpm)

    def set_bar_count(self, count: int) -> None:
        if count in VALID_BAR_COUNTS:
            self.bar_count = count

    @property
    def loop_length_frames(self) -> int:
        beats_per_bar = 4
        total_beats = beats_per_bar * self.bar_count
        seconds = total_beats * (60.0 / self.bpm)
        return int(seconds * self.sample_rate)

    @property
    def current_bar(self) -> int:
        if self.bar_count == 1:
            return 1
        frames_per_bar = self.loop_length_frames // self.bar_count
        return (self.position // frames_per_bar) + 1

    @property
    def loop_progress(self) -> float:
        if self.loop_length_frames == 0:
            return 0.0
        return self.position / self.loop_length_frames

    def advance(self, frames: int) -> list[int]:
        if not self.playing:
            return []
        boundaries = []
        loop_len = self.loop_length_frames
        self.position += frames
        while self.position >= loop_len:
            self.position -= loop_len
            self.pass_number += 1
            boundaries.append(self.pass_number)
        return boundaries

    def play(self) -> None:
        self.playing = True

    def stop(self) -> None:
        self.playing = False
        self.position = 0

    def stop_all(self) -> None:
        self.playing = False
        self.position = 0
        self.pass_number = 0
