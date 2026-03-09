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
    assert bank.note_to_pad(36) == 0
    assert bank.note_to_pad(51) == 15
    assert bank.note_to_pad(35) is None


def test_pad_bank_get_sample_by_note():
    bank = PadBank()
    sample = _make_sample()
    bank.assign(pad_index=0, sample=sample)
    assert bank.get_sample_by_note(36) is sample
    assert bank.get_sample_by_note(37) is None
