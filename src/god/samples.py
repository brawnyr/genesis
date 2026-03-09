"""Splice sample browser."""
from __future__ import annotations
import os


class SpliceBrowser:
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
