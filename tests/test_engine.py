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
