"""Audio engine for GOD — sample loading, playback, and mixing."""
from __future__ import annotations
import numpy as np
import soundfile as sf


class Sample:
    __slots__ = ("data", "sample_rate", "name")

    def __init__(self, data: np.ndarray, sample_rate: int, name: str = ""):
        self.data = data.astype(np.float32)
        self.sample_rate = sample_rate
        self.name = name

    @classmethod
    def from_file(cls, path: str) -> Sample:
        data, sr = sf.read(path, dtype="float32")
        if data.ndim > 1:
            data = data.mean(axis=1)
        return cls(data=data, sample_rate=sr, name=path.split("/")[-1])


class AudioEngine:
    def __init__(self, sample_rate: int = 44100):
        self.sample_rate = sample_rate
        self.master_volume: float = 1.0
        self._voices: list[Voice] = []

    def set_master_volume(self, volume: float) -> None:
        self.master_volume = max(0.0, min(1.0, volume))

    def trigger_sample(self, sample: Sample, volume: float = 1.0) -> None:
        self._voices.append(Voice(sample=sample, volume=volume))

    def fill_buffer(self, frames: int) -> np.ndarray:
        buf = np.zeros(frames, dtype=np.float32)
        finished = []
        for i, voice in enumerate(self._voices):
            written = voice.read_into(buf)
            if not written:
                finished.append(i)
        for i in reversed(finished):
            self._voices.pop(i)
        buf *= self.master_volume
        return buf


class Voice:
    __slots__ = ("sample", "volume", "_position")

    def __init__(self, sample: Sample, volume: float = 1.0):
        self.sample = sample
        self.volume = volume
        self._position = 0

    def read_into(self, buf: np.ndarray) -> bool:
        remaining = len(self.sample.data) - self._position
        if remaining <= 0:
            return False
        n = min(len(buf), remaining)
        buf[:n] += self.sample.data[self._position : self._position + n] * self.volume
        self._position += n
        return self._position < len(self.sample.data)
