"""Pattern system — record, stack, mute, undo."""
from __future__ import annotations
import enum
from dataclasses import dataclass, field


class PatternState(enum.Enum):
    EMPTY = "empty"
    PLAYING = "playing"
    MUTED = "muted"
    RECORDING = "recording"


@dataclass
class RecordedEvent:
    frame: int
    note: int
    velocity: int


@dataclass
class Pattern:
    loop_length_frames: int
    events: list[RecordedEvent] = field(default_factory=list)
    state: PatternState = PatternState.EMPTY
    volume: float = 1.0
    name: str = ""

    def record_event(self, frame: int, note: int, velocity: int) -> None:
        self.events.append(RecordedEvent(frame=frame, note=note, velocity=velocity))
        if self.state == PatternState.EMPTY:
            self.state = PatternState.PLAYING

    def mute(self) -> None:
        if self.state != PatternState.EMPTY:
            self.state = PatternState.MUTED

    def unmute(self) -> None:
        if self.state == PatternState.MUTED:
            self.state = PatternState.PLAYING

    def toggle_mute(self) -> None:
        if self.state == PatternState.PLAYING:
            self.mute()
        elif self.state == PatternState.MUTED:
            self.unmute()

    def set_volume(self, volume: float) -> None:
        self.volume = max(0.0, min(1.0, volume))

    def get_events_in_range(self, start_frame: int, end_frame: int) -> list[RecordedEvent]:
        return [e for e in self.events if start_frame <= e.frame < end_frame]


class PatternStack:
    def __init__(self):
        self.patterns: list[Pattern] = []
        self.active_index: int = -1
        self._redo_stack: list[Pattern] = []

    def add_pattern(self, loop_length_frames: int) -> Pattern:
        p = Pattern(loop_length_frames=loop_length_frames, name=f"Pattern {len(self.patterns) + 1}")
        self.patterns.append(p)
        self.active_index = len(self.patterns) - 1
        self._redo_stack.clear()
        return p

    def undo_last_pass(self) -> Pattern | None:
        if not self.patterns:
            return None
        removed = self.patterns.pop()
        self._redo_stack.append(removed)
        self.active_index = len(self.patterns) - 1
        return removed

    def redo(self) -> Pattern | None:
        if not self._redo_stack:
            return None
        restored = self._redo_stack.pop()
        self.patterns.append(restored)
        self.active_index = len(self.patterns) - 1
        return restored

    def get_playing_patterns(self) -> list[Pattern]:
        return [p for p in self.patterns if p.state == PatternState.PLAYING]

    def get_all_events_in_range(self, start: int, end: int) -> list[tuple[Pattern, RecordedEvent]]:
        result = []
        for p in self.patterns:
            if p.state in (PatternState.PLAYING, PatternState.RECORDING):
                for e in p.get_events_in_range(start, end):
                    result.append((p, e))
        return result
