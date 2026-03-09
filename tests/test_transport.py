from god.transport import Transport


def test_transport_defaults():
    transport = Transport(sample_rate=44100)
    assert transport.bpm == 120
    assert transport.bar_count == 1
    assert transport.playing is False
    assert transport.pass_number == 0


def test_set_bpm_whole_numbers_only():
    transport = Transport(sample_rate=44100)
    transport.set_bpm(90)
    assert transport.bpm == 90
    transport.set_bpm(90.5)
    assert transport.bpm == 90


def test_loop_length_in_frames():
    transport = Transport(sample_rate=44100)
    transport.set_bpm(120)
    transport.set_bar_count(1)
    assert transport.loop_length_frames == 88200


def test_loop_length_4_bars():
    transport = Transport(sample_rate=44100)
    transport.set_bpm(120)
    transport.set_bar_count(4)
    assert transport.loop_length_frames == 352800


def test_bar_count_only_1_2_4():
    transport = Transport(sample_rate=44100)
    transport.set_bar_count(3)
    assert transport.bar_count == 1


def test_advance_wraps_and_counts_passes():
    transport = Transport(sample_rate=44100)
    transport.set_bpm(120)
    transport.set_bar_count(1)
    transport.playing = True
    transport.advance(88199)
    assert transport.pass_number == 0
    transport.advance(1)
    assert transport.pass_number == 1
    assert transport.position == 0


def test_current_bar():
    transport = Transport(sample_rate=44100)
    transport.set_bpm(120)
    transport.set_bar_count(4)
    transport.playing = True
    transport.advance(88200 + 44100)
    assert transport.current_bar == 2


def test_loop_progress():
    transport = Transport(sample_rate=44100)
    transport.set_bpm(120)
    transport.set_bar_count(1)
    transport.playing = True
    transport.advance(44100)
    progress = transport.loop_progress
    assert 0.49 < progress < 0.51
