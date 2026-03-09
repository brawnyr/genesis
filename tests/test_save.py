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
