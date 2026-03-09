from god.patterns import Pattern, PatternState, PatternStack


def test_pattern_creates_empty():
    p = Pattern(loop_length_frames=88200)
    assert len(p.events) == 0
    assert p.state == PatternState.EMPTY
    assert p.volume == 1.0


def test_pattern_record_event():
    p = Pattern(loop_length_frames=88200)
    p.record_event(frame=1000, note=36, velocity=100)
    assert len(p.events) == 1
    assert p.events[0].frame == 1000
    assert p.events[0].note == 36


def test_pattern_state_transitions():
    p = Pattern(loop_length_frames=88200)
    assert p.state == PatternState.EMPTY
    p.record_event(frame=0, note=36, velocity=100)
    assert p.state == PatternState.PLAYING
    p.mute()
    assert p.state == PatternState.MUTED
    p.unmute()
    assert p.state == PatternState.PLAYING


def test_pattern_volume_clamp():
    p = Pattern(loop_length_frames=88200)
    p.set_volume(1.5)
    assert p.volume == 1.0
    p.set_volume(-0.5)
    assert p.volume == 0.0


def test_pattern_stack_add():
    stack = PatternStack()
    stack.add_pattern(loop_length_frames=88200)
    assert len(stack.patterns) == 1


def test_pattern_stack_active():
    stack = PatternStack()
    stack.add_pattern(loop_length_frames=88200)
    stack.add_pattern(loop_length_frames=88200)
    assert stack.active_index == 1


def test_pattern_stack_undo():
    stack = PatternStack()
    stack.add_pattern(loop_length_frames=88200)
    p = stack.patterns[0]
    p.record_event(frame=0, note=36, velocity=100)
    stack.add_pattern(loop_length_frames=88200)
    p2 = stack.patterns[1]
    p2.record_event(frame=0, note=38, velocity=100)
    stack.undo_last_pass()
    assert len(stack.patterns) == 1


def test_pattern_stack_redo():
    stack = PatternStack()
    stack.add_pattern(loop_length_frames=88200)
    stack.patterns[0].record_event(frame=0, note=36, velocity=100)
    stack.add_pattern(loop_length_frames=88200)
    stack.patterns[1].record_event(frame=0, note=38, velocity=100)
    stack.undo_last_pass()
    assert len(stack.patterns) == 1
    stack.redo()
    assert len(stack.patterns) == 2


def test_pattern_events_in_range():
    p = Pattern(loop_length_frames=88200)
    p.record_event(frame=1000, note=36, velocity=100)
    p.record_event(frame=5000, note=38, velocity=80)
    p.record_event(frame=9000, note=42, velocity=90)
    events = p.get_events_in_range(900, 5500)
    assert len(events) == 2
