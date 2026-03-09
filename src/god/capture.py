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
        if self.state == CaptureState.IDLE:
            self.arm()
        elif self.state == CaptureState.RECORDING:
            self.stop()
