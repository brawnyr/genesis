import numpy as np
from god.audio import Sample, AudioEngine


def test_sample_load_wav(tmp_path):
    import soundfile as sf
    sr = 44100
    duration = 0.1
    samples = np.sin(2 * np.pi * 440 * np.linspace(0, duration, int(sr * duration)))
    path = tmp_path / "test.wav"
    sf.write(str(path), samples, sr)
    sample = Sample.from_file(str(path))
    assert sample.sample_rate == sr
    assert len(sample.data) > 0


def test_sample_data_is_float32(tmp_path):
    import soundfile as sf
    sr = 44100
    samples = np.sin(2 * np.pi * 440 * np.linspace(0, 0.1, int(sr * 0.1)))
    path = tmp_path / "test.wav"
    sf.write(str(path), samples, sr)
    sample = Sample.from_file(str(path))
    assert sample.data.dtype == np.float32


def test_audio_engine_creates():
    engine = AudioEngine(sample_rate=44100)
    assert engine.sample_rate == 44100
    assert engine.master_volume == 1.0


def test_audio_engine_set_master_volume():
    engine = AudioEngine(sample_rate=44100)
    engine.set_master_volume(0.5)
    assert engine.master_volume == 0.5
    engine.set_master_volume(1.5)
    assert engine.master_volume == 1.0
    engine.set_master_volume(-0.5)
    assert engine.master_volume == 0.0
