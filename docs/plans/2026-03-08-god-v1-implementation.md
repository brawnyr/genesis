# GOD v1 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a terminal-based loop-stacking instrument driven by Arturia MiniLab 3 pads with a clean Textual TUI.

**Architecture:** Layered design — an audio engine handles sample playback and mixing, a transport engine handles timing/looping, a pattern system records and stacks MIDI events per-loop, and a Textual TUI renders state. MIDI input runs on a background thread. Audio mixing runs on a callback thread via sounddevice. The TUI is the main thread.

**Tech Stack:** Python 3.14, textual (TUI), mido + python-rtmidi (MIDI), sounddevice + soundfile (audio), numpy (mixing)

**Splice samples location:** `~/Splice/sounds/packs/` (`.wav` files)

---

### Task 1: Project scaffolding and dependencies

**Files:**
- Create: `pyproject.toml`
- Create: `src/god/__init__.py`
- Create: `src/god/main.py`
- Create: `tests/__init__.py`
- Create: `tests/test_placeholder.py`

**Step 1: Create pyproject.toml**

```toml
[project]
name = "god"
version = "0.1.0"
description = "Genesis On Disk — terminal loop-stacking instrument"
requires-python = ">=3.12"
dependencies = [
    "textual>=0.50.0",
    "mido>=1.3.0",
    "python-rtmidi>=1.5.0",
    "sounddevice>=0.4.6",
    "soundfile>=0.12.0",
    "numpy>=1.26.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.0.0",
    "pytest-asyncio>=0.23.0",
]

[project.scripts]
god = "god.main:run"

[build-system]
requires = ["setuptools>=68.0"]
build-backend = "setuptools.backends._legacy:_Backend"

[tool.setuptools.packages.find]
where = ["src"]
```

**Step 2: Create src/god/__init__.py**

```python
"""GOD — Genesis On Disk."""
```

**Step 3: Create src/god/main.py**

```python
"""Entry point for GOD."""


def run():
    print("GOD — Genesis On Disk")


if __name__ == "__main__":
    run()
```

**Step 4: Create tests/__init__.py and tests/test_placeholder.py**

```python
# tests/__init__.py — empty

# tests/test_placeholder.py
def test_import():
    import god
    assert god is not None
```

**Step 5: Create venv and install**

```bash
cd ~/god
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
```

**Step 6: Run tests**

```bash
pytest tests/ -v
```

Expected: PASS

**Step 7: Commit**

```bash
git add pyproject.toml src/ tests/
git commit -m "feat: project scaffolding with dependencies"
```

---

### Task 2: Audio engine — load and play samples

**Files:**
- Create: `src/god/audio.py`
- Create: `tests/test_audio.py`

The audio engine loads `.wav` files into memory as numpy arrays and plays them through sounddevice. It manages a mixer that sums all currently-playing sounds into one output stream.

**Step 1: Write failing tests**

```python
# tests/test_audio.py
import numpy as np
from god.audio import Sample, AudioEngine


def test_sample_load_wav(tmp_path):
    """Sample can load a wav file into a numpy array."""
    import soundfile as sf
    # Create a short test wav
    sr = 44100
    duration = 0.1
    samples = np.sin(2 * np.pi * 440 * np.linspace(0, duration, int(sr * duration)))
    path = tmp_path / "test.wav"
    sf.write(str(path), samples, sr)

    sample = Sample.from_file(str(path))
    assert sample.sample_rate == sr
    assert len(sample.data) > 0


def test_sample_data_is_float32(tmp_path):
    """Sample data should be float32 for sounddevice compatibility."""
    import soundfile as sf
    sr = 44100
    samples = np.sin(2 * np.pi * 440 * np.linspace(0, 0.1, int(sr * 0.1)))
    path = tmp_path / "test.wav"
    sf.write(str(path), samples, sr)

    sample = Sample.from_file(str(path))
    assert sample.data.dtype == np.float32


def test_audio_engine_creates():
    """AudioEngine can be instantiated."""
    engine = AudioEngine(sample_rate=44100)
    assert engine.sample_rate == 44100
    assert engine.master_volume == 1.0


def test_audio_engine_set_master_volume():
    """Master volume clamps between 0.0 and 1.0."""
    engine = AudioEngine(sample_rate=44100)
    engine.set_master_volume(0.5)
    assert engine.master_volume == 0.5
    engine.set_master_volume(1.5)
    assert engine.master_volume == 1.0
    engine.set_master_volume(-0.5)
    assert engine.master_volume == 0.0
```

**Step 2: Run tests — verify they fail**

```bash
pytest tests/test_audio.py -v
```

Expected: FAIL — `god.audio` doesn't exist

**Step 3: Implement audio engine**

```python
# src/god/audio.py
"""Audio engine for GOD — sample loading, playback, and mixing."""

from __future__ import annotations

import numpy as np
import soundfile as sf


class Sample:
    """A loaded audio sample stored as a numpy array."""

    __slots__ = ("data", "sample_rate", "name")

    def __init__(self, data: np.ndarray, sample_rate: int, name: str = ""):
        self.data = data.astype(np.float32)
        self.sample_rate = sample_rate
        self.name = name

    @classmethod
    def from_file(cls, path: str) -> Sample:
        data, sr = sf.read(path, dtype="float32")
        # Convert stereo to mono by averaging channels
        if data.ndim > 1:
            data = data.mean(axis=1)
        return cls(data=data, sample_rate=sr, name=path.split("/")[-1])


class AudioEngine:
    """Manages audio output, mixing, and playback."""

    def __init__(self, sample_rate: int = 44100):
        self.sample_rate = sample_rate
        self.master_volume: float = 1.0
        self._voices: list[Voice] = []

    def set_master_volume(self, volume: float) -> None:
        self.master_volume = max(0.0, min(1.0, volume))

    def trigger_sample(self, sample: Sample, volume: float = 1.0) -> None:
        """Start playing a sample immediately."""
        self._voices.append(Voice(sample=sample, volume=volume))

    def fill_buffer(self, frames: int) -> np.ndarray:
        """Mix all active voices into a buffer of `frames` length."""
        buf = np.zeros(frames, dtype=np.float32)
        finished = []
        for i, voice in enumerate(self._voices):
            written = voice.read_into(buf)
            if not written:
                finished.append(i)
        # Remove finished voices in reverse order
        for i in reversed(finished):
            self._voices.pop(i)
        buf *= self.master_volume
        return buf


class Voice:
    """A single playing instance of a sample."""

    __slots__ = ("sample", "volume", "_position")

    def __init__(self, sample: Sample, volume: float = 1.0):
        self.sample = sample
        self.volume = volume
        self._position = 0

    def read_into(self, buf: np.ndarray) -> bool:
        """Add this voice's audio into buf. Returns False if finished."""
        remaining = len(self.sample.data) - self._position
        if remaining <= 0:
            return False
        n = min(len(buf), remaining)
        buf[:n] += self.sample.data[self._position : self._position + n] * self.volume
        self._position += n
        return self._position < len(self.sample.data)
```

**Step 4: Run tests — verify they pass**

```bash
pytest tests/test_audio.py -v
```

Expected: PASS

**Step 5: Commit**

```bash
git add src/god/audio.py tests/test_audio.py
git commit -m "feat: audio engine with sample loading and mixing"
```

---

### Task 3: Transport engine — tempo, bars, loop timing

**Files:**
- Create: `src/god/transport.py`
- Create: `tests/test_transport.py`

The transport tracks tempo, bar length, current position in the loop, and pass count. It calculates frame positions from musical time.

**Step 1: Write failing tests**

```python
# tests/test_transport.py
from god.transport import Transport


def test_transport_defaults():
    transport = Transport(sample_rate=44100)
    assert transport.bpm == 120
    assert transport.bar_count == 1
    assert transport.playing is False
    assert transport.pass_number == 0


def test_set_bpm_whole_numbers_only():
    transport = Transport(sample_rate=44100)
    transport.set_bpm(90)
    assert transport.bpm == 90
    transport.set_bpm(90.5)
    assert transport.bpm == 90  # should reject decimals


def test_loop_length_in_frames():
    """1 bar at 120 BPM in 4/4 = 2 seconds = 88200 frames at 44100."""
    transport = Transport(sample_rate=44100)
    transport.set_bpm(120)
    transport.set_bar_count(1)
    assert transport.loop_length_frames == 88200


def test_loop_length_4_bars():
    """4 bars at 120 BPM = 8 seconds = 352800 frames."""
    transport = Transport(sample_rate=44100)
    transport.set_bpm(120)
    transport.set_bar_count(4)
    assert transport.loop_length_frames == 352800


def test_bar_count_only_1_2_4():
    transport = Transport(sample_rate=44100)
    transport.set_bar_count(3)
    assert transport.bar_count == 1  # reject invalid, keep current


def test_advance_wraps_and_counts_passes():
    transport = Transport(sample_rate=44100)
    transport.set_bpm(120)
    transport.set_bar_count(1)
    transport.playing = True
    # Advance to just before loop end
    transport.advance(88199)
    assert transport.pass_number == 0
    # One more frame wraps
    transport.advance(1)
    assert transport.pass_number == 1
    assert transport.position == 0


def test_current_bar():
    transport = Transport(sample_rate=44100)
    transport.set_bpm(120)
    transport.set_bar_count(4)
    transport.playing = True
    # Advance halfway through bar 2 (1 bar = 88200 frames)
    transport.advance(88200 + 44100)
    assert transport.current_bar == 2  # 1-indexed


def test_loop_progress():
    transport = Transport(sample_rate=44100)
    transport.set_bpm(120)
    transport.set_bar_count(1)
    transport.playing = True
    transport.advance(44100)  # half of 88200
    progress = transport.loop_progress
    assert 0.49 < progress < 0.51
```

**Step 2: Run tests — verify they fail**

```bash
pytest tests/test_transport.py -v
```

**Step 3: Implement transport**

```python
# src/god/transport.py
"""Transport engine — tempo, bars, loop timing."""

from __future__ import annotations

VALID_BAR_COUNTS = {1, 2, 4}


class Transport:
    """Tracks musical time and loop position."""

    def __init__(self, sample_rate: int = 44100):
        self.sample_rate = sample_rate
        self.bpm: int = 120
        self.bar_count: int = 1
        self.playing: bool = False
        self.position: int = 0  # current frame position in loop
        self.pass_number: int = 0

    def set_bpm(self, bpm: int | float) -> None:
        if isinstance(bpm, float) and bpm != int(bpm):
            return  # reject decimals
        self.bpm = int(bpm)

    def set_bar_count(self, count: int) -> None:
        if count in VALID_BAR_COUNTS:
            self.bar_count = count

    @property
    def loop_length_frames(self) -> int:
        """Total frames in one full loop (all bars)."""
        beats_per_bar = 4  # 4/4 time
        total_beats = beats_per_bar * self.bar_count
        seconds = total_beats * (60.0 / self.bpm)
        return int(seconds * self.sample_rate)

    @property
    def current_bar(self) -> int:
        """Current bar number (1-indexed)."""
        if self.bar_count == 1:
            return 1
        frames_per_bar = self.loop_length_frames // self.bar_count
        return (self.position // frames_per_bar) + 1

    @property
    def loop_progress(self) -> float:
        """Progress through current loop, 0.0 to 1.0."""
        if self.loop_length_frames == 0:
            return 0.0
        return self.position / self.loop_length_frames

    def advance(self, frames: int) -> list[int]:
        """Advance position by `frames`. Returns list of pass boundaries crossed (frame offsets)."""
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
```

**Step 4: Run tests — verify they pass**

```bash
pytest tests/test_transport.py -v
```

**Step 5: Commit**

```bash
git add src/god/transport.py tests/test_transport.py
git commit -m "feat: transport engine with tempo, bars, and loop timing"
```

---

### Task 4: Metronome — pleasant click sounds

**Files:**
- Create: `src/god/metronome.py`
- Create: `tests/test_metronome.py`

The metronome generates soft click sounds synthetically (no sample files needed). Multiple sound options. Integrates with transport to know when beats occur.

**Step 1: Write failing tests**

```python
# tests/test_metronome.py
import numpy as np
from god.metronome import Metronome, MetronomeSound


def test_metronome_creates():
    met = Metronome(sample_rate=44100)
    assert met.enabled is True
    assert met.sound == MetronomeSound.SOFT_CLICK


def test_metronome_sounds_available():
    """At least 3 pleasant sound options."""
    assert len(MetronomeSound) >= 3


def test_metronome_generates_click():
    met = Metronome(sample_rate=44100)
    click = met.generate_click(downbeat=False)
    assert isinstance(click, np.ndarray)
    assert click.dtype == np.float32
    assert len(click) > 0


def test_downbeat_louder_than_upbeat():
    met = Metronome(sample_rate=44100)
    down = met.generate_click(downbeat=True)
    up = met.generate_click(downbeat=False)
    assert np.max(np.abs(down)) > np.max(np.abs(up))


def test_metronome_toggle():
    met = Metronome(sample_rate=44100)
    met.toggle()
    assert met.enabled is False
    met.toggle()
    assert met.enabled is True


def test_metronome_cycle_sound():
    met = Metronome(sample_rate=44100)
    first = met.sound
    met.cycle_sound()
    assert met.sound != first
```

**Step 2: Run tests — verify fail**

**Step 3: Implement metronome**

```python
# src/god/metronome.py
"""Metronome — pleasant click generation."""

from __future__ import annotations

import enum

import numpy as np


class MetronomeSound(enum.Enum):
    SOFT_CLICK = "soft_click"
    WOODBLOCK = "woodblock"
    TICK = "tick"


class Metronome:
    """Generates metronome clicks synced to transport beats."""

    def __init__(self, sample_rate: int = 44100):
        self.sample_rate = sample_rate
        self.enabled: bool = True
        self.sound: MetronomeSound = MetronomeSound.SOFT_CLICK
        self.volume: float = 0.5

    def toggle(self) -> None:
        self.enabled = not self.enabled

    def cycle_sound(self) -> None:
        sounds = list(MetronomeSound)
        idx = sounds.index(self.sound)
        self.sound = sounds[(idx + 1) % len(sounds)]

    def generate_click(self, downbeat: bool = False) -> np.ndarray:
        """Generate a single click sound."""
        if self.sound == MetronomeSound.SOFT_CLICK:
            return self._soft_click(downbeat)
        elif self.sound == MetronomeSound.WOODBLOCK:
            return self._woodblock(downbeat)
        else:
            return self._tick(downbeat)

    def _soft_click(self, downbeat: bool) -> np.ndarray:
        duration = 0.02
        n = int(self.sample_rate * duration)
        t = np.linspace(0, duration, n, dtype=np.float32)
        freq = 1200 if downbeat else 900
        amp = 0.4 if downbeat else 0.25
        envelope = np.exp(-t * 150).astype(np.float32)
        click = (np.sin(2 * np.pi * freq * t) * envelope * amp * self.volume).astype(np.float32)
        return click

    def _woodblock(self, downbeat: bool) -> np.ndarray:
        duration = 0.03
        n = int(self.sample_rate * duration)
        t = np.linspace(0, duration, n, dtype=np.float32)
        freq = 800 if downbeat else 600
        amp = 0.35 if downbeat else 0.2
        envelope = np.exp(-t * 100).astype(np.float32)
        # Mix two frequencies for woody tone
        tone = (np.sin(2 * np.pi * freq * t) * 0.7 + np.sin(2 * np.pi * freq * 2.3 * t) * 0.3)
        click = (tone * envelope * amp * self.volume).astype(np.float32)
        return click

    def _tick(self, downbeat: bool) -> np.ndarray:
        duration = 0.01
        n = int(self.sample_rate * duration)
        t = np.linspace(0, duration, n, dtype=np.float32)
        freq = 2000 if downbeat else 1500
        amp = 0.3 if downbeat else 0.18
        envelope = np.exp(-t * 300).astype(np.float32)
        click = (np.sin(2 * np.pi * freq * t) * envelope * amp * self.volume).astype(np.float32)
        return click
```

**Step 4: Run tests — verify pass**

**Step 5: Commit**

```bash
git add src/god/metronome.py tests/test_metronome.py
git commit -m "feat: metronome with three pleasant sound options"
```

---

### Task 5: MIDI input — connect to MiniLab 3

**Files:**
- Create: `src/god/midi.py`
- Create: `tests/test_midi.py`

Connects to the MiniLab 3 via rtmidi, reads pad note-on/off events on a background thread, and dispatches callbacks.

**Step 1: Write failing tests**

```python
# tests/test_midi.py
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
    """Note-on with velocity 0 should be treated as note_off."""
    event = MidiEvent.from_raw([0x90, 36, 0])
    assert event.type == "note_off"


def test_midi_input_creates():
    midi = MidiInput()
    assert midi.connected is False


def test_midi_input_callback():
    midi = MidiInput()
    callback = MagicMock()
    midi.on_event = callback
    # Simulate receiving a message
    midi._handle_message([0x90, 36, 100], None)
    callback.assert_called_once()
    event = callback.call_args[0][0]
    assert event.note == 36
```

**Step 2: Run tests — verify fail**

**Step 3: Implement MIDI input**

```python
# src/god/midi.py
"""MIDI input handling for MiniLab 3."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Callable


@dataclass
class MidiEvent:
    """Parsed MIDI event."""
    type: str  # "note_on", "note_off", "cc"
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
    """Connects to a MIDI device and dispatches events."""

    def __init__(self):
        self.connected: bool = False
        self.port_name: str = ""
        self.on_event: Callable[[MidiEvent], None] | None = None
        self._midi_in = None

    def list_ports(self) -> list[str]:
        import mido
        return mido.get_input_names()

    def connect(self, port_name: str | None = None) -> bool:
        """Connect to a MIDI port. Auto-detects MiniLab 3 if no name given."""
        import mido
        ports = mido.get_input_names()
        if not ports:
            return False
        if port_name is None:
            # Auto-detect MiniLab 3
            for p in ports:
                if "minilab" in p.lower():
                    port_name = p
                    break
            if port_name is None:
                port_name = ports[0]  # fallback to first port
        try:
            self._midi_in = mido.open_input(port_name, callback=self._mido_callback)
            self.connected = True
            self.port_name = port_name
            return True
        except Exception:
            return False

    def _mido_callback(self, message) -> None:
        """Called by mido when a MIDI message arrives."""
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
```

**Step 4: Run tests — verify pass**

**Step 5: Commit**

```bash
git add src/god/midi.py tests/test_midi.py
git commit -m "feat: MIDI input with MiniLab 3 auto-detection"
```

---

### Task 6: Pattern system — record, stack, mute, volume

**Files:**
- Create: `src/god/patterns.py`
- Create: `tests/test_patterns.py`

A pattern stores timestamped MIDI events recorded within one loop pass. Multiple patterns stack. Each has mute/volume/state.

**Step 1: Write failing tests**

```python
# tests/test_patterns.py
from god.patterns import Pattern, PatternState, PatternStack


def test_pattern_creates_empty():
    p = Pattern(loop_length_frames=88200)
    assert len(p.events) == 0
    assert p.state == PatternState.EMPTY
    assert p.volume == 1.0


def test_pattern_record_event():
    p = Pattern(loop_length_frames=88200)
    p.record_event(frame=1000, note=36, velocity=100)
    assert len(p.events) == 1
    assert p.events[0].frame == 1000
    assert p.events[0].note == 36


def test_pattern_state_transitions():
    p = Pattern(loop_length_frames=88200)
    assert p.state == PatternState.EMPTY
    p.record_event(frame=0, note=36, velocity=100)
    assert p.state == PatternState.PLAYING
    p.mute()
    assert p.state == PatternState.MUTED
    p.unmute()
    assert p.state == PatternState.PLAYING


def test_pattern_volume_clamp():
    p = Pattern(loop_length_frames=88200)
    p.set_volume(1.5)
    assert p.volume == 1.0
    p.set_volume(-0.5)
    assert p.volume == 0.0


def test_pattern_stack_add():
    stack = PatternStack()
    stack.add_pattern(loop_length_frames=88200)
    assert len(stack.patterns) == 1


def test_pattern_stack_active():
    stack = PatternStack()
    stack.add_pattern(loop_length_frames=88200)
    stack.add_pattern(loop_length_frames=88200)
    assert stack.active_index == 1  # newest is active


def test_pattern_stack_undo():
    stack = PatternStack()
    stack.add_pattern(loop_length_frames=88200)
    p = stack.patterns[0]
    p.record_event(frame=0, note=36, velocity=100)
    stack.add_pattern(loop_length_frames=88200)
    p2 = stack.patterns[1]
    p2.record_event(frame=0, note=38, velocity=100)
    stack.undo_last_pass()
    assert len(stack.patterns) == 1


def test_pattern_stack_redo():
    stack = PatternStack()
    stack.add_pattern(loop_length_frames=88200)
    stack.patterns[0].record_event(frame=0, note=36, velocity=100)
    stack.add_pattern(loop_length_frames=88200)
    stack.patterns[1].record_event(frame=0, note=38, velocity=100)
    stack.undo_last_pass()
    assert len(stack.patterns) == 1
    stack.redo()
    assert len(stack.patterns) == 2


def test_pattern_events_in_range():
    p = Pattern(loop_length_frames=88200)
    p.record_event(frame=1000, note=36, velocity=100)
    p.record_event(frame=5000, note=38, velocity=80)
    p.record_event(frame=9000, note=42, velocity=90)
    events = p.get_events_in_range(900, 5500)
    assert len(events) == 2
```

**Step 2: Run tests — verify fail**

**Step 3: Implement patterns**

```python
# src/god/patterns.py
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
    """A single MIDI event recorded at a specific frame position in the loop."""
    frame: int
    note: int
    velocity: int


@dataclass
class Pattern:
    """A single recorded layer — timestamped MIDI events within one loop."""
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
    """Manages stacked pattern layers with undo/redo."""

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
```

**Step 4: Run tests — verify pass**

**Step 5: Commit**

```bash
git add src/god/patterns.py tests/test_patterns.py
git commit -m "feat: pattern system with stacking, mute, undo/redo"
```

---

### Task 7: GOD capture — record output to disk

**Files:**
- Create: `src/god/capture.py`
- Create: `tests/test_capture.py`

GOD capture records the mixed audio output to a WAV file. Arms on button press, starts recording at next loop pass, stops on second press.

**Step 1: Write failing tests**

```python
# tests/test_capture.py
import numpy as np
from god.capture import GodCapture, CaptureState


def test_capture_initial_state():
    cap = GodCapture(sample_rate=44100)
    assert cap.state == CaptureState.IDLE


def test_capture_arm():
    cap = GodCapture(sample_rate=44100)
    cap.arm()
    assert cap.state == CaptureState.ARMED


def test_capture_start_on_pass():
    cap = GodCapture(sample_rate=44100)
    cap.arm()
    cap.on_loop_boundary()
    assert cap.state == CaptureState.RECORDING


def test_capture_write_buffer():
    cap = GodCapture(sample_rate=44100)
    cap.arm()
    cap.on_loop_boundary()
    buf = np.zeros(1024, dtype=np.float32)
    cap.write(buf)
    assert cap.frames_recorded == 1024


def test_capture_stop_saves_file(tmp_path):
    cap = GodCapture(sample_rate=44100, output_dir=str(tmp_path))
    cap.arm()
    cap.on_loop_boundary()
    buf = np.random.randn(44100).astype(np.float32)
    cap.write(buf)
    path = cap.stop()
    assert path is not None
    assert path.endswith(".wav")
    import soundfile as sf
    data, sr = sf.read(path)
    assert sr == 44100
    assert len(data) == 44100


def test_capture_idle_ignores_write():
    cap = GodCapture(sample_rate=44100)
    buf = np.zeros(1024, dtype=np.float32)
    cap.write(buf)
    assert cap.frames_recorded == 0
```

**Step 2: Run tests — verify fail**

**Step 3: Implement GOD capture**

```python
# src/god/capture.py
"""GOD — Genesis On Disk. Captures audio output to WAV."""

from __future__ import annotations

import enum
import os
from datetime import datetime

import numpy as np
import soundfile as sf


class CaptureState(enum.Enum):
    IDLE = "idle"
    ARMED = "armed"
    RECORDING = "recording"


class GodCapture:
    """Records audio output to disk."""

    def __init__(self, sample_rate: int = 44100, output_dir: str = "."):
        self.sample_rate = sample_rate
        self.output_dir = output_dir
        self.state = CaptureState.IDLE
        self._buffers: list[np.ndarray] = []
        self.frames_recorded: int = 0

    def arm(self) -> None:
        if self.state == CaptureState.IDLE:
            self.state = CaptureState.ARMED

    def on_loop_boundary(self) -> None:
        if self.state == CaptureState.ARMED:
            self.state = CaptureState.RECORDING
            self._buffers = []
            self.frames_recorded = 0

    def write(self, buffer: np.ndarray) -> None:
        if self.state != CaptureState.RECORDING:
            return
        self._buffers.append(buffer.copy())
        self.frames_recorded += len(buffer)

    def stop(self) -> str | None:
        if self.state != CaptureState.RECORDING or not self._buffers:
            self.state = CaptureState.IDLE
            return None
        audio = np.concatenate(self._buffers)
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"GOD_{timestamp}.wav"
        path = os.path.join(self.output_dir, filename)
        os.makedirs(self.output_dir, exist_ok=True)
        sf.write(path, audio, self.sample_rate)
        self.state = CaptureState.IDLE
        self._buffers = []
        self.frames_recorded = 0
        return path

    def toggle(self) -> None:
        """Single GOD button behavior."""
        if self.state == CaptureState.IDLE:
            self.arm()
        elif self.state == CaptureState.RECORDING:
            self.stop()
```

**Step 4: Run tests — verify pass**

**Step 5: Commit**

```bash
git add src/god/capture.py tests/test_capture.py
git commit -m "feat: GOD capture — record output to WAV on next pass"
```

---

### Task 8: Save system — manual save + auto-save

**Files:**
- Create: `src/god/save.py`
- Create: `tests/test_save.py`

Saves full session state (patterns, transport settings, pad assignments) to JSON. Auto-save runs periodically + on key actions.

**Step 1: Write failing tests**

```python
# tests/test_save.py
import json
from god.save import SessionState, SaveManager


def test_session_state_serializes():
    state = SessionState(bpm=90, bar_count=2, patterns=[], pad_assignments={})
    data = state.to_dict()
    assert data["bpm"] == 90
    assert data["bar_count"] == 2


def test_session_state_round_trip():
    state = SessionState(
        bpm=140,
        bar_count=4,
        patterns=[{"events": [{"frame": 100, "note": 36, "velocity": 80}], "volume": 0.8, "muted": False}],
        pad_assignments={36: "/path/to/kick.wav"},
    )
    data = state.to_dict()
    restored = SessionState.from_dict(data)
    assert restored.bpm == 140
    assert restored.bar_count == 4
    assert len(restored.patterns) == 1
    assert restored.pad_assignments[36] == "/path/to/kick.wav"


def test_save_manager_save_and_load(tmp_path):
    mgr = SaveManager(save_dir=str(tmp_path))
    state = SessionState(bpm=100, bar_count=1, patterns=[], pad_assignments={})
    path = mgr.save(state, name="test_session")
    assert path.endswith(".json")
    loaded = mgr.load(path)
    assert loaded.bpm == 100


def test_save_manager_autosave(tmp_path):
    mgr = SaveManager(save_dir=str(tmp_path))
    state = SessionState(bpm=120, bar_count=2, patterns=[], pad_assignments={})
    path = mgr.autosave(state)
    assert "autosave" in path
```

**Step 2: Run tests — verify fail**

**Step 3: Implement save system**

```python
# src/god/save.py
"""Save system — manual save + auto-save."""

from __future__ import annotations

import json
import os
from dataclasses import dataclass, field
from datetime import datetime


@dataclass
class SessionState:
    """Serializable session state."""
    bpm: int
    bar_count: int
    patterns: list[dict] = field(default_factory=list)
    pad_assignments: dict[int, str] = field(default_factory=dict)
    master_volume: float = 1.0

    def to_dict(self) -> dict:
        return {
            "bpm": self.bpm,
            "bar_count": self.bar_count,
            "patterns": self.patterns,
            "pad_assignments": {str(k): v for k, v in self.pad_assignments.items()},
            "master_volume": self.master_volume,
        }

    @classmethod
    def from_dict(cls, data: dict) -> SessionState:
        return cls(
            bpm=data["bpm"],
            bar_count=data["bar_count"],
            patterns=data.get("patterns", []),
            pad_assignments={int(k): v for k, v in data.get("pad_assignments", {}).items()},
            master_volume=data.get("master_volume", 1.0),
        )


class SaveManager:
    """Handles manual saves and auto-saves."""

    def __init__(self, save_dir: str = "~/.god/sessions"):
        self.save_dir = os.path.expanduser(save_dir)
        os.makedirs(self.save_dir, exist_ok=True)

    def save(self, state: SessionState, name: str = "") -> str:
        if not name:
            name = datetime.now().strftime("session_%Y%m%d_%H%M%S")
        filename = f"{name}.json"
        path = os.path.join(self.save_dir, filename)
        with open(path, "w") as f:
            json.dump(state.to_dict(), f, indent=2)
        return path

    def autosave(self, state: SessionState) -> str:
        return self.save(state, name="autosave")

    def load(self, path: str) -> SessionState:
        with open(path) as f:
            data = json.load(f)
        return SessionState.from_dict(data)

    def list_saves(self) -> list[str]:
        if not os.path.exists(self.save_dir):
            return []
        return sorted(
            [os.path.join(self.save_dir, f) for f in os.listdir(self.save_dir) if f.endswith(".json")],
            key=os.path.getmtime,
            reverse=True,
        )
```

**Step 4: Run tests — verify pass**

**Step 5: Commit**

```bash
git add src/god/save.py tests/test_save.py
git commit -m "feat: save system with manual save and auto-save"
```

---

### Task 9: Pad mapping — assign samples to MIDI notes

**Files:**
- Create: `src/god/pads.py`
- Create: `tests/test_pads.py`

Maps MIDI note numbers from MiniLab 3 pads to loaded samples. The MiniLab 3 pads send notes 36-51 (pad bank A) and 52-67 (pad bank B) by default.

**Step 1: Write failing tests**

```python
# tests/test_pads.py
import numpy as np
from god.pads import PadBank
from god.audio import Sample


def _make_sample() -> Sample:
    data = np.sin(np.linspace(0, 1, 4410)).astype(np.float32)
    return Sample(data=data, sample_rate=44100, name="test")


def test_pad_bank_creates():
    bank = PadBank()
    assert len(bank.pads) == 16


def test_pad_bank_assign_sample():
    bank = PadBank()
    sample = _make_sample()
    bank.assign(pad_index=0, sample=sample)
    assert bank.get_sample(pad_index=0) is sample


def test_pad_bank_note_to_pad():
    bank = PadBank()
    # MiniLab 3 pad bank A: notes 36-51
    assert bank.note_to_pad(36) == 0
    assert bank.note_to_pad(51) == 15
    assert bank.note_to_pad(35) is None  # out of range


def test_pad_bank_get_sample_by_note():
    bank = PadBank()
    sample = _make_sample()
    bank.assign(pad_index=0, sample=sample)
    assert bank.get_sample_by_note(36) is sample
    assert bank.get_sample_by_note(37) is None
```

**Step 2: Run tests — verify fail**

**Step 3: Implement pad mapping**

```python
# src/god/pads.py
"""Pad bank — maps MIDI notes to samples."""

from __future__ import annotations

from god.audio import Sample

# MiniLab 3 pad bank A default note range
PAD_NOTE_START = 36
PAD_COUNT = 16


class PadBank:
    """16 pads mapped to MIDI notes, each holding a sample."""

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
```

**Step 4: Run tests — verify pass**

**Step 5: Commit**

```bash
git add src/god/pads.py tests/test_pads.py
git commit -m "feat: pad bank mapping MIDI notes to samples"
```

---

### Task 10: Core loop — wire everything together

**Files:**
- Create: `src/god/engine.py`
- Create: `tests/test_engine.py`

The engine ties audio, transport, patterns, metronome, MIDI, pads, and capture together into one main loop driven by the sounddevice audio callback.

**Step 1: Write failing tests**

```python
# tests/test_engine.py
import numpy as np
from god.engine import GodEngine


def test_engine_creates():
    engine = GodEngine(sample_rate=44100, buffer_size=512)
    assert engine.transport.bpm == 120
    assert engine.pad_bank is not None
    assert engine.pattern_stack is not None


def test_engine_audio_callback_silent_when_stopped():
    engine = GodEngine(sample_rate=44100, buffer_size=512)
    buf = engine.process_block(512)
    assert np.allclose(buf, 0.0)


def test_engine_play_starts_transport():
    engine = GodEngine(sample_rate=44100, buffer_size=512)
    engine.play()
    assert engine.transport.playing is True


def test_engine_stop():
    engine = GodEngine(sample_rate=44100, buffer_size=512)
    engine.play()
    engine.stop()
    assert engine.transport.playing is False


def test_engine_set_bpm():
    engine = GodEngine(sample_rate=44100, buffer_size=512)
    engine.set_bpm(140)
    assert engine.transport.bpm == 140
```

**Step 2: Run tests — verify fail**

**Step 3: Implement engine**

```python
# src/god/engine.py
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
    """Central engine that drives GOD."""

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

        # Wire MIDI callback
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
        """Process one audio block — called from audio callback."""
        buf = np.zeros(frames, dtype=np.float32)

        if not self.transport.playing:
            return buf

        old_position = self.transport.position
        boundaries = self.transport.advance(frames)

        # Check for loop boundaries — handle pass transitions
        if boundaries:
            self.capture.on_loop_boundary()
            # Start a new pattern layer for the next pass
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

        # Mix active voices
        buf += self.audio.fill_buffer(frames)

        # GOD capture
        self.capture.write(buf)

        # Apply master volume
        buf *= self.audio.master_volume

        return buf
```

**Step 4: Run tests — verify pass**

**Step 5: Commit**

```bash
git add src/god/engine.py tests/test_engine.py
git commit -m "feat: core engine wiring all components together"
```

---

### Task 11: TUI — Textual interface with Claude aesthetic

**Files:**
- Create: `src/god/ui/__init__.py`
- Create: `src/god/ui/app.py`
- Create: `src/god/ui/theme.py`
- Create: `src/god/ui/widgets/__init__.py`
- Create: `src/god/ui/widgets/transport_bar.py`
- Create: `src/god/ui/widgets/pattern_list.py`
- Create: `src/god/ui/widgets/status_panel.py`

This is the big one. Build the Textual app with the Claude-inspired dark theme and all panels.

**Step 1: Create the theme**

```python
# src/god/ui/theme.py
"""GOD visual theme — Claude-inspired dark terminal aesthetic."""

# Color palette — muted purples/blues, clean and premium
COLORS = {
    "bg": "#1a1a2e",
    "surface": "#16213e",
    "surface_light": "#1f2b47",
    "border": "#2d3a5c",
    "text": "#e0e0e0",
    "text_dim": "#7a7a9e",
    "accent": "#7c6fe0",
    "accent_bright": "#a78bfa",
    "playing": "#4ade80",
    "muted": "#6b7280",
    "recording": "#ef4444",
    "armed": "#f59e0b",
    "god_active": "#ef4444",
    "god_armed": "#f59e0b",
    "meter": "#7c6fe0",
}

# Symbols for pattern states
SYMBOLS = {
    "playing": "▶",
    "muted": "◼",
    "recording": "●",
    "armed": "◉",
    "empty": "○",
    "god_idle": "◇",
    "god_armed": "◈",
    "god_recording": "◆",
    "bar_fill": "█",
    "bar_empty": "░",
    "pass_dot": "●",
    "pass_empty": "○",
}
```

**Step 2: Create the transport bar widget**

```python
# src/god/ui/widgets/transport_bar.py
"""Transport bar — tempo, bars, play/stop, GOD button."""

from textual.app import ComposeResult
from textual.reactive import reactive
from textual.widget import Widget
from textual.widgets import Static

from god.ui.theme import COLORS, SYMBOLS


class TransportBar(Widget):
    """Top bar showing transport controls and status."""

    DEFAULT_CSS = """
    TransportBar {
        dock: top;
        height: 3;
        background: $surface;
        border-bottom: solid $accent;
        layout: horizontal;
        padding: 0 1;
    }

    .transport-section {
        width: auto;
        padding: 0 2;
        content-align: center middle;
        height: 100%;
    }

    .tempo-display {
        color: $text;
        text-style: bold;
    }

    .bar-display {
        color: $text-dim;
    }

    .god-status {
        color: $text;
    }
    """

    bpm: reactive[int] = reactive(120)
    bar_count: reactive[int] = reactive(1)
    playing: reactive[bool] = reactive(False)
    current_bar: reactive[int] = reactive(1)
    god_state: reactive[str] = reactive("idle")
    loop_progress: reactive[float] = reactive(0.0)

    def compose(self) -> ComposeResult:
        yield Static("", id="tempo", classes="transport-section tempo-display")
        yield Static("", id="bars", classes="transport-section bar-display")
        yield Static("", id="loop-pos", classes="transport-section")
        yield Static("", id="god", classes="transport-section god-status")

    def watch_bpm(self, value: int) -> None:
        self.query_one("#tempo", Static).update(f" {value} BPM ")

    def watch_bar_count(self, value: int) -> None:
        self.query_one("#bars", Static).update(f" {value} BAR{'S' if value > 1 else ''} ")

    def watch_playing(self, value: bool) -> None:
        symbol = SYMBOLS["playing"] if value else SYMBOLS["muted"]
        self.query_one("#loop-pos", Static).update(f" {symbol} ")

    def watch_god_state(self, value: str) -> None:
        symbol = SYMBOLS.get(f"god_{value}", SYMBOLS["god_idle"])
        label = {"idle": "GOD", "armed": "GOD ARMED", "recording": "GOD REC"}
        self.query_one("#god", Static).update(f" {symbol} {label.get(value, 'GOD')} ")
```

**Step 3: Create the pattern list widget**

```python
# src/god/ui/widgets/pattern_list.py
"""Pattern list — shows stacked patterns with state indicators."""

from textual.app import ComposeResult
from textual.widget import Widget
from textual.widgets import Static

from god.ui.theme import SYMBOLS


class PatternRow(Static):
    """Single pattern row with state indicator."""

    DEFAULT_CSS = """
    PatternRow {
        height: 1;
        padding: 0 1;
    }

    PatternRow.playing {
        color: #4ade80;
    }

    PatternRow.muted {
        color: #6b7280;
    }

    PatternRow.recording {
        color: #ef4444;
        text-style: bold;
    }
    """

    def __init__(self, name: str, state: str, volume: float, index: int, active: bool = False):
        self._pattern_name = name
        self._state = state
        self._volume = volume
        self._index = index
        self._active = active
        super().__init__(self._render())
        self.add_class(state)

    def _render(self) -> str:
        symbol = SYMBOLS.get(self._state, SYMBOLS["empty"])
        active_marker = "→" if self._active else " "
        vol_bar = "█" * int(self._volume * 8) + "░" * (8 - int(self._volume * 8))
        return f" {active_marker} {symbol} {self._pattern_name:<16} {vol_bar} "


class PatternList(Widget):
    """Scrollable list of stacked patterns."""

    DEFAULT_CSS = """
    PatternList {
        height: 1fr;
        border: solid $accent;
        background: $surface;
        padding: 1;
    }
    """

    def compose(self) -> ComposeResult:
        yield Static(" PATTERNS ", id="pattern-header")

    def refresh_patterns(self, patterns: list[dict]) -> None:
        """Update the pattern list. Each dict has: name, state, volume, active."""
        # Remove old rows
        for row in self.query(PatternRow):
            row.remove()
        # Add new rows
        for i, p in enumerate(patterns):
            self.mount(PatternRow(
                name=p["name"],
                state=p["state"],
                volume=p["volume"],
                index=i,
                active=p.get("active", False),
            ))
```

**Step 4: Create the status panel**

```python
# src/god/ui/widgets/status_panel.py
"""Status panel — loop position, pass counter, visual indicators."""

from textual.app import ComposeResult
from textual.widget import Widget
from textual.widgets import Static

from god.ui.theme import SYMBOLS


class StatusPanel(Widget):
    """Shows loop position, bar, pass count, and metronome state."""

    DEFAULT_CSS = """
    StatusPanel {
        height: 5;
        dock: bottom;
        background: $surface;
        border-top: solid $accent;
        padding: 0 1;
    }
    """

    def compose(self) -> ComposeResult:
        yield Static("", id="loop-bar")
        yield Static("", id="pass-counter")
        yield Static("", id="metronome-status")

    def update_loop(self, progress: float, current_bar: int, total_bars: int) -> None:
        width = 40
        filled = int(progress * width)
        bar = SYMBOLS["bar_fill"] * filled + SYMBOLS["bar_empty"] * (width - filled)
        self.query_one("#loop-bar", Static).update(f" BAR {current_bar}/{total_bars}  {bar} ")

    def update_passes(self, count: int) -> None:
        max_display = 16
        shown = min(count, max_display)
        dots = SYMBOLS["pass_dot"] * shown
        if count > max_display:
            dots += f" +{count - max_display}"
        self.query_one("#pass-counter", Static).update(f" PASSES  {dots} ")

    def update_metronome(self, enabled: bool, sound_name: str) -> None:
        state = "ON" if enabled else "OFF"
        self.query_one("#metronome-status", Static).update(f" METRONOME {state}  {sound_name} ")
```

**Step 5: Create the main app**

```python
# src/god/ui/__init__.py
"""GOD TUI package."""
```

```python
# src/god/ui/widgets/__init__.py
"""GOD UI widgets."""
```

```python
# src/god/ui/app.py
"""Main GOD Textual application."""

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.widgets import Footer, Header

from god.engine import GodEngine
from god.ui.theme import COLORS
from god.ui.widgets.pattern_list import PatternList
from god.ui.widgets.status_panel import StatusPanel
from god.ui.widgets.transport_bar import TransportBar


class GodApp(App):
    """GOD — Genesis On Disk."""

    TITLE = "GOD"
    SUB_TITLE = "Genesis On Disk"

    CSS = """
    Screen {
        background: #1a1a2e;
    }

    Header {
        background: #16213e;
        color: #a78bfa;
    }

    Footer {
        background: #16213e;
        color: #7a7a9e;
    }
    """

    BINDINGS = [
        Binding("space", "toggle_play", "Play/Stop"),
        Binding("escape", "stop_all", "Stop All"),
        Binding("g", "god_toggle", "GOD"),
        Binding("u", "undo", "Undo"),
        Binding("r", "redo", "Redo"),
        Binding("m", "toggle_metronome", "Metronome"),
        Binding("up", "bpm_up", "BPM +1", show=False),
        Binding("down", "bpm_down", "BPM -1", show=False),
        Binding("1", "set_bars_1", "1 Bar", show=False),
        Binding("2", "set_bars_2", "2 Bars", show=False),
        Binding("4", "set_bars_4", "4 Bars", show=False),
        Binding("q", "quit", "Quit"),
    ]

    def __init__(self):
        super().__init__()
        self.engine = GodEngine()

    def compose(self) -> ComposeResult:
        yield Header()
        yield TransportBar()
        yield PatternList()
        yield StatusPanel()
        yield Footer()

    def on_mount(self) -> None:
        self.engine.midi.connect()
        self._refresh_ui()
        self.set_interval(1 / 30, self._refresh_ui)

    def _refresh_ui(self) -> None:
        transport = self.query_one(TransportBar)
        transport.bpm = self.engine.transport.bpm
        transport.bar_count = self.engine.transport.bar_count
        transport.playing = self.engine.transport.playing
        transport.current_bar = self.engine.transport.current_bar
        transport.god_state = self.engine.capture.state.value

        patterns = self.query_one(PatternList)
        pattern_data = []
        for i, p in enumerate(self.engine.pattern_stack.patterns):
            pattern_data.append({
                "name": p.name,
                "state": p.state.value,
                "volume": p.volume,
                "active": i == self.engine.pattern_stack.active_index,
            })
        patterns.refresh_patterns(pattern_data)

        status = self.query_one(StatusPanel)
        status.update_loop(
            self.engine.transport.loop_progress,
            self.engine.transport.current_bar,
            self.engine.transport.bar_count,
        )
        status.update_passes(self.engine.transport.pass_number)
        status.update_metronome(
            self.engine.metronome.enabled,
            self.engine.metronome.sound.value,
        )

    def action_toggle_play(self) -> None:
        if self.engine.transport.playing:
            self.engine.stop()
        else:
            self.engine.play()

    def action_stop_all(self) -> None:
        self.engine.stop_all()

    def action_god_toggle(self) -> None:
        self.engine.god_toggle()

    def action_undo(self) -> None:
        self.engine.undo_last_pass()

    def action_redo(self) -> None:
        self.engine.redo()

    def action_toggle_metronome(self) -> None:
        self.engine.metronome.toggle()

    def action_bpm_up(self) -> None:
        self.engine.set_bpm(self.engine.transport.bpm + 1)

    def action_bpm_down(self) -> None:
        self.engine.set_bpm(self.engine.transport.bpm - 1)

    def action_set_bars_1(self) -> None:
        self.engine.set_bar_count(1)

    def action_set_bars_2(self) -> None:
        self.engine.set_bar_count(2)

    def action_set_bars_4(self) -> None:
        self.engine.set_bar_count(4)
```

**Step 6: Update main.py entry point**

```python
# src/god/main.py
"""Entry point for GOD."""


def run():
    from god.ui.app import GodApp
    app = GodApp()
    app.run()


if __name__ == "__main__":
    run()
```

**Step 7: Commit**

```bash
git add src/god/ui/ src/god/main.py
git commit -m "feat: TUI interface with Claude-inspired theme and all panels"
```

---

### Task 12: Audio stream — connect sounddevice output

**Files:**
- Modify: `src/god/engine.py`

Connect the engine's `process_block` to a real sounddevice output stream so audio actually plays.

**Step 1: Add stream management to engine**

Add these methods to `GodEngine`:

```python
def start_audio_stream(self) -> None:
    """Open the sounddevice output stream."""
    import sounddevice as sd
    self._stream = sd.OutputStream(
        samplerate=self.sample_rate,
        blocksize=self.buffer_size,
        channels=1,
        dtype="float32",
        callback=self._audio_callback,
    )
    self._stream.start()

def _audio_callback(self, outdata, frames, time_info, status) -> None:
    """Called by sounddevice to fill the output buffer."""
    buf = self.process_block(frames)
    outdata[:, 0] = buf

def stop_audio_stream(self) -> None:
    if hasattr(self, "_stream"):
        self._stream.stop()
        self._stream.close()
```

**Step 2: Wire into app on_mount and on_unmount**

Update `GodApp.on_mount`:

```python
def on_mount(self) -> None:
    self.engine.midi.connect()
    self.engine.start_audio_stream()
    self._refresh_ui()
    self.set_interval(1 / 30, self._refresh_ui)

def on_unmount(self) -> None:
    self.engine.stop_audio_stream()
    self.engine.midi.disconnect()
```

**Step 3: Test manually**

```bash
cd ~/god && source .venv/bin/activate && god
```

Expected: GOD launches in terminal, metronome clicks when you press space to play.

**Step 4: Commit**

```bash
git add src/god/engine.py src/god/ui/app.py
git commit -m "feat: connect audio output stream via sounddevice"
```

---

### Task 13: Splice sample loading

**Files:**
- Create: `src/god/samples.py`
- Create: `tests/test_samples.py`

Browse and load samples from `~/Splice/sounds/packs/`. Simple file listing for now — the TUI will get a sample loading screen later.

**Step 1: Write failing tests**

```python
# tests/test_samples.py
import os
from god.samples import SpliceBrowser


def test_splice_browser_finds_directory():
    browser = SpliceBrowser()
    assert os.path.isdir(browser.root_path)


def test_splice_browser_list_packs():
    browser = SpliceBrowser()
    packs = browser.list_packs()
    assert isinstance(packs, list)
    # We know there are packs in ~/Splice/sounds/packs/
    assert len(packs) > 0


def test_splice_browser_list_samples_in_pack():
    browser = SpliceBrowser()
    packs = browser.list_packs()
    if packs:
        samples = browser.list_samples(packs[0])
        assert isinstance(samples, list)
```

**Step 2: Implement**

```python
# src/god/samples.py
"""Splice sample browser."""

from __future__ import annotations

import os


class SpliceBrowser:
    """Browse Splice sample packs."""

    def __init__(self, root_path: str = "~/Splice/sounds/packs"):
        self.root_path = os.path.expanduser(root_path)

    def list_packs(self) -> list[str]:
        if not os.path.isdir(self.root_path):
            return []
        return sorted(
            d for d in os.listdir(self.root_path)
            if os.path.isdir(os.path.join(self.root_path, d))
        )

    def list_samples(self, pack_name: str) -> list[str]:
        pack_path = os.path.join(self.root_path, pack_name)
        if not os.path.isdir(pack_path):
            return []
        samples = []
        for root, _dirs, files in os.walk(pack_path):
            for f in files:
                if f.lower().endswith((".wav", ".mp3", ".flac", ".ogg")):
                    samples.append(os.path.join(root, f))
        return sorted(samples)
```

**Step 3: Run tests — verify pass**

**Step 4: Commit**

```bash
git add src/god/samples.py tests/test_samples.py
git commit -m "feat: Splice sample browser"
```

---

### Task 14: Integration — load samples onto pads via CLI args or config

**Files:**
- Modify: `src/god/main.py`

For v1, allow loading samples onto pads via a simple JSON config or command-line arguments. Full TUI sample browsing comes later.

**Step 1: Add config-based pad loading**

```python
# src/god/main.py
"""Entry point for GOD."""

import json
import os
import sys


def run():
    from god.audio import Sample
    from god.ui.app import GodApp

    app = GodApp()

    # Load pad config if it exists
    config_path = os.path.expanduser("~/.god/pads.json")
    if os.path.exists(config_path):
        with open(config_path) as f:
            pad_config = json.load(f)
        for pad_str, sample_path in pad_config.items():
            pad_idx = int(pad_str)
            if os.path.exists(sample_path):
                sample = Sample.from_file(sample_path)
                app.engine.pad_bank.assign(pad_idx, sample)

    app.run()


if __name__ == "__main__":
    run()
```

**Step 2: Create example pads.json**

```bash
mkdir -p ~/.god
```

```json
{
    "0": "/path/to/kick.wav",
    "1": "/path/to/snare.wav",
    "2": "/path/to/hihat.wav"
}
```

**Step 3: Commit**

```bash
git add src/god/main.py
git commit -m "feat: load pad samples from ~/.god/pads.json config"
```

---

### Task 15: End-to-end manual test and polish

**Step 1: Create a test pads.json using actual Splice samples**

```bash
# Find some one-shot samples to map to pads
find ~/Splice/sounds/packs -name "*kick*" -name "*.wav" | head -1
find ~/Splice/sounds/packs -name "*snare*" -name "*.wav" | head -1
find ~/Splice/sounds/packs -name "*hat*" -name "*.wav" | head -1
```

Write those paths into `~/.god/pads.json`.

**Step 2: Run GOD**

```bash
cd ~/god && source .venv/bin/activate && god
```

**Step 3: Test the full workflow**

1. GOD launches — verify clean TUI with Claude theme
2. Press Space — loop starts, metronome clicks
3. Play MiniLab 3 pads — samples trigger
4. Loop comes around — hear your recorded pattern play back
5. Play more — new layer stacks on top
6. Press U — last layer removed
7. Press G — GOD armed indicator shows
8. Next loop pass — recording starts, indicator changes
9. Press G again — recording stops, WAV saved
10. Press Q — GOD exits

**Step 4: Fix any issues found**

**Step 5: Final commit**

```bash
git add -A
git commit -m "feat: GOD v1 complete — loop stacking instrument"
```

---

Plan complete and saved to `docs/plans/2026-03-08-god-v1-implementation.md`. Two execution options:

**1. Subagent-Driven (this session)** — I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** — Open new session with executing-plans, batch execution with checkpoints

**Which approach?**
