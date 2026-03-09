import numpy as np
from god.metronome import Metronome, MetronomeSound


def test_metronome_creates():
    met = Metronome(sample_rate=44100)
    assert met.enabled is True
    assert met.sound == MetronomeSound.SOFT_CLICK


def test_metronome_sounds_available():
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
