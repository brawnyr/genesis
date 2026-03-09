"""Metronome — pleasant click generation."""
from __future__ import annotations
import enum
import numpy as np


class MetronomeSound(enum.Enum):
    SOFT_CLICK = "soft_click"
    WOODBLOCK = "woodblock"
    TICK = "tick"


class Metronome:
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
        return (np.sin(2 * np.pi * freq * t) * envelope * amp * self.volume).astype(np.float32)

    def _woodblock(self, downbeat: bool) -> np.ndarray:
        duration = 0.03
        n = int(self.sample_rate * duration)
        t = np.linspace(0, duration, n, dtype=np.float32)
        freq = 800 if downbeat else 600
        amp = 0.35 if downbeat else 0.2
        envelope = np.exp(-t * 100).astype(np.float32)
        tone = (np.sin(2 * np.pi * freq * t) * 0.7 + np.sin(2 * np.pi * freq * 2.3 * t) * 0.3)
        return (tone * envelope * amp * self.volume).astype(np.float32)

    def _tick(self, downbeat: bool) -> np.ndarray:
        duration = 0.01
        n = int(self.sample_rate * duration)
        t = np.linspace(0, duration, n, dtype=np.float32)
        freq = 2000 if downbeat else 1500
        amp = 0.3 if downbeat else 0.18
        envelope = np.exp(-t * 300).astype(np.float32)
        return (np.sin(2 * np.pi * freq * t) * envelope * amp * self.volume).astype(np.float32)
