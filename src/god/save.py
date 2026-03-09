"""Save system — manual save + auto-save."""
from __future__ import annotations
import json
import os
from dataclasses import dataclass, field
from datetime import datetime


@dataclass
class SessionState:
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
